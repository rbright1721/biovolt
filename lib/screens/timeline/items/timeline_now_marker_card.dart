import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../bloc/sensors/sensors_bloc.dart';
import '../../../bloc/sensors/sensors_state.dart';
import '../../../config/theme.dart';
import '../../../models/active_protocol.dart';
import '../timeline_item.dart';
import 'timeline_row.dart';

/// The NOW anchor card. Visually distinct from the row tiles —
/// horizontal teal rules above and below, prominent label, a
/// self-rebuilding time display, and a live biometric strip driven
/// by [SensorsBloc].
///
/// The card itself is stateless — it delegates everything that
/// updates on a cadence to internal widgets ([_NowTimeText] for
/// the minute ticker; a [BlocBuilder] for vitals) so the parent
/// list never has to rebuild the card on biometric or time ticks.
class TimelineNowMarkerCard extends StatelessWidget {
  final TimelineNowMarker item;
  const TimelineNowMarkerCard({required this.item, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: BioVoltColors.surface.withAlpha(180),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BioVoltColors.teal.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _NowDivider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'NOW',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: BioVoltColors.teal,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(width: 10),
              _NowTimeText(
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: BioVoltColors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          BlocBuilder<SensorsBloc, SensorsState>(
            builder: (context, state) {
              return Text(
                formatNowMarkerBiometrics(state),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: BioVoltColors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              );
            },
          ),
          if (item.activeProtocols.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _formatActiveProtocols(item.activeProtocols),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: BioVoltColors.amber,
                letterSpacing: 0.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          const _NowDivider(),
        ],
      ),
    );
  }

  String _formatActiveProtocols(List<ActiveProtocol> list) {
    return list.map((p) {
      if (p.isOngoing) return '${p.name} ongoing';
      return '${p.name} Day ${p.currentCycleDay}';
    }).join(' · ');
  }
}

/// Format a biometric strip from a [SensorsState] snapshot.
///
/// The SensorsState fields are non-nullable doubles defaulting to 0;
/// the app convention (see dashboard's bookmark sheet) is to treat
/// a zero reading as "no value" and render an em-dash. Values use
/// fixed decimal counts so the whole strip stays the same width as
/// readings update.
///
/// Public so it can be unit-tested without pumping a BlocBuilder.
String formatNowMarkerBiometrics(SensorsState state) {
  String fmt(double value, String unit, int decimals) {
    if (value <= 0) return '—';
    return '${value.toStringAsFixed(decimals)}$unit';
  }

  final hr = fmt(state.heartRate, '', 0);
  final hrv = fmt(state.hrv, 'ms', 0);
  final gsr = fmt(state.gsr, 'µS', 1);
  final temp = fmt(state.temperature, '°F', 1);
  final spo2 = fmt(state.spo2, '%', 0);

  return 'HR $hr  ·  HRV $hrv  ·  GSR $gsr  ·  Temp $temp  ·  SpO₂ $spo2';
}

/// Self-rebuilding time display for the NOW marker.
///
/// Ticks on the minute boundary so the displayed minute flips at
/// `:00` rather than at an arbitrary offset from mount. Only this
/// widget's subtree rebuilds — the rest of the marker card, the
/// biometric strip, and the surrounding list are untouched.
///
/// Reads DateTime.now() directly rather than from the surrounding
/// [TimelineNowMarker.time] — the marker's time field remains
/// authoritative for sort ordering at build time, but this display
/// keeps advancing without needing the parent list to rebuild.
class _NowTimeText extends StatefulWidget {
  final TextStyle? style;
  const _NowTimeText({this.style});

  @override
  State<_NowTimeText> createState() => _NowTimeTextState();
}

class _NowTimeTextState extends State<_NowTimeText> {
  Timer? _ticker;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    final delay = nextMinute.difference(now);
    _ticker = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
      _scheduleNextTick();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(formatTimelineTime(_now), style: widget.style);
  }
}

class _NowDivider extends StatelessWidget {
  const _NowDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BioVoltColors.teal.withAlpha(0),
            BioVoltColors.teal.withAlpha(180),
            BioVoltColors.teal.withAlpha(0),
          ],
        ),
      ),
    );
  }
}
