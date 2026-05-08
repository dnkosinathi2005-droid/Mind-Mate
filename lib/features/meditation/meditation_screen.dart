import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/meditation_session.dart';
import '../../services/activity_tracking_service.dart';
import '../../services/breathing_cue_service.dart';
import '../../services/local_db_service.dart';
import 'breathing_widget.dart';

enum MeditationMode { breathing, walking, running }

class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key});

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen>
    with TickerProviderStateMixin {

  MeditationMode _mode = MeditationMode.breathing;

  // Breathing state
  bool _isRunning = false;
  BreathingPhase _currentPhase = BreathingPhase.inhale;
  int _elapsedSeconds = 0;
  Timer? _timer;
  bool _voiceCuesEnabled = true;

  late TabController _presetTabCtrl;
  final List<_Preset> _presets = const [
    _Preset(label: '3 min',  minutes: 3,  inhale: 4, hold: 2, exhale: 6, rest: 2),
    _Preset(label: '5 min',  minutes: 5,  inhale: 4, hold: 2, exhale: 6, rest: 2),
    _Preset(label: '10 min', minutes: 10, inhale: 4, hold: 4, exhale: 6, rest: 4),
    _Preset(label: '15 min', minutes: 15, inhale: 4, hold: 4, exhale: 8, rest: 4),
  ];
  int _selectedPresetIndex = 0; // default: 3 min

  _Preset get _activePreset => _presets[_selectedPresetIndex];
  int get _targetSeconds => _activePreset.minutes * 60;
  int get _remainingSeconds =>
      (_targetSeconds - _elapsedSeconds).clamp(0, _targetSeconds);
  double get _progress =>
      _targetSeconds > 0 ? _elapsedSeconds / _targetSeconds : 0;

  // Activity state
  double _distance = 0;
  int _steps = 0;
  bool _locationPermitted = false;
  String? _activityError;

  // Stats
  int _totalSeconds = 0;
  int _streakDays = 0;
  List<MeditationSession> _recentSessions = [];
  bool _statsLoading = true;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;

    _presetTabCtrl = TabController(
      length: _presets.length,
      vsync: this,
      initialIndex: 0,
    )..addListener(() {
        if (!_presetTabCtrl.indexIsChanging && !_isRunning) {
          setState(() => _selectedPresetIndex = _presetTabCtrl.index);
        }
      });

    BreathingCueService.instance.init();
    _loadStats();

    ActivityTrackingService.instance.onDistanceUpdate =
        (d) { if (mounted) setState(() => _distance = d); };
    ActivityTrackingService.instance.onStepUpdate =
        (s) { if (mounted) setState(() => _steps = s); };
    ActivityTrackingService.instance.onError =
        (e) { if (mounted) setState(() => _activityError = e); };
  }

  @override
  void dispose() {
    _timer?.cancel();
    _presetTabCtrl.dispose();
    BreathingCueService.instance.stop();
    if (_isRunning) ActivityTrackingService.instance.stop();
    super.dispose();
  }

  Future<void> _loadStats() async {
    if (_uid == null) return;
    final total = await LocalDbService.instance.getTotalMeditationSeconds(_uid!);
    final streak = await LocalDbService.instance.getMeditationStreakDays(_uid!);
    final sessions = await LocalDbService.instance.getMeditationSessions(_uid!);
    if (mounted) {
      setState(() {
        _totalSeconds = total;
        _streakDays = streak;
        _recentSessions = sessions.take(5).toList();
        _statsLoading = false;
      });
    }
  }

  Future<void> _switchMode(MeditationMode mode) async {
    if (_isRunning) return;
    if (mode != MeditationMode.breathing && !_locationPermitted) {
      final granted = await ActivityTrackingService.instance.requestPermissions();
      if (!mounted) return;
      setState(() => _locationPermitted = granted);
      if (!granted) return;
    }
    setState(() { _mode = mode; _activityError = null; });
  }

  Future<void> _start() async {
    ActivityTrackingService.instance.reset();
    setState(() {
      _isRunning = true;
      _elapsedSeconds = 0;
      _distance = 0;
      _steps = 0;
    });
    if (_mode != MeditationMode.breathing) {
      await ActivityTrackingService.instance.start();
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
      if (_mode == MeditationMode.breathing &&
          _elapsedSeconds >= _targetSeconds) {
        _complete();
      }
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await ActivityTrackingService.instance.stop();
    await BreathingCueService.instance.stop();
    setState(() {
      _isRunning = false;
      _elapsedSeconds = 0;
      _distance = 0;
      _steps = 0;
      _currentPhase = BreathingPhase.inhale;
    });
  }

  Future<void> _complete() async {
    _timer?.cancel();
    await ActivityTrackingService.instance.stop();
    await BreathingCueService.instance.stop();
    final duration = _mode == MeditationMode.breathing
        ? _targetSeconds
        : _elapsedSeconds;
    setState(() { _isRunning = false; _elapsedSeconds = duration; });

    if (_uid != null) {
      final session = MeditationSession(
        userId: _uid!,
        durationSeconds: duration,
        type: _mode.name,
        completed: true,
        completedAt: DateTime.now(),
        distanceMeters: _distance,
        steps: _steps,
        avgPaceMinPerKm: ActivityTrackingService.instance.paceMinPerKm,
      );
      await LocalDbService.instance.insertMeditationSession(session);
      _loadStats();
    }
    if (mounted) _showCompletionDialog();
  }

  void _onPhaseChanged(BreathingPhase phase) {
    setState(() => _currentPhase = phase);
    if (_voiceCuesEnabled) {
      BreathingCueService.instance.speakPhase(phase.name);
    }
  }

  void _showCompletionDialog() {
    final isActivity = _mode != MeditationMode.breathing;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(
                  gradient: AppColors.splashGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(
                  _mode == MeditationMode.running ? '🏃'
                  : _mode == MeditationMode.walking ? '🚶' : '🧘',
                  style: const TextStyle(fontSize: 40),
                )),
              ),
              const SizedBox(height: 20),
              Text('Session complete!', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              if (isActivity) ...[
                _CompletionStat(label: 'Duration', value: _formatTime(_elapsedSeconds)),
                _CompletionStat(label: 'Distance', value: ActivityTrackingService.instance.formattedDistance),
                _CompletionStat(label: 'Steps', value: '$_steps'),
                _CompletionStat(label: 'Pace', value: ActivityTrackingService.instance.formattedPace),
              ] else
                Text(
                  'You completed a ${_activePreset.label} breathing session. '
                  'Take a moment to notice how you feel.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => _elapsedSeconds = 0);
                  },
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _phaseLabel(BreathingPhase phase) {
    switch (phase) {
      case BreathingPhase.inhale: return 'Breathe in';
      case BreathingPhase.hold:   return 'Hold';
      case BreathingPhase.exhale: return 'Breathe out';
      case BreathingPhase.rest:   return 'Rest';
    }
  }

  String _phaseSubLabel(BreathingPhase phase) {
    switch (phase) {
      case BreathingPhase.inhale: return 'Slowly through your nose';
      case BreathingPhase.hold:   return 'Gently hold your breath';
      case BreathingPhase.exhale: return 'Slowly through your mouth';
      case BreathingPhase.rest:   return 'Pause before the next breath';
    }
  }

  List<Color> _modeGradient(MeditationMode mode) {
    switch (mode) {
      case MeditationMode.walking:
        return const [Color(0xFF0D3B2E), Color(0xFF1B5E3B), Color(0xFF1A3A4A)];
      case MeditationMode.running:
        return const [Color(0xFF3B0D0D), Color(0xFF7B2D00), Color(0xFF1A1A3A)];
      case MeditationMode.breathing:
        return const [Color(0xFF1A0533), Color(0xFF2D1B69), Color(0xFF1A3A4A)];
    }
  }

  List<Widget> _buildParticles() {
    const positions = [
      Offset(0.1, 0.08), Offset(0.85, 0.12), Offset(0.25, 0.22),
      Offset(0.7, 0.18), Offset(0.5, 0.06), Offset(0.92, 0.35),
    ];
    final size = MediaQuery.of(context).size;
    return positions.map((pos) => Positioned(
      left: pos.dx * size.width,
      top: pos.dy * size.height,
      child: Container(
        width: 2, height: 2,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
      ),
    )).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () { if (_isRunning) _stop(); context.pop(); },
        ),
        title: Text('Meditation',
            style: AppTextStyles.titleLarge.copyWith(color: Colors.white)),
        centerTitle: true,
        actions: [
          if (_mode == MeditationMode.breathing)
            IconButton(
              icon: Icon(
                _voiceCuesEnabled
                    ? Icons.volume_up_outlined
                    : Icons.volume_off_outlined,
                color: Colors.white70, size: 22,
              ),
              tooltip: _voiceCuesEnabled ? 'Mute voice cues' : 'Enable voice cues',
              onPressed: () {
                setState(() => _voiceCuesEnabled = !_voiceCuesEnabled);
                BreathingCueService.instance.setEnabled(_voiceCuesEnabled);
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _modeGradient(_mode),
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          ..._buildParticles(),
          SafeArea(
            child: SingleChildScrollView(
              physics: _isRunning
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  if (!_isRunning) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _ModeSelector(selected: _mode, onSelect: _switchMode),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_mode == MeditationMode.breathing)
                    _buildBreathingContent()
                  else
                    _buildActivityContent(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreathingContent() {
    return Column(
      children: [
        if (!_isRunning) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Session duration',
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70)),
                const SizedBox(height: 10),
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _presetTabCtrl,
                    indicator: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                    tabs: _presets.map((p) => Tab(text: p.label)).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 24),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.78,
              height: MediaQuery.of(context).size.width * 0.78,
              child: CircularProgressIndicator(
                value: _isRunning ? _progress : 0,
                strokeWidth: 3,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(0.6)),
              ),
            ),
            BreathingWidget(
              isRunning: _isRunning,
              onPhaseChanged: _onPhaseChanged,
              inhaleSec: _activePreset.inhale,
              holdSec: _activePreset.hold,
              exhaleSec: _activePreset.exhale,
              restSec: _activePreset.rest,
            ),
          ],
        ),
        const SizedBox(height: 32),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.2), end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Column(
            key: ValueKey(_currentPhase),
            children: [
              Text(
                _isRunning ? _phaseLabel(_currentPhase) : 'Ready to begin',
                style: AppTextStyles.displayMedium
                    .copyWith(color: Colors.white, fontSize: 28),
              ),
              const SizedBox(height: 6),
              Text(
                _isRunning
                    ? _phaseSubLabel(_currentPhase)
                    : 'Default: 3 min · tap tabs to change · voice cues on',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white60),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          _isRunning ? _formatTime(_remainingSeconds) : _formatTime(_targetSeconds),
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 52,
            fontWeight: FontWeight.w200,
            color: Colors.white.withOpacity(0.9),
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isRunning ? 'remaining' : 'duration',
          style: AppTextStyles.caption.copyWith(color: Colors.white38, letterSpacing: 2),
        ),
        const SizedBox(height: 40),
        _StartStopButton(isRunning: _isRunning, onStart: _start, onStop: _stop),
        const SizedBox(height: 48),
        if (!_isRunning) _buildStats(),
      ],
    );
  }

  Widget _buildActivityContent() {
    final isRun = _mode == MeditationMode.running;
    return Column(
      children: [
        if (_activityError != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_outlined,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_activityError!,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.warning)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 16),
        Container(
          width: 140, height: 140,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 2),
          ),
          child: Center(
            child: Text(isRun ? '🏃' : '🚶',
                style: const TextStyle(fontSize: 64)),
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _ActivityStatCard(
                label: 'Distance',
                value: _isRunning
                    ? ActivityTrackingService.instance.formattedDistance
                    : '0 m',
                icon: '📍',
              ),
              const SizedBox(width: 12),
              _ActivityStatCard(label: 'Steps', value: '$_steps', icon: '👟'),
              if (isRun) ...[
                const SizedBox(width: 12),
                _ActivityStatCard(
                  label: 'Pace',
                  value: _isRunning
                      ? ActivityTrackingService.instance.formattedPace
                      : "--'--\"",
                  icon: '⚡',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _formatTime(_elapsedSeconds),
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 52,
            fontWeight: FontWeight.w200,
            color: Colors.white.withOpacity(0.9),
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isRunning ? 'elapsed' : 'tap start to begin',
          style: AppTextStyles.caption.copyWith(color: Colors.white38, letterSpacing: 2),
        ),
        const SizedBox(height: 24),
        if (!_isRunning) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              isRun
                  ? 'Mindful running — focus on your breath and footfall '
                    'rhythm. Run at a pace where you can hold a conversation.'
                  : 'Mindful walking — pay attention to each step, your '
                    'breath, and the sensations in your body as you move.',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (_isRunning)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _ActivityButton(
                    label: 'Stop',
                    icon: Icons.stop_rounded,
                    color: AppColors.error.withOpacity(0.8),
                    onTap: _stop,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _ActivityButton(
                    label: 'Finish',
                    icon: Icons.flag_rounded,
                    color: AppColors.success.withOpacity(0.8),
                    onTap: _complete,
                  ),
                ),
              ],
            ),
          )
        else
          _StartStopButton(isRunning: false, onStart: _start, onStop: _stop),
        const SizedBox(height: 48),
        if (!_isRunning) _buildStats(),
      ],
    );
  }

  Widget _buildStats() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _StatCard(
                label: 'Total time',
                value: _statsLoading ? '—' : _formatTotal(_totalSeconds),
                icon: '⏱️',
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Sessions',
                value: _statsLoading ? '—' : '${_recentSessions.length}',
                icon: '🧘',
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Day streak',
                value: _statsLoading ? '—' : '$_streakDays',
                icon: '🔥',
              ),
            ],
          ),
        ),
        if (_recentSessions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent sessions',
                  style: AppTextStyles.titleMedium.copyWith(color: Colors.white70)),
            ),
          ),
          const SizedBox(height: 12),
          ..._recentSessions.map((s) => _SessionTile(session: s)),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  String _formatTotal(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

// ─────────────────────────────────────────────────────────────────
// Private widgets
// ─────────────────────────────────────────────────────────────────

class _ModeSelector extends StatelessWidget {
  final MeditationMode selected;
  final ValueChanged<MeditationMode> onSelect;
  const _ModeSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModeChip(label: 'Breathing', emoji: '🧘',
            selected: selected == MeditationMode.breathing,
            onTap: () => onSelect(MeditationMode.breathing)),
        const SizedBox(width: 10),
        _ModeChip(label: 'Walking', emoji: '🚶',
            selected: selected == MeditationMode.walking,
            onTap: () => onSelect(MeditationMode.walking)),
        const SizedBox(width: 10),
        _ModeChip(label: 'Running', emoji: '🏃',
            selected: selected == MeditationMode.running,
            onTap: () => onSelect(MeditationMode.running)),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({required this.label, required this.emoji,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withOpacity(0.2)
                : Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? Colors.white.withOpacity(0.5)
                  : Colors.white.withOpacity(0.15),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(label,
                  style: AppTextStyles.caption.copyWith(
                    color: selected ? Colors.white : Colors.white54,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
  const _ActivityStatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(value,
                style: AppTextStyles.titleLarge
                    .copyWith(color: Colors.white, fontSize: 15)),
            Text(label,
                style: AppTextStyles.caption.copyWith(color: Colors.white54),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ActivityButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActivityButton(
      {required this.label, required this.icon,
       required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(label,
                style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _StartStopButton extends StatelessWidget {
  final bool isRunning;
  final VoidCallback onStart;
  final VoidCallback onStop;
  const _StartStopButton(
      {required this.isRunning, required this.onStart, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isRunning ? onStop : onStart,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: isRunning ? 72 : 160,
        height: 56,
        decoration: BoxDecoration(
          color: isRunning
              ? Colors.white.withOpacity(0.12)
              : Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(isRunning ? 36 : 18),
          border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isRunning
                ? const Icon(Icons.stop_rounded,
                    key: ValueKey('stop'), color: Colors.white, size: 28)
                : Row(
                    key: const ValueKey('start'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 6),
                      Text('Start',
                          style: AppTextStyles.labelLarge
                              .copyWith(color: Colors.white)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
  const _StatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(value,
                style: AppTextStyles.titleLarge
                    .copyWith(color: Colors.white, fontSize: 18)),
            Text(label,
                style: AppTextStyles.caption.copyWith(color: Colors.white54),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final MeditationSession session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Text(session.typeEmoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.typeLabel,
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w500)),
                Text(_formatDate(session.completedAt),
                    style: AppTextStyles.caption.copyWith(color: Colors.white38)),
                if (session.distanceMeters > 0)
                  Text(
                    '${session.formattedDistance} · ${session.steps} steps',
                    style: AppTextStyles.caption.copyWith(color: Colors.white54),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(session.formattedDuration,
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _CompletionStat extends StatelessWidget {
  final String label;
  final String value;
  const _CompletionStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium),
          Text(value,
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _Preset {
  final String label;
  final int minutes;
  final int inhale;
  final int hold;
  final int exhale;
  final int rest;
  const _Preset({required this.label, required this.minutes,
      required this.inhale, required this.hold,
      required this.exhale, required this.rest});
}





/*import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/meditation_session.dart';
import '../../services/local_db_service.dart';
import 'breathing_widget.dart';

class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key});

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────
  bool _isRunning = false;
  BreathingPhase _currentPhase = BreathingPhase.inhale;
  int _elapsedSeconds = 0;
  int _selectedDurationMinutes = 5;
  Timer? _timer;
  String? _uid;

  // Stats
  int _totalSeconds = 0;
  int _streakDays = 0;
  List<MeditationSession> _recentSessions = [];
  bool _statsLoading = true;

  // Tab controller for session presets
  late TabController _presetTabCtrl;
  final List<_Preset> _presets = const [
    _Preset(label: '3 min', minutes: 3, inhale: 4, hold: 2, exhale: 4, rest: 2),
    _Preset(label: '5 min', minutes: 5, inhale: 4, hold: 2, exhale: 6, rest: 2),
    _Preset(label: '10 min', minutes: 10, inhale: 4, hold: 4, exhale: 6, rest: 4),
    _Preset(label: '15 min', minutes: 15, inhale: 4, hold: 4, exhale: 8, rest: 4),
  ];
  int _selectedPresetIndex = 1;

  _Preset get _activePreset => _presets[_selectedPresetIndex];

  int get _targetSeconds => _selectedDurationMinutes * 60;
  int get _remainingSeconds =>
      (_targetSeconds - _elapsedSeconds).clamp(0, _targetSeconds);
  double get _progress =>
      _targetSeconds > 0 ? _elapsedSeconds / _targetSeconds : 0;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _presetTabCtrl = TabController(length: _presets.length, vsync: this)
      ..addListener(() {
        if (!_presetTabCtrl.indexIsChanging) {
          _selectPreset(_presetTabCtrl.index);
        }
      });
    _loadStats();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _presetTabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    if (_uid == null) return;
    final total =
        await LocalDbService.instance.getTotalMeditationSeconds(_uid!);
    final streak =
        await LocalDbService.instance.getMeditationStreakDays(_uid!);
    final sessions =
        await LocalDbService.instance.getMeditationSessions(_uid!);
    if (mounted) {
      setState(() {
        _totalSeconds = total;
        _streakDays = streak;
        _recentSessions = sessions.take(5).toList();
        _statsLoading = false;
      });
    }
  }

  void _selectPreset(int index) {
    if (_isRunning) return;
    setState(() {
      _selectedPresetIndex = index;
      _selectedDurationMinutes = _presets[index].minutes;
      _elapsedSeconds = 0;
    });
  }

  void _start() {
    setState(() {
      _isRunning = true;
      _elapsedSeconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
      if (_elapsedSeconds >= _targetSeconds) {
        _complete();
      }
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _elapsedSeconds = 0;
      _currentPhase = BreathingPhase.inhale;
    });
  }

  Future<void> _complete() async {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _elapsedSeconds = _targetSeconds;
    });

    if (_uid != null) {
      final session = MeditationSession(
        userId: _uid!,
        durationSeconds: _targetSeconds,
        type: 'breathing',
        completed: true,
        completedAt: DateTime.now(),
      );
      await LocalDbService.instance.insertMeditationSession(session);
      _loadStats();
    }

    if (mounted) _showCompletionDialog();
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.splashGradient,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🧘', style: TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Session complete!',
                  style: AppTextStyles.titleLarge),
              const SizedBox(height: 8),
              Text(
                'You completed a ${_activePreset.label} meditation session. '
                'Take a moment to notice how you feel.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _elapsedSeconds = 0);
                },
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _phaseLabel(BreathingPhase phase) {
    switch (phase) {
      case BreathingPhase.inhale:
        return 'Breathe in';
      case BreathingPhase.hold:
        return 'Hold';
      case BreathingPhase.exhale:
        return 'Breathe out';
      case BreathingPhase.rest:
        return 'Rest';
    }
  }

  String _phaseSubLabel(BreathingPhase phase) {
    switch (phase) {
      case BreathingPhase.inhale:
        return 'Slowly through your nose';
      case BreathingPhase.hold:
        return 'Gently hold your breath';
      case BreathingPhase.exhale:
        return 'Slowly through your mouth';
      case BreathingPhase.rest:
        return 'Pause before the next breath';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: Colors.white),
          onPressed: () {
            if (_isRunning) _stop();
            context.pop();
          },
        ),
        title: Text(
          'Meditation',
          style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // ── Calm gradient background ─────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A0533), // deep plum
                  Color(0xFF2D1B69), // dark violet
                  Color(0xFF1A3A4A), // dark teal
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // Subtle star-like particles in background
          ..._buildBackgroundParticles(),

          // ── Main content ─────────────────────
          SafeArea(
            child: SingleChildScrollView(
              physics: _isRunning
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // ── Preset tabs (hidden while running) ──
                  if (!_isRunning) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose a session',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TabBar(
                              controller: _presetTabCtrl,
                              indicator: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              labelColor: Colors.white,
                              unselectedLabelColor: Colors.white54,
                              labelStyle: AppTextStyles.labelLarge
                                  .copyWith(fontSize: 13),
                              tabs: _presets
                                  .map((p) => Tab(text: p.label))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ── Progress arc + breathing circle ──
                  const SizedBox(height: 24),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Progress arc
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.78,
                        height: MediaQuery.of(context).size.width * 0.78,
                        child: CircularProgressIndicator(
                          value: _isRunning ? _progress : 0,
                          strokeWidth: 3,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation(
                            Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ),
                      // Breathing circle
                      BreathingWidget(
                        isRunning: _isRunning,
                        onPhaseChanged: (phase) =>
                            setState(() => _currentPhase = phase),
                        inhaleSec: _activePreset.inhale,
                        holdSec: _activePreset.hold,
                        exhaleSec: _activePreset.exhale,
                        restSec: _activePreset.rest,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ── Phase guidance text ──────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Column(
                      key: ValueKey(_currentPhase),
                      children: [
                        Text(
                          _isRunning
                              ? _phaseLabel(_currentPhase)
                              : 'Ready to begin',
                          style: AppTextStyles.displayMedium.copyWith(
                            color: Colors.white,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isRunning
                              ? _phaseSubLabel(_currentPhase)
                              : 'Find a comfortable position and press start',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white60,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Timer display ────────────────────
                  Text(
                    _isRunning
                        ? _formatTime(_remainingSeconds)
                        : _formatTime(_targetSeconds),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 52,
                      fontWeight: FontWeight.w200,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRunning ? 'remaining' : 'duration',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white38,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ── Start / Stop button ──────────────
                  _StartStopButton(
                    isRunning: _isRunning,
                    onStart: _start,
                    onStop: _stop,
                  ),
                  const SizedBox(height: 48),

                  // ── Stats + recent sessions ──────────
                  if (!_isRunning) ...[
                    _StatsRow(
                      totalSeconds: _totalSeconds,
                      streakDays: _streakDays,
                      sessionCount: _recentSessions.length,
                      isLoading: _statsLoading,
                    ),
                    if (_recentSessions.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Recent sessions',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._recentSessions.map(
                        (s) => _SessionTile(session: s),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBackgroundParticles() {
    final positions = [
      const Offset(0.1, 0.08),
      const Offset(0.85, 0.12),
      const Offset(0.25, 0.22),
      const Offset(0.7, 0.18),
      const Offset(0.5, 0.06),
      const Offset(0.92, 0.35),
      const Offset(0.05, 0.4),
      const Offset(0.15, 0.65),
      const Offset(0.88, 0.6),
    ];
    return positions.map((pos) {
      final size = MediaQuery.of(context).size;
      return Positioned(
        left: pos.dx * size.width,
        top: pos.dy * size.height,
        child: Container(
          width: 2,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
        ),
      );
    }).toList();
  }
}

// ── Start / Stop button ───────────────────────
class _StartStopButton extends StatelessWidget {
  final bool isRunning;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _StartStopButton({
    required this.isRunning,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isRunning ? onStop : onStart,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: isRunning ? 72 : 160,
        height: 56,
        decoration: BoxDecoration(
          color: isRunning
              ? Colors.white.withOpacity(0.12)
              : Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(isRunning ? 36 : 18),
          border: Border.all(
            color: Colors.white.withOpacity(0.35),
            width: 1.5,
          ),
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isRunning
                ? const Icon(Icons.stop_rounded,
                    key: ValueKey('stop'),
                    color: Colors.white,
                    size: 28)
                : Row(
                    key: const ValueKey('start'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 6),
                      Text(
                        'Start',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int totalSeconds;
  final int streakDays;
  final int sessionCount;
  final bool isLoading;

  const _StatsRow({
    required this.totalSeconds,
    required this.streakDays,
    required this.sessionCount,
    required this.isLoading,
  });

  String _formatTotal(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _StatCard(
            label: 'Total time',
            value: isLoading ? '—' : _formatTotal(totalSeconds),
            icon: '⏱️',
          ),
          const SizedBox(width: 12),
          _StatCard(
            label: 'Sessions',
            value: isLoading ? '—' : '$sessionCount',
            icon: '🧘',
          ),
          const SizedBox(width: 12),
          _StatCard(
            label: 'Day streak',
            value: isLoading ? '—' : '$streakDays',
            icon: '🔥',
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.titleLarge.copyWith(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent session tile ───────────────────────
class _SessionTile extends StatelessWidget {
  final MeditationSession session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Text('🧘', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Breathing meditation',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDate(session.completedAt),
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              session.formattedDuration,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
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
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Preset data class ─────────────────────────
class _Preset {
  final String label;
  final int minutes;
  final int inhale;
  final int hold;
  final int exhale;
  final int rest;

  const _Preset({
    required this.label,
    required this.minutes,
    required this.inhale,
    required this.hold,
    required this.exhale,
    required this.rest,
  });
}*/
