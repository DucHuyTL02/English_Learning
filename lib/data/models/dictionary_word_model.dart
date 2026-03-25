class DictionaryWordModel {
  const DictionaryWordModel({
    this.id,
    required this.word,
    required this.phonetic,
    required this.partOfSpeech,
    required this.definition,
    required this.example,
    required this.isSaved,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String word;
  final String phonetic;
  final String partOfSpeech;
  final String definition;
  final String example;
  final bool isSaved;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'word': word,
      'phonetic': phonetic,
      'part_of_speech': partOfSpeech,
      'definition': definition,
      'example': example,
      'is_saved': isSaved ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DictionaryWordModel.fromMap(Map<String, Object?> map) {
    return DictionaryWordModel(
      id: map['id'] as int?,
      word: (map['word'] as String?) ?? '',
      phonetic: (map['phonetic'] as String?) ?? '',
      partOfSpeech: (map['part_of_speech'] as String?) ?? '',
      definition: (map['definition'] as String?) ?? '',
      example: (map['example'] as String?) ?? '',
      isSaved: _toBool(map['is_saved']),
      createdAt: _toDate(map['created_at']),
      updatedAt: _toDate(map['updated_at']),
    );
  }

  DictionaryWordModel copyWith({
    int? id,
    String? word,
    String? phonetic,
    String? partOfSpeech,
    String? definition,
    String? example,
    bool? isSaved,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DictionaryWordModel(
      id: id ?? this.id,
      word: word ?? this.word,
      phonetic: phonetic ?? this.phonetic,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      definition: definition ?? this.definition,
      example: example ?? this.example,
      isSaved: isSaved ?? this.isSaved,
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
