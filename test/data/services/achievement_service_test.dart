import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:english_learning/data/services/achievement_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final _service = AchievementService();

  const _userId = 1;

  // Helper: tạo stats đơn giản.
  UserLearningStats _stats({
    int completedLessons = 0,
    int currentStreak = 0,
    int longestStreak = 0,
    int savedWords = 0,
    int totalXp = 0,
  }) => UserLearningStats(
        completedLessons: completedLessons,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        savedWords: savedWords,
        totalXp: totalXp,
      );

  group('AchievementService.syncAchievements', () {
    test('unlocks "Bước Đầu Tiên" (id=1) when 1 lesson completed', () async {
      final result = await _service.syncAchievements(
        userId: _userId,
        stats: _stats(completedLessons: 1),
      );

      final unlocked = result.newlyUnlocked.map((p) => p.definition.id);
      expect(unlocked, contains(1));
    });

    test('does NOT re-unlock on second call', () async {
      // Lần 1: mở khóa
      await _service.syncAchievements(
        userId: _userId,
        stats: _stats(completedLessons: 1),
      );

      // Lần 2: cùng stats → không có newlyUnlocked
      final result2 = await _service.syncAchievements(
        userId: _userId,
        stats: _stats(completedLessons: 1),
      );
      expect(result2.newlyUnlocked, isEmpty);
    });

    test('progress is capped at target value', () async {
      final result = await _service.syncAchievements(
        userId: _userId,
        stats: _stats(completedLessons: 100),
      );

      for (final item in result.allProgress) {
        if (item.definition.metric == AchievementMetric.completedLessons) {
          expect(item.progress, lessThanOrEqualTo(item.definition.target));
        }
      }
    });

    test('unlocks multiple achievements in one call', () async {
      final result = await _service.syncAchievements(
        userId: _userId,
        stats: _stats(
          completedLessons: 12,
          currentStreak: 30,
          savedWords: 50,
          totalXp: 1000,
        ),
      );
      // Tất cả 12 thành tích phải được mở khóa.
      expect(result.newlyUnlocked.length, AchievementService.definitions.length);
    });

    test('allProgress length equals definitions length', () async {
      final result = await _service.syncAchievements(
        userId: _userId,
        stats: _stats(),
      );
      expect(result.allProgress.length, AchievementService.definitions.length);
    });

    test('unlockedCount is 0 for zero stats', () async {
      final result = await _service.syncAchievements(
        userId: _userId,
        stats: _stats(),
      );
      expect(result.unlockedCount, 0);
    });
  });

  group('UserLearningStats.maxStreak', () {
    test('returns currentStreak when it is higher', () {
      final stats = _stats(currentStreak: 10, longestStreak: 5);
      expect(stats.maxStreak, 10);
    });

    test('returns longestStreak when it is higher', () {
      final stats = _stats(currentStreak: 3, longestStreak: 30);
      expect(stats.maxStreak, 30);
    });

    test('returns currentStreak when both are equal', () {
      final stats = _stats(currentStreak: 7, longestStreak: 7);
      expect(stats.maxStreak, 7);
    });
  });
}
