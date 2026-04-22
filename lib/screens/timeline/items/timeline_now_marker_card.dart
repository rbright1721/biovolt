import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../models/active_protocol.dart';
import '../timeline_item.dart';
import 'timeline_row.dart';

/// The NOW anchor card. Visually distinct from the row tiles —
/// horizontal teal rules above and below, prominent label, and a
/// placeholder biometric strip. Live data wiring is intentionally
/// deferred to Session 3 (see CLAUDE.md / spec); the dash placeholders
/// are correct for Session 2.
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
              Text(
                formatTimelineTime(item.time),
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
          // Session 3 wires this strip to SensorsBloc — these dashes
          // are intentional placeholders for Session 2.
          Text(
            'HR —  ·  HRV —  ·  GSR —  ·  Temp —  ·  SpO₂ —',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: BioVoltColors.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
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
