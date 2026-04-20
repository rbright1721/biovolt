import 'package:flutter/widgets.dart';

import '../../../config/theme.dart';
import '../../../models/biovolt_event.dart';
import '../../../services/event_types.dart';
import '../timeline_event_renderer.dart';

class ProfileBloodworkEditedRenderer extends TimelineEventRenderer {
  const ProfileBloodworkEditedRenderer();

  @override
  String get eventType => EventTypes.profileBloodworkEdited;

  @override
  Widget buildRow(BuildContext context, BiovoltEvent event) {
    return TimelineRow(
      title: 'Bloodwork edited',
      summary: _labDate(event),
      timestamp: event.timestamp,
      accent: BioVoltColors.amber,
    );
  }

  @override
  String buildSummary(BiovoltEvent event) =>
      'Bloodwork edited — ${_labDate(event)}';

  String _labDate(BiovoltEvent event) {
    final labDate = event.payload['labDate']?.toString();
    if (labDate == null) return '';
    return labDate.length >= 10 ? labDate.substring(0, 10) : labDate;
  }
}
