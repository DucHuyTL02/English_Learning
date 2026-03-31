class SpeakHistoryModel {
  const SpeakHistoryModel({
    this.id,
    required this.targetWord,
    required this.spokenWord,
    required this.score,
    required this.editDistance,
    required this.createdAt,
  });

  final int? id;
  final String targetWord;
  final String spokenWord;
  final int score;
  final int editDistance;
  final String createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'target_word': targetWord,
        'spoken_word': spokenWord,
        'score': score,
        'edit_distance': editDistance,
        'created_at': createdAt,
      };

  factory SpeakHistoryModel.fromMap(Map<String, Object?> map) =>
      SpeakHistoryModel(
        id: map['id'] as int?,
        targetWord: (map['target_word'] as String?) ?? '',
        spokenWord: (map['spoken_word'] as String?) ?? '',
        score: (map['score'] as int?) ?? 0,
        editDistance: (map['edit_distance'] as int?) ?? 0,
        createdAt: (map['created_at'] as String?) ?? '',
      );
}
