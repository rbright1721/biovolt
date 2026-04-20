import 'package:flutter/widgets.dart';

import '../../../config/theme.dart';
import '../../../models/biovolt_event.dart';
import '../../../services/event_types.dart';
import '../timeline_event_renderer.dart';

class JournalEntryAddedRenderer extends TimelineEventRenderer {
  const JournalEntryAddedRenderer();

  @override
  String get eventType => EventTypes.journalEntryAdded;

  @override
  Widget buildRow(BuildContext context, BiovoltEvent event) {
    return TimelineRow(
      title: 'Journal entry added',
      summary: event.payload['conversationId']?.toString(),
      timestamp: event.timestamp,
      accent: BioVoltColors.teal,
    );
  }

  @override
  String buildSummary(BiovoltEvent event) => 'Journal entry added';
}
