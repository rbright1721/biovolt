import 'package:flutter/widgets.dart';

import '../../../config/theme.dart';
import '../../../models/biovolt_event.dart';
import '../../../services/event_types.dart';
import '../timeline_event_renderer.dart';

class ProfileBloodworkRemovedRenderer extends TimelineEventRenderer {
  const ProfileBloodworkRemovedRenderer();

  @override
  String get eventType => EventTypes.profileBloodworkRemoved;

  @override
  Widget buildRow(BuildContext context, BiovoltEvent event) {
    final labDate = event.payload['labDate']?.toString();
    final summary = labDate != null && labDate.length >= 10
        ? labDate.substring(0, 10)
        : labDate;
    return TimelineRow(
      title: 'Bloodwork removed',
      summary: summary,
      timestamp: event.timestamp,
      accent: BioVoltColors.coral,
    );
  }

  @override
  String buildSummary(BiovoltEvent event) => 'Bloodwork removed';
}
