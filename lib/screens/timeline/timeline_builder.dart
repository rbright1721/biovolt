import '../../models/active_protocol.dart';
import '../../services/storage_service.dart';
import 'timeline_item.dart';

/// Pure builder that assembles a NOW-anchored timeline from storage.
///
/// The builder is a read-only consumer of [StorageService]. It never
/// mutates state; calls are safe to make repeatedly (e.g. from a
/// reactive UI) without side effects.
class TimelineBuilder {
  final StorageService _storage;

  /// If provided, used in place of DateTime.now() for deterministic
  /// tests. Production always omits this.
  final DateTime Function()? _clock;

  TimelineBuilder(this._storage, {DateTime Function()? clock})
      : _clock = clock;

  DateTime _now() => _clock?.call() ?? DateTime.now();

  /// The spec uses the semantic "on-cycle protocols" — the actual
  /// StorageService API exposes [StorageService.getAllActiveProtocols]
  /// plus the [ActiveProtocol.isOnCycle] getter. Composing those two
  /// at the builder is the agreed resolution (the alternative would
  /// be extending StorageService, which Session 1 is not allowed to
  /// do). Cached once per build() call — used for NOW marker,
  /// expected-dose generation, and cycle-day marker generation.
  List<ActiveProtocol> _getOnCycleProtocols() {
    return _storage
        .getAllActiveProtocols()
        .where((p) => p.isOnCycle)
        .toList();
  }

  /// Build a timeline for the given range.
  ///
  /// [rangeStart] — earliest past item to include (inclusive).
  /// [rangeEnd]   — latest future item to include (inclusive).
  ///
  /// Returns items sorted DESC by time. The NOW marker sits at its
  /// actual position in the sort (between future and past). Items at
  /// exactly the same time have stable order via id tie-break.
  List<TimelineItem> build({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final now = _now();
    final onCycle = _getOnCycleProtocols();
    final items = <TimelineItem>[];

    // ═══ Past items ═══
    _addPastLogEntries(items, rangeStart, now);
    _addPastSessions(items, rangeStart, now);
    _addPastBookmarks(items, rangeStart, now);

    // ═══ NOW marker ═══
    items.add(TimelineNowMarker(
      time: now,
      activeProtocols: onCycle,
    ));

    // ═══ Future items ═══
    _addFutureExpectedDoses(items, now, rangeEnd, onCycle);
    _addFutureFastingWindow(items, now);
    _addFutureCycleDayMarkers(items, now, rangeEnd, onCycle);

    // ═══ Sort DESC, stable ═══
    items.sort((a, b) {
      final cmp = b.time.compareTo(a.time);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });

    return items;
  }

  // ---------------------------------------------------------------------------
  // Past
  // ---------------------------------------------------------------------------

  void _addPastLogEntries(
    List<TimelineItem> items,
    DateTime rangeStart,
    DateTime now,
  ) {
    final entries = _storage.getLogEntriesInRange(rangeStart, now);
    for (final e in entries) {
      items.add(TimelineLogEntry(e));
    }
  }

  void _addPastSessions(
    List<TimelineItem> items,
    DateTime rangeStart,
    DateTime now,
  ) {
    final sessions = _storage.getSessionsInRange(rangeStart, now);
    for (final s in sessions) {
      items.add(TimelineSession(s));
    }
  }

  void _addPastBookmarks(
    List<TimelineItem> items,
    DateTime rangeStart,
    DateTime now,
  ) {
    final bookmarks = _storage.getBookmarksInRange(rangeStart, now);
    for (final b in bookmarks) {
      items.add(TimelineBookmark(b));
    }
  }

  // ---------------------------------------------------------------------------
  // Future — expected doses
  // ---------------------------------------------------------------------------

  void _addFutureExpectedDoses(
    List<TimelineItem> items,
    DateTime now,
    DateTime rangeEnd,
    List<ActiveProtocol> onCycle,
  ) {
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final tomorrowMidnight = todayMidnight.add(const Duration(days: 1));

    for (final protocol in onCycle) {
      final times = protocol.timesOfDayMinutes;
      if (times == null || times.isEmpty) continue;

      for (final minute in times) {
        for (final dayStart in [todayMidnight, tomorrowMidnight]) {
          final expectedTime =
              dayStart.add(Duration(minutes: minute));
          if (!expectedTime.isAfter(now)) continue; // in past
          if (expectedTime.isAfter(rangeEnd)) continue;
          if (_hasMatchingLoggedDose(
            protocolId: protocol.id,
            expectedTime: expectedTime,
          )) {
            continue;
          }
          items.add(TimelineExpectedDose(
            protocol: protocol,
            expectedTime: expectedTime,
          ));
        }
      }
    }
  }

  bool _hasMatchingLoggedDose({
    required String protocolId,
    required DateTime expectedTime,
  }) {
    const window = Duration(minutes: 90);
    final windowStart = expectedTime.subtract(window);
    final windowEnd = expectedTime.add(window);
    final logs = _storage.getLogEntriesInRange(windowStart, windowEnd);
    for (final log in logs) {
      if (log.type == 'dose' && log.protocolIdAtTime == protocolId) {
        return true;
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Future — fasting window
  // ---------------------------------------------------------------------------

  void _addFutureFastingWindow(
    List<TimelineItem> items,
    DateTime now,
  ) {
    final profile = _storage.getUserProfile();
    if (profile == null) return;

    final fastingType = profile.fastingType;
    if (fastingType == null || fastingType == 'none') return;

    final eatStart = profile.eatWindowStartHour;
    final eatEnd = profile.eatWindowEndHour;
    if (eatStart == null) return;

    final todayMidnight = DateTime(now.year, now.month, now.day);
    final currentHourDecimal =
        now.hour + now.minute / 60.0 + now.second / 3600.0;

    // The eating window is [eatStart, eatEnd). Everything else is fasting.
    // If eatEnd is null, we treat any time before eatStart today as fasting
    // (the fast will end at eatStart today); anything at or after eatStart
    // today has no knowable next-fast-end.
    DateTime fastEndTime;
    if (eatEnd == null) {
      if (currentHourDecimal < eatStart) {
        fastEndTime = todayMidnight.add(Duration(hours: eatStart));
      } else {
        return;
      }
    } else {
      final inEatingWindow =
          currentHourDecimal >= eatStart && currentHourDecimal < eatEnd;
      if (inEatingWindow) return;

      if (currentHourDecimal < eatStart) {
        fastEndTime = todayMidnight.add(Duration(hours: eatStart));
      } else {
        // currentHourDecimal >= eatEnd → fast ends tomorrow at eatStart
        fastEndTime = todayMidnight
            .add(const Duration(days: 1))
            .add(Duration(hours: eatStart));
      }
    }

    items.add(TimelineFastingWindow(
      endTime: fastEndTime,
      fastingType: fastingType,
    ));
  }

  // ---------------------------------------------------------------------------
  // Future — cycle day markers
  // ---------------------------------------------------------------------------

  void _addFutureCycleDayMarkers(
    List<TimelineItem> items,
    DateTime now,
    DateTime rangeEnd,
    List<ActiveProtocol> onCycle,
  ) {
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final tomorrowMidnight = todayMidnight.add(const Duration(days: 1));

    for (final protocol in onCycle) {
      if (protocol.isOngoing) continue;
      if (tomorrowMidnight.isAfter(rangeEnd)) continue;
      final plannedEnd = protocol.plannedEndDate;
      if (plannedEnd != null && tomorrowMidnight.isAfter(plannedEnd)) {
        continue;
      }
      final nextCycleDay = protocol.currentCycleDay + 1;
      items.add(TimelineCycleDayMarker(
        protocol: protocol,
        date: tomorrowMidnight,
        cycleDay: nextCycleDay,
      ));
    }
  }
}
