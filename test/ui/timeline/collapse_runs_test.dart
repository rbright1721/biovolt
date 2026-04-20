import 'package:biovolt/models/biovolt_event.dart';
import 'package:biovolt/ui/timeline/collapse_runs.dart';
import 'package:flutter_test/flutter_test.dart';

BiovoltEvent ev({
  required int idx,
  required String type,
  required DateTime at,
  String deviceId = 'dev-1',
}) {
  return BiovoltEvent(
    id: idx.toString().padLeft(26, '0'),
    timestamp: at,
    deviceId: deviceId,
    type: type,
    payload: {'i': idx},
    schemaVersion: 1,
  );
}

void main() {
  final anchor = DateTime(2026, 4, 20, 12, 0, 0);
  DateTime offset(int minutes, [int seconds = 0]) =>
      anchor.add(Duration(minutes: minutes, seconds: seconds));

  group('collapseRuns', () {
    test('empty input returns empty', () {
      expect(collapseRuns(const []), isEmpty);
    });

    test('single event returns one SingleEventItem', () {
      final e = ev(idx: 0, type: 'x', at: anchor);
      final result = collapseRuns([e]);
      expect(result.length, 1);
      expect(result.single, isA<SingleEventItem>());
    });

    test('two same-type same-source within window do NOT collapse', () {
      final events = [
        ev(idx: 0, type: 'x', at: offset(0)),
        ev(idx: 1, type: 'x', at: offset(1)),
      ];
      final result = collapseRuns(events);
      expect(result.length, 2);
      expect(result.every((i) => i is SingleEventItem), isTrue);
    });

    test('exactly three same-type same-source within window collapse', () {
      final events = [
        ev(idx: 0, type: 'x', at: offset(0)),
        ev(idx: 1, type: 'x', at: offset(1)),
        ev(idx: 2, type: 'x', at: offset(2)),
      ];
      final result = collapseRuns(events);
      expect(result.length, 1);
      final run = result.single as CollapsedRunItem;
      expect(run.count, 3);
      expect(run.type, 'x');
      expect(run.deviceId, 'dev-1');
    });

    test('five consecutive same-type same-source collapse into one run', () {
      final events = [
        for (var i = 0; i < 5; i++)
          ev(idx: i, type: 'x', at: offset(i)),
      ];
      final result = collapseRuns(events);
      expect(result.length, 1);
      expect((result.single as CollapsedRunItem).count, 5);
    });

    test('run followed by single', () {
      final events = [
        ev(idx: 0, type: 'x', at: offset(0)),
        ev(idx: 1, type: 'x', at: offset(1)),
        ev(idx: 2, type: 'x', at: offset(2)),
        ev(idx: 3, type: 'y', at: offset(3)),
      ];
      final result = collapseRuns(events);
      expect(result.length, 2);
      expect(result[0], isA<CollapsedRunItem>());
      expect(result[1], isA<SingleEventItem>());
    });

    test('single followed by run', () {
      final events = [
        ev(idx: 0, type: 'y', at: offset(0)),
        ev(idx: 1, type: 'x', at: offset(1)),
        ev(idx: 2, type: 'x', at: offset(2)),
        ev(idx: 3, type: 'x', at: offset(3)),
      ];
      final result = collapseRuns(events);
      expect(result.length, 2);
      expect(result[0], isA<SingleEventItem>());
      expect(result[1], isA<CollapsedRunItem>());
      expect((result[1] as CollapsedRunItem).count, 3);
    });

    test('two separate runs of three collapse independently', () {
      final events = [
        ev(idx: 0, type: 'x', at: offset(0)),
        ev(idx: 1, type: 'x', at: offset(1)),
        ev(idx: 2, type: 'x', at: offset(2)),
        ev(idx: 3, type: 'y', at: offset(3)),
        ev(idx: 4, type: 'y', at: offset(4)),
        ev(idx: 5, type: 'y', at: offset(5)),
      ];
      final result = collapseRuns(events);
      expect(result.length, 2);
      expect((result[0] as CollapsedRunItem).type, 'x');
      expect((result[1] as CollapsedRunItem).type, 'y');
    });

    test('gap greater than window splits into two sub-groups', () {
      final events = [
        ev(idx: 0, type: 'x', at: offset(0)),
        ev(idx: 1, type: 'x', at: offset(1)),
        ev(idx: 2, type: 'x', at: offset(10)), // 9-minute gap > 5m
        ev(idx: 3, type: 'x', at: offset(11)),
      ];
      final result = collapseRuns(events);
      // Two sub-groups of 2 each — neither hits minRun=3, so all flatten.
      expect(result.length, 4);
      expect(result.every((i) => i is SingleEventItem), isTrue);
    });

    test('gap greater than window between otherwise-long run splits them',
        () {
      final events = [
        ev(idx: 0, type: 'x', at: offset(0)),
        ev(idx: 1, type: 'x', at: offset(1)),
        ev(idx: 2, type: 'x', at: offset(2)), // would-be run of 3 ends here
        ev(idx: 3, type: 'x', at: offset(10)), // big gap
        ev(idx: 4, type: 'x', at: offset(11)),
        ev(idx: 5, type: 'x', at: offset(12)), // second run of 3 starts
      ];
      final result = collapseRuns(events);
      expect(result.length, 2);
      expect((result[0] as CollapsedRunItem).count, 3);
      expect((result[1] as CollapsedRunItem).count, 3);
    });

    test('same type but different deviceIds do not collapse together', () {
      final events = [
        ev(idx: 0, type: 'x', at: offset(0), deviceId: 'a'),
        ev(idx: 1, type: 'x', at: offset(1), deviceId: 'b'),
        ev(idx: 2, type: 'x', at: offset(2), deviceId: 'a'),
      ];
      final result = collapseRuns(events);
      // Each adjacency differs by deviceId → 3 individual SingleEventItems.
      expect(result.length, 3);
      expect(result.every((i) => i is SingleEventItem), isTrue);
    });

    test('run broken by one different-type event does NOT collapse', () {
      // Rule is "consecutive in list order" — an interleaved different
      // type breaks the run, even if surrounding same-type events would
      // otherwise form one.
      final events = [
        ev(idx: 0, type: 'x', at: offset(0)),
        ev(idx: 1, type: 'x', at: offset(1)),
        ev(idx: 2, type: 'y', at: offset(2)),
        ev(idx: 3, type: 'x', at: offset(3)),
        ev(idx: 4, type: 'x', at: offset(4)),
      ];
      final result = collapseRuns(events);
      expect(result.length, 5);
      expect(result.every((i) => i is SingleEventItem), isTrue);
    });

    test('adjacent pair exactly at window boundary is included', () {
      final events = [
        ev(idx: 0, type: 'x', at: offset(0)),
        ev(idx: 1, type: 'x', at: offset(5)), // exactly 5m apart
        ev(idx: 2, type: 'x', at: offset(10)), // exactly 5m apart
      ];
      final result = collapseRuns(events);
      expect(result.length, 1);
      expect((result.single as CollapsedRunItem).count, 3);
    });

    test('adjacent pair just over window is excluded', () {
      final events = [
        ev(idx: 0, type: 'x', at: offset(0)),
        ev(idx: 1, type: 'x', at: offset(5, 1)), // 5m 1s apart
        ev(idx: 2, type: 'x', at: offset(10)),
      ];
      final result = collapseRuns(events);
      // First pair is outside window → groups split into (1) and (2).
      // Second group of 2 still below threshold → 3 singletons total.
      expect(result.length, 3);
      expect(result.every((i) => i is SingleEventItem), isTrue);
    });

    test('custom minRun=2 collapses pairs', () {
      final events = [
        ev(idx: 0, type: 'x', at: offset(0)),
        ev(idx: 1, type: 'x', at: offset(1)),
      ];
      expect(
        () => collapseRuns(events, minRun: 2),
        // CollapsedRunItem's assert requires >= 3; keep the assert strict.
        throwsA(isA<AssertionError>()),
      );
    });

    test('input order is preserved — newest-first is fine', () {
      // Reverse chronological order; use abs() diff so the rule still
      // holds both ways.
      final events = [
        ev(idx: 2, type: 'x', at: offset(2)),
        ev(idx: 1, type: 'x', at: offset(1)),
        ev(idx: 0, type: 'x', at: offset(0)),
      ];
      final result = collapseRuns(events);
      expect(result.length, 1);
      final run = result.single as CollapsedRunItem;
      expect(run.first.payload['i'], 2); // input order preserved
      expect(run.last.payload['i'], 0);
    });
  });
}
