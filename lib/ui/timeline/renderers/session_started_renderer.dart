import 'package:flutter/widgets.dart';

import '../../../config/theme.dart';
import '../../../models/biovolt_event.dart';
import '../../../services/event_types.dart';
import '../timeline_event_renderer.dart';

// TODO: verify payload shape once emission lands — assumed fields:
// sessionId (String), sessionType (String).
class SessionStartedRenderer extends TimelineEventRenderer {
  const SessionStartedRenderer();

  @override
  String get eventType => EventTypes.sessionStarted;

  @override
  Widget buildRow(BuildContext context, BiovoltEvent event) {
    final type = event.payload['sessionType']?.toString();
    return TimelineRow(
      title: 'Session started',
      summary: type,
      timestamp: event.timestamp,
      accent: BioVoltColors.teal,
    );
  }

  @override
  String buildSummary(BiovoltEvent event) {
    final type = event.payload['sessionType']?.toString();
    return type == null ? 'Session started' : 'Session started — $type';
  }
}
