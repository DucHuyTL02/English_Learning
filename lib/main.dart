import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/models/user_topic_model.dart';
import 'data/services/app_services.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/dictionary_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/exercise_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/gamification_screen.dart' show AchievementsScreen;
import 'screens/home_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/lesson_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/streak_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/topic_words_screen.dart';
import 'screens/user_topics_screen.dart';
import 'widgets/bottom_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppServices.initialize();
  _attachRouteStateListener();
  runApp(const MainApp());
}

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: false,
              child: child,
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNavigationBar2(),
          ),
        ],
      ),
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
      path: '/verify-email',
      builder: (context, state) => const EmailVerificationScreen(),
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
      builder: (context, state) {
        final lessonId = int.tryParse(
          state.uri.queryParameters['lessonId'] ?? '',
        );
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
      builder: (context, state) {
        final lessonId = int.tryParse(
          state.uri.queryParameters['lessonId'] ?? '',
        );
        final extra = state.extra;
        final launch = extra is FlashcardLaunchConfig ? extra : null;
        return FlashcardScreen(
          lessonId: lessonId,
          customCards: launch?.cards,
          customTitle: launch?.title,
          closeRoute: launch?.closeRoute,
          completeRoute: launch?.completeRoute,
        );
      },
    ),
    GoRoute(
      path: '/flashcard',
      builder: (context, state) {
        final lessonId = int.tryParse(
          state.uri.queryParameters['lessonId'] ?? '',
        );
        final extra = state.extra;
        final launch = extra is FlashcardLaunchConfig ? extra : null;
        return FlashcardScreen(
          lessonId: lessonId,
          customCards: launch?.cards,
          customTitle: launch?.title,
          closeRoute: launch?.closeRoute,
          completeRoute: launch?.completeRoute,
        );
      },
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
      builder: (context, state) {
        final lessonId = int.tryParse(
          state.uri.queryParameters['lessonId'] ?? '',
        );
        return FlashcardScreen(isExercise: true, lessonId: lessonId);
      },
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
      builder: (context, state) =>
          const _PlaceholderScreen(title: 'Trá»£ GiÃºp & Há»— Trá»£'),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/change-password',
      builder: (context, state) => const ChangePasswordScreen(),
    ),
    GoRoute(
      path: '/friends',
      builder: (context, state) => const FriendsScreen(),
    ),
    GoRoute(
      path: '/user-topics',
      builder: (context, state) => const UserTopicsScreen(),
    ),
    GoRoute(
      path: '/user-topics/:topicId',
      builder: (context, state) {
        final topicId = state.pathParameters['topicId'] ?? '';
        final topic = state.extra;
        return TopicWordsScreen(
          topicId: topicId,
          topic: topic is UserTopicModel ? topic : null,
        );
      },
    ),
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

bool _isRouteListenerAttached = false;

void _attachRouteStateListener() {
  if (_isRouteListenerAttached) return;
  _isRouteListenerAttached = true;

  _router.routerDelegate.addListener(() {
    final currentRoute = _router.routerDelegate.currentConfiguration.uri
        .toString();
    unawaited(AppServices.routeStateService.saveRoute(currentRoute));
  });
}

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
