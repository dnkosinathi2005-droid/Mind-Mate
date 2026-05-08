import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/resource_item.dart';
import '../../services/affirmation_service.dart';
import '../../services/audio_service.dart';
import 'sound_player_sheet.dart';

class ResourceHubScreen extends StatefulWidget {
  const ResourceHubScreen({super.key});

  @override
  State<ResourceHubScreen> createState() => _ResourceHubScreenState();
}

class _ResourceHubScreenState extends State<ResourceHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _affirmation = '';
  bool _affirmationLoading = true;
  bool _affirmationRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadAffirmation();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAffirmation() async {
    final text = await AffirmationService.instance.getTodayAffirmation();
    if (mounted) {
      setState(() {
        _affirmation = text;
        _affirmationLoading = false;
      });
    }
  }

  Future<void> _refreshAffirmation() async {
    setState(() => _affirmationRefreshing = true);
    final text = await AffirmationService.instance.refreshAffirmation();
    if (mounted) {
      setState(() {
        _affirmation = text;
        _affirmationRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Resource Hub'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: AppTextStyles.labelLarge.copyWith(fontSize: 13),
          tabs: const [
            Tab(text: 'Affirmations'),
            Tab(text: 'Soundscapes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _AffirmationsTab(
            affirmation: _affirmation,
            isLoading: _affirmationLoading,
            isRefreshing: _affirmationRefreshing,
            onRefresh: _refreshAffirmation,
          ),
          const _SoundscapesTab(),
        ],
      ),
    );
  }
}

// ── Affirmations tab ──────────────────────────
class _AffirmationsTab extends StatelessWidget {
  final String affirmation;
  final bool isLoading;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  const _AffirmationsTab({
    required this.affirmation,
    required this.isLoading,
    required this.isRefreshing,
    required this.onRefresh,
  });

  // Static affirmations library shown below the daily card
  static const List<_AffirmationItem> _library = [
    _AffirmationItem(emoji: '💪', text: 'I am stronger than I think.', category: 'Strength'),
    _AffirmationItem(emoji: '❤️', text: 'I deserve love and compassion, especially from myself.', category: 'Self-love'),
    _AffirmationItem(emoji: '🌱', text: 'I am growing and learning every single day.', category: 'Growth'),
    _AffirmationItem(emoji: '🌊', text: 'I let go of what I cannot control and find peace in the present.', category: 'Peace'),
    _AffirmationItem(emoji: '✨', text: 'My feelings are valid and I honour them without judgment.', category: 'Acceptance'),
    _AffirmationItem(emoji: '🔥', text: 'I have the courage to face difficult moments.', category: 'Courage'),
    _AffirmationItem(emoji: '🧠', text: 'I take care of my mental health and that is a strength.', category: 'Wellbeing'),
    _AffirmationItem(emoji: '🕊️', text: 'I release anxiety and welcome calm into my mind.', category: 'Calm'),
    _AffirmationItem(emoji: '🌸', text: 'I am worthy of good things happening to me.', category: 'Worthiness'),
    _AffirmationItem(emoji: '⭐', text: 'I trust myself to navigate whatever comes my way.', category: 'Trust'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Daily affirmation card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppColors.splashGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('✨', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'Today\'s affirmation',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: isRefreshing ? null : onRefresh,
                    child: isRefreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white70,
                            ),
                          )
                        : const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                )
              else
                Text(
                  affirmation,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                    fontSize: 17,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        Text('Affirmation library', style: AppTextStyles.titleMedium),
        const SizedBox(height: 6),
        Text(
          'Tap any card to see the full affirmation.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 16),

        ..._library.map((item) => _AffirmationCard(item: item)),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _AffirmationCard extends StatefulWidget {
  final _AffirmationItem item;
  const _AffirmationCard({required this.item});

  @override
  State<_AffirmationCard> createState() => _AffirmationCardState();
}

class _AffirmationCardState extends State<_AffirmationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expanded
                ? AppColors.primary.withOpacity(0.3)
                : AppColors.textHint.withOpacity(0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(_expanded ? 0.07 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.item.emoji,
                style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.item.category,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.item.text,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                    maxLines: _expanded ? null : 2,
                    overflow: _expanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              color: AppColors.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _AffirmationItem {
  final String emoji;
  final String text;
  final String category;

  const _AffirmationItem({
    required this.emoji,
    required this.text,
    required this.category,
  });
}

// ── Soundscapes tab ───────────────────────────
class _SoundscapesTab extends StatefulWidget {
  const _SoundscapesTab();

  @override
  State<_SoundscapesTab> createState() => _SoundscapesTabState();
}

class _SoundscapesTabState extends State<_SoundscapesTab> {
  String? _playingId;

  void _openPlayer(ResourceItem track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SoundPlayerSheet(
        track: track,
        onPlayingChanged: (id) => setState(() => _playingId = id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Group by category
    final Map<String, List<ResourceItem>> grouped = {};
    for (final track in AudioTracks.tracks) {
      grouped.putIfAbsent(track.category!, () => []).add(track);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Now playing bar
        if (_playingId != null) ...[
          _NowPlayingBar(
            trackId: _playingId!,
            onStop: () async {
              await AudioService.instance.stop();
              setState(() => _playingId = null);
            },
          ),
          const SizedBox(height: 16),
        ],

        Text(
          'Background sounds',
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Play calming sounds during meditation, focus, or rest. '
          'Add your own audio files to assets/audio/ to expand the library.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 20),

        for (final entry in grouped.entries) ...[
          Text(entry.key, style: AppTextStyles.titleMedium.copyWith(
            fontSize: 14,
            color: AppColors.textSecondary,
          )),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: entry.value.map((track) => _SoundCard(
              track: track,
              isPlaying: _playingId == track.id,
              onTap: () => _openPlayer(track),
            )).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _SoundCard extends StatelessWidget {
  final ResourceItem track;
  final bool isPlaying;
  final VoidCallback onTap;

  const _SoundCard({
    required this.track,
    required this.isPlaying,
    required this.onTap,
  });

  String get _emoji {
    switch (track.id) {
      case 'rain': return '🌧️';
      case 'ocean': return '🌊';
      case 'forest': return '🌳';
      case 'white_noise': return '〰️';
      case 'tibetan_bowl': return '🔔';
      case 'binaural': return '🧠';
      default: return '🎵';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: isPlaying
              ? LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.8),
                    AppColors.accent.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isPlaying ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isPlaying
                ? Colors.transparent
                : AppColors.textHint.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: (isPlaying ? AppColors.primary : Colors.black)
                  .withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_emoji, style: const TextStyle(fontSize: 26)),
                Icon(
                  isPlaying
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  color: isPlaying
                      ? Colors.white
                      : AppColors.primary,
                  size: 22,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontSize: 13,
                    color: isPlaying ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  track.subtitle ?? '',
                  style: AppTextStyles.caption.copyWith(
                    color: isPlaying ? Colors.white70 : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingBar extends StatelessWidget {
  final String trackId;
  final VoidCallback onStop;

  const _NowPlayingBar({required this.trackId, required this.onStop});

  @override
  Widget build(BuildContext context) {
    final track = AudioTracks.tracks.firstWhere(
      (t) => t.id == trackId,
      orElse: () => AudioTracks.tracks.first,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Now playing: ${track.title}',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: Colors.white),
            ),
          ),
          IconButton(
            onPressed: onStop,
            icon: const Icon(Icons.stop_circle_outlined,
                color: Colors.white, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
