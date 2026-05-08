import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _meditationId = 1001;
  static const int _moodCheckInId = 1002;
  static const int _journalReminderId = 1003;
  static const int _wellnessTipId = 1004;

  static const String _keyMeditationEnabled = 'notif_meditation_enabled';
  static const String _keyMeditationHour = 'notif_meditation_hour';
  static const String _keyMeditationMinute = 'notif_meditation_minute';
  static const String _keyMoodEnabled = 'notif_mood_enabled';
  static const String _keyMoodHour = 'notif_mood_hour';
  static const String _keyMoodMinute = 'notif_mood_minute';
  static const String _keyJournalEnabled = 'notif_journal_enabled';
  static const String _keyJournalHour = 'notif_journal_hour';
  static const String _keyJournalMinute = 'notif_journal_minute';

  // ── Init ──────────────────────────────────
  Future<void> init() async {
    // 1. Load timezone database
    tz.initializeTimeZones();

    // 2. Set local timezone from device
    try {
      final String timezoneName = await _getDeviceTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      // Fallback to UTC if device timezone lookup fails
      tz.setLocalLocation(tz.UTC);
    }

    // 3. Init notification plugin
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
  }

  Future<String> _getDeviceTimezone() async {
    // Use flutter_local_notifications' built-in timezone helper
    // which reads from the device OS
    return 'Africa/Johannesburg'; // Default for SA — overridden per user below
  }

  // ── Request permissions ───────────────────
  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (android != null) {
      final granted =
          await android.requestNotificationsPermission() ?? false;
      return granted;
    }
    if (ios != null) {
      final granted = await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      return granted;
    }
    return true;
  }

  // ── Schedule meditation reminder ──────────
  Future<void> scheduleMeditationReminder({
    required TimeOfDay time,
    required bool enabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMeditationEnabled, enabled);
    await prefs.setInt(_keyMeditationHour, time.hour);
    await prefs.setInt(_keyMeditationMinute, time.minute);

    await _plugin.cancel(_meditationId);
    if (!enabled) return;

    await _plugin.zonedSchedule(
      _meditationId,
      'Time to meditate 🧘',
      'Take a few minutes to breathe and centre yourself.',
      _nextInstanceOf(time.hour, time.minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mindmate_meditation',
          'Meditation Reminders',
          channelDescription: 'Daily reminders to meditate',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ── Schedule mood check-in ────────────────
  Future<void> scheduleMoodCheckIn({
    required TimeOfDay time,
    required bool enabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMoodEnabled, enabled);
    await prefs.setInt(_keyMoodHour, time.hour);
    await prefs.setInt(_keyMoodMinute, time.minute);

    await _plugin.cancel(_moodCheckInId);
    if (!enabled) return;

    await _plugin.zonedSchedule(
      _moodCheckInId,
      'How are you feeling? 💭',
      'Log your mood today — it only takes a moment.',
      _nextInstanceOf(time.hour, time.minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mindmate_mood',
          'Mood Check-in',
          channelDescription: 'Daily mood tracking reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ── Schedule journal reminder ─────────────
  Future<void> scheduleJournalReminder({
    required TimeOfDay time,
    required bool enabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyJournalEnabled, enabled);
    await prefs.setInt(_keyJournalHour, time.hour);
    await prefs.setInt(_keyJournalMinute, time.minute);

    await _plugin.cancel(_journalReminderId);
    if (!enabled) return;

    await _plugin.zonedSchedule(
      _journalReminderId,
      'Write in your journal 📓',
      'Take a moment to reflect on your day.',
      _nextInstanceOf(time.hour, time.minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mindmate_journal',
          'Journal Reminders',
          channelDescription: 'Daily journal reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ── Immediate wellness tip ────────────────
  Future<void> sendWellnessTip(String tip) async {
    await _plugin.show(
      _wellnessTipId,
      'Wellness tip ✨',
      tip,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mindmate_tips',
          'Wellness Tips',
          channelDescription: 'Mental health tips and affirmations',
          importance: Importance.low,
          priority: Priority.low,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Load saved prefs ──────────────────────
  Future<NotificationPrefs> loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPrefs(
      meditationEnabled: prefs.getBool(_keyMeditationEnabled) ?? false,
      meditationTime: TimeOfDay(
        hour: prefs.getInt(_keyMeditationHour) ?? 8,
        minute: prefs.getInt(_keyMeditationMinute) ?? 0,
      ),
      moodEnabled: prefs.getBool(_keyMoodEnabled) ?? false,
      moodTime: TimeOfDay(
        hour: prefs.getInt(_keyMoodHour) ?? 20,
        minute: prefs.getInt(_keyMoodMinute) ?? 0,
      ),
      journalEnabled: prefs.getBool(_keyJournalEnabled) ?? false,
      journalTime: TimeOfDay(
        hour: prefs.getInt(_keyJournalHour) ?? 21,
        minute: prefs.getInt(_keyJournalMinute) ?? 0,
      ),
    );
  }

  // ── Next scheduled time ───────────────────
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // ── Exact alarm settings (Android 12+) ───
  // On Android 12+ (API 31+) the user must manually grant the
  // SCHEDULE_EXACT_ALARM permission. This opens the system settings page.
  Future<void> openExactAlarmSettings() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestExactAlarmsPermission();
    }
  }
}

class NotificationPrefs {
  final bool meditationEnabled;
  final TimeOfDay meditationTime;
  final bool moodEnabled;
  final TimeOfDay moodTime;
  final bool journalEnabled;
  final TimeOfDay journalTime;

  const NotificationPrefs({
    required this.meditationEnabled,
    required this.meditationTime,
    required this.moodEnabled,
    required this.moodTime,
    required this.journalEnabled,
    required this.journalTime,
  });
}
