import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum AchievementMetric {
  completedLessons,
  maxStreak,
  savedWords,
  totalXp,
}

class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.metric,
    required this.target,
  });

  final int id;
  final String title;
  final String description;
  final String icon;
  final AchievementMetric metric;
  final int target;
}

class UserLearningStats {
  const UserLearningStats({
    required this.completedLessons,
    required this.currentStreak,
    required this.longestStreak,
    required this.savedWords,
    required this.totalXp,
  });

  final int completedLessons;
  final int currentStreak;
  final int longestStreak;
  final int savedWords;
  final int totalXp;

  int get maxStreak => currentStreak > longestStreak ? currentStreak : longestStreak;
}

class AchievementProgress {
  const AchievementProgress({
    required this.definition,
    required this.progress,
    required this.unlocked,
    required this.isNewlyUnlocked,
  });

  final AchievementDefinition definition;
  final int progress;
  final bool unlocked;
  final bool isNewlyUnlocked;
}

class AchievementSyncResult {
  const AchievementSyncResult({
    required this.allProgress,
    required this.newlyUnlocked,
  });

  final List<AchievementProgress> allProgress;
  final List<AchievementProgress> newlyUnlocked;

  int get unlockedCount => allProgress.where((item) => item.unlocked).length;
}

class AchievementService {
  static const List<AchievementDefinition> definitions = [
    AchievementDefinition(
      id: 1,
      title: 'Bước Đầu Tiên',
      description: 'Hoàn thành bài học đầu tiên',
      icon: '🎯',
      metric: AchievementMetric.completedLessons,
      target: 1,
    ),
    AchievementDefinition(
      id: 2,
      title: 'Chiến Binh Tuần',
      description: 'Duy trì chuỗi 7 ngày',
      icon: '🔥',
      metric: AchievementMetric.maxStreak,
      target: 7,
    ),
    AchievementDefinition(
      id: 3,
      title: 'Người Sưu Tầm',
      description: 'Lưu 10 từ vào từ điển',
      icon: '📚',
      metric: AchievementMetric.savedWords,
      target: 10,
    ),
    AchievementDefinition(
      id: 4,
      title: 'Học Viên Chăm Chỉ',
      description: 'Hoàn thành 5 bài học',
      icon: '⚡',
      metric: AchievementMetric.completedLessons,
      target: 5,
    ),
    AchievementDefinition(
      id: 5,
      title: 'Bậc Thầy Từ Vựng',
      description: 'Lưu 50 từ vào từ điển',
      icon: '📖',
      metric: AchievementMetric.savedWords,
      target: 50,
    ),
    AchievementDefinition(
      id: 6,
      title: 'Nhà Vô Địch XP',
      description: 'Đạt 500 XP',
      icon: '⭐',
      metric: AchievementMetric.totalXp,
      target: 500,
    ),
    AchievementDefinition(
      id: 7,
      title: 'Người Chạy Marathon',
      description: 'Chuỗi 30 ngày',
      icon: '🏃',
      metric: AchievementMetric.maxStreak,
      target: 30,
    ),
    AchievementDefinition(
      id: 8,
      title: 'Nhà Thám Hiểm',
      description: 'Hoàn thành 10 bài học',
      icon: '🎓',
      metric: AchievementMetric.completedLessons,
      target: 10,
    ),
    AchievementDefinition(
      id: 9,
      title: 'Siêu Sao XP',
      description: 'Đạt 1000 XP',
      icon: '🌟',
      metric: AchievementMetric.totalXp,
      target: 1000,
    ),
    AchievementDefinition(
      id: 10,
      title: 'Nửa Đường',
      description: 'Hoàn thành 6 bài học',
      icon: '🎯',
      metric: AchievementMetric.completedLessons,
      target: 6,
    ),
    AchievementDefinition(
      id: 11,
      title: 'Huyền Thoại',
      description: 'Hoàn thành tất cả 12 bài học',
      icon: '👑',
      metric: AchievementMetric.completedLessons,
      target: 12,
    ),
    AchievementDefinition(
      id: 12,
      title: 'Chuỗi Vàng',
      description: 'Chuỗi 14 ngày liên tiếp',
      icon: '🏅',
      metric: AchievementMetric.maxStreak,
      target: 14,
    ),
  ];

  String _unlockKey(int userId) => 'achievement_unlocked_ids_$userId';

  Future<AchievementSyncResult> syncAchievements({
    required int userId,
    required UserLearningStats stats,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final unlockedIds = await _getUnlockedIds(userId: userId, prefs: prefs);

    final progress = <AchievementProgress>[];
    final newlyUnlocked = <AchievementProgress>[];

    for (final definition in definitions) {
      final currentValue = _metricValue(definition.metric, stats);
      final capped = currentValue > definition.target ? definition.target : currentValue;
      final shouldBeUnlocked = currentValue >= definition.target;
      final isNew = shouldBeUnlocked && !unlockedIds.contains(definition.id);

      progress.add(AchievementProgress(
        definition: definition,
        progress: capped,
        unlocked: shouldBeUnlocked,
        isNewlyUnlocked: isNew,
      ));

      if (isNew) {
        unlockedIds.add(definition.id);
        newlyUnlocked.add(progress.last);
      }
    }

    await prefs.setString(_unlockKey(userId), jsonEncode(unlockedIds.toList()..sort()));

    return AchievementSyncResult(allProgress: progress, newlyUnlocked: newlyUnlocked);
  }

  Future<Set<int>> _getUnlockedIds({
    required int userId,
    required SharedPreferences prefs,
  }) async {
    final raw = prefs.getString(_unlockKey(userId));
    if (raw == null || raw.trim().isEmpty) return <int>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((item) => item is num ? item.toInt() : null)
            .whereType<int>()
            .toSet();
      }
    } catch (_) {
      return <int>{};
    }
    return <int>{};
  }

  int _metricValue(AchievementMetric metric, UserLearningStats stats) {
    switch (metric) {
      case AchievementMetric.completedLessons:
        return stats.completedLessons;
      case AchievementMetric.maxStreak:
        return stats.maxStreak;
      case AchievementMetric.savedWords:
        return stats.savedWords;
      case AchievementMetric.totalXp:
        return stats.totalXp;
    }
  }
}
