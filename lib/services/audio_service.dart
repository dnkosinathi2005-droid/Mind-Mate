import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../models/resource_item.dart';

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final AudioPlayer _player = AudioPlayer();
  ResourceItem? _currentTrack;
  bool _initialised = false;

  ResourceItem? get currentTrack => _currentTrack;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  bool get isPlaying => _player.playing;
  double get volume => _player.volume;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
      // gain (not transientMayDuck) keeps audio alive on Android
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));

    // Resume after audio interruptions (e.g. phone calls)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        _player.pause();
      } else {
        if (event.type == AudioInterruptionType.pause ||
            event.type == AudioInterruptionType.duck) {
          _player.play();
        }
      }
    });
  }

  Future<void> play(ResourceItem track) async {
    await init();

    // Same track already loaded — just resume
    if (_currentTrack?.id == track.id &&
        _player.processingState != ProcessingState.idle) {
      if (!_player.playing) await _player.play();
      return;
    }

    // Stop previous cleanly before loading new track
    await _player.stop();
    _currentTrack = track;

    try {
      if (track.url.startsWith('assets/')) {
        await _player.setAsset(track.url);
      } else if (track.cachedPath != null) {
        await _player.setFilePath(track.cachedPath!);
      } else {
        await _player.setUrl(track.url);
      }

      await _player.setLoopMode(LoopMode.one);
      await _player.setVolume(0.8);
      await _player.play();
    } catch (e) {
      _currentTrack = null;
      rethrow;
    }
  }

  Future<void> pause() async => _player.pause();
  Future<void> resume() async => _player.play();

  Future<void> stop() async {
    await _player.stop();
    _currentTrack = null;
  }

  Future<void> setVolume(double v) async =>
      _player.setVolume(v.clamp(0.0, 1.0));

  Future<void> seek(Duration position) async => _player.seek(position);

  Future<void> dispose() async => _player.dispose();

  bool isCurrentTrack(String id) => _currentTrack?.id == id;
}
