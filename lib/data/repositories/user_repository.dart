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
      throw UserRepositoryException(
        'Vui lÃƒÂ²ng Ã„â€˜Ã„Æ’ng nhÃ¡ÂºÂ­p Email vÃƒÂ  mÃ¡ÂºÂ­t khÃ¡ÂºÂ©u.',
      );
    }
    if (!_emailRegex.hasMatch(normalizedEmail)) {
      throw UserRepositoryException(
        'Email khÃƒÂ´ng Ã„â€˜ÃƒÂºng Ã„â€˜Ã¡Â»â€¹nh dÃ¡ÂºÂ¡ng.',
      );
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw UserRepositoryException(
          'KhÃƒÂ´ng thÃ¡Â»Æ’ tÃ¡ÂºÂ¡o phiÃƒÂªn Ã„â€˜Ã„Æ’ng nhÃ¡ÂºÂ­p.',
        );
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
          'Email chÃ†Â°a Ã„â€˜Ã†Â°Ã¡Â»Â£c xÃƒÂ¡c thÃ¡Â»Â±c. Vui lÃƒÂ²ng kiÃ¡Â»Æ’m tra hÃ¡Â»â„¢p thÃ†Â° vÃƒÂ  xÃƒÂ¡c thÃ¡Â»Â±c trÃ†Â°Ã¡Â»â€ºc khi Ã„â€˜Ã„Æ’ng nhÃ¡ÂºÂ­p.',
        );
      }

      final verifiedUser = _auth.currentUser;
      if (verifiedUser == null) {
        throw UserRepositoryException(
          'PhiÃƒÂªn Ã„â€˜Ã„Æ’ng nhÃ¡ÂºÂ­p khÃƒÂ´ng hÃ¡Â»Â£p lÃ¡Â»â€¡.',
        );
      }

      return await _syncLocalUser(firebaseUser: verifiedUser);
    } on FirebaseAuthException catch (e) {
      throw UserRepositoryException(_mapFirebaseAuthException(e));
    } on UserRepositoryException {
      rethrow;
    } catch (_) {
      throw UserRepositoryException(
        'Ã„ÂÃ„Æ’ng nhÃ¡ÂºÂ­p thÃ¡ÂºÂ¥t bÃ¡ÂºÂ¡i, vui lÃƒÂ²ng thÃ¡Â»Â­ lÃ¡ÂºÂ¡i.',
      );
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
      throw UserRepositoryException(
        'Vui lÃƒÂ²ng Ã„â€˜iÃ¡Â»Ân Ã„â€˜Ã¡ÂºÂ§y Ã„â€˜Ã¡Â»Â§ thÃƒÂ´ng tin Ã„â€˜Ã„Æ’ng kÃƒÂ½.',
      );
    }
    if (!_emailRegex.hasMatch(normalizedEmail)) {
      throw UserRepositoryException(
        'Email khÃƒÂ´ng Ã„â€˜ÃƒÂºng Ã„â€˜Ã¡Â»â€¹nh dÃ¡ÂºÂ¡ng.',
      );
    }
    if (password.length < 6) {
      throw UserRepositoryException(
        'MÃ¡ÂºÂ­t khÃ¡ÂºÂ©u phÃ¡ÂºÂ£i cÃƒÂ³ ÃƒÂ­t nhÃ¡ÂºÂ¥t 6 kÃƒÂ½ tÃ¡Â»Â±.',
      );
    }

    User? createdAuthUser;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw UserRepositoryException(
          'KhÃƒÂ´ng thÃ¡Â»Æ’ tÃ¡ÂºÂ¡o tÃƒÂ i khoÃ¡ÂºÂ£n.',
        );
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
      throw UserRepositoryException(
        'Ã„ÂÃ„Æ’ng kÃƒÂ½ thÃ¡ÂºÂ¥t bÃ¡ÂºÂ¡i, vui lÃƒÂ²ng thÃ¡Â»Â­ lÃ¡ÂºÂ¡i.',
      );
    }
  }

  Future<void> sendEmailVerificationForCurrentUser({
    ActionCodeSettings? actionCodeSettings,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw UserRepositoryException('KhÃ´ng tÃ¬m tháº¥y phiÃªn Ä‘Äƒng nháº­p.');
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
      throw UserRepositoryException('Vui lÃƒÂ²ng nhÃ¡ÂºÂ­p email.');
    }
    if (!_emailRegex.hasMatch(normalizedEmail)) {
      throw UserRepositoryException(
        'Email khÃƒÂ´ng Ã„â€˜ÃƒÂºng Ã„â€˜Ã¡Â»â€¹nh dÃ¡ÂºÂ¡ng.',
      );
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
        'KhÃƒÂ´ng thÃ¡Â»Æ’ gÃ¡Â»Â­i email Ã„â€˜Ã¡ÂºÂ·t lÃ¡ÂºÂ¡i mÃ¡ÂºÂ­t khÃ¡ÂºÂ©u. Vui lÃƒÂ²ng thÃ¡Â»Â­ lÃ¡ÂºÂ¡i.',
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
      throw UserRepositoryException(
        'KhÃƒÂ´ng thÃ¡Â»Æ’ Ã„â€˜Ã¡Â»â€œng bÃ¡Â»â„¢ tÃƒÂ i khoÃ¡ÂºÂ£n cÃ¡Â»Â¥c bÃ¡Â»â„¢.',
      );
    }
  }

  Future<void> sendEmailVerificationForCredentials({
    required String email,
    required String password,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw UserRepositoryException(
        'Vui lÃƒÂ²ng nhÃ¡ÂºÂ­p email vÃƒÂ  mÃ¡ÂºÂ­t khÃ¡ÂºÂ©u.',
      );
    }
    if (!_emailRegex.hasMatch(normalizedEmail)) {
      throw UserRepositoryException(
        'Email khÃƒÂ´ng Ã„â€˜ÃƒÂºng Ã„â€˜Ã¡Â»â€¹nh dÃ¡ÂºÂ¡ng.',
      );
    }

    UserCredential? credential;
    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final authUser = credential.user;
      if (authUser == null) {
        throw UserRepositoryException(
          'KhÃƒÂ´ng thÃ¡Â»Æ’ xÃƒÂ¡c thÃ¡Â»Â±c tÃƒÂ i khoÃ¡ÂºÂ£n.',
        );
      }

      final isVerified = await reloadAndCheckCurrentUserEmailVerified();
      if (isVerified) {
        throw UserRepositoryException(
          'Email nÃƒÂ y Ã„â€˜ÃƒÂ£ Ã„â€˜Ã†Â°Ã¡Â»Â£c xÃƒÂ¡c thÃ¡Â»Â±c.',
        );
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
        'KhÃƒÂ´ng thÃ¡Â»Æ’ gÃ¡Â»Â­i lÃ¡ÂºÂ¡i email xÃƒÂ¡c thÃ¡Â»Â±c. Vui lÃƒÂ²ng thÃ¡Â»Â­ lÃ¡ÂºÂ¡i.',
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
      'KhÃ´ng thá»ƒ gá»­i email xÃ¡c thá»±c. Vui lÃ²ng thá»­ láº¡i.',
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
      throw UserRepositoryException(
        'KhÃƒÂ´ng tÃƒÂ¬m thÃ¡ÂºÂ¥y tÃƒÂ i khoÃ¡ÂºÂ£n Ã„â€˜Ã¡Â»Æ’ cÃ¡ÂºÂ­p nhÃ¡ÂºÂ­t.',
      );
    }

    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw UserRepositoryException(
        'PhiÃƒÂªn Ã„â€˜Ã„Æ’ng nhÃ¡ÂºÂ­p Ã„â€˜ÃƒÂ£ hÃ¡ÂºÂ¿t hÃ¡ÂºÂ¡n.',
      );
    }
    if (!_isSameSignedInUser(localUser: user, authUser: authUser)) {
      throw UserRepositoryException(
        'BÃ¡ÂºÂ¡n khÃƒÂ´ng cÃƒÂ³ quyÃ¡Â»Ân cÃ¡ÂºÂ­p nhÃ¡ÂºÂ­t tÃƒÂ i khoÃ¡ÂºÂ£n nÃƒÂ y.',
      );
    }

    final trimmedName = fullName.trim();
    final normalizedEmail = email.trim().toLowerCase();
    if (trimmedName.isEmpty || normalizedEmail.isEmpty) {
      throw UserRepositoryException(
        'HÃ¡Â»Â tÃƒÂªn vÃƒÂ  email khÃƒÂ´ng Ã„â€˜Ã†Â°Ã¡Â»Â£c Ã„â€˜Ã¡Â»Æ’ trÃ¡Â»â€˜ng.',
      );
    }
    if (!_emailRegex.hasMatch(normalizedEmail)) {
      throw UserRepositoryException(
        'Email khÃƒÂ´ng Ã„â€˜ÃƒÂºng Ã„â€˜Ã¡Â»â€¹nh dÃ¡ÂºÂ¡ng.',
      );
    }

    final duplicatedEmailUser = await _localDataSource.getUserByEmail(
      normalizedEmail,
    );
    if (duplicatedEmailUser != null && duplicatedEmailUser.id != userId) {
      throw UserRepositoryException(
        'Email nÃƒÂ y Ã„â€˜ang Ã„â€˜Ã†Â°Ã¡Â»Â£c dÃƒÂ¹ng bÃ¡Â»Å¸i tÃƒÂ i khoÃ¡ÂºÂ£n khÃƒÂ¡c.',
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
        throw UserRepositoryException(
          'KhÃƒÂ´ng thÃ¡Â»Æ’ tÃ¡ÂºÂ£i hÃ¡Â»â€œ sÃ†Â¡ sau khi cÃ¡ÂºÂ­p nhÃ¡ÂºÂ­t.',
        );
      }
      return refreshed;
    } on FirebaseAuthException catch (e) {
      throw UserRepositoryException(_mapFirebaseAuthException(e));
    } on FirebaseException catch (_) {
      throw UserRepositoryException(
        'KhÃƒÂ´ng thÃ¡Â»Æ’ cÃ¡ÂºÂ­p nhÃ¡ÂºÂ­t hÃ¡Â»â€œ sÃ†Â¡ trÃƒÂªn Firebase.',
      );
    } on UserRepositoryException {
      rethrow;
    } catch (_) {
      throw UserRepositoryException(
        'CÃ¡ÂºÂ­p nhÃ¡ÂºÂ­t hÃ¡Â»â€œ sÃ†Â¡ thÃ¡ÂºÂ¥t bÃ¡ÂºÂ¡i.',
      );
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
        'KhÃƒÂ´ng tÃƒÂ¬m thÃ¡ÂºÂ¥y tÃƒÂ i khoÃ¡ÂºÂ£n Ã„â€˜Ã¡Â»Æ’ cÃ¡ÂºÂ­p nhÃ¡ÂºÂ­t cÃƒÂ i Ã„â€˜Ã¡ÂºÂ·t.',
      );
    }

    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw UserRepositoryException(
        'PhiÃƒÂªn Ã„â€˜Ã„Æ’ng nhÃ¡ÂºÂ­p Ã„â€˜ÃƒÂ£ hÃ¡ÂºÂ¿t hÃ¡ÂºÂ¡n.',
      );
    }
    if (!_isSameSignedInUser(localUser: user, authUser: authUser)) {
      throw UserRepositoryException(
        'BÃ¡ÂºÂ¡n khÃƒÂ´ng cÃƒÂ³ quyÃ¡Â»Ân cÃ¡ÂºÂ­p nhÃ¡ÂºÂ­t cÃƒÂ i Ã„â€˜Ã¡ÂºÂ·t nÃƒÂ y.',
      );
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
          'KhÃƒÂ´ng thÃ¡Â»Æ’ tÃ¡ÂºÂ£i cÃƒÂ i Ã„â€˜Ã¡ÂºÂ·t sau khi cÃ¡ÂºÂ­p nhÃ¡ÂºÂ­t.',
        );
      }
      return refreshed;
    } on FirebaseException catch (_) {
      throw UserRepositoryException(
        'KhÃƒÂ´ng thÃ¡Â»Æ’ cÃ¡ÂºÂ­p nhÃ¡ÂºÂ­t cÃƒÂ i Ã„â€˜Ã¡ÂºÂ·t trÃƒÂªn Firebase.',
      );
    } on UserRepositoryException {
      rethrow;
    } catch (_) {
      throw UserRepositoryException(
        'KhÃƒÂ´ng thÃ¡Â»Æ’ cÃ¡ÂºÂ­p nhÃ¡ÂºÂ­t cÃƒÂ i Ã„â€˜Ã¡ÂºÂ·t.',
      );
    }
  }

  Future<void> deleteUserWithPassword({
    required int userId,
    required String currentPassword,
  }) async {
    if (currentPassword.trim().isEmpty) {
      throw UserRepositoryException(
        'Vui lÃƒÂ²ng nhÃ¡ÂºÂ­p mÃ¡ÂºÂ­t khÃ¡ÂºÂ©u Ã„â€˜Ã¡Â»Æ’ xÃƒÂ¡c nhÃ¡ÂºÂ­n xÃƒÂ³a tÃƒÂ i khoÃ¡ÂºÂ£n.',
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
      throw UserRepositoryException(
        'BÃ¡ÂºÂ¡n khÃƒÂ´ng cÃƒÂ³ quyÃ¡Â»Ân xÃƒÂ³a tÃƒÂ i khoÃ¡ÂºÂ£n nÃƒÂ y.',
      );
    }

    if (currentPassword != null) {
      await _reauthenticateCurrentUser(
        authUser: authUser,
        currentPassword: currentPassword,
      );
    }

    try {
      await _firestore
          .collection(_firebaseUsersCollection)
          .doc(authUser.uid)
          .delete();
    } catch (_) {
      // Keep account deletion flow resilient even if profile doc is missing.
    }

    try {
      await authUser.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login' && currentPassword == null) {
        throw UserRepositoryException(
          'PhiÃƒÂªn Ã„â€˜Ã„Æ’ng nhÃ¡ÂºÂ­p Ã„â€˜ÃƒÂ£ cÃ…Â©. Vui lÃƒÂ²ng nhÃ¡ÂºÂ­p mÃ¡ÂºÂ­t khÃ¡ÂºÂ©u Ã„â€˜Ã¡Â»Æ’ xÃƒÂ¡c nhÃ¡ÂºÂ­n xÃƒÂ³a tÃƒÂ i khoÃ¡ÂºÂ£n.',
        );
      }
      throw UserRepositoryException(_mapFirebaseAuthException(e));
    } catch (_) {
      throw UserRepositoryException(
        'KhÃƒÂ´ng thÃ¡Â»Æ’ xÃƒÂ³a tÃƒÂ i khoÃ¡ÂºÂ£n.',
      );
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

  Future<void> logoutActiveUser() async {
    try {
      await _auth.signOut();
      await _localDataSource.deactivateAllUsers();
    } catch (_) {
      throw UserRepositoryException('Ã„ÂÃ„Æ’ng xuÃ¡ÂºÂ¥t thÃ¡ÂºÂ¥t bÃ¡ÂºÂ¡i.');
    }
  }

  Future<UserModel> _syncLocalUser({
    required User firebaseUser,
    String? preferredFullName,
  }) async {
    final normalizedEmail = (firebaseUser.email ?? '').trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw UserRepositoryException(
        'TÃƒÂ i khoÃ¡ÂºÂ£n Firebase chÃ†Â°a cÃƒÂ³ email hÃ¡Â»Â£p lÃ¡Â»â€¡.',
      );
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
        avatarEmoji: _readString(
          remoteProfile,
          'avatarEmoji',
          fallback: 'ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ‚Â¤',
        ),
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
        throw UserRepositoryException(
          'KhÃƒÂ´ng thÃ¡Â»Æ’ tÃ¡ÂºÂ¡o hÃ¡Â»â€œ sÃ†Â¡ ngÃ†Â°Ã¡Â»Âi dÃƒÂ¹ng.',
        );
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
      throw UserRepositoryException(
        'KhÃƒÂ´ng thÃ¡Â»Æ’ tÃ¡ÂºÂ£i phiÃƒÂªn Ã„â€˜Ã„Æ’ng nhÃ¡ÂºÂ­p.',
      );
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
      'avatarEmoji': 'Ã°Å¸â€˜Â¤',
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
        'KhÃƒÂ´ng thÃ¡Â»Æ’ xÃƒÂ¡c thÃ¡Â»Â±c lÃ¡ÂºÂ¡i tÃƒÂ i khoÃ¡ÂºÂ£n hiÃ¡Â»â€¡n tÃ¡ÂºÂ¡i.',
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
        'KhÃƒÂ´ng thÃ¡Â»Æ’ xÃƒÂ¡c thÃ¡Â»Â±c lÃ¡ÂºÂ¡i tÃƒÂ i khoÃ¡ÂºÂ£n. Vui lÃƒÂ²ng thÃ¡Â»Â­ lÃ¡ÂºÂ¡i.',
      );
    }
  }
}
