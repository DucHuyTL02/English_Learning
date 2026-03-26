import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'data/services/app_services.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/lesson_screen.dart';
import 'screens/exercise_screen.dart';
import 'screens/gamification_screen.dart';
import 'screens/dictionary_screen.dart';
import 'screens/streak_screen.dart';
import 'screens/utility_screens.dart';
import 'widgets/bottom_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppServices.initialize();
  runApp(const MainApp());
}

/// Shell scaffold — dùng Stack để đặt BottomNavigation lên trên màn hình con.
/// Tránh double-Scaffold bằng cách dùng Overlay/Stack thay vì lồng Scaffold.
class _ShellScaffold extends StatelessWidget {
  final Widget child;
  const _ShellScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Màn hình con (có Scaffold riêng), thêm padding phía dưới cho bottom nav
        MediaQuery.removePadding(
          context: context,
          removeBottom: false,
          child: child,
        ),
        // BottomNavigation cố định ở dưới
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: BottomNavigationBar2(),
        ),
      ],
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/onboarding-1',
      builder: (context, state) => const OnboardingScreen1(),
    ),
    GoRoute(
      path: '/onboarding-2',
      builder: (context, state) => const OnboardingScreen2(),
    ),
    GoRoute(
      path: '/onboarding-3',
      builder: (context, state) => const OnboardingScreen3(),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/lesson-intro/:lessonId',
      builder: (context, state) {
        final lessonId = int.tryParse(state.pathParameters['lessonId'] ?? '') ?? 1;
        return LessonIntroScreen(lessonId: lessonId);
      },
    ),
    GoRoute(
      path: '/exercise/multiple-choice',
      builder: (context, state) => const MultipleChoiceScreen(),
    ),
    GoRoute(
      path: '/exercise/listening',
      builder: (context, state) => const ListeningScreen(),
    ),
    GoRoute(
      path: '/exercise/speaking',
      builder: (context, state) => const SpeakingExerciseScreen(),
    ),
    GoRoute(
      path: '/exercise/matching',
      builder: (context, state) => const MatchingExerciseScreen(),
    ),
    GoRoute(
      path: '/practice/vocabulary',
      builder: (context, state) => const FlashcardScreen(),
    ),
    GoRoute(
      path: '/flashcard',
      builder: (context, state) => const FlashcardScreen(),
    ),
    GoRoute(
      path: '/lesson-completed',
      builder: (context, state) => const LessonCompletedScreen(),
    ),
    GoRoute(
      path: '/practice/speaking',
      builder: (context, state) => const SpeakingExerciseScreen(),
    ),
    GoRoute(
      path: '/exercise/flashcard',
      builder: (context, state) => const FlashcardScreen(isExercise: true),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/streak',
      builder: (context, state) => const StreakCalendarScreen(),
    ),
    GoRoute(
      path: '/subscription',
      builder: (context, state) => const SubscriptionScreen(),
    ),
    GoRoute(
      path: '/help',
      builder: (context, state) => const HelpScreen(),
    ),
    GoRoute(
      path: '/debug/local-users',
      builder: (context, state) => const LocalUsersDebugScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ChangePasswordScreen(),
    ),

    // ── Shell: các màn hình chính có BottomNavigation ──────────────────────
    ShellRoute(
      builder: (context, state, child) => _ShellScaffold(child: child),
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/course-map',
          builder: (context, state) => const CourseMapScreen(),
        ),
        GoRoute(
          path: '/dictionary',
          builder: (context, state) => const DictionaryScreen(),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (context, state) => const LeaderboardScreen(),
        ),
        GoRoute(
          path: '/achievements',
          builder: (context, state) => const AchievementsScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const UserProfileScreen(),
        ),
      ],
    ),
  ],
);

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LinguaJoy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFA5C5C)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      routerConfig: _router,
    );
  }
}


