class AppConstants {
  AppConstants._();

  // ── App info ──────────────────────────────
  static const String appName = 'MindMate';
  static const String appVersion = '1.0.0';

  // ── Route names ───────────────────────────
  static const String routeSplash = '/';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeForgotPassword = '/forgot-password';
  static const String routeLanding = '/home';
  static const String routeProfile = '/profile';
  static const String routeJournal = '/journal';
  static const String routeJournalEntry = '/journal/entry';
  static const String routeMood = '/mood';
  static const String routeMoodHistory = '/mood/history';
  static const String routeChatbot = '/chatbot';
  static const String routeMeditation = '/meditation';
  static const String routeResources = '/resources';

  // ── SQLite ────────────────────────────────
  static const String dbName = 'mindmate.db';
  static const int dbVersion = 1;

  // ── Firestore collections ─────────────────
  static const String colUsers = 'users';
  static const String colJournalEntries = 'journal_entries';
  static const String colMoodEntries = 'mood_entries';
  static const String colChatMessages = 'chat_messages';
  static const String colMeditationSessions = 'meditation_sessions';

  // ── Firebase Storage paths ────────────────
  static const String storageAvatars = 'avatars';

  // ── Emergency contact numbers (SA) ────────
  static const String emergencyNameSadag = 'SADAG (Depression & Anxiety)';
  static const String emergencyNumSadag = '0800 21 22 23';
  static const String emergencyNameLifeline = 'Lifeline South Africa';
  static const String emergencyNumLifeline = '0861 322 322';
  static const String emergencyNameChildline = 'Childline SA';
  static const String emergencyNumChildline = '116';
  static const String emergencyNameSuicide = 'SA Depression & Bipolar Group';
  static const String emergencyNumSuicide = '0800 456 789';

  // ── Timeouts & limits ─────────────────────
  static const int splashDurationMs = 2500;
  static const int httpTimeoutSeconds = 30;
  static const int maxJournalChars = 2000;
  static const int maxChatHistory = 20;

  // ── Poppins fallback when font not loaded ─
  static const String fontFamily = 'Poppins';
}
