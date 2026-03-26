import '../app_database.dart';
import '../datasources/dictionary_local_datasource.dart';
import '../datasources/learning_local_datasource.dart';
import '../datasources/user_local_datasource.dart';
import '../repositories/dictionary_repository.dart';
import '../repositories/learning_repository.dart';
import '../repositories/user_repository.dart';
import 'achievement_service.dart';
import 'exercise_session.dart';
import 'leaderboard_service.dart';
import 'notification_service.dart';
import 'route_state_service.dart';
import 'tts_service.dart';

class AppServices {
  AppServices._();

  static final AppDatabase database = AppDatabase.instance;
  static final UserRepository userRepository = UserRepository(
    UserLocalDataSource(database),
  );
  static final DictionaryRepository dictionaryRepository = DictionaryRepository(
    DictionaryLocalDataSource(database),
  );
  static final LearningRepository learningRepository = LearningRepository(
    LearningLocalDataSource(database),
  );
  static final LeaderboardService leaderboardService = LeaderboardService();
  static final AchievementService achievementService = AchievementService();
  static final NotificationService notificationService = NotificationService();
  static final TtsService tts = TtsService.instance;
  static final ExerciseSession exerciseSession = ExerciseSession.instance;
  static final RouteStateService routeStateService = RouteStateService();

  static Future<void> initialize() async {
    await database.database;
    await routeStateService.initialize();
    await tts.init();
    await notificationService.initialize();
  }

  static Future<void> syncGamificationForUser(int userId) async {
    final user = await userRepository.getActiveUser();
    if (user == null || user.id != userId) return;

    final completedIds = await learningRepository.getCompletedLessonIds(userId);
    final currentStreak = await learningRepository.getCurrentStreak(userId);
    final longestStreak = await learningRepository.getLongestStreak(userId);
    final totalXp = await learningRepository.getTotalXp(userId);
    final savedWords = await dictionaryRepository.countSavedWords();

    final stats = UserLearningStats(
      completedLessons: completedIds.length,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      savedWords: savedWords,
      totalXp: totalXp,
    );

    final achievementResult = await achievementService.syncAchievements(
      userId: userId,
      stats: stats,
    );

    await leaderboardService.upsertUserEntry(
      userId: userId,
      displayName: user.displayName,
      avatarEmoji: user.avatarEmoji,
      totalXp: totalXp,
      currentStreak: currentStreak,
      achievementsUnlocked: achievementResult.unlockedCount,
    );

    for (final unlocked in achievementResult.newlyUnlocked) {
      await notificationService.addEvent(
        title: 'Thành tích mới được mở khóa',
        body: '${unlocked.definition.icon} ${unlocked.definition.title}',
        type: 'achievement',
        showLocalToast: true,
      );
    }
  }
}
