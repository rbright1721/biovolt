import '../../models/biovolt_event.dart';

/// A rendered item in the timeline list — either a single event row or a
/// collapsed run of same-type same-source events that the UI can expand
/// on tap.
sealed class TimelineItem {
  const TimelineItem();
}

/// A single event rendered as one row.
class SingleEventItem extends TimelineItem {
  const SingleEventItem(this.event);
  final BiovoltEvent event;
}

/// A run of [minRun] or more consecutive (in input order) events with the
/// same [BiovoltEvent.type] and [BiovoltEvent.deviceId], where each
/// adjacent pair's timestamps are within [collapseRuns]'s `window`.
class CollapsedRunItem extends TimelineItem {
  CollapsedRunItem(this.events)
      : assert(events.length >= 3,
            'CollapsedRunItem requires at least 3 events');

  final List<BiovoltEvent> events;

  BiovoltEvent get first => events.first;
  BiovoltEvent get last => events.last;
  int get count => events.length;
  String get type => first.type;
  String get deviceId => first.deviceId;
}

/// Group consecutive same-type same-source events whose adjacent
/// timestamps are within [window] into [CollapsedRunItem]s when the run
/// is at least [minRun] long. Shorter clusters are flattened back into
/// individual [SingleEventItem]s.
///
/// Input [events] is assumed to be in the display order the caller wants
/// — this function does not sort. For a "newest-first" timeline, sort
/// newest-first before calling. The 5-minute window comparison uses the
/// absolute difference between adjacent timestamps so the same rules
/// apply in either direction.
List<TimelineItem> collapseRuns(
  List<BiovoltEvent> events, {
  Duration window = const Duration(minutes: 5),
  int minRun = 3,
}) {
  if (events.isEmpty) return const [];

  final result = <TimelineItem>[];
  var runStart = 0;

  bool adjacentInRun(BiovoltEvent a, BiovoltEvent b) {
    if (a.type != b.type) return false;
    if (a.deviceId != b.deviceId) return false;
    final diff = a.timestamp.difference(b.timestamp).abs();
    return diff <= window;
  }

  void flush(int endExclusive) {
    final runLength = endExclusive - runStart;
    if (runLength >= minRun) {
      result.add(CollapsedRunItem(events.sublist(runStart, endExclusive)));
    } else {
      for (var i = runStart; i < endExclusive; i++) {
        result.add(SingleEventItem(events[i]));
      }
    }
  }

  for (var i = 1; i < events.length; i++) {
    if (!adjacentInRun(events[i - 1], events[i])) {
      flush(i);
      runStart = i;
    }
  }
  flush(events.length);
  return result;
}
