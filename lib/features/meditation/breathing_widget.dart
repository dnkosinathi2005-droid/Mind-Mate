import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

enum BreathingPhase { inhale, hold, exhale, rest }

class BreathingWidget extends StatefulWidget {
  final bool isRunning;
  final ValueChanged<BreathingPhase> onPhaseChanged;
  final int inhaleSec;
  final int holdSec;
  final int exhaleSec;
  final int restSec;

  const BreathingWidget({
    super.key,
    required this.isRunning,
    required this.onPhaseChanged,
    this.inhaleSec = 4,
    this.holdSec = 2,
    this.exhaleSec = 6,
    this.restSec = 2,
  });

  @override
  State<BreathingWidget> createState() => _BreathingWidgetState();
}

class _BreathingWidgetState extends State<BreathingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  BreathingPhase _currentPhase = BreathingPhase.inhale;
  int _phaseIndex = 0;

  List<_PhaseConfig> get _phases => [
        _PhaseConfig(
          phase: BreathingPhase.inhale,
          durationMs: widget.inhaleSec * 1000,
          targetScale: 1.0,
          startScale: 0.55,
        ),
        _PhaseConfig(
          phase: BreathingPhase.hold,
          durationMs: widget.holdSec * 1000,
          targetScale: 1.0,
          startScale: 1.0,
        ),
        _PhaseConfig(
          phase: BreathingPhase.exhale,
          durationMs: widget.exhaleSec * 1000,
          targetScale: 0.55,
          startScale: 1.0,
        ),
        _PhaseConfig(
          phase: BreathingPhase.rest,
          durationMs: widget.restSec * 1000,
          targetScale: 0.55,
          startScale: 0.55,
        ),
      ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _scaleAnim = Tween<double>(begin: 0.55, end: 1.0).animate(_controller);
    _controller.addStatusListener(_onAnimationStatus);
    if (widget.isRunning) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startPhase(0));
    }
  }

  @override
  void didUpdateWidget(BreathingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning && !oldWidget.isRunning) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startPhase(0));
    } else if (!widget.isRunning && oldWidget.isRunning) {
      _controller.stop();
      _controller.reset();
      if (mounted) {
        setState(() {
          _phaseIndex = 0;
          _currentPhase = BreathingPhase.inhale;
        });
      }
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && widget.isRunning) {
      final next = (_phaseIndex + 1) % _phases.length;
      _startPhase(next);
    }
  }

  void _startPhase(int index) {
    if (!mounted) return;

    final config = _phases[index];

    // Update local state
    if (mounted) {
      setState(() {
        _phaseIndex = index;
        _currentPhase = config.phase;
      });
    }

    // Notify parent AFTER the current build frame completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPhaseChanged(config.phase);
    });

    _scaleAnim = Tween<double>(
      begin: config.startScale,
      end: config.targetScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: (config.phase == BreathingPhase.inhale ||
              config.phase == BreathingPhase.exhale)
          ? Curves.easeInOut
          : Curves.linear,
    ));

    _controller.duration = Duration(milliseconds: config.durationMs);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  Color get _phaseColor {
    switch (_currentPhase) {
      case BreathingPhase.inhale:
        return AppColors.accent;
      case BreathingPhase.hold:
        return AppColors.primaryLight;
      case BreathingPhase.exhale:
        return AppColors.primary;
      case BreathingPhase.rest:
        return AppColors.primaryDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.62;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = widget.isRunning ? _scaleAnim.value : 0.65;

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow rings
              for (int i = 3; i >= 1; i--)
                Transform.scale(
                  scale: scale + (i * 0.12),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _phaseColor.withOpacity(0.04 * i),
                    ),
                  ),
                ),

              // Ripple ring on inhale
              if (widget.isRunning &&
                  _currentPhase == BreathingPhase.inhale)
                Transform.scale(
                  scale: scale + 0.05 + (_controller.value * 0.2),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _phaseColor
                            .withOpacity((1.0 - _controller.value) * 0.4),
                        width: 2,
                      ),
                    ),
                  ),
                ),

              // Main breathing circle
              Transform.scale(
                scale: scale,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _phaseColor.withOpacity(0.85),
                        _phaseColor.withOpacity(0.55),
                      ],
                      stops: const [0.3, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _phaseColor.withOpacity(0.35),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),

              // Particles
              if (widget.isRunning) ..._buildParticles(size, scale),

              // Centre dot
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildParticles(double size, double scale) {
    const count = 8;
    final radius = (size / 2) * scale;
    return List.generate(count, (i) {
      final angle = (2 * pi / count) * i;
      final dx = radius * cos(angle);
      final dy = radius * sin(angle);
      final opacity = (_currentPhase == BreathingPhase.inhale)
          ? _controller.value * 0.8
          : (_currentPhase == BreathingPhase.exhale)
              ? (1.0 - _controller.value) * 0.8
              : 0.6;
      return Transform.translate(
        offset: Offset(dx, dy),
        child: Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            shape: BoxShape.circle,
          ),
        ),
      );
    });
  }
}

class _PhaseConfig {
  final BreathingPhase phase;
  final int durationMs;
  final double targetScale;
  final double startScale;

  const _PhaseConfig({
    required this.phase,
    required this.durationMs,
    required this.targetScale,
    required this.startScale,
  });
}
