import 'package:flutter/widgets.dart';

import '../../../config/theme.dart';
import '../../../models/biovolt_event.dart';
import '../../../services/event_types.dart';
import '../timeline_event_renderer.dart';

class ProfileBloodworkAddedRenderer extends TimelineEventRenderer {
  const ProfileBloodworkAddedRenderer();

  @override
  String get eventType => EventTypes.profileBloodworkAdded;

  @override
  Widget buildRow(BuildContext context, BiovoltEvent event) {
    return TimelineRow(
      title: 'Bloodwork added',
      summary: _summary(event),
      timestamp: event.timestamp,
      accent: BioVoltColors.amber,
    );
  }

  @override
  String buildSummary(BiovoltEvent event) =>
      'Bloodwork added — ${_summary(event)}';

  String _summary(BiovoltEvent event) {
    final labDate = event.payload['labDate']?.toString();
    final date = labDate != null && labDate.length >= 10
        ? labDate.substring(0, 10)
        : (labDate ?? '');
    final markerCount = _countNonNullMarkers(event.payload);
    return markerCount > 0 ? '$date · $markerCount markers' : date;
  }

  int _countNonNullMarkers(Map<String, dynamic> payload) {
    const structural = {'id', 'labDate', 'fastingHours', 'protocolContext', 'notes'};
    var count = 0;
    for (final entry in payload.entries) {
      if (structural.contains(entry.key)) continue;
      if (entry.value != null) count++;
    }
    return count;
  }
}
