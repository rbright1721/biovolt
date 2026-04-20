import 'package:flutter/widgets.dart';

import '../../../config/theme.dart';
import '../../../models/biovolt_event.dart';
import '../../../services/event_types.dart';
import '../timeline_event_renderer.dart';

class ProtocolItemRemovedRenderer extends TimelineEventRenderer {
  const ProtocolItemRemovedRenderer();

  @override
  String get eventType => EventTypes.protocolItemRemoved;

  @override
  Widget buildRow(BuildContext context, BiovoltEvent event) {
    return TimelineRow(
      title: 'Protocol removed',
      summary: event.payload['name']?.toString(),
      timestamp: event.timestamp,
      accent: BioVoltColors.coral,
    );
  }

  @override
  String buildSummary(BiovoltEvent event) =>
      'Protocol removed — ${event.payload['name'] ?? ''}';
}
