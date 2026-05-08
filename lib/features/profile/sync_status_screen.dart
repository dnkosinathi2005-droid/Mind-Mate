import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../services/connectivity_service.dart';
import '../../services/local_db_service.dart';
import '../../services/sync_service.dart';

class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  int _pendingJournals = 0;
  int _pendingMoods = 0;
  bool _isOnline = false;
  bool _isSyncing = false;
  String? _lastSyncMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityService.instance.isOnline;
    _loadPending();

    ConnectivityService.instance.onlineStream.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });

    SyncService.instance.syncStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isSyncing = state.isSyncing;
        if (state is SyncSuccess) {
          _lastSyncMessage = state.synced > 0
              ? '${state.synced} item${state.synced == 1 ? '' : 's'} synced successfully'
              : 'Everything is up to date';
          _loadPending();
        } else if (state is SyncPartialSuccess) {
          _lastSyncMessage =
              '${state.synced} synced, ${state.failed} failed';
          _loadPending();
        } else if (state is SyncError) {
          _lastSyncMessage = 'Sync error: ${state.message}';
        }
      });
    });
  }

  Future<void> _loadPending() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final journals =
        await LocalDbService.instance.getUnsyncedJournals(uid);
    final moods = await LocalDbService.instance.getUnsyncedMoods(uid);
    if (mounted) {
      setState(() {
        _pendingJournals = journals.length;
        _pendingMoods = moods.length;
        _isLoading = false;
      });
    }
  }

  Future<void> _syncNow() async {
    await SyncService.instance.syncNow();
  }

  int get _totalPending => _pendingJournals + _pendingMoods;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Sync Status'),
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
                  // Connection status card
                  _StatusCard(
                    icon: _isOnline ? Icons.wifi : Icons.wifi_off,
                    iconColor:
                        _isOnline ? AppColors.success : AppColors.warning,
                    title: _isOnline ? 'Online' : 'Offline',
                    subtitle: _isOnline
                        ? 'Connected — data will sync automatically'
                        : 'No connection — data is saved locally',
                  ),
                  const SizedBox(height: 14),

                  // Pending items card
                  _StatusCard(
                    icon: _totalPending > 0
                        ? Icons.cloud_upload_outlined
                        : Icons.cloud_done_outlined,
                    iconColor: _totalPending > 0
                        ? AppColors.warning
                        : AppColors.success,
                    title: _totalPending > 0
                        ? '$_totalPending item${_totalPending == 1 ? '' : 's'} pending sync'
                        : 'All data synced',
                    subtitle: _totalPending > 0
                        ? '$_pendingJournals journal ${_pendingJournals == 1 ? 'entry' : 'entries'}, '
                            '$_pendingMoods mood ${_pendingMoods == 1 ? 'entry' : 'entries'}'
                        : 'Your journal, mood, and meditation data is up to date on Firebase',
                  ),
                  const SizedBox(height: 14),

                  // Last sync message
                  if (_lastSyncMessage != null)
                    _StatusCard(
                      icon: Icons.history_outlined,
                      iconColor: AppColors.textSecondary,
                      title: 'Last sync result',
                      subtitle: _lastSyncMessage!,
                    ),

                  const SizedBox(height: 32),

                  // How sync works
                  Text('How sync works', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: '📱',
                    text:
                        'All data is saved to your device immediately when you write a journal entry or log a mood.',
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: '☁️',
                    text:
                        'When your device is online, data is automatically pushed to Firebase so it is backed up securely.',
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: '🔄',
                    text:
                        'If you go offline, entries queue up locally. As soon as you reconnect, the queue flushes automatically.',
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: '🔒',
                    text:
                        'Your data is private. Firestore rules ensure only you can read or write your entries.',
                  ),
                  const SizedBox(height: 36),

                  // Sync now button
                  if (_isSyncing)
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Syncing...',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isOnline ? _syncNow : null,
                        icon: const Icon(Icons.sync_rounded, size: 18),
                        label: Text(
                          _isOnline
                              ? 'Sync now'
                              : 'Connect to sync',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _StatusCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: AppTextStyles.bodyMedium),
        ),
      ],
    );
  }
}
