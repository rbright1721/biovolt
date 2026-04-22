import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../timeline_item.dart';
import 'timeline_row.dart';

class TimelineExpectedDoseTile extends StatelessWidget {
  final TimelineExpectedDose item;
  const TimelineExpectedDoseTile({required this.item, super.key});

  @override
  Widget build(BuildContext context) {
    final p = item.protocol;
    final dose = p.doseDisplay?.trim();
    final primary = dose != null && dose.isNotEmpty
        ? '${p.name} $dose expected'
        : '${p.name} expected';
    return TimelineRow(
      time: item.expectedTime,
      iconWidget: const TimelineLeadingIcon(
        icon: Icons.circle_outlined,
        color: BioVoltColors.teal,
        ghost: true,
      ),
      primary: primary,
      opacity: 0.55,
    );
  }
}
