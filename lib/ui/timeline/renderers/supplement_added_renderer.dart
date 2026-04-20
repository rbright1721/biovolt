import 'package:flutter/widgets.dart';

import '../../../config/theme.dart';
import '../../../models/biovolt_event.dart';
import '../../../services/event_types.dart';
import '../timeline_event_renderer.dart';

// TODO: verify payload shape once emission lands — assumed fields:
// name (String), dose (String/num). No emission site exists yet in
// StorageService for this type; the constant is defined in EventTypes
// and reserved for a future supplement-tracking feature.
class SupplementAddedRenderer extends TimelineEventRenderer {
  const SupplementAddedRenderer();

  @override
  String get eventType => EventTypes.supplementAdded;

  @override
  Widget buildRow(BuildContext context, BiovoltEvent event) {
    return TimelineRow(
      title: 'Supplement added',
      summary: _summary(event),
      timestamp: event.timestamp,
      accent: BioVoltColors.amber,
    );
  }

  @override
  String buildSummary(BiovoltEvent event) =>
      'Supplement added — ${_summary(event)}';

  String _summary(BiovoltEvent event) {
    final name = event.payload['name']?.toString() ?? '';
    final dose = event.payload['dose']?.toString();
    return dose != null ? '$name · $dose' : name;
  }
}
