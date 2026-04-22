import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../timeline_item.dart';
import 'timeline_row.dart';

class TimelineCycleDayMarkerTile extends StatelessWidget {
  final TimelineCycleDayMarker item;
  const TimelineCycleDayMarkerTile({required this.item, super.key});

  @override
  Widget build(BuildContext context) {
    return TimelineRow(
      time: item.date,
      iconWidget: const TimelineLeadingIcon(
        icon: Icons.event_outlined,
        color: BioVoltColors.teal,
        ghost: true,
      ),
      primary: '${item.protocol.name} Day ${item.cycleDay} starts',
      opacity: 0.55,
    );
  }
}
