import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

/// Overlay that monitors SpO2 during altered-state sessions and shows
/// warnings at unsafe levels.
///
/// - Below 80%: gentle amber warning suggesting the user resume breathing
/// - Below 75%: urgent coral warning
/// - 85-90% is expected during Wim Hof holds and does NOT trigger a warning
class Spo2SafetyMonitor extends StatefulWidget {
  final Stream<double> spo2Stream;

  const Spo2SafetyMonitor({super.key, required this.spo2Stream});

  @override
  State<Spo2SafetyMonitor> createState() => _Spo2SafetyMonitorState();
}

class _Spo2SafetyMonitorState extends State<Spo2SafetyMonitor>
    with SingleTickerProviderStateMixin {
  double _spo2 = 98;
  StreamSubscription<double>? _sub;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _sub = widget.spo2Stream.listen((v) {
      setState(() => _spo2 = v);
      if (v < 80 && !_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      } else if (v >= 80 && _pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.value = 0;
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_spo2 >= 80) return const SizedBox.shrink();

    final isUrgent = _spo2 < 75;
    final color = isUrgent ? BioVoltColors.coral : BioVoltColors.amber;
    final message = isUrgent
        ? 'SpO2 critically low \u2014 resume breathing now'
        : 'SpO2 below 80% \u2014 consider resuming breathing';

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final alpha = isUrgent
            ? (180 + 75 * _pulseController.value).round()
            : (140 + 60 * _pulseController.value).round();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withAlpha(15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withAlpha(alpha)),
          ),
          child: Row(
            children: [
              Icon(
                isUrgent
                    ? Icons.warning_rounded
                    : Icons.warning_amber_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Text(
                '${_spo2.toStringAsFixed(0)}%',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
