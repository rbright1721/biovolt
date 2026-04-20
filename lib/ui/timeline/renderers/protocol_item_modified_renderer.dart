import 'package:flutter/widgets.dart';

import '../../../config/theme.dart';
import '../../../models/biovolt_event.dart';
import '../../../services/event_types.dart';
import '../timeline_event_renderer.dart';

class ProtocolItemModifiedRenderer extends TimelineEventRenderer {
  const ProtocolItemModifiedRenderer();

  @override
  String get eventType => EventTypes.protocolItemModified;

  @override
  Widget buildRow(BuildContext context, BiovoltEvent event) {
    final name = event.payload['name']?.toString() ?? '';
    final isActive = event.payload['isActive'];
    final status = isActive == false ? 'ended' : 'modified';
    return TimelineRow(
      title: 'Protocol $status',
      summary: name,
      timestamp: event.timestamp,
      accent: isActive == false ? BioVoltColors.amber : BioVoltColors.teal,
    );
  }

  @override
  String buildSummary(BiovoltEvent event) {
    final name = event.payload['name']?.toString() ?? '';
    final isActive = event.payload['isActive'];
    final status = isActive == false ? 'ended' : 'modified';
    return 'Protocol $status — $name';
  }
}
