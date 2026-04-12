/// Model for a user-created vocabulary topic stored in Firestore.
///
/// Firestore path: users/{userId}/topics/{topicId}
class UserTopicModel {
  const UserTopicModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.wordCount = 0,
  });

  final String id;
  final String userId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int wordCount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'wordCount': wordCount,
    };
  }

  factory UserTopicModel.fromMap(Map<String, dynamic> map) {
    return UserTopicModel(
      id: (map['id'] as String?) ?? '',
      userId: (map['userId'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
      wordCount: (map['wordCount'] as int?) ?? 0,
    );
  }

  UserTopicModel copyWith({
    String? id,
    String? userId,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? wordCount,
  }) {
    return UserTopicModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      wordCount: wordCount ?? this.wordCount,
    );
  }

  static DateTime _toDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

/// Model for a vocabulary word saved under a user topic in Firestore.
///
/// Firestore path: users/{userId}/topics/{topicId}/words/{wordId}
class TopicWordModel {
  const TopicWordModel({
    required this.id,
    required this.word,
    required this.phonetic,
    required this.partOfSpeech,
    required this.definition,
    required this.example,
    required this.createdAt,
  });

  final String id;
  final String word;
  final String phonetic;
  final String partOfSpeech;
  final String definition;
  final String example;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'phonetic': phonetic,
      'partOfSpeech': partOfSpeech,
      'definition': definition,
      'example': example,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TopicWordModel.fromMap(Map<String, dynamic> map) {
    return TopicWordModel(
      id: (map['id'] as String?) ?? '',
      word: (map['word'] as String?) ?? '',
      phonetic: (map['phonetic'] as String?) ?? '',
      partOfSpeech: (map['partOfSpeech'] as String?) ?? '',
      definition: (map['definition'] as String?) ?? '',
      example: (map['example'] as String?) ?? '',
      createdAt: _toDate(map['createdAt']),
    );
  }

  static DateTime _toDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
