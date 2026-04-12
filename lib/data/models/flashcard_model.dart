class FlashcardModel {
  const FlashcardModel({
    required this.word,
    required this.translation,
    required this.phonetic,
    required this.example,
    required this.illustration,
    required this.gradStart,
    required this.gradEnd,
  });

  final String word;
  final String translation;
  final String phonetic;
  final String example;
  final String illustration;
  final int gradStart;
  final int gradEnd;
}
