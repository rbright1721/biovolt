import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/biovolt_event.dart';
import '../../../services/event_types.dart';
import '../timeline_event_renderer.dart';

/// Renderer for [EventTypes.entryReclassified] — the worker wrote a
/// new classifier verdict over a previously-classified entry. Rare in
/// current code (only fires when an already-'classified' entry is
/// updated again), but worth distinguishing from a first-time
/// classification so a timeline reader can tell corrections from
/// initial verdicts.
class TimelineEntryReclassifiedRenderer extends TimelineEventRenderer {
  const TimelineEntryReclassifiedRenderer();

  @override
  String get eventType => EventTypes.entryReclassified;

  static const int _titleMaxChars = 60;
  static const double _lowConfidenceThreshold = 0.7;

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

  /// "Re-classified as DOSE" / "Re-classified as DOSE · low confidence".
  /// The prefix differentiates visually from the first-time
  /// classification renderer without relying on a distinct icon (our
  /// TimelineRow uses a colored dot, not icons).
  String _summary(BiovoltEvent event) {
    final type = event.payload['type']?.toString() ?? 'other';
    final confidence = (event.payload['confidence'] as num?)?.toDouble();
    final typeLabel = type.toUpperCase();
    final base = 'Re-classified as $typeLabel';
    if (confidence != null && confidence < _lowConfidenceThreshold) {
      return '$base · low confidence';
    }
    return base;
  }
}
