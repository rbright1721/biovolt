import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/biovolt_event.dart';
import '../../../services/event_types.dart';
import '../timeline_event_renderer.dart';

/// Renderer for [EventTypes.entryClassified] — a [LogEntry] whose
/// classifier verdict has just been written by the worker. Shows the
/// same rawText the create event showed, upgraded with the classified
/// type (and a low-confidence annotation when confidence < 0.7).
///
/// Distinct from [TimelineEntryCreatedRenderer] so the timeline reads
/// chronologically as "captured → classified" rather than blurring the
/// two events into one generic row.
class TimelineEntryClassifiedRenderer extends TimelineEventRenderer {
  const TimelineEntryClassifiedRenderer();

  @override
  String get eventType => EventTypes.entryClassified;

  static const int _titleMaxChars = 60;

  /// Mirror of the server's CONFIDENCE_GOOD_THRESHOLD. Hoisted here as
  /// a UI-side annotation trigger — the server already clamps/rewrites
  /// below this threshold, but surfacing the boundary in the row lets
  /// the user see "classified, but uncertain" at a glance.
  static const double _lowConfidenceThreshold = 0.7;

  @override
  Widget buildRow(BuildContext context, BiovoltEvent event) {
    return TimelineRow(
      title: _title(event),
      summary: _summary(event),
      timestamp: event.timestamp,
      accent: BioVoltColors.teal,
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
    final confidence = (event.payload['confidence'] as num?)?.toDouble();
    final typeLabel = type.toUpperCase();
    if (confidence != null && confidence < _lowConfidenceThreshold) {
      return '$typeLabel · low confidence';
    }
    return typeLabel;
  }
}
