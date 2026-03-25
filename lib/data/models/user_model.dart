class UserModel {
  const UserModel({
    this.id,
    required this.fullName,
    required this.email,
    required this.password,
    required this.bio,
    required this.location,
    required this.birthDate,
    required this.avatarEmoji,
    required this.notificationsEnabled,
    required this.soundEnabled,
    required this.darkModeEnabled,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String fullName;
  final String email;
  final String password;
  final String bio;
  final String location;
  final String birthDate;
  final String avatarEmoji;
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool darkModeEnabled;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'Bạn';
    return trimmed;
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'password': password,
      'bio': bio,
      'location': location,
      'birth_date': birthDate,
      'avatar_emoji': avatarEmoji,
      'notifications_enabled': notificationsEnabled ? 1 : 0,
      'sound_enabled': soundEnabled ? 1 : 0,
      'dark_mode_enabled': darkModeEnabled ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, Object?> map) {
    return UserModel(
      id: map['id'] as int?,
      fullName: (map['full_name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      password: (map['password'] as String?) ?? '',
      bio: (map['bio'] as String?) ?? '',
      location: (map['location'] as String?) ?? '',
      birthDate: (map['birth_date'] as String?) ?? '',
      avatarEmoji: (map['avatar_emoji'] as String?) ?? '👤',
      notificationsEnabled: _toBool(map['notifications_enabled']),
      soundEnabled: _toBool(map['sound_enabled']),
      darkModeEnabled: _toBool(map['dark_mode_enabled']),
      isActive: _toBool(map['is_active']),
      createdAt: _toDate(map['created_at']),
      updatedAt: _toDate(map['updated_at']),
    );
  }

  UserModel copyWith({
    int? id,
    String? fullName,
    String? email,
    String? password,
    String? bio,
    String? location,
    String? birthDate,
    String? avatarEmoji,
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? darkModeEnabled,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      birthDate: birthDate ?? this.birthDate,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static bool _toBool(Object? value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  static DateTime _toDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
