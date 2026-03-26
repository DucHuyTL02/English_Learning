import 'package:flutter_test/flutter_test.dart';

import 'package:english_learning/data/models/user_model.dart';

void main() {
  final _now = DateTime(2024, 6, 1, 12, 0, 0);
  final _later = DateTime(2024, 6, 2, 8, 0, 0);

  // Bản đồ đầy đủ dùng xuyên suốt để test fromMap.
  Map<String, Object?> _fullMap() => {
        'id': 42,
        'firebase_uid': 'uid-abc123',
        'full_name': 'Nguyễn Văn A',
        'email': 'user@example.com',
        'password': 'hashed_pw',
        'bio': 'Học tiếng Anh mỗi ngày',
        'location': 'Hà Nội',
        'birth_date': '2000-01-01',
        'avatar_emoji': '😊',
        'notifications_enabled': 1,
        'sound_enabled': 0,
        'dark_mode_enabled': 1,
        'total_xp': 350,
        'is_active': 1,
        'created_at': _now.toIso8601String(),
        'updated_at': _later.toIso8601String(),
      };

  group('UserModel.fromMap', () {
    test('parses all fields correctly', () {
      final user = UserModel.fromMap(_fullMap());

      expect(user.id, 42);
      expect(user.firebaseUid, 'uid-abc123');
      expect(user.fullName, 'Nguyễn Văn A');
      expect(user.email, 'user@example.com');
      expect(user.password, 'hashed_pw');
      expect(user.bio, 'Học tiếng Anh mỗi ngày');
      expect(user.location, 'Hà Nội');
      expect(user.birthDate, '2000-01-01');
      expect(user.avatarEmoji, '😊');
      expect(user.notificationsEnabled, isTrue);
      expect(user.soundEnabled, isFalse);
      expect(user.darkModeEnabled, isTrue);
      expect(user.totalXp, 350);
      expect(user.isActive, isTrue);
      expect(user.createdAt, _now);
      expect(user.updatedAt, _later);
    });

    test('handles null firebase_uid', () {
      final map = _fullMap()..['firebase_uid'] = null;
      final user = UserModel.fromMap(map);
      expect(user.firebaseUid, isNull);
    });

    test('defaults totalXp to 0 when key is missing', () {
      final map = _fullMap()..remove('total_xp');
      final user = UserModel.fromMap(map);
      expect(user.totalXp, 0);
    });

    test('converts integer 0/1 to bool correctly', () {
      final map = _fullMap()
        ..['notifications_enabled'] = 0
        ..['sound_enabled'] = 1
        ..['dark_mode_enabled'] = 0;
      final user = UserModel.fromMap(map);
      expect(user.notificationsEnabled, isFalse);
      expect(user.soundEnabled, isTrue);
      expect(user.darkModeEnabled, isFalse);
    });

    test('defaults missing string fields to empty string', () {
      final minimal = <String, Object?>{
        'created_at': _now.toIso8601String(),
        'updated_at': _now.toIso8601String(),
      };
      final user = UserModel.fromMap(minimal);
      expect(user.fullName, '');
      expect(user.email, '');
      expect(user.avatarEmoji, '👤');
    });
  });

  group('UserModel.toMap', () {
    test('serialises booleans as integers', () {
      final user = UserModel(
        id: 1,
        fullName: 'Test',
        email: 'test@test.com',
        password: 'pw',
        bio: '',
        location: '',
        birthDate: '',
        avatarEmoji: '😀',
        notificationsEnabled: true,
        soundEnabled: false,
        darkModeEnabled: true,
        totalXp: 0,
        isActive: true,
        createdAt: _now,
        updatedAt: _now,
      );
      final map = user.toMap();
      expect(map['notifications_enabled'], 1);
      expect(map['sound_enabled'], 0);
      expect(map['dark_mode_enabled'], 1);
      expect(map['is_active'], 1);
    });

    test('roundtrip toMap → fromMap preserves all fields', () {
      final original = UserModel.fromMap(_fullMap());
      final roundtrip = UserModel.fromMap(original.toMap());

      expect(roundtrip.id, original.id);
      expect(roundtrip.firebaseUid, original.firebaseUid);
      expect(roundtrip.fullName, original.fullName);
      expect(roundtrip.email, original.email);
      expect(roundtrip.totalXp, original.totalXp);
      expect(roundtrip.notificationsEnabled, original.notificationsEnabled);
      expect(roundtrip.soundEnabled, original.soundEnabled);
      expect(roundtrip.darkModeEnabled, original.darkModeEnabled);
      expect(roundtrip.isActive, original.isActive);
      expect(roundtrip.createdAt, original.createdAt);
    });
  });

  group('UserModel.displayName', () {
    test('returns fullName when non-empty', () {
      final user = UserModel.fromMap(_fullMap()..['full_name'] = 'Lê Thị B');
      expect(user.displayName, 'Lê Thị B');
    });

    test("returns 'Bạn' when fullName is empty string", () {
      final user = UserModel.fromMap(_fullMap()..['full_name'] = '');
      expect(user.displayName, 'Bạn');
    });

    test("returns 'Bạn' when fullName is only whitespace", () {
      final user = UserModel.fromMap(_fullMap()..['full_name'] = '   ');
      expect(user.displayName, 'Bạn');
    });
  });

  group('UserModel.copyWith', () {
    test('updates specified fields', () {
      final original = UserModel.fromMap(_fullMap());
      final copy = original.copyWith(fullName: 'Mới', totalXp: 999);

      expect(copy.fullName, 'Mới');
      expect(copy.totalXp, 999);
    });

    test('preserves unchanged fields', () {
      final original = UserModel.fromMap(_fullMap());
      final copy = original.copyWith(totalXp: 1);

      expect(copy.id, original.id);
      expect(copy.email, original.email);
      expect(copy.avatarEmoji, original.avatarEmoji);
      expect(copy.darkModeEnabled, original.darkModeEnabled);
    });
  });
}
