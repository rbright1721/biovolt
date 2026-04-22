import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/vitals_bookmark.dart';
import '../timeline_item.dart';
import 'timeline_row.dart';

class TimelineBookmarkTile extends StatelessWidget {
  final TimelineBookmark item;
  const TimelineBookmarkTile({required this.item, super.key});

  @override
  Widget build(BuildContext context) {
    final b = item.bookmark;
    return TimelineRow(
      time: b.timestamp,
      iconWidget: const TimelineLeadingIcon(
        icon: Icons.bookmark_rounded,
        color: BioVoltColors.teal,
      ),
      primary: b.note?.trim().isNotEmpty == true
          ? b.note!
          : 'Vitals snapshot',
      secondary: _vitalsLine(b),
    );
  }

  String? _vitalsLine(VitalsBookmark b) {
    final parts = <String>[];
    if (b.hrBpm != null) parts.add('HR ${b.hrBpm!.toStringAsFixed(0)}');
    if (b.hrvMs != null) parts.add('HRV ${b.hrvMs!.toStringAsFixed(0)}ms');
    if (b.gsrUs != null) parts.add('GSR ${b.gsrUs!.toStringAsFixed(1)}µS');
    if (b.skinTempF != null) {
      parts.add('${b.skinTempF!.toStringAsFixed(1)}°F');
    }
    if (b.spo2Percent != null) {
      parts.add('SpO₂ ${b.spo2Percent!.toStringAsFixed(0)}%');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
