import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../timeline_item.dart';
import 'timeline_row.dart';

class TimelineFastingWindowTile extends StatelessWidget {
  final TimelineFastingWindow item;
  const TimelineFastingWindowTile({required this.item, super.key});

  @override
  Widget build(BuildContext context) {
    return TimelineRow(
      time: item.endTime,
      iconWidget: const TimelineLeadingIcon(
        icon: Icons.water_drop_outlined,
        color: BioVoltColors.amber,
        ghost: true,
      ),
      primary: 'Fast ends · ${item.fastingType} window',
      opacity: 0.55,
    );
  }
}
