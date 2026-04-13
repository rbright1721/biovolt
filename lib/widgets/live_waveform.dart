import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// A scrolling real-time waveform display using CustomPainter.
/// Looks like a medical ECG/PPG monitor with grid background.
class LiveWaveform extends StatefulWidget {
  final Stream<double> dataStream;
  final Color lineColor;
  final double strokeWidth;
  final int maxPoints;
  final double minY;
  final double maxY;
  final bool showGrid;

  const LiveWaveform({
    super.key,
    required this.dataStream,
    this.lineColor = BioVoltColors.teal,
    this.strokeWidth = 2.0,
    this.maxPoints = 300,
    this.minY = -0.5,
    this.maxY = 1.2,
    this.showGrid = true,
  });

  @override
  State<LiveWaveform> createState() => _LiveWaveformState();
}

class _LiveWaveformState extends State<LiveWaveform>
    with SingleTickerProviderStateMixin {
  final List<double> _data = [];
  StreamSubscription<double>? _subscription;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();

    _subscription = widget.dataStream.listen((value) {
      _data.add(value);
      if (_data.length > widget.maxPoints) {
        _data.removeAt(0);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        return CustomPaint(
          painter: _WaveformPainter(
            data: List.from(_data),
            lineColor: widget.lineColor,
            strokeWidth: widget.strokeWidth,
            minY: widget.minY,
            maxY: widget.maxY,
            showGrid: widget.showGrid,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final double strokeWidth;
  final double minY;
  final double maxY;
  final bool showGrid;

  _WaveformPainter({
    required this.data,
    required this.lineColor,
    required this.strokeWidth,
    required this.minY,
    required this.maxY,
    required this.showGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) {
      _drawGrid(canvas, size);
    }

    if (data.length < 2) return;

    // Draw glow effect behind the line
    final glowPaint = Paint()
      ..color = lineColor.withAlpha(30)
      ..strokeWidth = strokeWidth + 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final range = maxY - minY;

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final normalized = (data[i] - minY) / range;
      final y = size.height - (normalized * size.height);

      if (i == 0) {
        path.moveTo(x, y.clamp(0, size.height));
      } else {
        path.lineTo(x, y.clamp(0, size.height));
      }
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    // Draw leading dot
    if (data.isNotEmpty) {
      final lastX = size.width;
      final lastNorm = (data.last - minY) / range;
      final lastY = size.height - (lastNorm * size.height);

      final dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(lastX, lastY.clamp(0, size.height)),
        4,
        dotPaint,
      );

      // Dot glow
      final dotGlow = Paint()
        ..color = lineColor.withAlpha(60)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(
        Offset(lastX, lastY.clamp(0, size.height)),
        8,
        dotGlow,
      );
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = BioVoltColors.gridLine
      ..strokeWidth = 0.5;

    // Vertical lines
    const vCount = 12;
    for (int i = 0; i <= vCount; i++) {
      final x = (i / vCount) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Horizontal lines
    const hCount = 4;
    for (int i = 0; i <= hCount; i++) {
      final y = (i / hCount) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) => true;
}
