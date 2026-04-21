import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/biovolt_event.dart';
import 'renderers/analysis_completed_renderer.dart';
import 'renderers/device_connected_renderer.dart';
import 'renderers/device_disconnected_renderer.dart';
import 'renderers/device_state_changed_renderer.dart';
import 'renderers/journal_entry_added_renderer.dart';
import 'renderers/journal_entry_edited_renderer.dart';
import 'renderers/profile_bloodwork_added_renderer.dart';
import 'renderers/profile_bloodwork_edited_renderer.dart';
import 'renderers/profile_bloodwork_removed_renderer.dart';
import 'renderers/protocol_item_added_renderer.dart';
import 'renderers/protocol_item_modified_renderer.dart';
import 'renderers/protocol_item_removed_renderer.dart';
import 'renderers/session_discarded_renderer.dart';
import 'renderers/session_ended_renderer.dart';
import 'renderers/session_started_renderer.dart';
import 'renderers/supplement_added_renderer.dart';

/// Pluggable renderer for a single event type on the timeline screen.
///
/// Add a new renderer by creating a subclass under
/// `lib/ui/timeline/renderers/` and registering it in
/// [TimelineRendererRegistry.defaultRegistry].
abstract class TimelineEventRenderer {
  const TimelineEventRenderer();

  /// The exact [BiovoltEvent.type] string this renderer handles.
  String get eventType;

  /// The collapsed row shown in the day-grouped list.
  Widget buildRow(BuildContext context, BiovoltEvent event);

  /// The expanded view shown when a row is tapped. Defaults to a generic
  /// key/value dump of the payload — override for custom detail layouts.
  Widget buildExpanded(BuildContext context, BiovoltEvent event) {
    return _PayloadKeyValueList(payload: event.payload);
  }

  /// One-line summary used inside collapsed-run rows ("5 events from X").
  String buildSummary(BiovoltEvent event);
}

/// Looks up a renderer by event type, falling back to a generic renderer
/// for any type not registered.
class TimelineRendererRegistry {
  TimelineRendererRegistry(Iterable<TimelineEventRenderer> renderers)
      : _byType = {for (final r in renderers) r.eventType: r};

  final Map<String, TimelineEventRenderer> _byType;

  static const TimelineEventRenderer _fallback = GenericTimelineRenderer();

  TimelineEventRenderer forEvent(BiovoltEvent event) =>
      _byType[event.type] ?? _fallback;

  TimelineEventRenderer forType(String type) =>
      _byType[type] ?? _fallback;

  /// The renderer registered for [type], or null if none is registered.
  /// Useful for tests that want to assert a specific renderer handles a
  /// specific type without going through the fallback.
  TimelineEventRenderer? getRegistered(String type) => _byType[type];

  /// The default registry wired with all first-class renderers shipped
  /// with the app. Test code that wants isolation can construct its own
  /// registry from a smaller list.
  static final TimelineRendererRegistry defaultRegistry =
      TimelineRendererRegistry(const [
    SessionEndedRenderer(),
    SessionDiscardedRenderer(),
    SessionStartedRenderer(),
    ProfileBloodworkAddedRenderer(),
    ProfileBloodworkEditedRenderer(),
    ProfileBloodworkRemovedRenderer(),
    ProtocolItemAddedRenderer(),
    ProtocolItemModifiedRenderer(),
    ProtocolItemRemovedRenderer(),
    DeviceStateChangedRenderer(),
    DeviceConnectedRenderer(),
    DeviceDisconnectedRenderer(),
    AnalysisCompletedRenderer(),
    SupplementAddedRenderer(),
    JournalEntryAddedRenderer(),
    JournalEntryEditedRenderer(),
  ]);
}

/// Fallback renderer for any event type not explicitly registered.
/// Shows humanized type + relative time, and a key/value payload on
/// expand.
class GenericTimelineRenderer extends TimelineEventRenderer {
  const GenericTimelineRenderer();

  @override
  String get eventType => '';

  @override
  Widget buildRow(BuildContext context, BiovoltEvent event) {
    return TimelineRow(
      title: humanizeEventType(event.type),
      summary: _firstPayloadSummary(event.payload),
      timestamp: event.timestamp,
      accent: BioVoltColors.textSecondary,
    );
  }

  @override
  String buildSummary(BiovoltEvent event) => humanizeEventType(event.type);

  String? _firstPayloadSummary(Map<String, dynamic> payload) {
    if (payload.isEmpty) return null;
    final entry = payload.entries.first;
    return '${entry.key}: ${entry.value}';
  }
}

// -------------------------------------------------------------------------
// Shared row widget used by most first-class renderers.
// -------------------------------------------------------------------------

/// Standard timeline row layout: colored leading dot + title/summary +
/// trailing relative time. Use from inside [TimelineEventRenderer.buildRow]
/// to keep all rows visually consistent.
class TimelineRow extends StatelessWidget {
  const TimelineRow({
    super.key,
    required this.title,
    this.summary,
    required this.timestamp,
    required this.accent,
  });

  final String title;
  final String? summary;
  final DateTime timestamp;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: 12),
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withAlpha(80),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BioVoltColors.textPrimary,
                  ),
                ),
                if (summary != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    summary!,
                    style: TextStyle(
                      fontSize: 11,
                      color: BioVoltColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatRelativeTime(timestamp),
            style: TextStyle(
              fontSize: 10,
              color: BioVoltColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Key/value dump of an event payload. Used as the default expanded view
/// by [TimelineEventRenderer.buildExpanded].
class _PayloadKeyValueList extends StatelessWidget {
  const _PayloadKeyValueList({required this.payload});

  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    if (payload.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'No payload',
          style: TextStyle(
            fontSize: 11,
            color: BioVoltColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in payload.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 10,
                        color: BioVoltColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatValue(entry.value),
                      style: TextStyle(
                        fontSize: 11,
                        color: BioVoltColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatValue(Object? value) {
    if (value == null) return 'null';
    if (value is Map || value is List) return value.toString();
    return value.toString();
  }
}

// -------------------------------------------------------------------------
// Formatting helpers shared across renderers.
// -------------------------------------------------------------------------

/// Turn an event type string like `profile.bloodwork_added` into a
/// human-readable `Profile bloodwork added`.
String humanizeEventType(String type) {
  final withSpaces = type.replaceAll('.', ' ').replaceAll('_', ' ');
  if (withSpaces.isEmpty) return type;
  return withSpaces[0].toUpperCase() + withSpaces.substring(1);
}

/// Short relative timestamp: "just now", "2m ago", "3h ago", "5d ago".
String formatRelativeTime(DateTime when, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final delta = reference.difference(when);
  if (delta.inSeconds < 45) return 'just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
  if (delta.inHours < 24) return '${delta.inHours}h ago';
  if (delta.inDays < 30) return '${delta.inDays}d ago';
  final months = (delta.inDays / 30).floor();
  if (months < 12) return '${months}mo ago';
  final years = (delta.inDays / 365).floor();
  return '${years}y ago';
}
