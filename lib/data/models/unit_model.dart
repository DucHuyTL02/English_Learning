class UnitModel {
  const UnitModel({
    this.id,
    required this.title,
    required this.sortOrder,
  });

  final int? id;
  final String title;
  final int sortOrder;

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'sort_order': sortOrder,
      };

  factory UnitModel.fromMap(Map<String, Object?> map) => UnitModel(
        id: map['id'] as int?,
        title: (map['title'] as String?) ?? '',
        sortOrder: (map['sort_order'] as int?) ?? 0,
      );
}
