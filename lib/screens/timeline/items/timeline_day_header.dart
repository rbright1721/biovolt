import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';

/// Inline (non-sticky) day header inserted between items when crossing
/// midnight boundaries.
///
/// Display rules:
///   * date == today      → "Today"
///   * date == yesterday  → "Yesterday"
///   * date == tomorrow   → "Tomorrow"
///   * else               → "Monday Apr 20"
class TimelineDayHeader extends StatelessWidget {
  final DateTime date;

  /// Reference now used for the today/yesterday/tomorrow comparison.
  /// Tests inject a fixed value; production omits it.
  final DateTime? now;

  const TimelineDayHeader({required this.date, this.now, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
      child: Text(
        formatDayHeader(date, now: now),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: BioVoltColors.teal,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

/// Public so screen-level grouping & tests can verify formatting
/// without instantiating the widget.
String formatDayHeader(DateTime date, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = target.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return '${_weekday(target.weekday)} ${_month(target.month)} ${target.day}';
}

String _weekday(int w) {
  const names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return names[(w - 1).clamp(0, 6)];
}

String _month(int m) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return names[(m - 1).clamp(0, 11)];
}
