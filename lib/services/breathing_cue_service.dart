import 'package:flutter_tts/flutter_tts.dart';

/// Speaks inhale / hold / exhale / rest cues during breathing meditation.
/// Uses the device's built-in TTS engine — no internet required.
class BreathingCueService {
  BreathingCueService._();
  static final BreathingCueService instance = BreathingCueService._();

  final FlutterTts _tts = FlutterTts();
  bool _enabled = true;
  bool _initialised = false;

  bool get isEnabled => _enabled;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.38);   // slow and calm
    await _tts.setVolume(0.85);
    await _tts.setPitch(0.9);         // slightly lower — more soothing

    // Prefer a female voice if available
    final voices = await _tts.getVoices;
    if (voices is List) {
      final female = voices.firstWhere(
        (v) =>
            v is Map &&
            (v['name']?.toString().toLowerCase().contains('female') == true ||
             v['name']?.toString().toLowerCase().contains('samantha') == true ||
             v['name']?.toString().toLowerCase().contains('karen') == true),
        orElse: () => null,
      );
      if (female != null && female is Map) {
        await _tts.setVoice({
          'name': female['name'],
          'locale': female['locale'],
        });
      }
    }
  }

  void setEnabled(bool value) => _enabled = value;

  Future<void> speakInhale() async {
    if (!_enabled) return;
    await _speak('Breathe in');
  }

  Future<void> speakHold() async {
    if (!_enabled) return;
    await _speak('Hold');
  }

  Future<void> speakExhale() async {
    if (!_enabled) return;
    await _speak('Breathe out');
  }

  Future<void> speakRest() async {
    if (!_enabled) return;
    await _speak('Rest');
  }

  Future<void> speakPhase(String phase) async {
    switch (phase) {
      case 'inhale': return speakInhale();
      case 'hold':   return speakHold();
      case 'exhale': return speakExhale();
      case 'rest':   return speakRest();
    }
  }

  Future<void> speakCustom(String text) async {
    if (!_enabled) return;
    await _speak(text);
  }

  Future<void> stop() async => _tts.stop();

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
