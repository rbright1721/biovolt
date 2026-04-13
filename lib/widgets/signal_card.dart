import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Signal status levels for color-coding.
enum SignalStatus { good, moderate, warning }

/// A glass-morphism dark card displaying a single biometric signal.
class SignalCard extends StatefulWidget {
  final String label;
  final String unit;
  final Stream<double> valueStream;
  final Color accentColor;
  final bool showPulse;
  final String Function(double)? formatValue;
  final SignalStatus Function(double)? getStatus;

  /// Callback when the info icon is tapped. Receives the current value.
  final void Function(double currentValue)? onInfoTap;

  /// Optional widget shown next to the label (e.g. source badge).
  final Widget? labelTrailing;

  const SignalCard({
    super.key,
    required this.label,
    required this.unit,
    required this.valueStream,
    this.accentColor = BioVoltColors.teal,
    this.showPulse = false,
    this.formatValue,
    this.getStatus,
    this.onInfoTap,
    this.labelTrailing,
  });

  @override
  State<SignalCard> createState() => _SignalCardState();
}

class _SignalCardState extends State<SignalCard>
    with SingleTickerProviderStateMixin {
  double _currentValue = 0;
  final List<double> _sparkline = [];
  StreamSubscription<double>? _subscription;
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();

    if (widget.showPulse) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      );
    }

    _subscription = widget.valueStream.listen((value) {
      setState(() {
        _currentValue = value;
        _sparkline.add(value);
        if (_sparkline.length > 30) {
          _sparkline.removeAt(0);
        }
      });

      if (widget.showPulse) {
        _pulseController?.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pulseController?.dispose();
    super.dispose();
  }

  Color _statusColor() {
    if (widget.getStatus == null) return widget.accentColor;
    return switch (widget.getStatus!(_currentValue)) {
      SignalStatus.good => BioVoltColors.teal,
      SignalStatus.moderate => BioVoltColors.amber,
      SignalStatus.warning => BioVoltColors.coral,
    };
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final displayValue = widget.formatValue?.call(_currentValue) ??
        _currentValue.toStringAsFixed(0);

    return Container(
      decoration: BioVoltTheme.glassCard(glowColor: statusColor),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withAlpha(120),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.5,
                      ),
                ),
              ),
              if (widget.labelTrailing != null) ...[
                widget.labelTrailing!,
                const SizedBox(width: 6),
              ],
              if (widget.onInfoTap != null)
                GestureDetector(
                  onTap: () => widget.onInfoTap!(_currentValue),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: BioVoltColors.textSecondary.withAlpha(140),
                  ),
                ),
            ],
          ),
          const Spacer(),
          // Value with optional pulse animation
          _buildValue(displayValue, statusColor),
          const SizedBox(height: 2),
          Text(
            widget.unit,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BioVoltColors.textSecondary,
                ),
          ),
          const Spacer(),
          // Sparkline
          if (_sparkline.length > 2)
            SizedBox(
              height: 24,
              child: CustomPaint(
                painter: _SparklinePainter(
                  data: List.from(_sparkline),
                  color: statusColor,
                ),
                size: const Size(double.infinity, 24),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildValue(String displayValue, Color statusColor) {
    final valueWidget = Text(
      displayValue,
      style: BioVoltTheme.valueStyle(36, color: statusColor),
    );

    if (!widget.showPulse || _pulseController == null) {
      return valueWidget;
    }

    return AnimatedBuilder(
      animation: _pulseController!,
      builder: (context, child) {
        final scale = 1.0 + 0.05 * (1 - _pulseController!.value);
        return Transform.scale(
          scale: scale,
          alignment: Alignment.centerLeft,
          child: child,
        );
      },
      child: valueWidget,
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minVal = data.reduce((a, b) => a < b ? a : b);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal;
    if (range == 0) return;

    final paint = Paint()
      ..color = color.withAlpha(150)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minVal) / range) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Fill gradient beneath
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withAlpha(30), color.withAlpha(0)],
    );

    final fillPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => true;
}
