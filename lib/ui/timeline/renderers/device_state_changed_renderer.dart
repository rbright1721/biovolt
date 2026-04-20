import 'package:flutter/widgets.dart';

import '../../../config/theme.dart';
import '../../../models/biovolt_event.dart';
import '../../../services/event_types.dart';
import '../timeline_event_renderer.dart';

class DeviceStateChangedRenderer extends TimelineEventRenderer {
  const DeviceStateChangedRenderer();

  @override
  String get eventType => EventTypes.deviceStateChanged;

  @override
  Widget buildRow(BuildContext context, BiovoltEvent event) {
    return TimelineRow(
      title: 'Device state changed',
      summary: _summary(event),
      timestamp: event.timestamp,
      accent: BioVoltColors.textSecondary,
    );
  }

  @override
  String buildSummary(BiovoltEvent event) =>
      'Device state changed — ${_summary(event)}';

  String _summary(BiovoltEvent event) {
    final connector = event.payload['connectorId']?.toString() ??
        event.payload['name']?.toString() ??
        '';
    final status = event.payload['status']?.toString();
    if (status == null) return connector;
    return connector.isEmpty ? status : '$connector · $status';
  }
}
