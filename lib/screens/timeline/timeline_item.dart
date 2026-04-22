import '../../models/active_protocol.dart';
import '../../models/log_entry.dart';
import '../../models/session.dart';
import '../../models/vitals_bookmark.dart';

/// Base type for every item that can appear on the timeline.
///
/// Implementations are sorted by [time] DESC in the rendered list,
/// with [TimelineNowMarker] acting as the anchor between past and
/// future items.
sealed class TimelineItem {
  /// The moment this item represents. Past items use their
  /// occurrence time (LogEntry.occurredAt, Session.createdAt, etc).
  /// Future items use their expected time.
  DateTime get time;

  /// Unique identifier across ALL item types. Uses a type prefix
  /// (e.g., `log:{id}`, `session:{id}`,
  /// `expected-dose:{protocolId}:{timestamp}`) to guarantee uniqueness
  /// when the screen uses this as a list key.
  String get id;

  /// True if this item is in the future relative to DateTime.now()
  /// at the moment of evaluation. The builder sets this at build
  /// time — do NOT recompute in rendering.
  bool get isFuture;
}

/// Past: a LogEntry the user captured.
final class TimelineLogEntry extends TimelineItem {
  final LogEntry entry;

  TimelineLogEntry(this.entry);

  @override
  DateTime get time => entry.occurredAt;

  @override
  String get id => 'log:${entry.id}';

  @override
  bool get isFuture => false;
}

/// Past: a recorded Session.
final class TimelineSession extends TimelineItem {
  final Session session;

  TimelineSession(this.session);

  @override
  DateTime get time => session.createdAt;

  @override
  String get id => 'session:${session.sessionId}';

  @override
  bool get isFuture => false;
}

/// Past: a VitalsBookmark snapshot.
final class TimelineBookmark extends TimelineItem {
  final VitalsBookmark bookmark;

  TimelineBookmark(this.bookmark);

  @override
  DateTime get time => bookmark.timestamp;

  @override
  String get id => 'bookmark:${bookmark.id}';

  @override
  bool get isFuture => false;
}

/// The NOW anchor. Synthetic — not persisted.
/// The builder inserts exactly one of these per build() call.
final class TimelineNowMarker extends TimelineItem {
  @override
  final DateTime time;

  /// Snapshot of active protocols for rendering at NOW.
  final List<ActiveProtocol> activeProtocols;

  TimelineNowMarker({
    required this.time,
    required this.activeProtocols,
  });

  @override
  String get id => 'now-marker';

  @override
  bool get isFuture => false;
}

/// Future: an expected dose from a protocol's timesOfDayMinutes.
/// Omitted by the builder if a matching logged dose exists within
/// the deduplication window.
final class TimelineExpectedDose extends TimelineItem {
  final ActiveProtocol protocol;
  final DateTime expectedTime;

  TimelineExpectedDose({
    required this.protocol,
    required this.expectedTime,
  });

  @override
  DateTime get time => expectedTime;

  @override
  String get id =>
      'expected-dose:${protocol.id}:${expectedTime.millisecondsSinceEpoch}';

  @override
  bool get isFuture => true;
}

/// Future: when the user's current fasting window will end.
/// Only generated if the user is currently in a fasting window.
final class TimelineFastingWindow extends TimelineItem {
  final DateTime endTime;
  final String fastingType;

  TimelineFastingWindow({
    required this.endTime,
    required this.fastingType,
  });

  @override
  DateTime get time => endTime;

  @override
  String get id => 'fasting-end:${endTime.millisecondsSinceEpoch}';

  @override
  bool get isFuture => true;
}

/// Future: a protocol's next cycle day.
/// Generated for non-ongoing protocols where the next day is
/// still within plannedEndDate.
final class TimelineCycleDayMarker extends TimelineItem {
  final ActiveProtocol protocol;
  final DateTime date;
  final int cycleDay;

  TimelineCycleDayMarker({
    required this.protocol,
    required this.date,
    required this.cycleDay,
  });

  @override
  DateTime get time => date;

  @override
  String get id => 'cycle-day:${protocol.id}:$cycleDay';

  @override
  bool get isFuture => true;
}
