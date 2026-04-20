import 'package:flutter/widgets.dart';

import '../../../config/theme.dart';
import '../../../models/biovolt_event.dart';
import '../../../services/event_types.dart';
import '../timeline_event_renderer.dart';

class SessionEndedRenderer extends TimelineEventRenderer {
  const SessionEndedRenderer();

  @override
  String get eventType => EventTypes.sessionEnded;

  @override
  Widget buildRow(BuildContext context, BiovoltEvent event) {
    return TimelineRow(
      title: 'Session ended',
      summary: _summary(event),
      timestamp: event.timestamp,
      accent: BioVoltColors.teal,
    );
  }

  @override
  String buildSummary(BiovoltEvent event) => 'Session ended — ${_summary(event)}';

  String _summary(BiovoltEvent event) {
    final duration = event.payload['durationSeconds'];
    if (duration is int) {
      final mins = duration ~/ 60;
      final secs = duration % 60;
      return mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
    }
    return event.payload['sessionId']?.toString() ?? '';
  }
}
