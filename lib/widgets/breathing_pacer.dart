import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

/// A breathing phase in the pattern.
enum BreathPhase { inhale, holdIn, exhale, holdOut }

extension BreathPhaseLabel on BreathPhase {
  String get label => switch (this) {
        BreathPhase.inhale => 'INHALE',
        BreathPhase.holdIn => 'HOLD',
        BreathPhase.exhale => 'EXHALE',
        BreathPhase.holdOut => 'HOLD',
      };
}

/// Configurable breathing pattern (durations in seconds).
class BreathingPattern {
  final String name;
  final int inhale;
  final int holdIn;
  final int exhale;
  final int holdOut;

  const BreathingPattern({
    required this.name,
    required this.inhale,
    required this.holdIn,
    required this.exhale,
    required this.holdOut,
  });

  int get totalCycleDuration => inhale + holdIn + exhale + holdOut;

  static const box4 = BreathingPattern(
    name: 'Box 4-4-4-4',
    inhale: 4,
    holdIn: 4,
    exhale: 4,
    holdOut: 4,
  );

  static const relaxing478 = BreathingPattern(
    name: 'Relaxing 4-7-8',
    inhale: 4,
    holdIn: 7,
    exhale: 8,
    holdOut: 0,
  );

  static const coherence = BreathingPattern(
    name: 'Coherence 5-5',
    inhale: 5,
    holdIn: 0,
    exhale: 5,
    holdOut: 0,
  );

  /// Tummo breathing: nose inhale 2s, mouth exhale 2s, no holds.
  static const tummo = BreathingPattern(
    name: 'Tummo 2-2',
    inhale: 2,
    holdIn: 0,
    exhale: 2,
    holdOut: 0,
  );
}

/// Animated breathing pacer circle.
///
/// Supports custom [accentColor] for altered-state patterns (amber for Tummo)
/// and [continuous] mode for Holotropic-style circular breathing where the
/// circle flows smoothly without pausing at top/bottom.
class BreathingPacer extends StatefulWidget {
  final BreathingPattern pattern;
  final bool isActive;
  final double size;
  final Color accentColor;

  /// If true, the circle animates as a continuous smooth sine wave with no
  /// hard stops at fully expanded or contracted positions.
  final bool continuous;

  /// Label shown below the cycle count (e.g., 'NOSE IN \u2022 MOUTH OUT').
  final String? subtitleLabel;

  const BreathingPacer({
    super.key,
    this.pattern = BreathingPattern.box4,
    this.isActive = true,
    this.size = 220,
    this.accentColor = BioVoltColors.teal,
    this.continuous = false,
    this.subtitleLabel,
  });

  @override
  State<BreathingPacer> createState() => _BreathingPacerState();
}

class _BreathingPacerState extends State<BreathingPacer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  BreathPhase _currentPhase = BreathPhase.inhale;
  int _countdown = 0;
  int _cycleCount = 0;

  @override
  void initState() {
    super.initState();
    _countdown = widget.pattern.inhale;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.pattern.totalCycleDuration),
    );

    if (widget.isActive) {
      _controller.repeat();
    }

    _controller.addListener(_updatePhase);
  }

  @override
  void didUpdateWidget(BreathingPacer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  void _updatePhase() {
    final p = widget.pattern;
    final total = p.totalCycleDuration.toDouble();
    final elapsed = _controller.value * total;

    BreathPhase newPhase;
    int newCountdown;

    if (elapsed < p.inhale) {
      newPhase = BreathPhase.inhale;
      newCountdown = p.inhale - elapsed.floor();
    } else if (elapsed < p.inhale + p.holdIn) {
      newPhase = BreathPhase.holdIn;
      newCountdown = p.holdIn - (elapsed - p.inhale).floor();
    } else if (elapsed < p.inhale + p.holdIn + p.exhale) {
      newPhase = BreathPhase.exhale;
      newCountdown = p.exhale - (elapsed - p.inhale - p.holdIn).floor();
    } else {
      newPhase = BreathPhase.holdOut;
      newCountdown =
          p.holdOut - (elapsed - p.inhale - p.holdIn - p.exhale).floor();
    }

    // Skip zero-duration phases
    if (_phaseSeconds(newPhase) == 0) return;

    if (newPhase != _currentPhase || newCountdown != _countdown) {
      setState(() {
        if (newPhase == BreathPhase.inhale && _currentPhase == BreathPhase.holdOut) {
          _cycleCount++;
        }
        // Also count when transitioning directly from exhale to inhale (no holdOut)
        if (newPhase == BreathPhase.inhale && _currentPhase == BreathPhase.exhale &&
            widget.pattern.holdOut == 0) {
          _cycleCount++;
        }
        _currentPhase = newPhase;
        _countdown = newCountdown.clamp(1, 99);
      });
    }
  }

  int _phaseSeconds(BreathPhase phase) => switch (phase) {
        BreathPhase.inhale => widget.pattern.inhale,
        BreathPhase.holdIn => widget.pattern.holdIn,
        BreathPhase.exhale => widget.pattern.exhale,
        BreathPhase.holdOut => widget.pattern.holdOut,
      };

  /// Returns 0.0 (fully contracted) to 1.0 (fully expanded) based on breath.
  double get _breathProgress {
    final p = widget.pattern;
    final total = p.totalCycleDuration.toDouble();
    final elapsed = _controller.value * total;

    if (widget.continuous) {
      // Smooth sine wave for continuous circular breathing
      return 0.5 + 0.5 * sin(2 * pi * _controller.value - pi / 2);
    }

    if (elapsed < p.inhale) {
      return elapsed / p.inhale;
    } else if (elapsed < p.inhale + p.holdIn) {
      return 1.0;
    } else if (elapsed < p.inhale + p.holdIn + p.exhale) {
      return 1.0 - (elapsed - p.inhale - p.holdIn) / p.exhale;
    } else {
      return 0.0;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updatePhase);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _breathProgress;
        final minScale = 0.4;
        final scale = minScale + (1.0 - minScale) * progress;
        final circleSize = widget.size * scale;
        final glowIntensity = progress;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              Container(
                width: circleSize + 30,
                height: circleSize + 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha((40 * glowIntensity).round()),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
              // Main circle
              CustomPaint(
                size: Size(circleSize, circleSize),
                painter: _PacerCirclePainter(
                  progress: progress,
                  phase: _currentPhase,
                  color: color,
                ),
              ),
              // Phase label + countdown
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.continuous)
                    Text(
                      _currentPhase.label,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color.withAlpha(200),
                        letterSpacing: 3,
                      ),
                    )
                  else
                    Text(
                      _currentPhase == BreathPhase.inhale ? 'IN' : 'OUT',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color.withAlpha(200),
                        letterSpacing: 3,
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (!widget.continuous)
                    Text(
                      '$_countdown',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Cycle $_cycleCount',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: BioVoltColors.textSecondary,
                    ),
                  ),
                  if (widget.subtitleLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitleLabel!,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        color: color.withAlpha(120),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PacerCirclePainter extends CustomPainter {
  final double progress;
  final BreathPhase phase;
  final Color color;

  _PacerCirclePainter({
    required this.progress,
    required this.phase,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Filled circle with gradient
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withAlpha((30 + 40 * progress).round()),
          color.withAlpha((10 + 15 * progress).round()),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, fillPaint);

    // Border ring
    final borderPaint = Paint()
      ..color = color.withAlpha((80 + 100 * progress).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, borderPaint);

    // Progress arc
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 6),
      -pi / 2,
      2 * pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PacerCirclePainter oldDelegate) =>
      progress != oldDelegate.progress ||
      phase != oldDelegate.phase ||
      color != oldDelegate.color;
}

/// Holotropic breathing pacer with automatic slowdown in the final minutes.
///
/// Starts at fast pace (1.5s/1.5s) and gradually slows to 3s/3s
/// during the last [slowdownMinutes] minutes of the session.
class HolotropicPacer extends StatefulWidget {
  final double size;
  final bool isActive;
  final Duration sessionElapsed;
  final Duration totalDuration;
  final int slowdownMinutes;

  const HolotropicPacer({
    super.key,
    this.size = 240,
    this.isActive = true,
    required this.sessionElapsed,
    this.totalDuration = const Duration(minutes: 25),
    this.slowdownMinutes = 5,
  });

  @override
  State<HolotropicPacer> createState() => _HolotropicPacerState();
}

class _HolotropicPacerState extends State<HolotropicPacer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    if (widget.isActive) _controller.repeat();
  }

  @override
  void didUpdateWidget(HolotropicPacer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update speed based on session elapsed time
    final newDuration = Duration(milliseconds: _cycleDurationMs());
    if (_controller.duration != newDuration) {
      _controller.duration = newDuration;
      if (widget.isActive && !_controller.isAnimating) {
        _controller.repeat();
      }
    }
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  /// Cycle duration in ms — starts at 3000ms (1.5s+1.5s) and slows to 6000ms (3s+3s).
  int _cycleDurationMs() {
    final totalMs = widget.totalDuration.inMilliseconds;
    final elapsedMs = widget.sessionElapsed.inMilliseconds;
    final slowdownStartMs = totalMs - (widget.slowdownMinutes * 60 * 1000);

    if (elapsedMs < slowdownStartMs) return 3000;

    final slowdownProgress =
        ((elapsedMs - slowdownStartMs) / (widget.slowdownMinutes * 60 * 1000))
            .clamp(0.0, 1.0);
    return (3000 + (3000 * slowdownProgress)).round();
  }

  double get _breathProgress {
    return 0.5 + 0.5 * sin(2 * pi * _controller.value - pi / 2);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const color = BioVoltColors.amber;
    final elapsed = widget.sessionElapsed;
    final elapsedMin = elapsed.inMinutes.toString().padLeft(2, '0');
    final elapsedSec = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _breathProgress;
        final minScale = 0.4;
        final scale = minScale + (1.0 - minScale) * progress;
        final circleSize = widget.size * scale;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: circleSize + 30,
                height: circleSize + 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha((40 * progress).round()),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
              CustomPaint(
                size: Size(circleSize, circleSize),
                painter: _PacerCirclePainter(
                  progress: progress,
                  phase: progress > 0.5 ? BreathPhase.inhale : BreathPhase.exhale,
                  color: color,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    progress > 0.5 ? 'IN' : 'OUT',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color.withAlpha(200),
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$elapsedMin:$elapsedSec',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'CONTINUOUS',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: BioVoltColors.textSecondary,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
