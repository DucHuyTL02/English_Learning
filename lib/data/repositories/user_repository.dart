import '../datasources/user_local_datasource.dart';
import '../models/user_model.dart';

class UserRepositoryException implements Exception {
  UserRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UserRepository {
  UserRepository(this._localDataSource);

  final UserLocalDataSource _localDataSource;
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
    try {
      final normalizedEmail = email.trim().toLowerCase();
      if (normalizedEmail.isEmpty || password.trim().isEmpty) {
        throw UserRepositoryException(
          'Vui lòng nhập đầy đủ email và mật khẩu.',
        );
      }
      final user = await _localDataSource.getUserByEmail(normalizedEmail);
      if (user == null || user.password != password) {
        throw UserRepositoryException('Email hoặc mật khẩu không chính xác.');
      }
      if (user.id == null) {
        throw UserRepositoryException('Tài khoản không hợp lệ.');
      }
      await _localDataSource.setOnlyActiveUser(user.id!);
      final activeUser = await _localDataSource.getUserById(user.id!);
      if (activeUser == null) {
        throw UserRepositoryException('Không thể tải phiên đăng nhập.');
      }
      return activeUser;
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
      final existing = await _localDataSource.getUserByEmail(normalizedEmail);
      if (existing != null) {
        throw UserRepositoryException('Email này đã được đăng ký.');
      }

      final now = DateTime.now();
      final user = UserModel(
        fullName: trimmedName,
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
      final insertedId = await _localDataSource.insertUser(user);
      await _localDataSource.setOnlyActiveUser(insertedId);
      final created = await _localDataSource.getUserById(insertedId);
      if (created == null) {
        throw UserRepositoryException('Không thể tạo tài khoản.');
      }
      return created;
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
      await _localDataSource.updateUser(updated);
      final refreshed = await _localDataSource.getUserById(userId);
      if (refreshed == null) {
        throw UserRepositoryException('Không thể tải hồ sơ sau khi cập nhật.');
      }
      return refreshed;
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

      await _localDataSource.deleteUserById(userId);

      if (!user.isActive) return;
      final remainingUsers = await _localDataSource.getAllUsers();
      if (remainingUsers.isEmpty) return;
      final nextUser = remainingUsers.firstWhere(
        (item) => item.id != null,
        orElse: () => remainingUsers.first,
      );
      if (nextUser.id != null) {
        await _localDataSource.setOnlyActiveUser(nextUser.id!);
      }
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
      await _localDataSource.deactivateAllUsers();
    } catch (_) {
      throw UserRepositoryException('Đăng xuất thất bại.');
    }
  }
}
