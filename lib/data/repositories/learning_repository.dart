import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../datasources/learning_local_datasource.dart';
import '../datasources/user_local_datasource.dart';
import '../models/unit_model.dart';
import '../models/lesson_model.dart';
import '../models/exercise_model.dart';
import '../models/user_progress_model.dart';
import '../models/daily_activity_model.dart';
import '../models/user_model.dart';

class LearningRepositoryException implements Exception {
  LearningRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LearningRepository {
  LearningRepository(
    this._ds, {
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    UserLocalDataSource? userLocalDataSource,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _userLocalDataSource = userLocalDataSource;

  final LearningLocalDataSource _ds;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final UserLocalDataSource? _userLocalDataSource;

  static const String _usersCollection = 'users';
  static const String _dailyActivityCollection = 'daily_activity';
  static const String _lessonProgressCollection = 'lesson_progress';

  Future<void> upsertLearningContent({
    required List<UnitModel> units,
    required List<LessonModel> lessons,
    required List<ExerciseModel> exercises,
  }) async {
    try {
      await _ds.upsertLearningContent(
        units: units,
        lessons: lessons,
        exercises: exercises,
      );
    } catch (_) {
      throw LearningRepositoryException('Khong the dong bo noi dung bai hoc.');
    }
  }

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

  // ── Progress ──

  Future<Set<int>> getCompletedLessonIds(int userId) async {
    try {
      final remoteIds = await _getRemoteCompletedLessonIds();
      if (remoteIds != null) {
        if (remoteIds.isEmpty) {
          final localIds = await _ds.getCompletedLessonIds(userId);
          if (localIds.isNotEmpty) {
            final localProgress = await _ds.getUserProgress(userId);
            final uid = _auth.currentUser?.uid;
            if (uid != null) {
              await _seedRemoteLessonProgress(uid, localProgress);
            }
            return localIds;
          }
        }
        return remoteIds;
      }
      return await _ds.getCompletedLessonIds(userId);
    } catch (_) {
      throw LearningRepositoryException('Không thể tải tiến độ học.');
    }
  }

  Future<int> countLearnedWordsFromLessons(int userId) async {
    try {
      return await _ds.countLearnedWordsFromLessons(userId);
    } catch (_) {
      throw LearningRepositoryException('Không thể tải số từ vựng khóa học.');
    }
  }

  Future<int> getTotalXp(int userId) async {
    try {
      final remote = await _getRemoteStats(userId);
      if (remote != null) return remote.totalXp;
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
      final completedAt = DateTime.now();
      final progress = UserProgressModel(
        userId: userId,
        lessonId: lessonId,
        score: score,
        xpEarned: xpEarned,
        completedAt: completedAt,
      );
      await _ds.insertProgress(progress);
      await _ds.recordActivity(userId, xpEarned);
      await _syncRemoteLessonProgress(progress);
      await _syncRemoteStatsAfterLesson(
        userId: userId,
        xpEarned: xpEarned,
        completedAt: completedAt,
      );
    } catch (_) {
      throw LearningRepositoryException('Không thể lưu tiến độ bài học.');
    }
  }

  // ── Streak ──

  Future<int> getCurrentStreak(int userId) async {
    try {
      final remote = await _getRemoteStats(userId);
      if (remote != null) return remote.currentStreak;
      return await _ds.getCurrentStreak(userId);
    } catch (_) {
      return 0;
    }
  }

  Future<int> getLongestStreak(int userId) async {
    try {
      final remote = await _getRemoteStats(userId);
      if (remote != null) return remote.longestStreak;
      return await _ds.getLongestStreak(userId);
    } catch (_) {
      return 0;
    }
  }

  Future<int> getTotalActivityDays(int userId) async {
    try {
      final remote = await _getRemoteStats(userId);
      if (remote != null) return remote.totalActivityDays;
      final activities = await _ds.getAllActivities(userId);
      return activities.length;
    } catch (_) {
      return 0;
    }
  }

  Future<List<DailyActivityModel>> getActivitiesForMonth(
    int userId,
    int year,
    int month,
  ) async {
    try {
      final remoteActivities = await _getRemoteActivitiesForMonth(
        userId,
        year,
        month,
      );
      if (remoteActivities != null) return remoteActivities;
      return await _ds.getActivitiesForMonth(userId, year, month);
    } catch (_) {
      return [];
    }
  }

  Future<int> getMonthActivityCount(int userId, int year, int month) async {
    try {
      final activities = await getActivitiesForMonth(userId, year, month);
      return activities.length;
    } catch (_) {
      return 0;
    }
  }

  /// Trả về true nếu user được phép học lesson này.
  /// Bài đầu tiên (sortOrder = 1, unitId = 1) luôn FREE.
  /// Tất cả bài còn lại yêu cầu Premium.
  Future<bool> canAccessLesson(int lessonId, UserModel user) async {
    try {
      final lesson = await _ds.getLessonById(lessonId);
      if (lesson == null) return false;
      if (lesson.unitId == 1 && lesson.sortOrder == 1) return true;
      return user.isActivePremium;
    } catch (_) {
      return false;
    }
  }

  /// Seeds Firestore completed lesson documents from local progress cache.
  Future<void> ensureRemoteLessonProgressSeeded(int userId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final hasRemoteProgress = await _hasAnyRemoteLessonProgress(uid);
      if (hasRemoteProgress) return;

      final localProgress = await _ds.getUserProgress(userId);
      if (localProgress.isEmpty) return;

      await _seedRemoteLessonProgress(uid, localProgress);
    } catch (_) {
      // Keep startup resilient. App can continue with local fallback.
    }
  }

  /// Seeds Firestore XP/streak from local cache if cloud stats are empty.
  Future<void> ensureRemoteStatsSeeded(int userId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final hasRemoteActivity = await _hasAnyRemoteActivity(uid);
      if (hasRemoteActivity) {
        return;
      }

      final localActivities = await _ds.getAllActivities(userId);
      if (localActivities.isEmpty) {
        final remoteStats = await _getRemoteStats(userId);
        final hasRemoteStats =
            remoteStats != null &&
            (remoteStats.totalXp > 0 || remoteStats.currentStreak > 0);
        if (hasRemoteStats) return;
      }

      if (localActivities.isNotEmpty) {
        await _seedRemoteActivities(uid, localActivities);
      }

      final totalXp = localActivities.isNotEmpty
          ? localActivities.fold<int>(0, (acc, a) => acc + a.xpEarned)
          : await _ds.getTotalXp(userId);
      final currentStreak = _calculateCurrentStreak(localActivities);
      final longestStreak = _calculateLongestStreak(localActivities);
      final totalDays = localActivities.length;

      await _firestore.collection(_usersCollection).doc(uid).set({
        'xp': totalXp,
        'totalXp': totalXp,
        'streak': currentStreak,
        'longestStreak': longestStreak,
        'totalActivityDays': totalDays,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _syncLocalUserXp(userId: userId, totalXp: totalXp);
    } catch (_) {
      // Keep startup resilient. App can continue with local fallback.
    }
  }

  Future<void> _syncRemoteStatsAfterLesson({
    required int userId,
    required int xpEarned,
    required DateTime completedAt,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final date = _formatDate(completedAt);
      final dayRef = _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_dailyActivityCollection)
          .doc(date);

      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(dayRef);
        final data = snap.data();
        final nextXp = _readInt(data, 'xpEarned') + xpEarned;
        final nextLessons = _readInt(data, 'lessonsCompleted') + 1;
        txn.set(dayRef, {
          'date': date,
          'xpEarned': nextXp,
          'lessonsCompleted': nextLessons,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      final activities = await _getAllRemoteActivities(uid, userId: userId);
      final totalXp = activities.fold<int>(0, (acc, a) => acc + a.xpEarned);
      final currentStreak = _calculateCurrentStreak(activities);
      final longestStreak = _calculateLongestStreak(activities);
      final totalDays = activities.length;

      await _firestore.collection(_usersCollection).doc(uid).set({
        'xp': totalXp,
        'totalXp': totalXp,
        'streak': currentStreak,
        'longestStreak': longestStreak,
        'totalActivityDays': totalDays,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _syncLocalUserXp(userId: userId, totalXp: totalXp);
    } catch (_) {
      // Keep lesson completion smooth when cloud sync is temporarily unavailable.
    }
  }

  Future<void> _syncRemoteLessonProgress(UserProgressModel progress) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final lessonId = progress.lessonId;
      final ref = _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_lessonProgressCollection)
          .doc('$lessonId');

      await ref.set({
        'lessonId': lessonId,
        'score': progress.score,
        'xpEarned': progress.xpEarned,
        'completedAt': Timestamp.fromDate(progress.completedAt),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Keep lesson completion smooth when cloud sync is temporarily unavailable.
    }
  }

  Future<Set<int>?> _getRemoteCompletedLessonIds() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_lessonProgressCollection)
          .get();

      final ids = <int>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lessonId = _readInt(
          data,
          'lessonId',
          fallback: int.tryParse(doc.id) ?? 0,
        );
        if (lessonId > 0) ids.add(lessonId);
      }
      return ids;
    } catch (_) {
      return null;
    }
  }

  Future<_RemoteStats?> _getRemoteStats(int userId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;

      final totalXp = _readInt(
        data,
        'xp',
        fallback: _readInt(data, 'totalXp'),
      );
      final currentStreak = _readInt(data, 'streak');
      final longestStreak = _readInt(
        data,
        'longestStreak',
        fallback: currentStreak,
      );
      final totalActivityDays = _readInt(data, 'totalActivityDays');

      await _syncLocalUserXp(userId: userId, totalXp: totalXp);

      return _RemoteStats(
        totalXp: totalXp,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        totalActivityDays: totalActivityDays,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncLocalUserXp({
    required int userId,
    required int totalXp,
  }) async {
    final userDs = _userLocalDataSource;
    if (userDs == null) return;
    final user = await userDs.getUserById(userId);
    if (user == null || user.totalXp == totalXp) return;
    await userDs.updateUser(user.copyWith(totalXp: totalXp));
  }

  Future<List<DailyActivityModel>?> _getRemoteActivitiesForMonth(
    int userId,
    int year,
    int month,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
    final endMonth = month == 12 ? 1 : month + 1;
    final endYear = month == 12 ? year + 1 : year;
    final endDate =
        '$endYear-${endMonth.toString().padLeft(2, '0')}-01';

    try {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_dailyActivityCollection)
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThan: endDate)
          .orderBy('date')
          .get();

      return snapshot.docs
          .map((doc) => _toDailyActivity(
                doc.data(),
                userId,
                fallbackDate: doc.id,
              ))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<List<DailyActivityModel>> _getAllRemoteActivities(
    String uid, {
    required int userId,
  }) async {
    final snapshot = await _firestore
        .collection(_usersCollection)
        .doc(uid)
        .collection(_dailyActivityCollection)
        .orderBy('date')
        .get();
    return snapshot.docs
      .map((doc) => _toDailyActivity(
          doc.data(),
          userId,
          fallbackDate: doc.id,
        ))
        .toList();
  }

  Future<bool> _hasAnyRemoteActivity(String uid) async {
    final snapshot = await _firestore
        .collection(_usersCollection)
        .doc(uid)
        .collection(_dailyActivityCollection)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<bool> _hasAnyRemoteLessonProgress(String uid) async {
    final snapshot = await _firestore
        .collection(_usersCollection)
        .doc(uid)
        .collection(_lessonProgressCollection)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> _seedRemoteActivities(
    String uid,
    List<DailyActivityModel> localActivities,
  ) async {
    const batchSize = 350;
    for (int i = 0; i < localActivities.length; i += batchSize) {
      final end = i + batchSize < localActivities.length
          ? i + batchSize
          : localActivities.length;
      final batch = _firestore.batch();
      for (final activity in localActivities.sublist(i, end)) {
        final date = activity.date.trim();
        if (date.isEmpty) continue;
        final ref = _firestore
            .collection(_usersCollection)
            .doc(uid)
            .collection(_dailyActivityCollection)
            .doc(date);
        batch.set(ref, {
          'date': date,
          'xpEarned': activity.xpEarned,
          'lessonsCompleted': activity.lessonsCompleted,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  Future<void> _seedRemoteLessonProgress(
    String uid,
    List<UserProgressModel> localProgress,
  ) async {
    if (localProgress.isEmpty) return;

    final latestByLesson = <int, UserProgressModel>{};
    for (final progress in localProgress) {
      final existing = latestByLesson[progress.lessonId];
      if (existing == null || progress.completedAt.isAfter(existing.completedAt)) {
        latestByLesson[progress.lessonId] = progress;
      }
    }

    const batchSize = 350;
    final deduped = latestByLesson.values.toList();
    for (int i = 0; i < deduped.length; i += batchSize) {
      final end = i + batchSize < deduped.length ? i + batchSize : deduped.length;
      final batch = _firestore.batch();
      for (final progress in deduped.sublist(i, end)) {
        final lessonId = progress.lessonId;
        if (lessonId <= 0) continue;
        final ref = _firestore
            .collection(_usersCollection)
            .doc(uid)
            .collection(_lessonProgressCollection)
            .doc('$lessonId');
        batch.set(ref, {
          'lessonId': lessonId,
          'score': progress.score,
          'xpEarned': progress.xpEarned,
          'completedAt': Timestamp.fromDate(progress.completedAt),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  DailyActivityModel _toDailyActivity(
    Map<String, dynamic> data,
    int userId, {
    String fallbackDate = '',
  }) {
    return DailyActivityModel(
      userId: userId,
      date: _readString(data, 'date', fallback: fallbackDate),
      xpEarned: _readInt(data, 'xpEarned'),
      lessonsCompleted: _readInt(data, 'lessonsCompleted'),
    );
  }

  int _calculateCurrentStreak(List<DailyActivityModel> activities) {
    if (activities.isEmpty) return 0;
    final dates = _extractSortedDistinctDates(activities);
    if (dates.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var checkDate = today;

    final todayHasActivity = dates.contains(checkDate);
    if (!todayHasActivity) {
      checkDate = today.subtract(const Duration(days: 1));
      if (!dates.contains(checkDate)) return 0;
    }

    int streak = 0;
    for (
      var date = checkDate;
      ;
      date = date.subtract(const Duration(days: 1))
    ) {
      if (dates.contains(date)) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int _calculateLongestStreak(List<DailyActivityModel> activities) {
    if (activities.isEmpty) return 0;
    final dates = _extractSortedDistinctDates(activities).toList()..sort();
    if (dates.isEmpty) return 0;

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

  Set<DateTime> _extractSortedDistinctDates(List<DailyActivityModel> activities) {
    return activities
        .map((a) => DateTime.tryParse(a.date))
        .whereType<DateTime>()
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
  }

  String _formatDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _readString(
    Map<String, dynamic>? data,
    String key, {
    String fallback = '',
  }) {
    if (data == null) return fallback;
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value;
    return fallback;
  }

  int _readInt(Map<String, dynamic>? data, String key, {int fallback = 0}) {
    if (data == null) return fallback;
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class _RemoteStats {
  const _RemoteStats({
    required this.totalXp,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalActivityDays,
  });

  final int totalXp;
  final int currentStreak;
  final int longestStreak;
  final int totalActivityDays;
}
