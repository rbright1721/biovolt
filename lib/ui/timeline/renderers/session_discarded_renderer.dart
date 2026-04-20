import 'package:flutter/widgets.dart';

import '../../../config/theme.dart';
import '../../../models/biovolt_event.dart';
import '../../../services/event_types.dart';
import '../timeline_event_renderer.dart';

class SessionDiscardedRenderer extends TimelineEventRenderer {
  const SessionDiscardedRenderer();

  @override
  String get eventType => EventTypes.sessionDiscarded;

  @override
  Widget buildRow(BuildContext context, BiovoltEvent event) {
    return TimelineRow(
      title: 'Session discarded',
      summary: event.payload['sessionId']?.toString(),
      timestamp: event.timestamp,
      accent: BioVoltColors.coral,
    );
  }

  @override
  String buildSummary(BiovoltEvent event) => 'Session discarded';
}
