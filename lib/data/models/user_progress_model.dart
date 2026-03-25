class UserProgressModel {
  const UserProgressModel({
    this.id,
    required this.userId,
    required this.lessonId,
    required this.score,
    required this.xpEarned,
    required this.completedAt,
  });

  final int? id;
  final int userId;
  final int lessonId;
  final int score;
  final int xpEarned;
  final DateTime completedAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'lesson_id': lessonId,
        'score': score,
        'xp_earned': xpEarned,
        'completed_at': completedAt.toIso8601String(),
      };

  factory UserProgressModel.fromMap(Map<String, Object?> map) =>
      UserProgressModel(
        id: map['id'] as int?,
        userId: (map['user_id'] as int?) ?? 0,
        lessonId: (map['lesson_id'] as int?) ?? 0,
        score: (map['score'] as int?) ?? 0,
        xpEarned: (map['xp_earned'] as int?) ?? 0,
        completedAt: _toDate(map['completed_at']),
      );

  static DateTime _toDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
