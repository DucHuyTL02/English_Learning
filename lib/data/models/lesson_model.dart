class LessonModel {
  const LessonModel({
    this.id,
    required this.unitId,
    required this.title,
    required this.icon,
    required this.sortOrder,
    required this.xpReward,
  });

  final int? id;
  final int unitId;
  final String title;
  final String icon;
  final int sortOrder;
  final int xpReward;

  Map<String, Object?> toMap() => {
        'id': id,
        'unit_id': unitId,
        'title': title,
        'icon': icon,
        'sort_order': sortOrder,
        'xp_reward': xpReward,
      };

  factory LessonModel.fromMap(Map<String, Object?> map) => LessonModel(
        id: map['id'] as int?,
        unitId: (map['unit_id'] as int?) ?? 0,
        title: (map['title'] as String?) ?? '',
        icon: (map['icon'] as String?) ?? '📖',
        sortOrder: (map['sort_order'] as int?) ?? 0,
        xpReward: (map['xp_reward'] as int?) ?? 50,
      );
}
