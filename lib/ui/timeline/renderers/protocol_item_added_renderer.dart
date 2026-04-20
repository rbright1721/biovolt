import 'package:flutter/widgets.dart';

import '../../../config/theme.dart';
import '../../../models/biovolt_event.dart';
import '../../../services/event_types.dart';
import '../timeline_event_renderer.dart';

class ProtocolItemAddedRenderer extends TimelineEventRenderer {
  const ProtocolItemAddedRenderer();

  @override
  String get eventType => EventTypes.protocolItemAdded;

  @override
  Widget buildRow(BuildContext context, BiovoltEvent event) {
    return TimelineRow(
      title: 'Protocol added',
      summary: _summary(event),
      timestamp: event.timestamp,
      accent: BioVoltColors.teal,
    );
  }

  @override
  String buildSummary(BiovoltEvent event) =>
      'Protocol added — ${_summary(event)}';

  String _summary(BiovoltEvent event) {
    final name = event.payload['name']?.toString() ?? '';
    final type = event.payload['type']?.toString();
    return type != null ? '$name · $type' : name;
  }
}
