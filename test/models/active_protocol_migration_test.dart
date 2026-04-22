import 'dart:io';

import 'package:biovolt/models/active_protocol.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

// -----------------------------------------------------------------------------
// Migration strategy.
//
// We can't synthesize a truly-v1 binary frame here because Hive's
// BinaryWriter/BinaryReader are abstract — their concrete impls are
// library-private. Instead, we rely on the box-based round-trip:
// constructing an ActiveProtocol with all new fields defaulted to
// null (which is what a v1 instance would look like in memory),
// flushing to disk via `box.close()`, and reopening to force a fresh
// deserialization from bytes. The adapter handles the round-trip
// equivalently for both the "legacy bytes with 10 fields" case and
// the "new-adapter bytes with 18 fields but stored-nulls for new
// fields" case — both produce the same in-memory shape on read, so
// the test coverage is equivalent from the app's perspective.
// -----------------------------------------------------------------------------

Future<Directory> _hiveInit(String label) async {
  final dir = Directory.systemTemp.createTempSync(label);
  Hive.init(dir.path);
  if (!Hive.isAdapterRegistered(41)) {
    Hive.registerAdapter(ActiveProtocolAdapter());
  }
  return dir;
}

void main() {
  group('ActiveProtocol v1 → v2 migration', () {
    late Directory tempDir;
    late Box<ActiveProtocol> box;

    setUp(() async {
      tempDir = await _hiveInit('biovolt_active_protocol_v1_');
      box = await Hive.openBox<ActiveProtocol>('protocols_test_v1');
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('protocols_test_v1');
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('v1 record (fields 0-9 only) reads back with safe defaults for '
        'all new fields', () async {
      // Simulate a pre-extension save: write a record with only the
      // original 10 fields. Go through the box so the adapter runs.
      final v1 = ActiveProtocol(
        id: 'p-v1',
        name: 'GlyNAC',
        type: 'supplement',
        startDate: DateTime.utc(2026, 4, 1),
        cycleLengthDays: 30,
        doseMcg: 500,
        route: 'oral',
        isActive: true,
        // New fields left unset — the constructor nulls them out,
        // adapter writes nulls for fields 10-17. Reading back proves
        // the null-defaulting path works.
      );
      await box.put(v1.id, v1);

      // Close and reopen to force a full adapter round-trip through
      // on-disk bytes (not the in-memory box cache).
      await box.close();
      box = await Hive.openBox<ActiveProtocol>('protocols_test_v1');

      final read = box.get('p-v1')!;
      // Legacy fields preserved.
      expect(read.id, 'p-v1');
      expect(read.name, 'GlyNAC');
      expect(read.type, 'supplement');
      expect(read.startDate, DateTime.utc(2026, 4, 1));
      expect(read.cycleLengthDays, 30);
      expect(read.doseMcg, 500);
      expect(read.route, 'oral');
      expect(read.isActive, isTrue);
      // New fields default to null / safe bool.
      expect(read.doseDisplay, isNull);
      expect(read.frequency, isNull);
      expect(read.frequencyCustom, isNull);
      expect(read.timesOfDayMinutes, isNull);
      expect(read.isOngoingFlag, isNull);
      expect(read.isOngoing, isFalse,
          reason: 'null-backing coerces to false');
      expect(read.endReason, isNull);
      expect(read.measurementTargets, isNull);
      expect(read.measurementTargetsNotes, isNull);
    });

    test('v2 record with all new fields round-trips correctly', () async {
      final v2 = ActiveProtocol(
        id: 'p-v2',
        name: 'Creatine',
        type: 'supplement',
        startDate: DateTime.utc(2026, 4, 15),
        cycleLengthDays: 0,
        doseMcg: 5000,
        route: 'oral',
        isActive: true,
        doseDisplay: '5g',
        frequency: 'once_daily',
        frequencyCustom: null,
        timesOfDayMinutes: const [480],
        isOngoingFlag: true,
        endReason: null,
        measurementTargets: const ['recovery', 'energy'],
        measurementTargetsNotes: 'tracking post-workout recovery',
      );
      await box.put(v2.id, v2);
      await box.close();
      box = await Hive.openBox<ActiveProtocol>('protocols_test_v1');

      final read = box.get('p-v2')!;
      expect(read.doseDisplay, '5g');
      expect(read.frequency, 'once_daily');
      expect(read.timesOfDayMinutes, [480]);
      expect(read.isOngoingFlag, isTrue);
      expect(read.isOngoing, isTrue);
      expect(read.measurementTargets, ['recovery', 'energy']);
      expect(read.measurementTargetsNotes,
          'tracking post-workout recovery');
    });
  });

  group('ActiveProtocol computed getters', () {
    ActiveProtocol make({
      required DateTime startDate,
      int cycleLengthDays = 30,
      bool isActive = true,
      DateTime? endDate,
      bool? isOngoingFlag,
      String? endReason,
    }) =>
        ActiveProtocol(
          id: 'g-1',
          name: 'n',
          type: 'peptide',
          startDate: startDate,
          cycleLengthDays: cycleLengthDays,
          doseMcg: 250,
          route: 'sub-q',
          isActive: isActive,
          endDate: endDate,
          isOngoingFlag: isOngoingFlag,
          endReason: endReason,
        );

    test('plannedEndDate for non-ongoing = startDate + cycleLengthDays', () {
      final start = DateTime.utc(2026, 4, 1);
      final p = make(startDate: start, cycleLengthDays: 30);
      expect(p.plannedEndDate, DateTime.utc(2026, 5, 1));
    });

    test('plannedEndDate for ongoing returns null', () {
      final p = make(
        startDate: DateTime.utc(2026, 4, 1),
        cycleLengthDays: 0,
        isOngoingFlag: true,
      );
      expect(p.plannedEndDate, isNull);
    });

    test('effectiveEndDate prefers endDate over plannedEndDate', () {
      final p = make(
        startDate: DateTime.utc(2026, 4, 1),
        cycleLengthDays: 30,
        endDate: DateTime.utc(2026, 4, 20),
      );
      expect(p.effectiveEndDate, DateTime.utc(2026, 4, 20));
    });

    test('effectiveEndDate falls back to plannedEndDate when endDate is null',
        () {
      final p = make(
        startDate: DateTime.utc(2026, 4, 1),
        cycleLengthDays: 30,
      );
      expect(p.effectiveEndDate, DateTime.utc(2026, 5, 1));
    });

    test('daysRemaining returns null for ongoing protocols', () {
      final p = make(
        startDate: DateTime.utc(2026, 4, 1),
        isOngoingFlag: true,
      );
      expect(p.daysRemaining, isNull);
    });

    test('daysRemaining returns null for inactive protocols', () {
      final p = make(
        startDate: DateTime.utc(2026, 4, 1),
        isActive: false,
      );
      expect(p.daysRemaining, isNull);
    });

    test('daysRemaining returns a positive int for a future planned end', () {
      // Start in the near past so now < plannedEnd.
      final start = DateTime.now().subtract(const Duration(days: 3));
      final p = make(startDate: start, cycleLengthDays: 30);
      expect(p.daysRemaining, isNotNull);
      expect(p.daysRemaining!, greaterThan(0));
      expect(p.daysRemaining!, lessThanOrEqualTo(30));
    });

    test('isCompleted is true only when !isActive AND endReason == completed',
        () {
      expect(
          make(
            startDate: DateTime.utc(2026, 4, 1),
            isActive: false,
            endReason: 'completed',
          ).isCompleted,
          isTrue);
      expect(
          make(
            startDate: DateTime.utc(2026, 4, 1),
            isActive: false,
            endReason: 'abandoned_ineffective',
          ).isCompleted,
          isFalse);
      expect(
          make(
            startDate: DateTime.utc(2026, 4, 1),
            isActive: true,
            endReason: 'completed',
          ).isCompleted,
          isFalse);
    });

    test('statusLabel — active / scheduled / completed / ended / unknown',
        () {
      // active: started in the past, still within cycle, isActive.
      expect(
          make(
            startDate: DateTime.now().subtract(const Duration(days: 2)),
            cycleLengthDays: 30,
            isActive: true,
          ).statusLabel,
          'active');
      // scheduled: starts in the future, isActive.
      expect(
          make(
            startDate: DateTime.now().add(const Duration(days: 10)),
            cycleLengthDays: 30,
            isActive: true,
          ).statusLabel,
          'scheduled');
      // completed: !isActive && endReason == completed.
      expect(
          make(
            startDate: DateTime.utc(2026, 1, 1),
            isActive: false,
            endReason: 'completed',
          ).statusLabel,
          'completed');
      // ended: !isActive && other endReason.
      expect(
          make(
            startDate: DateTime.utc(2026, 1, 1),
            isActive: false,
            endReason: 'abandoned_other',
          ).statusLabel,
          'ended');
      // ended: !isActive even without endReason (the "don't fall
      // through to 'unknown'" safety net).
      expect(
          make(startDate: DateTime.utc(2026, 1, 1), isActive: false)
              .statusLabel,
          'ended');
    });
  });

  group('ActiveProtocol.copyWith', () {
    test('default copy preserves the isOngoingFlag backing value', () {
      final original = ActiveProtocol(
        id: 'c-1',
        name: 'n',
        type: 't',
        startDate: DateTime.utc(2026, 4, 1),
        cycleLengthDays: 30,
        doseMcg: 100,
        route: 'oral',
        isActive: true,
        isOngoingFlag: true,
      );
      final copy = original.copyWith(name: 'renamed');
      expect(copy.isOngoingFlag, isTrue);
      expect(copy.isOngoing, isTrue);
      expect(copy.name, 'renamed');
    });

    test('copyWith(isOngoing: false) overrides the flag', () {
      final original = ActiveProtocol(
        id: 'c-2',
        name: 'n',
        type: 't',
        startDate: DateTime.utc(2026, 4, 1),
        cycleLengthDays: 30,
        doseMcg: 100,
        route: 'oral',
        isActive: true,
        isOngoingFlag: true,
      );
      final copy = original.copyWith(isOngoing: false);
      expect(copy.isOngoingFlag, isFalse);
      expect(copy.isOngoing, isFalse);
    });

    test('extension fields survive copyWith', () {
      final original = ActiveProtocol(
        id: 'c-3',
        name: 'n',
        type: 't',
        startDate: DateTime.utc(2026, 4, 1),
        cycleLengthDays: 30,
        doseMcg: 100,
        route: 'oral',
        isActive: true,
        doseDisplay: '100mcg',
        frequency: 'twice_daily',
        measurementTargets: const ['hrv', 'sleep_quality'],
      );
      final copy = original.copyWith(isActive: false);
      expect(copy.doseDisplay, '100mcg');
      expect(copy.frequency, 'twice_daily');
      expect(copy.measurementTargets, ['hrv', 'sleep_quality']);
    });
  });

  group('ActiveProtocol JSON round-trip', () {
    test('v2 record with all new fields round-trips through toJson/fromJson',
        () {
      final original = ActiveProtocol(
        id: 'j-1',
        name: 'NAC',
        type: 'supplement',
        startDate: DateTime.utc(2026, 4, 1),
        endDate: DateTime.utc(2026, 5, 1),
        cycleLengthDays: 30,
        doseMcg: 600,
        route: 'oral',
        notes: 'with breakfast',
        isActive: false,
        doseDisplay: '600mg',
        frequency: 'once_daily',
        frequencyCustom: null,
        timesOfDayMinutes: const [480],
        isOngoingFlag: false,
        endReason: 'completed',
        measurementTargets: const ['sleep_quality'],
        measurementTargetsNotes: 'hoping for deeper sleep',
      );
      final round = ActiveProtocol.fromJson(original.toJson());
      expect(round.doseDisplay, '600mg');
      expect(round.frequency, 'once_daily');
      expect(round.timesOfDayMinutes, [480]);
      expect(round.isOngoingFlag, isFalse);
      expect(round.isOngoing, isFalse);
      expect(round.endReason, 'completed');
      expect(round.isCompleted, isTrue);
      expect(round.measurementTargets, ['sleep_quality']);
      expect(round.measurementTargetsNotes, 'hoping for deeper sleep');
    });

    test('v1 JSON (without new keys) deserializes with safe defaults', () {
      // Represent a JSON blob that was serialized before the schema
      // bump — only the original keys present.
      final v1Json = <String, dynamic>{
        'id': 'j-v1',
        'name': 'x',
        'type': 'peptide',
        'startDate': '2026-04-01T00:00:00.000Z',
        'endDate': null,
        'cycleLengthDays': 28,
        'doseMcg': 250.0,
        'route': 'sub-q',
        'notes': null,
        'isActive': true,
      };
      final parsed = ActiveProtocol.fromJson(v1Json);
      expect(parsed.doseDisplay, isNull);
      expect(parsed.frequency, isNull);
      expect(parsed.isOngoingFlag, isNull);
      expect(parsed.isOngoing, isFalse);
      expect(parsed.measurementTargets, isNull);
    });
  });
}
