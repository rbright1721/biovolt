import 'package:flutter/widgets.dart';

import '../../../config/theme.dart';
import '../../../models/biovolt_event.dart';
import '../../../services/event_types.dart';
import '../timeline_event_renderer.dart';

class JournalEntryEditedRenderer extends TimelineEventRenderer {
  const JournalEntryEditedRenderer();

  @override
  String get eventType => EventTypes.journalEntryEdited;

  @override
  Widget buildRow(BuildContext context, BiovoltEvent event) {
    return TimelineRow(
      title: 'Journal entry edited',
      summary: event.payload['conversationId']?.toString(),
      timestamp: event.timestamp,
      accent: BioVoltColors.amber,
    );
  }

  @override
  String buildSummary(BiovoltEvent event) => 'Journal entry edited';
}
