class ExerciseModel {
  const ExerciseModel({
    this.id,
    required this.lessonId,
    required this.type,
    required this.question,
    required this.correctAnswer,
    required this.options,
    required this.illustration,
    required this.sortOrder,
  });

  final int? id;
  final int lessonId;
  final String type; // 'multiple_choice', 'listening', 'speaking'
  final String question;
  final String correctAnswer;
  final String options; // pipe-separated for multiple choice
  final String illustration;
  final int sortOrder;

  List<String> get optionList =>
      options.isEmpty ? [] : options.split('|');

  Map<String, Object?> toMap() => {
        'id': id,
        'lesson_id': lessonId,
        'type': type,
        'question': question,
        'correct_answer': correctAnswer,
        'options': options,
        'illustration': illustration,
        'sort_order': sortOrder,
      };

  factory ExerciseModel.fromMap(Map<String, Object?> map) => ExerciseModel(
        id: map['id'] as int?,
        lessonId: (map['lesson_id'] as int?) ?? 0,
        type: (map['type'] as String?) ?? '',
        question: (map['question'] as String?) ?? '',
        correctAnswer: (map['correct_answer'] as String?) ?? '',
        options: (map['options'] as String?) ?? '',
        illustration: (map['illustration'] as String?) ?? '',
        sortOrder: (map['sort_order'] as int?) ?? 0,
      );
}
