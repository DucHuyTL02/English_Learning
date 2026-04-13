import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../datasources/user_local_datasource.dart';
import '../models/user_model.dart';

class UserRepositoryException implements Exception {
  UserRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UserRepository {
  UserRepository(
    this._localDataSource, {
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final UserLocalDataSource _localDataSource;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static final RegExp _emailRegex = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    caseSensitive: false,
  );
  static const String _firebaseUsersCollection = 'users';
  static const String _firebaseTopicsCollection = 'topics';
  static const String _firebaseWordsCollection = 'words';
  static const int _firestoreDeleteBatchLimit = 400;
  static const String _localPasswordPlaceholder = '__firebase_auth__';

  Future<UserModel?> getActiveUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      await _localDataSource.deactivateAllUsers();
      return null;
    }

    final isVerified = await reloadAndCheckCurrentUserEmailVerified();
    if (!isVerified) {
      await _localDataSource.deactivateAllUsers();
      return null;
    }

    final verifiedUser = _auth.currentUser;
    if (verifiedUser == null) {
      await _localDataSource.deactivateAllUsers();
      return null;
    }

    try {
      return await _syncLocalUser(firebaseUser: verifiedUser);
    } catch (_) {
      return _localDataSource.getActiveUser();
    }
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.trim().isEmpty) {
      throw UserRepositoryException('Vui lòng đăng nhập Email và mật khẩu.');
    }
    if (!_emailRegex.hasMatch(normalizedEmail)) {
      throw UserRepositoryException('Email không đúng định dạng.');
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw UserRepositoryException('Không thể tạo phiên đăng nhập.');
      }
      final isVerified = await reloadAndCheckCurrentUserEmailVerified();
      if (!isVerified) {
        try {
          await _sendEmailVerificationWithRetry(firebaseUser);
        } catch (_) {
          // best effort: keep login blocked for unverified accounts.
        }
        await _auth.signOut();
        await _localDataSource.deactivateAllUsers();
        throw UserRepositoryException(
          'Email chưa được xác thực. Vui lòng kiểm tra hộp thư và xác thực trước khi đăng nhập.',
        );
      }

      final verifiedUser = _auth.currentUser;
      if (verifiedUser == null) {
        throw UserRepositoryException('Phiên đăng nhập không hợp lệ.');
      }

      return await _syncLocalUser(firebaseUser: verifiedUser);
    } on FirebaseAuthException catch (e) {
      throw UserRepositoryException(_mapFirebaseAuthException(e));
    } on UserRepositoryException {
      rethrow;
    } catch (_) {
      throw UserRepositoryException('Đăng nhập thất bại, vui lòng thử lại.');
    }
  }

  Future<void> registerUser({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final trimmedName = fullName.trim();
    final normalizedEmail = email.trim().toLowerCase();
    if (trimmedName.isEmpty || normalizedEmail.isEmpty || password.isEmpty) {
      throw UserRepositoryException('Vui lòng điền đầy đủ thông tin đăng ký.');
    }
    if (!_emailRegex.hasMatch(normalizedEmail)) {
      throw UserRepositoryException('Email không đúng định dạng.');
    }
    if (password.length < 6) {
      throw UserRepositoryException('Mật khẩu phải có ít nhất 6 ký tự.');
    }

    User? createdAuthUser;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw UserRepositoryException('Không thể tạo tài khoản.');
      }
      createdAuthUser = firebaseUser;

      await firebaseUser.updateDisplayName(trimmedName);
      await _createRemoteProfileForRegistration(
        firebaseUid: firebaseUser.uid,
        fullName: trimmedName,
        email: normalizedEmail,
      );

      await _sendEmailVerificationWithRetry(firebaseUser);
      await _localDataSource.deactivateAllUsers();
    } on FirebaseAuthException catch (e) {
      throw UserRepositoryException(_mapFirebaseAuthException(e));
    } on FirebaseException catch (e) {
      await _rollbackPartialRegistration(createdAuthUser);
      throw UserRepositoryException(_mapFirestoreException(e));
    } on UserRepositoryException {
      rethrow;
    } catch (_) {
      throw UserRepositoryException('Đăng ký thất bại, vui lòng thử lại.');
    }
  }

  Future<void> sendEmailVerificationForCurrentUser({
    ActionCodeSettings? actionCodeSettings,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw UserRepositoryException('Không tìm thấy phiên đăng nhập.');
    }
    if (authUser.emailVerified) return;

    await _sendEmailVerificationWithRetry(
      authUser,
      actionCodeSettings: actionCodeSettings,
    );
  }

  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw UserRepositoryException('Vui lòng nhập email.');
    }
    if (!_emailRegex.hasMatch(normalizedEmail)) {
      throw UserRepositoryException('Email không đúng định dạng.');
    }

    try {
      await _auth.sendPasswordResetEmail(
        email: normalizedEmail,
        actionCodeSettings: actionCodeSettings,
      );
    } on FirebaseAuthException catch (e) {
      throw UserRepositoryException(_mapFirebaseAuthException(e));
    } on UserRepositoryException {
      rethrow;
    } catch (_) {
      throw UserRepositoryException(
        'Không thể gửi email đặt lại mật khẩu. Vui lòng thử lại.',
      );
    }
  }

  Future<void> changePasswordWithEmailVerification({
    required String currentPassword,
    required String newPassword,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw UserRepositoryException('Phiên đăng nhập đã hết hạn.');
    }

    if (currentPassword.trim().isEmpty) {
      throw UserRepositoryException('Vui lòng nhập mật khẩu hiện tại.');
    }

    final normalizedNewPassword = newPassword.trim();
    _validateNewPassword(normalizedNewPassword);

    final isVerified = await reloadAndCheckCurrentUserEmailVerified();
    if (!isVerified) {
      try {
        await sendEmailVerificationForCurrentUser();
      } catch (_) {
        // best effort
      }
      throw UserRepositoryException(
        'Email chưa được xác thực. Đã gửi lại email xác thực, vui lòng xác thực rồi thử lại.',
      );
    }

    try {
      await _reauthenticateCurrentUser(
        authUser: authUser,
        currentPassword: currentPassword,
      );
      final refreshedUser = _auth.currentUser ?? authUser;
      await refreshedUser.updatePassword(normalizedNewPassword);
    } on FirebaseAuthException catch (e) {
      throw UserRepositoryException(_mapFirebaseAuthException(e));
    } on UserRepositoryException {
      rethrow;
    } catch (_) {
      throw UserRepositoryException(
        'Không thể đổi mật khẩu lúc này. Vui lòng thử lại.',
      );
    }
  }

  Future<bool> reloadAndCheckCurrentUserEmailVerified() async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      await _localDataSource.deactivateAllUsers();
      return false;
    }

    User latestUser = authUser;
    try {
      await authUser.reload();
      latestUser = _auth.currentUser ?? authUser;
    } catch (_) {
      latestUser = _auth.currentUser ?? authUser;
    }

    if (!latestUser.emailVerified) {
      await _localDataSource.deactivateAllUsers();
      return false;
    }
    return true;
  }

  Future<bool> hasPendingEmailVerification() async {
    final authUser = _auth.currentUser;
    if (authUser == null) return false;
    final isVerified = await reloadAndCheckCurrentUserEmailVerified();
    return !isVerified;
  }

  Stream<bool> watchCurrentUserEmailVerified({
    Duration interval = const Duration(seconds: 3),
  }) async* {
    while (true) {
      final authUser = _auth.currentUser;
      if (authUser == null) {
        yield false;
        return;
      }

      final isVerified = await reloadAndCheckCurrentUserEmailVerified();
      yield isVerified;
      if (isVerified) return;

      await Future<void>.delayed(interval);
    }
  }

  User? get currentFirebaseUser => _auth.currentUser;

  Future<void> syncVerifiedCurrentUserToLocal() async {
    final authUser = _auth.currentUser;
    if (authUser == null) return;

    final isVerified = await reloadAndCheckCurrentUserEmailVerified();
    if (!isVerified) return;

    try {
      await _syncLocalUser(firebaseUser: authUser);
    } on UserRepositoryException {
      rethrow;
    } catch (_) {
      throw UserRepositoryException('Không thể đồng bộ tài khoản cục bộ.');
    }
  }

  Future<void> sendEmailVerificationForCredentials({
    required String email,
    required String password,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw UserRepositoryException('Vui lòng nhập email và mật khẩu.');
    }
    if (!_emailRegex.hasMatch(normalizedEmail)) {
      throw UserRepositoryException('Email không đúng định dạng.');
    }

    UserCredential? credential;
    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final authUser = credential.user;
      if (authUser == null) {
        throw UserRepositoryException('Không thể xác thực tài khoản.');
      }

      final isVerified = await reloadAndCheckCurrentUserEmailVerified();
      if (isVerified) {
        throw UserRepositoryException('Email này đã được xác thực.');
      }

      await _sendEmailVerificationWithRetry(
        authUser,
        actionCodeSettings: actionCodeSettings,
      );
    } on FirebaseAuthException catch (e) {
      throw UserRepositoryException(_mapFirebaseAuthException(e));
    } on UserRepositoryException {
      rethrow;
    } catch (_) {
      throw UserRepositoryException(
        'Không thể gửi lại email xác thực. Vui lòng thử lại.',
      );
    } finally {
      try {
        final user = credential?.user ?? _auth.currentUser;
        if (user != null && !user.emailVerified) {
          await _auth.signOut();
        }
      } catch (_) {
        // best effort
      }
      await _localDataSource.deactivateAllUsers();
    }
  }

  Future<void> _sendEmailVerificationWithRetry(
    User user, {
    ActionCodeSettings? actionCodeSettings,
  }) async {
    if (user.emailVerified) return;

    FirebaseAuthException? lastAuthException;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await user.sendEmailVerification(actionCodeSettings);
        return;
      } on FirebaseAuthException catch (e) {
        lastAuthException = e;
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 600));
        }
      } catch (_) {
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 600));
        }
      }
    }

    if (lastAuthException != null) {
      throw UserRepositoryException(
        _mapFirebaseAuthException(lastAuthException),
      );
    }
    throw UserRepositoryException(
      'Không thể gửi email xác thực. Vui lòng thử lại.',
    );
  }

  Future<UserModel> updateProfile({
    required int userId,
    required String fullName,
    required String email,
    required String bio,
    required String location,
    required String birthDate,
  }) async {
    final user = await _localDataSource.getUserById(userId);
    if (user == null) {
      throw UserRepositoryException('Không tìm thấy tài khoản để cập nhật.');
    }

    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw UserRepositoryException('Phiên đăng nhập đã hết hạn.');
    }
    if (!_isSameSignedInUser(localUser: user, authUser: authUser)) {
      throw UserRepositoryException(
        'Bạn không có quyền cập nhật tài khoản này.',
      );
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

    try {
      if (normalizedEmail != (authUser.email ?? '').trim().toLowerCase()) {
        // ignore: deprecated_member_use
        await authUser.updateEmail(normalizedEmail);
      }
      await authUser.updateDisplayName(trimmedName);

      await _updateRemoteProfile(
        firebaseUid: authUser.uid,
        data: {
          'hoTen': trimmedName,
          'fullName': trimmedName,
          'email': normalizedEmail,
          'bio': bio.trim(),
          'location': location.trim(),
          'birthDate': birthDate.trim(),
        },
      );

      final updated = user.copyWith(
        firebaseUid: authUser.uid,
        fullName: trimmedName,
        email: normalizedEmail,
        bio: bio.trim(),
        location: location.trim(),
        birthDate: birthDate.trim(),
        password: _localPasswordPlaceholder,
        updatedAt: DateTime.now(),
      );
      await _localDataSource.updateUser(updated);
      await _localDataSource.setOnlyActiveUser(userId);

      final refreshed = await _localDataSource.getUserById(userId);
      if (refreshed == null) {
        throw UserRepositoryException('Không thể tải hồ sơ sau khi cập nhật.');
      }
      return refreshed;
    } on FirebaseAuthException catch (e) {
      throw UserRepositoryException(_mapFirebaseAuthException(e));
    } on FirebaseException catch (_) {
      throw UserRepositoryException('Không thể cập nhật hồ sơ trên Firebase.');
    } on UserRepositoryException {
      rethrow;
    } catch (_) {
      throw UserRepositoryException('Cập nhật hồ sơ thất bại.');
    }
  }

  Future<UserModel> updateAvatarEmoji({
    required int userId,
    required String avatarEmoji,
  }) async {
    final emoji = avatarEmoji.trim();
    if (emoji.isEmpty) {
      throw UserRepositoryException('Vui lòng chọn một biểu tượng avatar.');
    }

    final user = await _localDataSource.getUserById(userId);
    if (user == null) {
      throw UserRepositoryException('Không tìm thấy tài khoản để cập nhật.');
    }

    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw UserRepositoryException('Phiên đăng nhập đã hết hạn.');
    }
    if (!_isSameSignedInUser(localUser: user, authUser: authUser)) {
      throw UserRepositoryException(
        'Bạn không có quyền cập nhật tài khoản này.',
      );
    }

    try {
      await _updateRemoteProfile(
        firebaseUid: authUser.uid,
        data: {'avatarEmoji': emoji},
      );

      final updated = user.copyWith(
        avatarEmoji: emoji,
        updatedAt: DateTime.now(),
      );
      await _localDataSource.updateUser(updated);
      await _localDataSource.setOnlyActiveUser(userId);

      final refreshed = await _localDataSource.getUserById(userId);
      if (refreshed == null) {
        throw UserRepositoryException(
          'Không thể tải hồ sơ sau khi cập nhật avatar.',
        );
      }
      return refreshed;
    } on FirebaseException catch (_) {
      throw UserRepositoryException(
        'Không thể cập nhật avatar trên Firebase.',
      );
    } on UserRepositoryException {
      rethrow;
    } catch (_) {
      throw UserRepositoryException('Cập nhật avatar thất bại.');
    }
  }

  Future<UserModel> updatePreferences({
    required int userId,
    required bool notificationsEnabled,
    required bool soundEnabled,
    required bool darkModeEnabled,
  }) async {
    final user = await _localDataSource.getUserById(userId);
    if (user == null) {
      throw UserRepositoryException(
        'Không tìm thấy tài khoản để cập nhật cài đặt.',
      );
    }

    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw UserRepositoryException('Phiên đăng nhập đã hết hạn.');
    }
    if (!_isSameSignedInUser(localUser: user, authUser: authUser)) {
      throw UserRepositoryException('Bạn không có quyền cập nhật cài đặt này.');
    }

    try {
      await _updateRemoteProfile(
        firebaseUid: authUser.uid,
        data: {
          'notificationsEnabled': notificationsEnabled,
          'soundEnabled': soundEnabled,
          'darkModeEnabled': darkModeEnabled,
        },
      );

      final updated = user.copyWith(
        firebaseUid: authUser.uid,
        notificationsEnabled: notificationsEnabled,
        soundEnabled: soundEnabled,
        darkModeEnabled: darkModeEnabled,
        updatedAt: DateTime.now(),
      );
      await _localDataSource.updateUser(updated);
      await _localDataSource.setOnlyActiveUser(userId);

      final refreshed = await _localDataSource.getUserById(userId);
      if (refreshed == null) {
        throw UserRepositoryException(
          'Không thể tải cài đặt sau khi cập nhật.',
        );
      }
      return refreshed;
    } on FirebaseException catch (_) {
      throw UserRepositoryException(
        'Không thể cập nhật cài đặt trên Firebase.',
      );
    } on UserRepositoryException {
      rethrow;
    } catch (_) {
      throw UserRepositoryException('Không thể cập nhật cài đặt.');
    }
  }

  Future<void> deleteUserWithPassword({
    required int userId,
    required String currentPassword,
  }) async {
    if (currentPassword.trim().isEmpty) {
      throw UserRepositoryException(
        'Vui lòng nhập mật khẩu để xác nhận xóa tài khoản.',
      );
    }
    await _deleteUserInternal(userId: userId, currentPassword: currentPassword);
  }

  Future<void> deleteUser(int userId) {
    return _deleteUserInternal(userId: userId);
  }

  Future<void> _deleteUserInternal({
    required int userId,
    String? currentPassword,
  }) async {
    final user = await _localDataSource.getUserById(userId);
    if (user == null) return;

    final authUser = _auth.currentUser;
    if (authUser == null) {
      await _localDataSource.deleteUserById(userId);
      await _localDataSource.deactivateAllUsers();
      return;
    }

    if (!_isSameSignedInUser(localUser: user, authUser: authUser)) {
      throw UserRepositoryException('Bạn không có quyền xóa tài khoản này.');
    }

    if (currentPassword != null) {
      await _reauthenticateCurrentUser(
        authUser: authUser,
        currentPassword: currentPassword,
      );
    }

    try {
      await _deleteRemoteUserData(authUser.uid);
    } on FirebaseException catch (_) {
      throw UserRepositoryException(
        'Không thể xóa dữ liệu tài khoản trên Firestore.',
      );
    } catch (_) {
      throw UserRepositoryException(
        'Không thể xóa dữ liệu tài khoản trên Firestore.',
      );
    }

    try {
      await authUser.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login' && currentPassword == null) {
        throw UserRepositoryException(
          'Phiên đăng nhập đã cũ. Vui lòng nhập mật khẩu để xác nhận xóa tài khoản.',
        );
      }
      throw UserRepositoryException(_mapFirebaseAuthException(e));
    } catch (_) {
      throw UserRepositoryException('Không thể xóa tài khoản.');
    }

    await _localDataSource.deleteUserById(userId);
    await _localDataSource.deactivateAllUsers();
  }

  Future<void> deleteActiveUser() async {
    final active = await _localDataSource.getActiveUser();
    if (active?.id == null) return;
    await deleteUser(active!.id!);
  }

  Future<void> deleteActiveUserWithPassword(String currentPassword) async {
    final active = await _localDataSource.getActiveUser();
    if (active?.id == null) return;
    await deleteUserWithPassword(
      userId: active!.id!,
      currentPassword: currentPassword,
    );
  }

  Future<void> _deleteRemoteUserData(String firebaseUid) async {
    final userDoc = _firestore
        .collection(_firebaseUsersCollection)
        .doc(firebaseUid);
    final topicsCol = userDoc.collection(_firebaseTopicsCollection);

    while (true) {
      final topicsSnap = await topicsCol
          .limit(_firestoreDeleteBatchLimit)
          .get();
      if (topicsSnap.docs.isEmpty) break;

      for (final topicDoc in topicsSnap.docs) {
        await _deleteCollectionInBatches(
          topicDoc.reference.collection(_firebaseWordsCollection),
        );
      }

      final batch = _firestore.batch();
      for (final topicDoc in topicsSnap.docs) {
        batch.delete(topicDoc.reference);
      }
      await batch.commit();

      if (topicsSnap.docs.length < _firestoreDeleteBatchLimit) break;
    }

    await userDoc.delete();
  }

  Future<void> _deleteCollectionInBatches(
    Query<Map<String, dynamic>> query,
  ) async {
    while (true) {
      final snap = await query.limit(_firestoreDeleteBatchLimit).get();
      if (snap.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snap.docs.length < _firestoreDeleteBatchLimit) break;
    }
  }

  Future<void> logoutActiveUser() async {
    try {
      await _auth.signOut();
      await _localDataSource.deactivateAllUsers();
    } catch (_) {
      throw UserRepositoryException('Đăng xuất thất bại.');
    }
  }

  Future<UserModel> _syncLocalUser({
    required User firebaseUser,
    String? preferredFullName,
  }) async {
    final normalizedEmail = (firebaseUser.email ?? '').trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw UserRepositoryException('Tài khoản Firebase chưa có email hợp lệ.');
    }

    final remoteProfile = await _fetchRemoteProfile(firebaseUser.uid);

    UserModel? user = await _localDataSource.getUserByFirebaseUid(
      firebaseUser.uid,
    );
    user ??= await _localDataSource.getUserByEmail(normalizedEmail);

    final now = DateTime.now();
    final remoteName = _readString(
      remoteProfile,
      'hoTen',
      fallback: _readString(remoteProfile, 'fullName'),
    );
    final name = remoteName.isNotEmpty
        ? remoteName
        : (preferredFullName?.trim().isNotEmpty ?? false)
        ? preferredFullName!.trim()
        : ((firebaseUser.displayName ?? '').trim().isNotEmpty
              ? firebaseUser.displayName!.trim()
              : _fallbackNameFromEmail(normalizedEmail));

    if (user == null) {
      final created = UserModel(
        firebaseUid: firebaseUser.uid,
        fullName: name,
        email: normalizedEmail,
        password: _localPasswordPlaceholder,
        bio: _readString(remoteProfile, 'bio'),
        location: _readString(remoteProfile, 'location'),
        birthDate: _readString(remoteProfile, 'birthDate'),
        avatarEmoji: _readString(remoteProfile, 'avatarEmoji', fallback: '🙂'),
        notificationsEnabled: _readBool(
          remoteProfile,
          'notificationsEnabled',
          fallback: true,
        ),
        soundEnabled: _readBool(remoteProfile, 'soundEnabled', fallback: true),
        darkModeEnabled: _readBool(
          remoteProfile,
          'darkModeEnabled',
          fallback: false,
        ),
        totalXp: _readInt(
          remoteProfile,
          'xp',
          fallback: _readInt(remoteProfile, 'totalXp'),
        ),
        isActive: true,
        createdAt: _readDate(remoteProfile, 'createdAt') ?? now,
        updatedAt: now,
      );
      final insertedId = await _localDataSource.insertUser(created);
      await _localDataSource.setOnlyActiveUser(insertedId);
      final persisted = await _localDataSource.getUserById(insertedId);
      if (persisted == null) {
        throw UserRepositoryException('Không thể tạo hồ sơ người dùng.');
      }
      if (remoteProfile == null) {
        await _tryCreateRemoteProfile(
          user: persisted,
          firebaseUid: firebaseUser.uid,
        );
      }
      return persisted;
    }

    final merged = user.copyWith(
      firebaseUid: firebaseUser.uid,
      fullName: name,
      email: normalizedEmail,
      password: _localPasswordPlaceholder,
      bio: _readString(remoteProfile, 'bio', fallback: user.bio),
      location: _readString(remoteProfile, 'location', fallback: user.location),
      birthDate: _readString(
        remoteProfile,
        'birthDate',
        fallback: user.birthDate,
      ),
      avatarEmoji: _readString(
        remoteProfile,
        'avatarEmoji',
        fallback: user.avatarEmoji,
      ),
      notificationsEnabled: _readBool(
        remoteProfile,
        'notificationsEnabled',
        fallback: user.notificationsEnabled,
      ),
      soundEnabled: _readBool(
        remoteProfile,
        'soundEnabled',
        fallback: user.soundEnabled,
      ),
      darkModeEnabled: _readBool(
        remoteProfile,
        'darkModeEnabled',
        fallback: user.darkModeEnabled,
      ),
      totalXp: _readInt(
        remoteProfile,
        'xp',
        fallback: _readInt(remoteProfile, 'totalXp', fallback: user.totalXp),
      ),
      isActive: true,
      updatedAt: now,
    );

    await _localDataSource.updateUser(merged);
    await _localDataSource.setOnlyActiveUser(user.id!);
    final persisted = await _localDataSource.getUserById(user.id!);
    if (persisted == null) {
      throw UserRepositoryException('Không thể tải phiên đăng nhập.');
    }
    if (remoteProfile == null) {
      await _tryCreateRemoteProfile(
        user: persisted,
        firebaseUid: firebaseUser.uid,
      );
    }
    return persisted;
  }

  Future<Map<String, dynamic>?> _fetchRemoteProfile(String firebaseUid) async {
    try {
      final doc = await _firestore
          .collection(_firebaseUsersCollection)
          .doc(firebaseUid)
          .get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  Future<void> _createRemoteProfileForRegistration({
    required String firebaseUid,
    required String fullName,
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final resolvedName = fullName.trim().isNotEmpty
        ? fullName.trim()
        : _fallbackNameFromEmail(normalizedEmail);

    await _firestore.collection(_firebaseUsersCollection).doc(firebaseUid).set({
      'id': firebaseUid,
      'uid': firebaseUid,
      'hoTen': resolvedName,
      'fullName': resolvedName,
      'email': normalizedEmail,
      'bio': '',
      'location': '',
      'birthDate': '',
      'avatarEmoji': '🙂',
      'notificationsEnabled': true,
      'soundEnabled': true,
      'darkModeEnabled': false,
      'xp': 0,
      'totalXp': 0,
      'level': _levelFromXp(0),
      'streak': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _tryCreateRemoteProfile({
    required UserModel user,
    required String firebaseUid,
  }) async {
    try {
      await _createRemoteProfile(user: user, firebaseUid: firebaseUid);
    } on FirebaseException {
      // Keep register/login resilient even when Firestore write is unavailable.
    }
  }

  Future<void> _createRemoteProfile({
    required UserModel user,
    required String firebaseUid,
  }) {
    return _firestore
        .collection(_firebaseUsersCollection)
        .doc(firebaseUid)
        .set({
          'id': firebaseUid,
          'uid': firebaseUid,
          'hoTen': user.fullName,
          'fullName': user.fullName,
          'email': user.email,
          'bio': user.bio,
          'location': user.location,
          'birthDate': user.birthDate,
          'avatarEmoji': user.avatarEmoji,
          'notificationsEnabled': user.notificationsEnabled,
          'soundEnabled': user.soundEnabled,
          'darkModeEnabled': user.darkModeEnabled,
          'xp': user.totalXp,
          'totalXp': user.totalXp,
          'level': _levelFromXp(user.totalXp),
          'streak': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _updateRemoteProfile({
    required String firebaseUid,
    required Map<String, Object?> data,
  }) {
    final payload = <String, Object?>{...data};

    final normalizedName = _readString(
      payload,
      'hoTen',
      fallback: _readString(payload, 'fullName'),
    );
    if (normalizedName.isNotEmpty) {
      payload['hoTen'] = normalizedName;
      payload['fullName'] = normalizedName;
    }

    final syncedXp = _readInt(
      payload,
      'xp',
      fallback: _readInt(payload, 'totalXp', fallback: -1),
    );
    if (syncedXp >= 0) {
      payload['xp'] = syncedXp;
      payload['totalXp'] = syncedXp;
      payload['level'] = _levelFromXp(syncedXp);
    }

    payload['id'] = firebaseUid;
    payload['uid'] = firebaseUid;
    payload['updatedAt'] = FieldValue.serverTimestamp();

    return _firestore
        .collection(_firebaseUsersCollection)
        .doc(firebaseUid)
        .set(payload, SetOptions(merge: true));
  }

  String _readString(
    Map<String, dynamic>? data,
    String key, {
    String fallback = '',
  }) {
    if (data == null) return fallback;
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  bool _readBool(
    Map<String, dynamic>? data,
    String key, {
    required bool fallback,
  }) {
    if (data == null) return fallback;
    final value = data[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return fallback;
  }

  int _readInt(Map<String, dynamic>? data, String key, {int fallback = 0}) {
    if (data == null) return fallback;
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  DateTime? _readDate(Map<String, dynamic>? data, String key) {
    if (data == null) return null;
    final value = data[key];
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }

  String _fallbackNameFromEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return 'Ban';
    return email.substring(0, at);
  }

  int _levelFromXp(int xp) {
    if (xp <= 0) return 1;
    return (xp ~/ 500) + 1;
  }

  Future<void> _rollbackPartialRegistration(User? createdAuthUser) async {
    if (createdAuthUser == null) return;
    try {
      await createdAuthUser.delete();
    } catch (_) {
      // Best-effort rollback.
    }

    try {
      if (_auth.currentUser?.uid == createdAuthUser.uid) {
        await _auth.signOut();
      }
    } catch (_) {
      // Best-effort rollback.
    }
  }

  String _mapFirestoreException(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Khong co quyen ghi du lieu Firestore. Hay kiem tra Firestore Rules.';
      case 'unavailable':
        return 'Firestore tam thoi khong kha dung. Vui long thu lai.';
      case 'deadline-exceeded':
        return 'Het thoi gian ket noi Firestore. Vui long thu lai.';
      default:
        return e.message ?? 'Khong the tao ho so nguoi dung tren Firestore.';
    }
  }

  String _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email khong dung dinh dang.';
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Email hoac mat khau khong chinh xac.';
      case 'email-already-in-use':
        return 'Email nay da duoc dang ky.';
      case 'weak-password':
        return 'Mat khau phai co it nhat 6 ky tu.';
      case 'operation-not-allowed':
        return 'Email/Password chua duoc bat trong Firebase Authentication.';
      case 'network-request-failed':
        return 'Khong co ket noi mang. Vui long thu lai.';
      case 'too-many-requests':
        return 'Ban thu qua nhieu lan. Vui long thu lai sau.';
      case 'user-disabled':
        return 'Tai khoan da bi vo hieu hoa.';
      case 'requires-recent-login':
        return 'Vui long dang nhap lai de thuc hien thao tac nay.';
      default:
        return e.message ?? 'Xac thuc Firebase that bai.';
    }
  }

  void _validateNewPassword(String newPassword) {
    if (newPassword.isEmpty) {
      throw UserRepositoryException('Vui long nhap mat khau moi.');
    }
    if (newPassword.length < 6) {
      throw UserRepositoryException('Mat khau moi phai co it nhat 6 ky tu.');
    }
  }

  bool _isSameSignedInUser({
    required UserModel localUser,
    required User authUser,
  }) {
    if (localUser.firebaseUid != null) {
      return localUser.firebaseUid == authUser.uid;
    }
    return localUser.email.trim().toLowerCase() ==
        (authUser.email ?? '').trim().toLowerCase();
  }

  Future<void> _reauthenticateCurrentUser({
    required User authUser,
    required String currentPassword,
  }) async {
    final normalizedEmail = (authUser.email ?? '').trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw UserRepositoryException(
        'Không thể xác thực lại tài khoản hiện tại.',
      );
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: normalizedEmail,
        password: currentPassword,
      );
      await authUser.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw UserRepositoryException(_mapFirebaseAuthException(e));
    } catch (_) {
      throw UserRepositoryException(
        'Không thể xác thực lại tài khoản. Vui lòng thử lại.',
      );
    }
  }
}
