class UserModel {
  const UserModel({
    this.id,
    this.firebaseUid,
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
    this.totalXp = 0,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.isPremium = false,
    this.premiumExpiresAt,
    this.subscriptionPlan = '',
  });

  final int? id;
  final String? firebaseUid;
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
  final int totalXp;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPremium;
  final DateTime? premiumExpiresAt;
  final String subscriptionPlan;

  bool get isActivePremium =>
      isPremium &&
      premiumExpiresAt != null &&
      premiumExpiresAt!.isAfter(DateTime.now());

  String get displayName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'Bạn';
    return trimmed;
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'firebase_uid': firebaseUid,
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
      'total_xp': totalXp,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_premium': isPremium ? 1 : 0,
      'premium_expires_at': premiumExpiresAt?.toIso8601String(),
      'subscription_plan': subscriptionPlan,
    };
  }

  factory UserModel.fromMap(Map<String, Object?> map) {
    return UserModel(
      id: map['id'] as int?,
      firebaseUid: map['firebase_uid'] as String?,
      fullName: (map['full_name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      password: (map['password'] as String?) ?? '',
      bio: (map['bio'] as String?) ?? '',
      location: (map['location'] as String?) ?? '',
      birthDate: (map['birth_date'] as String?) ?? '',
      avatarEmoji: (map['avatar_emoji'] as String?) ?? '🙂',
      notificationsEnabled: _toBool(map['notifications_enabled']),
      soundEnabled: _toBool(map['sound_enabled']),
      darkModeEnabled: _toBool(map['dark_mode_enabled']),
      totalXp: (map['total_xp'] as int?) ?? 0,
      isActive: _toBool(map['is_active']),
      createdAt: _toDate(map['created_at']),
      updatedAt: _toDate(map['updated_at']),
      isPremium: _toBool(map['is_premium']),
      premiumExpiresAt: _toNullableDate(map['premium_expires_at']),
      subscriptionPlan: (map['subscription_plan'] as String?) ?? '',
    );
  }

  UserModel copyWith({
    int? id,
    String? firebaseUid,
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
    int? totalXp,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPremium,
    DateTime? premiumExpiresAt,
    String? subscriptionPlan,
  }) {
    return UserModel(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
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
      totalXp: totalXp ?? this.totalXp,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPremium: isPremium ?? this.isPremium,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
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

  static DateTime? _toNullableDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
