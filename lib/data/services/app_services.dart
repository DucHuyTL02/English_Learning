import '../app_database.dart';
import '../datasources/dictionary_local_datasource.dart';
import '../datasources/learning_local_datasource.dart';
import '../datasources/user_local_datasource.dart';
import '../repositories/dictionary_repository.dart';
import '../repositories/learning_repository.dart';
import '../repositories/user_repository.dart';
import 'exercise_session.dart';
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
  static final TtsService tts = TtsService.instance;
  static final ExerciseSession exerciseSession = ExerciseSession.instance;
  static final RouteStateService routeStateService = RouteStateService();

  static Future<void> initialize() async {
    await database.database;
    await routeStateService.initialize();
    await tts.init();
  }
}
