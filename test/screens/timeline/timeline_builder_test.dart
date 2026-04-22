import 'dart:io';

import 'package:biovolt/models/active_protocol.dart';
import 'package:biovolt/models/log_entry.dart';
import 'package:biovolt/models/session.dart';
import 'package:biovolt/models/user_profile.dart';
import 'package:biovolt/models/vitals_bookmark.dart';
import 'package:biovolt/screens/timeline/timeline_builder.dart';
import 'package:biovolt/screens/timeline/timeline_item.dart';
import 'package:biovolt/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late StorageService storage;

  setUp(() async {
    tempDir =
        Directory.systemTemp.createTempSync('biovolt_timeline_builder_');
    storage = StorageService();
    await storage.initForTest(tempDir.path);
  });

  tearDown(() async {
    await storage.resetForTest();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  // ---------------------------------------------------------------------------
  // Helpers.
  // ---------------------------------------------------------------------------

  /// Fixed clock injection factory.
  TimelineBuilder buildAt(DateTime now) =>
      TimelineBuilder(storage, clock: () => now);

  /// Protocol whose [ActiveProtocol.isOnCycle] evaluates true regardless
  /// of when the test runs. The isOnCycle getter reads real
  /// DateTime.now(), so we anchor to DateTime.now() rather than the
  /// injected clock.
  ActiveProtocol onCycleProtocol({
    required String id,
    String name = 'Test protocol',
    String type = 'peptide',
    int cycleLengthDays = 365,
    List<int>? timesOfDayMinutes,
    bool isOngoing = false,
    DateTime? startDate,
  }) {
    return ActiveProtocol(
      id: id,
      name: name,
      type: type,
      startDate: startDate ?? DateTime.now().subtract(const Duration(days: 1)),
      cycleLengthDays: cycleLengthDays,
      doseMcg: 250,
      route: 'sc',
      isActive: true,
      timesOfDayMinutes: timesOfDayMinutes,
      isOngoingFlag: isOngoing,
    );
  }

  Future<void> seedLog(
    String id,
    DateTime occurredAt, {
    String type = 'note',
    String? protocolIdAtTime,
  }) async {
    await storage.saveLogEntry(LogEntry(
      id: id,
      rawText: id,
      occurredAt: occurredAt,
      loggedAt: occurredAt,
      type: type,
      classificationStatus: 'classified',
      protocolIdAtTime: protocolIdAtTime,
    ));
  }

  Future<void> seedSession(String id, DateTime createdAt) async {
    await storage.saveSession(Session(
      sessionId: id,
      userId: 'test-user',
      createdAt: createdAt,
      timezone: 'UTC',
      dataSources: const [],
    ));
  }

  Future<void> seedBookmark(String id, DateTime timestamp) async {
    await storage.saveBookmark(VitalsBookmark(id: id, timestamp: timestamp));
  }

  Future<void> seedProfile({
    String? fastingType,
    int? eatWindowStartHour,
    int? eatWindowEndHour,
  }) async {
    await storage.saveUserProfile(UserProfile(
      userId: 'test-user',
      createdAt: DateTime.now(),
      healthGoals: const [],
      knownConditions: const [],
      baselineEstablished: false,
      preferredUnits: 'imperial',
      fastingType: fastingType,
      eatWindowStartHour: eatWindowStartHour,
      eatWindowEndHour: eatWindowEndHour,
    ));
  }

  // ---------------------------------------------------------------------------
  // 1. Empty storage returns only NOW marker.
  // ---------------------------------------------------------------------------

  test('empty storage returns only NOW marker', () {
    final now = DateTime(2026, 4, 20, 12);
    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 2)),
    );
    expect(items, hasLength(1));
    expect(items.single, isA<TimelineNowMarker>());
    expect(items.single.time, now);
  });

  // ---------------------------------------------------------------------------
  // 2. Past LogEntry within range appears.
  // ---------------------------------------------------------------------------

  test('past LogEntry within range appears', () async {
    final now = DateTime(2026, 4, 20, 12);
    await seedLog('e1', now.subtract(const Duration(hours: 2)));

    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 2)),
    );
    expect(
      items.whereType<TimelineLogEntry>().map((t) => t.entry.id).toList(),
      ['e1'],
    );
  });

  // ---------------------------------------------------------------------------
  // 3. Past LogEntry outside range is excluded.
  // ---------------------------------------------------------------------------

  test('past LogEntry outside range is excluded', () async {
    final now = DateTime(2026, 4, 20, 12);
    await seedLog('e_old', now.subtract(const Duration(days: 30)));

    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 2)),
    );
    expect(items.whereType<TimelineLogEntry>(), isEmpty);
  });

  // ---------------------------------------------------------------------------
  // 4. Session and Bookmark both appear in past.
  // ---------------------------------------------------------------------------

  test('session and bookmark both appear in past', () async {
    final now = DateTime(2026, 4, 20, 12);
    await seedSession('s1', now.subtract(const Duration(hours: 3)));
    await seedBookmark('b1', now.subtract(const Duration(hours: 4)));

    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 2)),
    );
    expect(items.whereType<TimelineSession>(), hasLength(1));
    expect(items.whereType<TimelineBookmark>(), hasLength(1));
  });

  // ---------------------------------------------------------------------------
  // 5. Sort order: DESC by time.
  // ---------------------------------------------------------------------------

  test('items sorted DESC by time', () async {
    final now = DateTime(2026, 4, 20, 12);
    await seedLog('a', now.subtract(const Duration(hours: 3)));
    await seedLog('b', now.subtract(const Duration(hours: 1)));
    await seedLog('c', now.subtract(const Duration(hours: 2)));

    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 2)),
    );
    final logs =
        items.whereType<TimelineLogEntry>().map((t) => t.entry.id).toList();
    expect(logs, ['b', 'c', 'a']);
  });

  // ---------------------------------------------------------------------------
  // 6. NOW marker placed correctly among items.
  // ---------------------------------------------------------------------------

  test('NOW marker placed between past and future', () async {
    // Build at 12:00 with timesOfDayMinutes = [13*60] (1pm) to get a
    // future expected-dose at +1h. Also seed a past log at -1h.
    final now = DateTime(2026, 4, 20, 12);
    final protocol = onCycleProtocol(
      id: 'p1',
      timesOfDayMinutes: [13 * 60], // 1pm
    );
    await storage.saveActiveProtocol(protocol);
    await seedLog('past-log', now.subtract(const Duration(hours: 1)));

    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 2)),
    );

    final kinds = items.map((i) => i.runtimeType.toString()).toList();
    final nowIdx = kinds.indexOf('TimelineNowMarker');
    final expectedIdx = items.indexWhere((i) => i is TimelineExpectedDose);
    final logIdx = items.indexWhere((i) => i is TimelineLogEntry);

    expect(nowIdx, isNonNegative);
    expect(expectedIdx, isNonNegative);
    expect(logIdx, isNonNegative);
    // DESC: future first, then NOW, then past.
    expect(expectedIdx < nowIdx, isTrue);
    expect(nowIdx < logIdx, isTrue);
  });

  // ---------------------------------------------------------------------------
  // 7. Active protocol with timesOfDayMinutes generates expected doses.
  // ---------------------------------------------------------------------------

  test('protocol with timesOfDayMinutes generates expected doses',
      () async {
    final now = DateTime(2026, 4, 20, 12); // noon today
    final protocol = onCycleProtocol(
      id: 'p1',
      timesOfDayMinutes: [420, 1200], // 7am, 8pm
    );
    await storage.saveActiveProtocol(protocol);

    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 2)),
    );
    final doses = items.whereType<TimelineExpectedDose>().toList();
    // Today 7am is past → skipped.
    // Today 8pm, tomorrow 7am, tomorrow 8pm expected.
    expect(doses, hasLength(3));
    final doseTimes = doses.map((d) => d.expectedTime).toSet();
    expect(doseTimes, contains(DateTime(2026, 4, 20, 20)));
    expect(doseTimes, contains(DateTime(2026, 4, 21, 7)));
    expect(doseTimes, contains(DateTime(2026, 4, 21, 20)));
  });

  // ---------------------------------------------------------------------------
  // 8. Expected dose deduplicated by logged dose in window.
  // ---------------------------------------------------------------------------

  test('expected dose deduplicated by matching logged dose', () async {
    final now = DateTime(2026, 4, 20, 12);
    final protocol = onCycleProtocol(
      id: 'p1',
      timesOfDayMinutes: [420, 1200],
    );
    await storage.saveActiveProtocol(protocol);
    // Logged dose at 8:15pm today — within ±90min of 8pm expected.
    await seedLog(
      'logged-dose',
      DateTime(2026, 4, 20, 20, 15),
      type: 'dose',
      protocolIdAtTime: 'p1',
    );

    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 2)),
    );
    final doses = items.whereType<TimelineExpectedDose>().toList();
    expect(doses, hasLength(2));
    final times = doses.map((d) => d.expectedTime).toSet();
    expect(times, isNot(contains(DateTime(2026, 4, 20, 20))));
    expect(times, contains(DateTime(2026, 4, 21, 7)));
    expect(times, contains(DateTime(2026, 4, 21, 20)));
  });

  // ---------------------------------------------------------------------------
  // 9. Dedup only matches when protocolIdAtTime matches.
  // ---------------------------------------------------------------------------

  test('dedup does not match different protocol', () async {
    final now = DateTime(2026, 4, 20, 12);
    final protoA = onCycleProtocol(id: 'A', timesOfDayMinutes: [1200]);
    await storage.saveActiveProtocol(protoA);
    await seedLog(
      'b-dose',
      DateTime(2026, 4, 20, 20),
      type: 'dose',
      protocolIdAtTime: 'B',
    );

    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 2)),
    );
    final aDoses = items
        .whereType<TimelineExpectedDose>()
        .where((d) => d.protocol.id == 'A')
        .toList();
    // Should still include today 8pm for A.
    expect(
      aDoses.map((d) => d.expectedTime),
      contains(DateTime(2026, 4, 20, 20)),
    );
  });

  // ---------------------------------------------------------------------------
  // 10. Dedup only matches when log type is 'dose'.
  // ---------------------------------------------------------------------------

  test('dedup does not match non-dose log type', () async {
    final now = DateTime(2026, 4, 20, 12);
    final proto = onCycleProtocol(id: 'p1', timesOfDayMinutes: [1200]);
    await storage.saveActiveProtocol(proto);
    await seedLog(
      'meal',
      DateTime(2026, 4, 20, 20),
      type: 'meal',
      protocolIdAtTime: 'p1',
    );

    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 2)),
    );
    final doses = items.whereType<TimelineExpectedDose>().toList();
    expect(
      doses.map((d) => d.expectedTime),
      contains(DateTime(2026, 4, 20, 20)),
    );
  });

  // ---------------------------------------------------------------------------
  // 11. Protocol without timesOfDayMinutes generates no expected doses.
  // ---------------------------------------------------------------------------

  test('protocol with null timesOfDayMinutes generates no doses',
      () async {
    final now = DateTime(2026, 4, 20, 12);
    final proto = onCycleProtocol(id: 'p1', timesOfDayMinutes: null);
    await storage.saveActiveProtocol(proto);

    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 2)),
    );
    expect(items.whereType<TimelineExpectedDose>(), isEmpty);
  });

  // ---------------------------------------------------------------------------
  // 12. Protocol with empty timesOfDayMinutes generates no expected doses.
  // ---------------------------------------------------------------------------

  test('protocol with empty timesOfDayMinutes generates no doses',
      () async {
    final now = DateTime(2026, 4, 20, 12);
    final proto = onCycleProtocol(id: 'p1', timesOfDayMinutes: const []);
    await storage.saveActiveProtocol(proto);

    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 2)),
    );
    expect(items.whereType<TimelineExpectedDose>(), isEmpty);
  });

  // ---------------------------------------------------------------------------
  // 13. Fasting window generated when inside window.
  // ---------------------------------------------------------------------------

  test('fasting window generated when currently fasting (pre-eating)',
      () async {
    final now = DateTime(2026, 4, 20, 9); // 9am, before 12pm
    await seedProfile(
      fastingType: '16:8',
      eatWindowStartHour: 12,
      eatWindowEndHour: 20,
    );
    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 2)),
    );
    final fast = items.whereType<TimelineFastingWindow>().toList();
    expect(fast, hasLength(1));
    expect(fast.single.endTime, DateTime(2026, 4, 20, 12));
    expect(fast.single.fastingType, '16:8');
  });

  // ---------------------------------------------------------------------------
  // 14. Fasting window NOT generated when inside eating window.
  // ---------------------------------------------------------------------------

  test('fasting window not generated when in eating window', () async {
    final now = DateTime(2026, 4, 20, 15); // 3pm inside 12-20
    await seedProfile(
      fastingType: '16:8',
      eatWindowStartHour: 12,
      eatWindowEndHour: 20,
    );
    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 2)),
    );
    expect(items.whereType<TimelineFastingWindow>(), isEmpty);
  });

  // ---------------------------------------------------------------------------
  // 15. Fasting window after eating window rolls to tomorrow.
  // ---------------------------------------------------------------------------

  test('fasting window rolls to tomorrow after eating window closes',
      () async {
    final now = DateTime(2026, 4, 20, 22); // 10pm, after 8pm close
    await seedProfile(
      fastingType: '16:8',
      eatWindowStartHour: 12,
      eatWindowEndHour: 20,
    );
    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 2)),
    );
    final fast = items.whereType<TimelineFastingWindow>().toList();
    expect(fast, hasLength(1));
    expect(fast.single.endTime, DateTime(2026, 4, 21, 12));
  });

  // ---------------------------------------------------------------------------
  // 16. Fasting window not generated when fastingType is null or 'none'.
  // ---------------------------------------------------------------------------

  test('fasting window not generated when fastingType is null', () async {
    final now = DateTime(2026, 4, 20, 9);
    await seedProfile(
      fastingType: null,
      eatWindowStartHour: 12,
      eatWindowEndHour: 20,
    );
    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 2)),
    );
    expect(items.whereType<TimelineFastingWindow>(), isEmpty);
  });

  test("fasting window not generated when fastingType is 'none'",
      () async {
    final now = DateTime(2026, 4, 20, 9);
    await seedProfile(
      fastingType: 'none',
      eatWindowStartHour: 12,
      eatWindowEndHour: 20,
    );
    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 2)),
    );
    expect(items.whereType<TimelineFastingWindow>(), isEmpty);
  });

  // ---------------------------------------------------------------------------
  // 17. Cycle day marker generated for non-ongoing protocol.
  // ---------------------------------------------------------------------------

  test('cycle day marker generated for non-ongoing protocol', () async {
    // Anchor clock to real DateTime.now() because ActiveProtocol's
    // currentCycleDay / isOnCycle use real DateTime.now().
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 4));
    final proto = onCycleProtocol(
      id: 'p1',
      cycleLengthDays: 30,
      isOngoing: false,
      startDate: startDate,
    );
    await storage.saveActiveProtocol(proto);

    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 14)),
    );
    final markers = items.whereType<TimelineCycleDayMarker>().toList();
    expect(markers, hasLength(1));
    final todayMid = DateTime(now.year, now.month, now.day);
    final tomorrowMid = todayMid.add(const Duration(days: 1));
    expect(markers.single.date, tomorrowMid);
    expect(markers.single.cycleDay, proto.currentCycleDay + 1);
  });

  // ---------------------------------------------------------------------------
  // 18. Cycle day marker NOT generated for ongoing protocol.
  // ---------------------------------------------------------------------------

  test('cycle day marker not generated for ongoing protocol', () async {
    final now = DateTime.now();
    final proto = onCycleProtocol(
      id: 'p1',
      cycleLengthDays: 30,
      isOngoing: true,
    );
    await storage.saveActiveProtocol(proto);

    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 14)),
    );
    expect(items.whereType<TimelineCycleDayMarker>(), isEmpty);
  });

  // ---------------------------------------------------------------------------
  // 19. Cycle day marker NOT generated when tomorrow is past plannedEndDate.
  // ---------------------------------------------------------------------------

  test(
      'cycle day marker not generated when tomorrow is past plannedEndDate',
      () async {
    final now = DateTime.now();
    // plannedEndDate = startDate + 1 day  →  today (or very close).
    // Tomorrow midnight will be past it.
    final startDate = now.subtract(const Duration(days: 1));
    final proto = onCycleProtocol(
      id: 'p1',
      cycleLengthDays: 1,
      isOngoing: false,
      startDate: startDate,
    );
    await storage.saveActiveProtocol(proto);

    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 14)),
    );
    expect(items.whereType<TimelineCycleDayMarker>(), isEmpty);
  });

  // ---------------------------------------------------------------------------
  // 20. NOW marker includes active protocols snapshot.
  // ---------------------------------------------------------------------------

  test('NOW marker includes active protocols snapshot', () async {
    final now = DateTime.now();
    final ongoing = onCycleProtocol(
      id: 'ongoing',
      cycleLengthDays: 365,
      isOngoing: true,
    );
    final oncycle = onCycleProtocol(
      id: 'oncycle',
      cycleLengthDays: 30,
      isOngoing: false,
    );
    await storage.saveActiveProtocol(ongoing);
    await storage.saveActiveProtocol(oncycle);

    final items = buildAt(now).build(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: now.add(const Duration(days: 2)),
    );
    final marker = items.whereType<TimelineNowMarker>().single;
    final ids = marker.activeProtocols.map((p) => p.id).toSet();
    expect(ids, containsAll(<String>['ongoing', 'oncycle']));
  });

  // ---------------------------------------------------------------------------
  // 21. Stable sort on tied timestamps.
  // ---------------------------------------------------------------------------

  test('stable order when log entries share a timestamp', () async {
    final now = DateTime(2026, 4, 20, 12);
    final tied = now.subtract(const Duration(hours: 1));
    await seedLog('a', tied);
    await seedLog('b', tied);

    final first = buildAt(now)
        .build(
          rangeStart: now.subtract(const Duration(days: 1)),
          rangeEnd: now.add(const Duration(days: 1)),
        )
        .whereType<TimelineLogEntry>()
        .map((t) => t.entry.id)
        .toList();
    final second = buildAt(now)
        .build(
          rangeStart: now.subtract(const Duration(days: 1)),
          rangeEnd: now.add(const Duration(days: 1)),
        )
        .whereType<TimelineLogEntry>()
        .map((t) => t.entry.id)
        .toList();
    expect(first, second);
    // And ids appear in deterministic order (alphabetical by id).
    expect(first, ['a', 'b']);
  });

  // ---------------------------------------------------------------------------
  // 22. Clock injection works.
  // ---------------------------------------------------------------------------

  test('clock injection is used in place of DateTime.now()', () {
    final fixed = DateTime(2026, 4, 20, 12);
    final builder = TimelineBuilder(storage, clock: () => fixed);
    final first = builder.build(
      rangeStart: fixed.subtract(const Duration(days: 1)),
      rangeEnd: fixed.add(const Duration(days: 1)),
    );
    final second = builder.build(
      rangeStart: fixed.subtract(const Duration(days: 1)),
      rangeEnd: fixed.add(const Duration(days: 1)),
    );
    expect(first.whereType<TimelineNowMarker>().single.time, fixed);
    expect(second.whereType<TimelineNowMarker>().single.time, fixed);
  });
}
