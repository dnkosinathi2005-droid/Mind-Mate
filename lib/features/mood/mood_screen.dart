import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/mood_entry.dart';
import '../../services/local_db_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/offline_banner.dart';

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen>
    with SingleTickerProviderStateMixin {
  int _selectedScore = 5;
  final _noteCtrl = TextEditingController();
  bool _isSaving = false;
  bool _alreadyLoggedToday = false;
  late AnimationController _emojiAnim;
  late Animation<double> _emojiScale;

  @override
  void initState() {
    super.initState();
    _emojiAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _emojiScale = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _emojiAnim, curve: Curves.elasticOut),
    );
    _checkTodayMood();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _emojiAnim.dispose();
    super.dispose();
  }

  Future<void> _checkTodayMood() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final today = await LocalDbService.instance.getTodayMood(uid);
    if (today != null && mounted) {
      setState(() {
        _alreadyLoggedToday = true;
        _selectedScore = today.moodScore;
        _noteCtrl.text = today.note;
      });
    }
  }

  void _selectScore(int score) {
    setState(() => _selectedScore = score);
    _emojiAnim.forward(from: 0);
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      final entry = MoodEntry(
        userId: uid,
        moodScore: _selectedScore,
        moodLabel: MoodEntry.labelForScore(_selectedScore),
        note: _noteCtrl.text.trim(),
        createdAt: DateTime.now(),
      );
      await LocalDbService.instance.insertMood(entry);
      // Attempt immediate sync if online
      SyncService.instance.syncNow();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mood logged — keep it up!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save mood. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moodColor = AppColors.moodGradient[_selectedScore - 1];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('How are you feeling?'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push(AppConstants.routeMoodHistory),
            icon: const Icon(Icons.bar_chart_outlined, size: 18),
            label: const Text('History'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Already logged banner
              if (_alreadyLoggedToday)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "You've already logged today's mood. Saving again will add a new entry.",
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Big emoji display
              AnimatedBuilder(
                animation: _emojiScale,
                builder: (_, __) => Transform.scale(
                  scale: _emojiScale.value,
                  child: Text(
                    MoodEntry.emojiForScore(_selectedScore),
                    style: const TextStyle(fontSize: 80),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Mood label
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  MoodEntry.labelForScore(_selectedScore),
                  key: ValueKey(_selectedScore),
                  style: AppTextStyles.displayMedium.copyWith(
                    color: moodColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Score: $_selectedScore / 10',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 28),

              // Score selector
              _MoodSlider(
                score: _selectedScore,
                onChanged: _selectScore,
              ),
              const SizedBox(height: 32),

              // Emoji row preview
              _MoodEmojiRow(
                selectedScore: _selectedScore,
                onTap: _selectScore,
              ),
              const SizedBox(height: 32),

              // Note field
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add a note (optional)',
                  style: AppTextStyles.titleMedium,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteCtrl,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.bodyLarge,
                decoration: InputDecoration(
                  hintText:
                      'What\'s contributing to this feeling? Any thoughts you\'d like to capture...',
                  hintStyle: AppTextStyles.bodyMedium,
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  counterStyle: AppTextStyles.caption,
                ),
              ),
              const SizedBox(height: 28),

              PrimaryButton(
                label: 'Log My Mood',
                onPressed: _isSaving ? null : _save,
                isLoading: _isSaving,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Custom mood slider ────────────────────────
class _MoodSlider extends StatelessWidget {
  final int score;
  final ValueChanged<int> onChanged;

  const _MoodSlider({required this.score, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final moodColor = AppColors.moodGradient[score - 1];
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: moodColor,
            inactiveTrackColor: moodColor.withOpacity(0.2),
            thumbColor: moodColor,
            overlayColor: moodColor.withOpacity(0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
            trackHeight: 6,
            valueIndicatorColor: moodColor,
            valueIndicatorTextStyle: AppTextStyles.labelLarge.copyWith(
              color: Colors.white,
            ),
          ),
          child: Slider(
            value: score.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '$score',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1 — Terrible', style: AppTextStyles.caption),
            Text('10 — Amazing', style: AppTextStyles.caption),
          ],
        ),
      ],
    );
  }
}

// ── Emoji tap row ─────────────────────────────
class _MoodEmojiRow extends StatelessWidget {
  final int selectedScore;
  final ValueChanged<int> onTap;

  const _MoodEmojiRow({required this.selectedScore, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(10, (i) {
        final score = i + 1;
        final isSelected = score == selectedScore;
        final color = AppColors.moodGradient[i];
        return GestureDetector(
          onTap: () => onTap(score),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: isSelected ? 36 : 28,
            height: isSelected ? 36 : 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: color, width: 2)
                  : null,
            ),
            child: Text(
              MoodEntry.emojiForScore(score),
              style: TextStyle(fontSize: isSelected ? 22 : 16),
            ),
          ),
        );
      }),
    );
  }
}
