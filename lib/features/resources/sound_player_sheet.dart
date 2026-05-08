import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/theme.dart';
import '../../models/resource_item.dart';
import '../../services/audio_service.dart';

class SoundPlayerSheet extends StatefulWidget {
  final ResourceItem track;
  final ValueChanged<String?> onPlayingChanged;

  const SoundPlayerSheet({
    super.key,
    required this.track,
    required this.onPlayingChanged,
  });

  @override
  State<SoundPlayerSheet> createState() => _SoundPlayerSheetState();
}

class _SoundPlayerSheetState extends State<SoundPlayerSheet> {
  bool _isLoading = true;
  bool _hasError = false;
  double _volume = 0.8;
  String? _errorMessage;

  String get _emoji {
    switch (widget.track.id) {
      case 'rain':         return '🌧️';
      case 'ocean':        return '🌊';
      case 'forest':       return '🌳';
      case 'white_noise':  return '〰️';
      case 'tibetan_bowl': return '🔔';
      case 'binaural':     return '🧠';
      default:             return '🎵';
    }
  }

  @override
  void initState() {
    super.initState();
    _startPlayback();
  }

  Future<void> _startPlayback() async {
    try {
      await AudioService.instance.play(widget.track);
      await AudioService.instance.setVolume(_volume);
      widget.onPlayingChanged(widget.track.id);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('[SoundPlayer] Error playing ${widget.track.id}: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = _friendlyError(e.toString(), widget.track.url);
        });
      }
    }
  }

  String _friendlyError(String raw, String url) {
    if (raw.contains('Unable to load asset') ||
        raw.contains('asset') ||
        raw.contains('FileNotFoundException')) {
      return 'Audio file not found.\n\n'
          'Make sure "${url.split('/').last}" exists in assets/audio/\n'
          'and is listed in pubspec.yaml under assets.';
    }
    if (raw.contains('AudioHandlerService') ||
        raw.contains('ServiceConnection')) {
      return 'Audio service failed to start.\n\n'
          'Check that AudioHandlerService is declared in AndroidManifest.xml.';
    }
    if (raw.contains('codec') || raw.contains('format')) {
      return 'This audio format is not supported on this device.\n\n'
          'Try converting the file to MP3 (128–256 kbps, 44.1 kHz).';
    }
    return 'Playback error:\n$raw';
  }

  Future<void> _togglePlayPause() async {
    if (AudioService.instance.isPlaying) {
      await AudioService.instance.pause();
    } else {
      await AudioService.instance.resume();
    }
    setState(() {});
  }

  Future<void> _stop() async {
    await AudioService.instance.stop();
    widget.onPlayingChanged(null);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _setVolume(double v) async {
    setState(() => _volume = v);
    await AudioService.instance.setVolume(v);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textHint.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Emoji
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              gradient: AppColors.splashGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(_emoji, style: const TextStyle(fontSize: 44)),
            ),
          ),
          const SizedBox(height: 16),

          Text(widget.track.title, style: AppTextStyles.titleLarge),
          const SizedBox(height: 4),
          Text(
            widget.track.subtitle ?? '',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 28),

          // Error state
          if (_hasError) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.error.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ?? 'Playback error',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

          // Loading state
          ] else if (_isLoading) ...[
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text('Loading audio...', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 20),

          // Playback controls
          ] else ...[
            StreamBuilder<PlayerState>(
              stream: AudioService.instance.playerStateStream,
              builder: (context, snapshot) {
                final playing = snapshot.data?.playing ?? false;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _stop,
                      icon: const Icon(Icons.stop_rounded),
                      iconSize: 36,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          gradient: AppColors.splashGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.loop_rounded,
                      color: AppColors.primary.withOpacity(0.7),
                      size: 28,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
          ],

          // Volume slider
          Row(
            children: [
              const Icon(Icons.volume_down_outlined,
                  size: 20, color: AppColors.textSecondary),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.primary.withOpacity(0.2),
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withOpacity(0.15),
                    trackHeight: 4,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 10),
                  ),
                  child: Slider(
                    value: _volume,
                    onChanged: _setVolume,
                    min: 0,
                    max: 1,
                  ),
                ),
              ),
              const Icon(Icons.volume_up_outlined,
                  size: 20, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            'Plays on loop • Supports MP3, WAV, OGG, AAC, FLAC',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
