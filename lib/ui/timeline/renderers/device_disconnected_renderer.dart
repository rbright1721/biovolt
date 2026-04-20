import 'package:flutter/widgets.dart';

import '../../../config/theme.dart';
import '../../../models/biovolt_event.dart';
import '../../../services/event_types.dart';
import '../timeline_event_renderer.dart';

// TODO: verify payload shape once emission lands — assumed fields:
// deviceName (String), connectorId (String).
class DeviceDisconnectedRenderer extends TimelineEventRenderer {
  const DeviceDisconnectedRenderer();

  @override
  String get eventType => EventTypes.deviceDisconnected;

  @override
  Widget buildRow(BuildContext context, BiovoltEvent event) {
    final name = event.payload['deviceName']?.toString() ??
        event.payload['connectorId']?.toString();
    return TimelineRow(
      title: 'Device disconnected',
      summary: name,
      timestamp: event.timestamp,
      accent: BioVoltColors.coral,
    );
  }

  @override
  String buildSummary(BiovoltEvent event) {
    final name = event.payload['deviceName']?.toString() ??
        event.payload['connectorId']?.toString();
    return name == null ? 'Device disconnected' : 'Device disconnected — $name';
  }
}
