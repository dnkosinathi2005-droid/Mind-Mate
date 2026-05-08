import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../services/notification_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  NotificationPrefs? _prefs;
  bool _isLoading = true;
  bool _permissionGranted = false;

  // Local mutable state while editing
  bool _meditationEnabled = false;
  TimeOfDay _meditationTime = const TimeOfDay(hour: 8, minute: 0);

  bool _moodEnabled = false;
  TimeOfDay _moodTime = const TimeOfDay(hour: 20, minute: 0);

  bool _journalEnabled = false;
  TimeOfDay _journalTime = const TimeOfDay(hour: 21, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final granted =
        await NotificationService.instance.requestPermissions();
    final prefs = await NotificationService.instance.loadPrefs();
    if (mounted) {
      setState(() {
        _permissionGranted = granted;
        _prefs = prefs;
        _meditationEnabled = prefs.meditationEnabled;
        _meditationTime = prefs.meditationTime;
        _moodEnabled = prefs.moodEnabled;
        _moodTime = prefs.moodTime;
        _journalEnabled = prefs.journalEnabled;
        _journalTime = prefs.journalTime;
        _isLoading = false;
      });
    }
  }

  /*Future<void> _openExactAlarmSettings() async {
    await NotificationService.instance.openExactAlarmSettings();
  }*/

  Future<void> _pickTime(
    TimeOfDay current,
    ValueChanged<TimeOfDay> onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _saveMeditation() async {
    await NotificationService.instance.scheduleMeditationReminder(
      time: _meditationTime,
      enabled: _meditationEnabled,
    );
    _showSaved();
  }

  Future<void> _saveMood() async {
    await NotificationService.instance.scheduleMoodCheckIn(
      time: _moodTime,
      enabled: _moodEnabled,
    );
    _showSaved();
  }

  Future<void> _saveJournal() async {
    await NotificationService.instance.scheduleJournalReminder(
      time: _journalTime,
      enabled: _journalEnabled,
    );
    _showSaved();
  }

  /*Future<void> _sendTestNotification() async {
    await NotificationService.instance.sendWellnessTip(
      'This is a test notification from MindMate. Your reminders are working!',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }*/

  void _showSaved() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reminder saved'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Reminders & Alerts'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Permission warning
                  if (!_permissionGranted)
                    _PermissionBanner(onRetry: _load),

                  Text(
                    'Daily reminders',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Set daily alerts to help build consistent wellness habits.',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  // Meditation reminder
                  _ReminderCard(
                    icon: '🧘',
                    title: 'Meditation reminder',
                    description: 'Daily nudge to take a breathing session',
                    enabled: _meditationEnabled,
                    time: _meditationTime,
                    onToggle: (v) =>
                        setState(() => _meditationEnabled = v),
                    onTimeTap: () => _pickTime(
                      _meditationTime,
                      (t) => setState(() => _meditationTime = t),
                    ),
                    onSave: _saveMeditation,
                    formatTime: _formatTime,
                  ),
                  const SizedBox(height: 14),

                  // Mood check-in
                  _ReminderCard(
                    icon: '🎭',
                    title: 'Mood check-in',
                    description: 'Reminder to log how you are feeling',
                    enabled: _moodEnabled,
                    time: _moodTime,
                    onToggle: (v) => setState(() => _moodEnabled = v),
                    onTimeTap: () => _pickTime(
                      _moodTime,
                      (t) => setState(() => _moodTime = t),
                    ),
                    onSave: _saveMood,
                    formatTime: _formatTime,
                  ),
                  const SizedBox(height: 14),

                  // Journal reminder
                  _ReminderCard(
                    icon: '📓',
                    title: 'Journal reminder',
                    description: 'Prompt to write a daily journal entry',
                    enabled: _journalEnabled,
                    time: _journalTime,
                    onToggle: (v) =>
                        setState(() => _journalEnabled = v),
                    onTimeTap: () => _pickTime(
                      _journalTime,
                      (t) => setState(() => _journalTime = t),
                    ),
                    onSave: _saveJournal,
                    formatTime: _formatTime,
                  ),
                  const SizedBox(height: 32),

                  // Test notification button
                  /*OutlinedButton.icon(
                    onPressed:
                        _permissionGranted ? _sendTestNotification : null,
                    icon: const Icon(Icons.notifications_outlined, size: 18),
                    label: const Text('Send test notification'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Exact alarm settings — required on Android 12+
                  // for scheduled notifications to fire on time
                  OutlinedButton.icon(
                    onPressed: _openExactAlarmSettings,
                    icon: const Icon(Icons.alarm_outlined, size: 18),
                    label: const Text('Grant exact alarm permission (Android 12+)'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      foregroundColor: AppColors.warning,
                      side: const BorderSide(color: AppColors.warning),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'If reminders are not arriving, tap above and enable '
                    '"Alarms & reminders" for MindMate in system settings.',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),*/
                ],
              ),
            ),
    );
  }
}

// ── Permission banner ─────────────────────────
class _PermissionBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _PermissionBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined,
              color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notification permission required',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Please allow notifications in your device settings.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ── Reminder card ─────────────────────────────
class _ReminderCard extends StatelessWidget {
  final String icon;
  final String title;
  final String description;
  final bool enabled;
  final TimeOfDay time;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTimeTap;
  final VoidCallback onSave;
  final String Function(TimeOfDay) formatTime;

  const _ReminderCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.enabled,
    required this.time,
    required this.onToggle,
    required this.onTimeTap,
    required this.onSave,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.textHint.withValues(alpha: 0.2),
          width: enabled ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary
                .withValues(alpha: enabled ? 0.08 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.titleMedium),
                      Text(description, style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: onToggle,
                  activeThumbColor: AppColors.primary,
                ),
              ],
            ),
            if (enabled) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.schedule_outlined,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text('Daily at', style: AppTextStyles.bodyMedium),
                  const SizedBox(width: 8),
                  // Time chip
                  GestureDetector(
                    onTap: onTimeTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            formatTime(time),
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.primary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_outlined,
                              size: 14, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onSave,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
