class DailyActivityModel {
  const DailyActivityModel({
    this.id,
    required this.userId,
    required this.date,
    required this.xpEarned,
    required this.lessonsCompleted,
  });

  final int? id;
  final int userId;
  final String date; // 'yyyy-MM-dd'
  final int xpEarned;
  final int lessonsCompleted;

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'date': date,
        'xp_earned': xpEarned,
        'lessons_completed': lessonsCompleted,
      };

  factory DailyActivityModel.fromMap(Map<String, Object?> map) =>
      DailyActivityModel(
        id: map['id'] as int?,
        userId: (map['user_id'] as int?) ?? 0,
        date: (map['date'] as String?) ?? '',
        xpEarned: (map['xp_earned'] as int?) ?? 0,
        lessonsCompleted: (map['lessons_completed'] as int?) ?? 0,
      );
}
