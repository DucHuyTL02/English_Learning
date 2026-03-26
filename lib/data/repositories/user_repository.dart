import '../datasources/user_local_datasource.dart';
import '../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRepositoryException implements Exception {
  UserRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UserRepository {
  UserRepository(this._localDataSource);

  final UserLocalDataSource _localDataSource;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final RegExp _emailRegex = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    caseSensitive: false,
  );

  Future<UserModel?> getActiveUser() {
    return _localDataSource.getActiveUser();
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      if (normalizedEmail.isEmpty || password.trim().isEmpty) {
        throw UserRepositoryException(
          'Vui lòng nhập đầy đủ email và mật khẩu.',
        );
      }

      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw UserRepositoryException('Không thể tải phiên đăng nhập.');
      }

      final activeUser = await _upsertLocalUserFromFirebase(
        firebaseUser: firebaseUser,
        password: password,
      );
      await _syncUserProfileToFirestore(activeUser);
      return activeUser;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'wrong-password') {
        final migrated = await _tryMigrateLegacyLocalAccount(
          email: normalizedEmail,
          password: password,
        );
        if (migrated != null) {
          return migrated;
        }
      }
      throw UserRepositoryException(_mapFirebaseAuthError(e));
    } on UserRepositoryException {
      rethrow;
    } catch (_) {
      throw UserRepositoryException('Đăng nhập thất bại, vui lòng thử lại.');
    }
  }

  Future<UserModel> registerUser({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final trimmedName = fullName.trim();
      final normalizedEmail = email.trim().toLowerCase();
      if (trimmedName.isEmpty || normalizedEmail.isEmpty || password.isEmpty) {
        throw UserRepositoryException(
          'Vui lòng điền đầy đủ thông tin đăng ký.',
        );
      }
      if (!_emailRegex.hasMatch(normalizedEmail)) {
        throw UserRepositoryException('Email không đúng định dạng.');
      }
      if (password.length < 6) {
        throw UserRepositoryException('Mật khẩu phải có ít nhất 6 ký tự.');
      }

      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw UserRepositoryException('Không thể tạo tài khoản.');
      }

      if (trimmedName.isNotEmpty) {
        await firebaseUser.updateDisplayName(trimmedName);
      }

      final created = await _upsertLocalUserFromFirebase(
        firebaseUser: firebaseUser,
        password: password,
        preferredFullName: trimmedName,
      );
      await _syncUserProfileToFirestore(created);
      return created;
    } on FirebaseAuthException catch (e) {
      throw UserRepositoryException(_mapFirebaseAuthError(e));
    } on UserRepositoryException {
      rethrow;
    } catch (_) {
      throw UserRepositoryException('Đăng ký thất bại, vui lòng thử lại.');
    }
  }

  Future<UserModel> updateProfile({
    required int userId,
    required String fullName,
    required String email,
    required String bio,
    required String location,
    required String birthDate,
  }) async {
    try {
      final user = await _localDataSource.getUserById(userId);
      if (user == null) {
        throw UserRepositoryException('Không tìm thấy tài khoản để cập nhật.');
      }

      final trimmedName = fullName.trim();
      final normalizedEmail = email.trim().toLowerCase();
      if (trimmedName.isEmpty || normalizedEmail.isEmpty) {
        throw UserRepositoryException('Họ tên và email không được để trống.');
      }
      if (!_emailRegex.hasMatch(normalizedEmail)) {
        throw UserRepositoryException('Email không đúng định dạng.');
      }

      final duplicatedEmailUser = await _localDataSource.getUserByEmail(
        normalizedEmail,
      );
      if (duplicatedEmailUser != null && duplicatedEmailUser.id != userId) {
        throw UserRepositoryException(
          'Email này đang được dùng bởi tài khoản khác.',
        );
      }

      final updated = user.copyWith(
        fullName: trimmedName,
        email: normalizedEmail,
        bio: bio.trim(),
        location: location.trim(),
        birthDate: birthDate.trim(),
        updatedAt: DateTime.now(),
      );

      final currentFirebaseUser = _firebaseAuth.currentUser;
      if (currentFirebaseUser != null && currentFirebaseUser.uid == user.firebaseUid) {
        if ((currentFirebaseUser.displayName ?? '').trim() != trimmedName) {
          await currentFirebaseUser.updateDisplayName(trimmedName);
        }
        final currentEmail = (currentFirebaseUser.email ?? '').trim().toLowerCase();
        if (currentEmail != normalizedEmail) {
          await currentFirebaseUser.verifyBeforeUpdateEmail(normalizedEmail);
        }
      }

      await _localDataSource.updateUser(updated);
      final refreshed = await _localDataSource.getUserById(userId);
      if (refreshed == null) {
        throw UserRepositoryException('Không thể tải hồ sơ sau khi cập nhật.');
      }
      await _syncUserProfileToFirestore(refreshed);
      return refreshed;
    } on FirebaseAuthException catch (e) {
      throw UserRepositoryException(_mapFirebaseAuthError(e));
    } on UserRepositoryException {
      rethrow;
    } catch (_) {
      throw UserRepositoryException('Cập nhật hồ sơ thất bại.');
    }
  }

  Future<UserModel> updatePreferences({
    required int userId,
    required bool notificationsEnabled,
    required bool soundEnabled,
    required bool darkModeEnabled,
  }) async {
    try {
      final user = await _localDataSource.getUserById(userId);
      if (user == null) {
        throw UserRepositoryException(
          'Không tìm thấy tài khoản để cập nhật cài đặt.',
        );
      }
      final updated = user.copyWith(
        notificationsEnabled: notificationsEnabled,
        soundEnabled: soundEnabled,
        darkModeEnabled: darkModeEnabled,
        updatedAt: DateTime.now(),
      );
      await _localDataSource.updateUser(updated);
      final refreshed = await _localDataSource.getUserById(userId);
      if (refreshed == null) {
        throw UserRepositoryException(
          'Không thể tải cài đặt sau khi cập nhật.',
        );
      }
      return refreshed;
    } on UserRepositoryException {
      rethrow;
    } catch (_) {
      throw UserRepositoryException('Không thể cập nhật cài đặt.');
    }
  }

  Future<void> deleteUser(int userId) async {
    try {
      final user = await _localDataSource.getUserById(userId);
      if (user == null) return;

      // Xóa tài liệu Firestore nếu có.
      if (user.firebaseUid != null && user.firebaseUid!.isNotEmpty) {
        try {
          await _firestore.collection('users').doc(user.firebaseUid).delete();
        } catch (_) {
          // Best-effort Firestore cleanup.
        }
      }

      // Xóa Firebase Auth account nếu đang đăng nhập bằng user đó.
      final currentFirebaseUser = _firebaseAuth.currentUser;
      if (currentFirebaseUser != null &&
          user.firebaseUid != null &&
          currentFirebaseUser.uid == user.firebaseUid) {
        try {
          await currentFirebaseUser.delete();
        } on FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login') {
            throw UserRepositoryException(
              'Vui lòng đăng nhập lại trước khi xóa tài khoản.',
            );
          }
          // Other errors: still proceed with local deletion.
        }
      }

      await _localDataSource.deleteUserById(userId);

      if (!user.isActive) return;
      final remainingUsers = await _localDataSource.getAllUsers();
      if (remainingUsers.isEmpty) {
        // Sign out if no users left.
        try { await _firebaseAuth.signOut(); } catch (_) {}
        return;
      }
      final nextUser = remainingUsers.firstWhere(
        (item) => item.id != null,
        orElse: () => remainingUsers.first,
      );
      if (nextUser.id != null) {
        await _localDataSource.setOnlyActiveUser(nextUser.id!);
      }
    } on UserRepositoryException {
      rethrow;
    } catch (_) {
      throw UserRepositoryException('Không thể xóa tài khoản.');
    }
  }

  Future<void> deleteActiveUser() async {
    try {
      final active = await _localDataSource.getActiveUser();
      if (active?.id == null) return;
      await deleteUser(active!.id!);
    } on UserRepositoryException {
      rethrow;
    } catch (_) {
      throw UserRepositoryException('Không thể xóa tài khoản hiện tại.');
    }
  }

  Future<void> logoutActiveUser() async {
    try {
      await _firebaseAuth.signOut();
      await _localDataSource.deactivateAllUsers();
    } catch (_) {
      throw UserRepositoryException('Đăng xuất thất bại.');
    }
  }

  Future<bool> verifyPassword(int userId, String password) async {
    try {
      final user = await _localDataSource.getUserById(userId);
      if (user == null) return false;
      return user.password == password;
    } catch (_) {
      return false;
    }
  }

  Future<void> updatePassword(int userId, String newPassword) async {
    try {
      final user = await _localDataSource.getUserById(userId);
      if (user == null) {
        throw UserRepositoryException('Không tìm thấy tài khoản.');
      }
      final currentFirebaseUser = _firebaseAuth.currentUser;
      if (currentFirebaseUser != null && currentFirebaseUser.uid == user.firebaseUid) {
        await currentFirebaseUser.updatePassword(newPassword);
      }
      final updated = user.copyWith(password: newPassword, updatedAt: DateTime.now());
      await _localDataSource.updateUser(updated);
    } catch (e) {
      if (e is FirebaseAuthException) {
        throw UserRepositoryException(_mapFirebaseAuthError(e));
      }
      if (e is UserRepositoryException) rethrow;
      throw UserRepositoryException('Không thể đổi mật khẩu.');
    }
  }

  Future<List<UserModel>> getAllLocalUsers() {
    return _localDataSource.getAllUsers();
  }

  /// Gửi email đặt lại mật khẩu qua Firebase Auth.
  Future<void> sendPasswordResetEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw UserRepositoryException('Vui lòng nhập email.');
    }
    if (!_emailRegex.hasMatch(normalizedEmail)) {
      throw UserRepositoryException('Email không đúng định dạng.');
    }
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: normalizedEmail);
    } on FirebaseAuthException catch (e) {
      throw UserRepositoryException(_mapFirebaseAuthError(e));
    } catch (_) {
      throw UserRepositoryException(
        'Không thể gửi email đặt lại mật khẩu. Vui lòng thử lại.',
      );
    }
  }

  /// Xác thực lại người dùng trước khi thực hiện thao tác nhạy cảm (xóa tài khoản).
  /// Nếu Firebase session chưa có (app restart), sẽ đăng nhập lại trước.
  Future<void> reauthenticate(String password, {int? userId}) async {
    final trimmedPassword = password.trim();
    if (trimmedPassword.isEmpty) {
      throw UserRepositoryException('Vui lòng nhập mật khẩu.');
    }

    var currentFirebaseUser = _firebaseAuth.currentUser;

    // Nếu chưa có Firebase session, đăng nhập lại bằng email từ local DB.
    if (currentFirebaseUser == null && userId != null) {
      final localUser = await _localDataSource.getUserById(userId);
      if (localUser != null && localUser.email.isNotEmpty) {
        try {
          final credential = await _firebaseAuth.signInWithEmailAndPassword(
            email: localUser.email,
            password: trimmedPassword,
          );
          currentFirebaseUser = credential.user;
        } on FirebaseAuthException catch (e) {
          throw UserRepositoryException(_mapFirebaseAuthError(e));
        }
      }
    }

    if (currentFirebaseUser == null || currentFirebaseUser.email == null) {
      throw UserRepositoryException('Không tìm thấy phiên đăng nhập. Vui lòng đăng xuất rồi đăng nhập lại.');
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: currentFirebaseUser.email!,
        password: trimmedPassword,
      );
      await currentFirebaseUser.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw UserRepositoryException(_mapFirebaseAuthError(e));
    }
  }

  Future<UserModel> _upsertLocalUserFromFirebase({
    required User firebaseUser,
    required String password,
    String? preferredFullName,
  }) async {
    final now = DateTime.now();
    final normalizedEmail = (firebaseUser.email ?? '').trim().toLowerCase();

    final byUid = await _localDataSource.getUserByFirebaseUid(firebaseUser.uid);
    final byEmail = byUid == null && normalizedEmail.isNotEmpty
        ? await _localDataSource.getUserByEmail(normalizedEmail)
        : null;
    final existing = byUid ?? byEmail;

    final displayName = preferredFullName?.trim().isNotEmpty == true
        ? preferredFullName!.trim()
        : ((firebaseUser.displayName ?? '').trim().isNotEmpty
              ? firebaseUser.displayName!.trim()
              : (existing?.fullName.isNotEmpty == true
                    ? existing!.fullName
                    : _nameFromEmail(normalizedEmail)));

    if (existing == null) {
      final created = UserModel(
        firebaseUid: firebaseUser.uid,
        fullName: displayName,
        email: normalizedEmail,
        password: password,
        bio: '',
        location: '',
        birthDate: '',
        avatarEmoji: '👤',
        notificationsEnabled: true,
        soundEnabled: true,
        darkModeEnabled: false,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      final insertedId = await _localDataSource.insertUser(created);
      await _localDataSource.setOnlyActiveUser(insertedId);
      final localCreated = await _localDataSource.getUserById(insertedId);
      if (localCreated == null) {
        throw UserRepositoryException('Không thể tạo hồ sơ người dùng.');
      }
      return localCreated;
    }

    final updated = existing.copyWith(
      firebaseUid: firebaseUser.uid,
      fullName: displayName,
      email: normalizedEmail.isEmpty ? existing.email : normalizedEmail,
      password: password,
      isActive: true,
      updatedAt: now,
    );
    await _localDataSource.updateUser(updated);
    if (updated.id == null) {
      throw UserRepositoryException('Không thể tải phiên đăng nhập.');
    }
    await _localDataSource.setOnlyActiveUser(updated.id!);
    final activeUser = await _localDataSource.getUserById(updated.id!);
    if (activeUser == null) {
      throw UserRepositoryException('Không thể tải phiên đăng nhập.');
    }
    return activeUser;
  }

  Future<void> _syncUserProfileToFirestore(UserModel user) async {
    if (user.firebaseUid == null || user.firebaseUid!.isEmpty) return;
    try {
      await _firestore.collection('users').doc(user.firebaseUid).set({
        'id': user.firebaseUid,
        'email': user.email,
        'fullName': user.fullName,
        'avatarEmoji': user.avatarEmoji,
        'bio': user.bio,
        'location': user.location,
        'birthDate': user.birthDate,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': user.createdAt.toIso8601String(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Firestore sync is best-effort; auth/local session should still work.
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email không đúng định dạng.';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không chính xác.';
      case 'email-already-in-use':
        return 'Email này đã được đăng ký.';
      case 'weak-password':
        return 'Mật khẩu quá yếu, vui lòng chọn mật khẩu mạnh hơn.';
      case 'too-many-requests':
        return 'Bạn thử quá nhiều lần. Vui lòng đợi rồi thử lại.';
      case 'requires-recent-login':
        return 'Vui lòng đăng nhập lại để thực hiện thao tác này.';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng. Vui lòng kiểm tra Internet.';
      default:
        return 'Xác thực thất bại. Vui lòng thử lại.';
    }
  }

  String _nameFromEmail(String email) {
    if (email.isEmpty) return 'Người dùng mới';
    final localPart = email.split('@').first.trim();
    if (localPart.isEmpty) return 'Người dùng mới';
    return localPart;
  }

  Future<UserModel?> _tryMigrateLegacyLocalAccount({
    required String email,
    required String password,
  }) async {
    final local = await _localDataSource.getUserByEmail(email);
    if (local == null || local.password != password) {
      return null;
    }

    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        return null;
      }

      if (local.fullName.trim().isNotEmpty) {
        await firebaseUser.updateDisplayName(local.fullName.trim());
      }

      final synced = await _upsertLocalUserFromFirebase(
        firebaseUser: firebaseUser,
        password: password,
        preferredFullName: local.fullName,
      );

      final merged = synced.copyWith(
        bio: local.bio,
        location: local.location,
        birthDate: local.birthDate,
        avatarEmoji: local.avatarEmoji,
        notificationsEnabled: local.notificationsEnabled,
        soundEnabled: local.soundEnabled,
        darkModeEnabled: local.darkModeEnabled,
        totalXp: local.totalXp,
        updatedAt: DateTime.now(),
      );

      await _localDataSource.updateUser(merged);
      await _syncUserProfileToFirestore(merged);
      return merged;
    } on FirebaseAuthException {
      return null;
    }
  }
}
