import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';

/// Format a [DateTime] as `h:mm am/pm`. The leading hour is NOT
/// zero-padded so columns aren't overly wide for one-digit hours;
/// the SizedBox width in [TimelineRow] handles alignment.
String formatTimelineTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final period = t.hour < 12 ? 'am' : 'pm';
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m $period';
}

/// Shared row layout used by every past/future tile EXCEPT the
/// NOW marker. Library-private so item tile widgets in this folder
/// share the layout without it leaking into the rest of the app.
class TimelineRow extends StatelessWidget {
  final DateTime time;
  final Widget iconWidget;
  final String primary;
  final String? secondary;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// 1.0 for past, 0.55 for future (ghost-styled).
  final double opacity;

  const TimelineRow({
    super.key,
    required this.time,
    required this.iconWidget,
    required this.primary,
    this.secondary,
    this.trailing,
    this.onTap,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 68,
              child: Text(
                formatTimelineTime(time),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: BioVoltColors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            iconWidget,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    primary,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: BioVoltColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (secondary != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      secondary!,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: BioVoltColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );

    return opacity < 1.0 ? Opacity(opacity: opacity, child: row) : row;
  }
}

/// Small leading icon container styled to match the ghost vs solid
/// theme — solid for past items, outlined for future items.
class TimelineLeadingIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool ghost;

  const TimelineLeadingIcon({
    super.key,
    required this.icon,
    required this.color,
    this.ghost = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: ghost ? Colors.transparent : color.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withAlpha(ghost ? 100 : 60),
          width: ghost ? 1.2 : 1,
        ),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

/// Type chip used by log-entry tiles: small uppercase label inside a
/// rounded rectangle, color-tinted by status.
class TimelineTypeChip extends StatelessWidget {
  final String label;
  final Color color;

  const TimelineTypeChip({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
