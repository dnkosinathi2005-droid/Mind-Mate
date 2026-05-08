import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/mood_entry.dart';
import '../../services/local_db_service.dart';

class MoodHistoryScreen extends StatefulWidget {
  const MoodHistoryScreen({super.key});

  @override
  State<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

class _MoodHistoryScreenState extends State<MoodHistoryScreen> {
  List<MoodEntry> _recent = [];
  List<MoodEntry> _all = [];
  bool _isLoading = true;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _load();
  }

  Future<void> _load() async {
    if (_uid == null) return;
    final recent = await LocalDbService.instance
        .getRecentMoodEntries(_uid!, days: 7);
    final all = await LocalDbService.instance.getMoodEntries(_uid!);
    if (mounted) {
      setState(() {
        _recent = recent;
        _all = all;
        _isLoading = false;
      });
    }
  }

  double get _avgScore {
    if (_all.isEmpty) return 0;
    return _all.map((e) => e.moodScore).reduce((a, b) => a + b) /
        _all.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Mood History'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            )
          : _all.isEmpty
              ? _EmptyHistory()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    children: [
                      // Summary cards
                      _SummaryRow(
                        total: _all.length,
                        average: _avgScore,
                        streak: _calculateStreak(),
                      ),
                      const SizedBox(height: 24),

                      // 7-day bar chart
                      Text('Last 7 days', style: AppTextStyles.titleMedium),
                      const SizedBox(height: 14),
                      _WeekChart(entries: _recent),
                      const SizedBox(height: 28),

                      // Full history list
                      Text('All entries', style: AppTextStyles.titleMedium),
                      const SizedBox(height: 12),
                      ..._all.map((e) => _MoodTile(entry: e)).toList(),
                    ],
                  ),
                ),
    );
  }

  int _calculateStreak() {
    if (_all.isEmpty) return 0;
    int streak = 0;
    DateTime cursor = DateTime.now();

    for (final entry in _all) {
      final entryDate = DateTime(
        entry.createdAt.year,
        entry.createdAt.month,
        entry.createdAt.day,
      );
      final cursorDate = DateTime(cursor.year, cursor.month, cursor.day);
      if (entryDate == cursorDate ||
          entryDate == cursorDate.subtract(const Duration(days: 1))) {
        streak++;
        cursor = entryDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }
}

// ── Summary row ───────────────────────────────
class _SummaryRow extends StatelessWidget {
  final int total;
  final double average;
  final int streak;

  const _SummaryRow({
    required this.total,
    required this.average,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryCard(
          label: 'Total logs',
          value: '$total',
          emoji: '📊',
        ),
        const SizedBox(width: 12),
        _SummaryCard(
          label: 'Average mood',
          value: average.toStringAsFixed(1),
          emoji: MoodEntry.emojiForScore(average.round().clamp(1, 10)),
        ),
        const SizedBox(width: 12),
        _SummaryCard(
          label: 'Day streak',
          value: '$streak',
          emoji: '🔥',
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String emoji;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.titleLarge,
            ),
            Text(label, style: AppTextStyles.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── 7-day bar chart (pure Flutter, no library needed) ─
class _WeekChart extends StatelessWidget {
  final List<MoodEntry> entries;

  const _WeekChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    // Build a map: day-of-week label → average score
    final Map<String, List<int>> dayScores = {};
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Initialise all 7 days
    final today = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final label = dayLabels[d.weekday - 1];
      dayScores[label] = [];
    }

    for (final entry in entries) {
      final label = dayLabels[entry.createdAt.weekday - 1];
      dayScores[label]?.add(entry.moodScore);
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: dayScores.entries.map((entry) {
          final scores = entry.value;
          final avg = scores.isEmpty
              ? 0.0
              : scores.reduce((a, b) => a + b) / scores.length;
          final barHeight = avg == 0 ? 4.0 : (avg / 10) * 120;
          final color = avg == 0
              ? AppColors.surfaceVariant
              : AppColors.moodGradient[(avg.round() - 1).clamp(0, 9)];

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (avg > 0)
                Text(
                  avg.toStringAsFixed(0),
                  style: AppTextStyles.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 28,
                height: barHeight,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 6),
              Text(entry.key, style: AppTextStyles.caption),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Mood history tile ─────────────────────────
class _MoodTile extends StatelessWidget {
  final MoodEntry entry;

  const _MoodTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.moodGradient[entry.moodScore - 1];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Score badge
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  MoodEntry.emojiForScore(entry.moodScore),
                  style: const TextStyle(fontSize: 18),
                ),
                Text(
                  '${entry.moodScore}',
                  style: AppTextStyles.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.moodLabel,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: color,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(entry.createdAt),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                if (entry.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.note,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Empty history ─────────────────────────────
class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📈', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            Text(
              'No mood data yet',
              style: AppTextStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Start logging your daily mood to see patterns and track your emotional wellbeing over time.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
