import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import 'widgets/bottom_navigation.dart';

void main() {
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
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
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
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
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
      path: '/lesson-intro',
      builder: (context, state) => const LessonIntroScreen(),
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
      builder: (context, state) => const _PlaceholderScreen(title: 'Thông Báo'),
    ),
    GoRoute(
      path: '/streak',
      builder: (context, state) => const StreakCalendarScreen(),
    ),
    GoRoute(
      path: '/subscription',
      builder: (context, state) => const _PlaceholderScreen(title: 'Gói Premium'),
    ),
    GoRoute(
      path: '/help',
      builder: (context, state) => const _PlaceholderScreen(title: 'Trợ Giúp & Hỗ Trợ'),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const _PlaceholderScreen(title: 'Đổi Mật Khẩu'),
    ),

    // ── Shell: các màn hình chính có BottomNavigation ──────────────────────
    ShellRoute(
      builder: (context, state, child) => _ShellScaffold(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
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

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFFFA5C5C),
        foregroundColor: Colors.white,
      ),
      body: Center(child: Text(title, style: const TextStyle(fontSize: 20))),
    );
  }
}
