import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/biovolt_event.dart';
import '../../../services/event_types.dart';
import '../timeline_event_renderer.dart';

/// Renderer for [EventTypes.entryCreated] — a [LogEntry] saved through
/// the dashboard's Quick Log sheet. Renders the user's rawText as the
/// primary line and the current classification type ('other' for
/// freshly captured entries, upgraded by the Part 2 classifier) as the
/// summary.
class TimelineEntryCreatedRenderer extends TimelineEventRenderer {
  const TimelineEntryCreatedRenderer();

  @override
  String get eventType => EventTypes.entryCreated;

  static const int _titleMaxChars = 60;

  @override
  Widget buildRow(BuildContext context, BiovoltEvent event) {
    return TimelineRow(
      title: _title(event),
      summary: _summary(event),
      timestamp: event.timestamp,
      accent: BioVoltColors.amber,
    );
  }

  @override
  String buildSummary(BiovoltEvent event) => _title(event);

  String _title(BiovoltEvent event) {
    final raw = (event.payload['rawText'] as String?)?.trim() ?? '';
    if (raw.isEmpty) return 'Vitals snapshot';
    if (raw.length <= _titleMaxChars) return raw;
    return '${raw.substring(0, _titleMaxChars - 1).trimRight()}…';
  }

  String _summary(BiovoltEvent event) {
    final type = event.payload['type']?.toString() ?? 'other';
    // 'other' is the pre-classification default — show it as "log" so
    // it reads naturally in the row; real types ('dose', 'meal', etc.)
    // render verbatim.
    return type == 'other' ? 'log' : type;
  }
}
