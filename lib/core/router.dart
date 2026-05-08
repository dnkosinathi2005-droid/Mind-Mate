import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/alerts/alerts_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/chatbot/chatbot_screen.dart';
import '../features/journal/journal_entry_screen.dart';
import '../features/journal/journal_screen.dart';
import '../features/landing/landing_screen.dart';
import '../features/meditation/meditation_screen.dart';
import '../features/mood/mood_history_screen.dart';
import '../features/mood/mood_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/sync_status_screen.dart';
import '../features/resources/resource_hub_screen.dart';
import '../features/splash/splash_screen.dart';
import '../models/journal_entry.dart';
import 'constants.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: AppConstants.routeSplash,
    debugLogDiagnostics: false,
    redirect: _guard,
    routes: [
      GoRoute(
        path: AppConstants.routeSplash,
        name: 'splash',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SplashScreen()),
      ),
      GoRoute(
        path: AppConstants.routeLogin,
        name: 'login',
        pageBuilder: (context, state) =>
            _slideIn(const LoginScreen(), state),
      ),
      GoRoute(
        path: AppConstants.routeRegister,
        name: 'register',
        pageBuilder: (context, state) =>
            _slideIn(const RegisterScreen(), state),
      ),
      GoRoute(
        path: AppConstants.routeForgotPassword,
        name: 'forgotPassword',
        pageBuilder: (context, state) =>
            _slideIn(const ForgotPasswordScreen(), state),
      ),
      GoRoute(
        path: AppConstants.routeLanding,
        name: 'landing',
        pageBuilder: (context, state) =>
            _fadeIn(const LandingScreen(), state),
      ),
      GoRoute(
        path: AppConstants.routeProfile,
        name: 'profile',
        pageBuilder: (context, state) =>
            _slideIn(const ProfileScreen(), state),
      ),
      GoRoute(
        path: '/sync-status',
        name: 'syncStatus',
        pageBuilder: (context, state) =>
            _slideIn(const SyncStatusScreen(), state),
      ),
      GoRoute(
        path: AppConstants.routeJournal,
        name: 'journal',
        pageBuilder: (context, state) =>
            _slideIn(const JournalScreen(), state),
      ),
      GoRoute(
        path: AppConstants.routeJournalEntry,
        name: 'journalEntry',
        pageBuilder: (context, state) {
          final existing = state.extra as JournalEntry?;
          return _slideIn(
              JournalEntryScreen(existingEntry: existing), state);
        },
      ),
      GoRoute(
        path: AppConstants.routeMood,
        name: 'mood',
        pageBuilder: (context, state) =>
            _slideIn(const MoodScreen(), state),
      ),
      GoRoute(
        path: AppConstants.routeMoodHistory,
        name: 'moodHistory',
        pageBuilder: (context, state) =>
            _slideIn(const MoodHistoryScreen(), state),
      ),
      GoRoute(
        path: AppConstants.routeChatbot,
        name: 'chatbot',
        pageBuilder: (context, state) =>
            _slideIn(const ChatbotScreen(), state),
      ),
      GoRoute(
        path: AppConstants.routeMeditation,
        name: 'meditation',
        pageBuilder: (context, state) =>
            _fadeIn(const MeditationScreen(), state),
      ),
      GoRoute(
        path: AppConstants.routeResources,
        name: 'resources',
        pageBuilder: (context, state) =>
            _slideIn(const ResourceHubScreen(), state),
      ),
      GoRoute(
        path: '/alerts',
        name: 'alerts',
        pageBuilder: (context, state) =>
            _slideIn(const AlertsScreen(), state),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );

  static String? _guard(BuildContext context, GoRouterState state) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    const authRoutes = [
      AppConstants.routeLogin,
      AppConstants.routeRegister,
      AppConstants.routeForgotPassword,
      AppConstants.routeSplash,
    ];

    const protectedRoutes = [
      AppConstants.routeLanding,
      AppConstants.routeProfile,
      '/sync-status',
      AppConstants.routeJournal,
      AppConstants.routeJournalEntry,
      AppConstants.routeMood,
      AppConstants.routeMoodHistory,
      AppConstants.routeChatbot,
      AppConstants.routeMeditation,
      AppConstants.routeResources,
      '/alerts',
    ];

    final location = state.matchedLocation;

    if (isLoggedIn && authRoutes.contains(location)) {
      return AppConstants.routeLanding;
    }
    if (!isLoggedIn && protectedRoutes.contains(location)) {
      return AppConstants.routeLogin;
    }
    return null;
  }

  static CustomTransitionPage _slideIn(Widget child, GoRouterState state) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(
            position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 280),
    );
  }

  static CustomTransitionPage _fadeIn(Widget child, GoRouterState state) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}
