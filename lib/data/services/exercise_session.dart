import '../models/exercise_model.dart';

/// Lightweight in-memory session that holds the exercises for the current lesson.
/// Loaded when user enters LessonIntro, consumed by exercise screens.
class ExerciseSession {
  ExerciseSession._();
  static final ExerciseSession instance = ExerciseSession._();

  int _lessonId = 0;
  int _currentIndex = 0;
  List<ExerciseModel> _exercises = [];
  int _correctCount = 0;

  int get lessonId => _lessonId;
  int get currentIndex => _currentIndex;
  int get total => _exercises.length;
  bool get hasNext => _currentIndex < _exercises.length - 1;
  int get correctCount => _correctCount;
  int get scorePercent => total > 0 ? ((_correctCount / total) * 100).round() : 0;
  int get xpEarned {
    final s = scorePercent;
    if (s >= 90) return 50;
    if (s >= 70) return 35;
    if (s >= 50) return 25;
    return 15;
  }
  ExerciseModel? get current =>
      _exercises.isNotEmpty && _currentIndex < _exercises.length
          ? _exercises[_currentIndex]
          : null;

  void load(int lessonId, List<ExerciseModel> exercises) {
    _lessonId = lessonId;
    _exercises = exercises;
    _currentIndex = 0;
    _correctCount = 0;
  }

  void recordAnswer(bool isCorrect) {
    if (isCorrect) _correctCount++;
  }

  /// Advance to next exercise.  Returns the next exercise or null if finished.
  ExerciseModel? next() {
    if (_currentIndex < _exercises.length - 1) {
      _currentIndex++;
      return _exercises[_currentIndex];
    }
    return null;
  }

  void reset() {
    _lessonId = 0;
    _currentIndex = 0;
    _exercises = [];
    _correctCount = 0;
  }
}
