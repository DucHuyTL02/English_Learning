import '../app_database.dart';
import '../datasources/dictionary_local_datasource.dart';
import '../datasources/dictionary_remote_datasource.dart';
import '../datasources/learning_local_datasource.dart';
import '../datasources/user_local_datasource.dart';
import '../repositories/dictionary_repository.dart';
import '../repositories/learning_repository.dart';
import '../repositories/user_repository.dart';
import 'exercise_session.dart';
import 'learning_content_service.dart';
import 'notification_service.dart';
import 'route_state_service.dart';
import 'social_service.dart';
import 'tts_service.dart';
import 'user_topic_service.dart';

class AppServices {
  AppServices._();

  static final AppDatabase database = AppDatabase.instance;
  static final UserLocalDataSource _userLocalDataSource = UserLocalDataSource(
    database,
  );
  static final LearningLocalDataSource _learningLocalDataSource =
      LearningLocalDataSource(database);
  static final UserRepository userRepository = UserRepository(
    _userLocalDataSource,
  );
  static final DictionaryRepository dictionaryRepository = DictionaryRepository(
    DictionaryLocalDataSource(database),
    DictionaryRemoteDataSource(),
  );
  static final LearningRepository learningRepository = LearningRepository(
    _learningLocalDataSource,
    userLocalDataSource: _userLocalDataSource,
  );
  static final LearningContentService learningContentService =
      LearningContentService();
  static final TtsService tts = TtsService.instance;
  static final ExerciseSession exerciseSession = ExerciseSession.instance;
  static final RouteStateService routeStateService = RouteStateService();
  static final NotificationService notificationService = NotificationService(
    database: database,
  );
  static final SocialService socialService = SocialService(
    notificationService: notificationService,
  );
  static final UserTopicService userTopicService = UserTopicService();

  static Future<void> initialize() async {
    await database.database;
    await learningContentService.bootstrapLearningData(
      repository: learningRepository,
    );
    await notificationService.initialize();
    final user = await userRepository.getActiveUser();
    if (user != null && user.id != null) {
      await learningRepository.ensureRemoteLessonProgressSeeded(user.id!);
      await learningRepository.ensureRemoteStatsSeeded(user.id!);
      final totalXp = await learningRepository.getTotalXp(user.id!);
      final currentStreak = await learningRepository.getCurrentStreak(user.id!);
      try {
        await socialService.syncCurrentUserStats(
          totalXp: totalXp,
          streak: currentStreak,
          localUser: user,
        );
      } catch (_) {
        // Keep app startup resilient when Firestore is temporarily unavailable.
      }
      await notificationService.maybeSendDailyStudyReminder(user: user);
      await socialService.syncInAppNotifications(user: user);
    }
    await routeStateService.initialize();
    await tts.init();
  }
}
