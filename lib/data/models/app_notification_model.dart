class AppNotificationModel {
  const AppNotificationModel({
    this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.payload,
    required this.isRead,
    required this.createdAt,
  });

  final int? id;
  final int userId;
  final String type;
  final String title;
  final String message;
  final String payload;
  final bool isRead;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'title': title,
      'message': message,
      'payload': payload,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AppNotificationModel.fromMap(Map<String, Object?> map) {
    return AppNotificationModel(
      id: map['id'] as int?,
      userId: (map['user_id'] as int?) ?? 0,
      type: (map['type'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      message: (map['message'] as String?) ?? '',
      payload: (map['payload'] as String?) ?? '',
      isRead: _toBool(map['is_read']),
      createdAt: _toDate(map['created_at']),
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
