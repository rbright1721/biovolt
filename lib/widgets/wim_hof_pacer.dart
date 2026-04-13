import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

/// Wim Hof Method phases.
enum WimHofPhase { rapidBreathing, retention, recovery, roundSummary, complete }

/// Data for one completed Wim Hof round.
class WimHofRoundResult {
  final int roundNumber;
  final int retentionSeconds;
  final double minSpo2;

  const WimHofRoundResult({
    required this.roundNumber,
    required this.retentionSeconds,
    this.minSpo2 = 0,
  });
}

/// Multi-phase Wim Hof breathing widget.
///
/// Phase 1: 30 cycles of rapid deep breathing (inhale 2s, exhale 1.5s)
/// Phase 2: Full exhale retention hold — user taps to end
/// Phase 3: Deep recovery breath hold for 15 seconds
/// Repeats for [totalRounds] rounds, then 2 minutes of calm breathing.
class WimHofPacer extends StatefulWidget {
  final double size;
  final int totalRounds;
  final int rapidCycles;
  final Stream<double>? spo2Stream;
  final void Function(List<WimHofRoundResult> results)? onComplete;

  const WimHofPacer({
    super.key,
    this.size = 260,
    this.totalRounds = 3,
    this.rapidCycles = 30,
    this.spo2Stream,
    this.onComplete,
  });

  @override
  State<WimHofPacer> createState() => WimHofPacerState();
}

class WimHofPacerState extends State<WimHofPacer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  WimHofPhase _phase = WimHofPhase.rapidBreathing;
  int _currentRound = 1;
  int _rapidCycleCount = 0;
  int _retentionSeconds = 0;
  int _recoveryCountdown = 15;
  double _currentSpo2 = 98;
  double _minSpo2InHold = 100;
  final List<WimHofRoundResult> _results = [];

  Timer? _retentionTimer;
  Timer? _recoveryTimer;
  Timer? _summaryTimer;
  StreamSubscription<double>? _spo2Sub;

  @override
  void initState() {
    super.initState();
    // Rapid breathing cycle: 3.5s total (2s in + 1.5s out)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..addStatusListener(_onAnimationStatus);

    _spo2Sub = widget.spo2Stream?.listen((v) {
      _currentSpo2 = v;
      if (_phase == WimHofPhase.retention && v < _minSpo2InHold) {
        _minSpo2InHold = v;
      }
    });

    _controller.repeat();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _phase == WimHofPhase.rapidBreathing) {
      setState(() => _rapidCycleCount++);
      if (_rapidCycleCount >= widget.rapidCycles) {
        _startRetention();
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  void _startRetention() {
    _controller.stop();
    setState(() {
      _phase = WimHofPhase.retention;
      _retentionSeconds = 0;
      _minSpo2InHold = _currentSpo2;
    });
    _retentionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _retentionSeconds++);
    });
  }

  /// Called when user taps "BREATHE" during retention.
  void endRetention() {
    _retentionTimer?.cancel();
    setState(() {
      _phase = WimHofPhase.recovery;
      _recoveryCountdown = 15;
    });
    // Start recovery countdown
    _controller.duration = const Duration(seconds: 15);
    _controller.forward(from: 0);
    _recoveryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recoveryCountdown--);
      if (_recoveryCountdown <= 0) {
        timer.cancel();
        _finishRound();
      }
    });
  }

  void _finishRound() {
    _controller.stop();
    _results.add(WimHofRoundResult(
      roundNumber: _currentRound,
      retentionSeconds: _retentionSeconds,
      minSpo2: _minSpo2InHold,
    ));

    if (_currentRound >= widget.totalRounds) {
      setState(() => _phase = WimHofPhase.complete);
      widget.onComplete?.call(_results);
    } else {
      setState(() => _phase = WimHofPhase.roundSummary);
      _summaryTimer = Timer(const Duration(seconds: 5), () {
        setState(() {
          _currentRound++;
          _rapidCycleCount = 0;
          _phase = WimHofPhase.rapidBreathing;
        });
        _controller.duration = const Duration(milliseconds: 3500);
        _controller.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    _retentionTimer?.cancel();
    _recoveryTimer?.cancel();
    _summaryTimer?.cancel();
    _spo2Sub?.cancel();
    super.dispose();
  }

  /// Breath progress for rapid phase: 0->1 (inhale 2s), 1->0 (exhale 1.5s)
  double get _rapidBreathProgress {
    final v = _controller.value;
    // inhale takes 2/3.5 = ~0.571 of the cycle
    const inhaleRatio = 2.0 / 3.5;
    if (v < inhaleRatio) {
      return v / inhaleRatio;
    } else {
      return 1.0 - (v - inhaleRatio) / (1.0 - inhaleRatio);
    }
  }

  List<WimHofRoundResult> get results => List.unmodifiable(_results);

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      WimHofPhase.rapidBreathing => _buildRapidPhase(),
      WimHofPhase.retention => _buildRetentionPhase(),
      WimHofPhase.recovery => _buildRecoveryPhase(),
      WimHofPhase.roundSummary => _buildRoundSummary(),
      WimHofPhase.complete => _buildComplete(),
    };
  }

  Widget _buildRapidPhase() {
    const color = BioVoltColors.amber;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _rapidBreathProgress;
        final minScale = 0.45;
        final scale = minScale + (1.0 - minScale) * progress;
        final circleSize = widget.size * scale;

        return SizedBox(
          width: widget.size,
          height: widget.size + 60,
          child: Column(
            children: [
              // Round indicator
              Text(
                'ROUND $_currentRound/${widget.totalRounds}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: circleSize + 20,
                      height: circleSize + 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withAlpha((50 * progress).round()),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            color.withAlpha((30 + 40 * progress).round()),
                            color.withAlpha((10 + 15 * progress).round()),
                          ],
                        ),
                        border: Border.all(
                          color: color.withAlpha((80 + 100 * progress).round()),
                          width: 2,
                        ),
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
                        const SizedBox(height: 4),
                        Text(
                          '${_rapidCycleCount + 1}/${widget.rapidCycles}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'RAPID BREATHING',
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
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRetentionPhase() {
    final minutes = (_retentionSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_retentionSeconds % 60).toString().padLeft(2, '0');

    return SizedBox(
      width: widget.size,
      height: widget.size + 60,
      child: Column(
        children: [
          Text(
            'ROUND $_currentRound/${widget.totalRounds}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: BioVoltColors.amber,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Dim pulsing circle
                Container(
                  width: widget.size * 0.7,
                  height: widget.size * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: BioVoltColors.surface,
                    border: Border.all(
                      color: BioVoltColors.amber.withAlpha(40),
                      width: 2,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'HOLD',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BioVoltColors.amber.withAlpha(160),
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Large timer
                    Text(
                      '$minutes:$seconds',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: BioVoltColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // SpO2
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SpO2',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: BioVoltColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_currentSpo2.toStringAsFixed(0)}%',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _currentSpo2 < 85
                                ? BioVoltColors.amber
                                : BioVoltColors.teal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // BREATHE button
          GestureDetector(
            onTap: endRetention,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                color: BioVoltColors.amber.withAlpha(20),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: BioVoltColors.amber.withAlpha(100),
                  width: 2,
                ),
              ),
              child: Text(
                'BREATHE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: BioVoltColors.amber,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryPhase() {
    return SizedBox(
      width: widget.size,
      height: widget.size + 60,
      child: Column(
        children: [
          Text(
            'ROUND $_currentRound/${widget.totalRounds}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: BioVoltColors.teal,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: widget.size * 0.75,
                  height: widget.size * 0.75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        BioVoltColors.teal.withAlpha(40),
                        BioVoltColors.teal.withAlpha(10),
                      ],
                    ),
                    border: Border.all(
                      color: BioVoltColors.teal.withAlpha(80),
                      width: 2,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'RECOVERY HOLD',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BioVoltColors.teal.withAlpha(200),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_recoveryCountdown',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: BioVoltColors.teal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'FULL LUNGS',
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
          ),
        ],
      ),
    );
  }

  Widget _buildRoundSummary() {
    final lastResult = _results.last;
    final retMin = (lastResult.retentionSeconds ~/ 60).toString().padLeft(1, '0');
    final retSec = (lastResult.retentionSeconds % 60).toString().padLeft(2, '0');

    return SizedBox(
      width: widget.size,
      height: widget.size + 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ROUND $_currentRound COMPLETE',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: BioVoltColors.amber,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          _summaryRow('RETENTION', '$retMin:$retSec'),
          const SizedBox(height: 8),
          _summaryRow('MIN SpO2', '${lastResult.minSpo2.toStringAsFixed(0)}%'),
          const SizedBox(height: 24),
          Text(
            'NEXT ROUND IN 5s...',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: BioVoltColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplete() {
    return SizedBox(
      width: widget.size,
      height: widget.size + 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'SESSION COMPLETE',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: BioVoltColors.teal,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 24),
          ..._results.map((r) {
            final retMin = (r.retentionSeconds ~/ 60).toString().padLeft(1, '0');
            final retSec = (r.retentionSeconds % 60).toString().padLeft(2, '0');
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: BioVoltColors.surfaceLight.withAlpha(100),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BioVoltColors.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'R${r.roundNumber}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: BioVoltColors.amber,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$retMin:$retSec',
                      style: BioVoltTheme.valueStyle(20),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'SpO2 ${r.minSpo2.toStringAsFixed(0)}%',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: BioVoltColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          // Retention trend
          if (_results.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _results.last.retentionSeconds > _results.first.retentionSeconds
                      ? Icons.trending_up_rounded
                      : Icons.trending_flat_rounded,
                  size: 14,
                  color: BioVoltColors.teal,
                ),
                const SizedBox(width: 6),
                Text(
                  _results.last.retentionSeconds > _results.first.retentionSeconds
                      ? 'RETENTION IMPROVING'
                      : 'CONSISTENT HOLDS',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: BioVoltColors.teal,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: BioVoltColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
        ),
        Text(
          value,
          style: BioVoltTheme.valueStyle(22),
        ),
      ],
    );
  }
}
