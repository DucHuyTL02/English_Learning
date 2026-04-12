import '../datasources/learning_local_datasource.dart';
import '../models/user_model.dart';
import '../models/unit_model.dart';
import '../models/lesson_model.dart';
import '../models/exercise_model.dart';
import '../models/user_progress_model.dart';
import '../models/daily_activity_model.dart';

class LearningRepositoryException implements Exception {
  LearningRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LearningRepository {
  LearningRepository(this._ds);
  final LearningLocalDataSource _ds;

  // ── Units & Lessons ──

  Future<List<UnitModel>> getUnits() async {
    try {
      return await _ds.getUnits();
    } catch (_) {
      throw LearningRepositoryException('Không thể tải danh sách đơn vị.');
    }
  }

  Future<List<LessonModel>> getLessonsByUnit(int unitId) async {
    try {
      return await _ds.getLessonsByUnit(unitId);
    } catch (_) {
      throw LearningRepositoryException('Không thể tải danh sách bài học.');
    }
  }

  Future<List<LessonModel>> getAllLessons() async {
    try {
      return await _ds.getAllLessons();
    } catch (_) {
      throw LearningRepositoryException('Không thể tải bài học.');
    }
  }

  Future<LessonModel?> getLessonById(int id) async {
    try {
      return await _ds.getLessonById(id);
    } catch (_) {
      throw LearningRepositoryException('Không thể tải bài học.');
    }
  }

  // ── Exercises ──

  Future<List<ExerciseModel>> getExercisesByLesson(int lessonId) async {
    try {
      return await _ds.getExercisesByLesson(lessonId);
    } catch (_) {
      throw LearningRepositoryException('Không thể tải bài tập.');
    }
  }

  // ── Premium gate ──

  /// Bài đầu tiên (unit 1, sortOrder 1) luôn miễn phí.
  /// Tất cả bài còn lại yêu cầu Premium.
  Future<bool> canAccessLesson(int lessonId, UserModel user) async {
    if (user.isActivePremium) return true;
    final lesson = await _ds.getLessonById(lessonId);
    if (lesson == null) return false;
    return lesson.unitId == 1 && lesson.sortOrder == 1;
  }

  // ── Progress ──

  Future<Set<int>> getCompletedLessonIds(int userId) async {
    try {
      return await _ds.getCompletedLessonIds(userId);
    } catch (_) {
      throw LearningRepositoryException('Không thể tải tiến độ học.');
    }
  }

  Future<int> getTotalXp(int userId) async {
    try {
      return await _ds.getTotalXp(userId);
    } catch (_) {
      throw LearningRepositoryException('Không thể tải XP.');
    }
  }

  Future<void> completeLesson({
    required int userId,
    required int lessonId,
    required int score,
    required int xpEarned,
  }) async {
    try {
      final progress = UserProgressModel(
        userId: userId,
        lessonId: lessonId,
        score: score,
        xpEarned: xpEarned,
        completedAt: DateTime.now(),
      );
      await _ds.insertProgress(progress);
      await _ds.recordActivity(userId, xpEarned);
    } catch (_) {
      throw LearningRepositoryException('Không thể lưu tiến độ bài học.');
    }
  }

  // ── Streak ──

  Future<int> getCurrentStreak(int userId) async {
    try {
      return await _ds.getCurrentStreak(userId);
    } catch (_) {
      return 0;
    }
  }

  Future<int> getLongestStreak(int userId) async {
    try {
      return await _ds.getLongestStreak(userId);
    } catch (_) {
      return 0;
    }
  }

  Future<int> getTotalActivityDays(int userId) async {
    try {
      final activities = await _ds.getAllActivities(userId);
      return activities.length;
    } catch (_) {
      return 0;
    }
  }

  Future<List<DailyActivityModel>> getActivitiesForMonth(int userId, int year, int month) async {
    try {
      return await _ds.getActivitiesForMonth(userId, year, month);
    } catch (_) {
      return [];
    }
  }

  Future<int> getMonthActivityCount(int userId, int year, int month) async {
    try {
      final activities = await _ds.getActivitiesForMonth(userId, year, month);
      return activities.length;
    } catch (_) {
      return 0;
    }
  }
}
