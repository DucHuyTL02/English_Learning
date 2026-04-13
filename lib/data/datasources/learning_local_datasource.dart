import '../app_database.dart';
import '../models/unit_model.dart';
import '../models/lesson_model.dart';
import '../models/exercise_model.dart';
import '../models/user_progress_model.dart';
import '../models/daily_activity_model.dart';
import 'package:sqflite/sqflite.dart';

class LearningLocalDataSource {
  LearningLocalDataSource(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<void> upsertLearningContent({
    required List<UnitModel> units,
    required List<LessonModel> lessons,
    required List<ExerciseModel> exercises,
  }) async {
    if (units.isEmpty || lessons.isEmpty || exercises.isEmpty) return;

    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      final batch = txn.batch();

      for (final unit in units) {
        if (unit.id == null) continue;
        batch.insert(
          AppDatabase.unitsTable,
          unit.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final lesson in lessons) {
        if (lesson.id == null) continue;
        batch.insert(
          AppDatabase.lessonsTable,
          lesson.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final lessonIds = exercises.map((e) => e.lessonId).toSet();
      for (final lessonId in lessonIds) {
        batch.delete(
          AppDatabase.exercisesTable,
          where: 'lesson_id = ?',
          whereArgs: [lessonId],
        );
      }

      for (final exercise in exercises) {
        final payload = exercise.toMap()..remove('id');
        batch.insert(
          AppDatabase.exercisesTable,
          payload,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    });
  }

  // ── Units ──

  Future<List<UnitModel>> getUnits() async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppDatabase.unitsTable,
      orderBy: 'sort_order ASC',
    );
    return maps.map(UnitModel.fromMap).toList();
  }

  // ── Lessons ──

  Future<List<LessonModel>> getLessonsByUnit(int unitId) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppDatabase.lessonsTable,
      where: 'unit_id = ?',
      whereArgs: [unitId],
      orderBy: 'sort_order ASC',
    );
    return maps.map(LessonModel.fromMap).toList();
  }

  Future<List<LessonModel>> getAllLessons() async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppDatabase.lessonsTable,
      orderBy: 'unit_id ASC, sort_order ASC',
    );
    return maps.map(LessonModel.fromMap).toList();
  }

  Future<LessonModel?> getLessonById(int id) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppDatabase.lessonsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return LessonModel.fromMap(maps.first);
  }

  // ── Exercises ──

  Future<List<ExerciseModel>> getExercisesByLesson(int lessonId) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppDatabase.exercisesTable,
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      orderBy: 'sort_order ASC',
    );
    return maps.map(ExerciseModel.fromMap).toList();
  }

  // ── User Progress ──

  Future<List<UserProgressModel>> getUserProgress(int userId) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppDatabase.userProgressTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'completed_at DESC',
    );
    return maps.map(UserProgressModel.fromMap).toList();
  }

  Future<Set<int>> getCompletedLessonIds(int userId) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppDatabase.userProgressTable,
      columns: ['lesson_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return maps.map((m) => m['lesson_id'] as int).toSet();
  }

  Future<int> countLearnedWordsFromLessons(int userId) async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT LOWER(TRIM(correct_answer))) as word_count 
      FROM ${AppDatabase.exercisesTable} 
      WHERE lesson_id IN (
        SELECT lesson_id 
        FROM ${AppDatabase.userProgressTable} 
        WHERE user_id = ?
      )
      ''',
      [userId],
    );
    if (result.isEmpty) return 0;
    return (result.first['word_count'] as num?)?.toInt() ?? 0;
  }

  Future<int> getTotalXp(int userId) async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(xp_earned), 0) AS total FROM ${AppDatabase.userProgressTable} WHERE user_id = ?',
      [userId],
    );
    final val = result.first['total'];
    if (val is int) return val;
    if (val is num) return val.toInt();
    return 0;
  }

  Future<int> insertProgress(UserProgressModel progress) async {
    final db = await _appDatabase.database;
    return db.insert(AppDatabase.userProgressTable, progress.toMap());
  }

  // ── Daily Activity ──

  Future<List<DailyActivityModel>> getActivitiesForMonth(
    int userId,
    int year,
    int month,
  ) async {
    final db = await _appDatabase.database;
    final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
    final endMonth = month == 12 ? 1 : month + 1;
    final endYear = month == 12 ? year + 1 : year;
    final endDate = '$endYear-${endMonth.toString().padLeft(2, '0')}-01';
    final maps = await db.query(
      AppDatabase.dailyActivityTable,
      where: 'user_id = ? AND date >= ? AND date < ?',
      whereArgs: [userId, startDate, endDate],
      orderBy: 'date ASC',
    );
    return maps.map(DailyActivityModel.fromMap).toList();
  }

  Future<List<DailyActivityModel>> getAllActivities(int userId) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppDatabase.dailyActivityTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date ASC',
    );
    return maps.map(DailyActivityModel.fromMap).toList();
  }

  Future<void> recordActivity(int userId, int xpEarned) async {
    final db = await _appDatabase.database;
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final existing = await db.query(
      AppDatabase.dailyActivityTable,
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, dateStr],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert(AppDatabase.dailyActivityTable, {
        'user_id': userId,
        'date': dateStr,
        'xp_earned': xpEarned,
        'lessons_completed': 1,
      });
    } else {
      await db.rawUpdate(
        'UPDATE ${AppDatabase.dailyActivityTable} SET xp_earned = xp_earned + ?, lessons_completed = lessons_completed + 1 WHERE user_id = ? AND date = ?',
        [xpEarned, userId, dateStr],
      );
    }
  }

  Future<int> getCurrentStreak(int userId) async {
    final activities = await getAllActivities(userId);
    if (activities.isEmpty) return 0;

    final dates = activities.map((a) => DateTime.parse(a.date)).toList()
      ..sort();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    int streak = 0;
    var checkDate = todayDate;

    // Check if today has activity
    final todayHasActivity = dates.any(
      (d) =>
          d.year == checkDate.year &&
          d.month == checkDate.month &&
          d.day == checkDate.day,
    );

    if (!todayHasActivity) {
      // Check if yesterday had activity (streak can still be valid)
      checkDate = todayDate.subtract(const Duration(days: 1));
      final yesterdayHasActivity = dates.any(
        (d) =>
            d.year == checkDate.year &&
            d.month == checkDate.month &&
            d.day == checkDate.day,
      );
      if (!yesterdayHasActivity) return 0;
    }

    // Count consecutive days backward
    for (
      var date = checkDate;
      ;
      date = date.subtract(const Duration(days: 1))
    ) {
      final hasActivity = dates.any(
        (d) =>
            d.year == date.year && d.month == date.month && d.day == date.day,
      );
      if (hasActivity) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  Future<int> getLongestStreak(int userId) async {
    final activities = await getAllActivities(userId);
    if (activities.isEmpty) return 0;

    final dates = activities.map((a) => DateTime.parse(a.date)).toList()
      ..sort();

    int longest = 1;
    int current = 1;

    for (int i = 1; i < dates.length; i++) {
      final diff = dates[i].difference(dates[i - 1]).inDays;
      if (diff == 1) {
        current++;
        if (current > longest) longest = current;
      } else if (diff > 1) {
        current = 1;
      }
    }
    return longest;
  }
}
