import 'dart:io';

import 'package:biovolt/models/active_protocol.dart';
import 'package:biovolt/models/biovolt_event.dart';
import 'package:biovolt/models/bloodwork.dart';
import 'package:biovolt/services/event_log.dart';
import 'package:biovolt/services/event_types.dart';
import 'package:biovolt/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Group 1: EventLog in isolation
  // ---------------------------------------------------------------------------

  group('EventLog', () {
    late Directory tempDir;
    late Box<BiovoltEvent> eventsBox;
    late EventLog log;

    setUpAll(() {
      if (!Hive.isAdapterRegistered(42)) {
        Hive.registerAdapter(BiovoltEventAdapter());
      }
    });

    setUp(() async {
      tempDir = Directory.systemTemp
          .createTempSync('biovolt_events_log_');
      Hive.init(tempDir.path);
      eventsBox = await Hive.openBox<BiovoltEvent>(EventLog.boxName);
      log = EventLog(eventsBox: eventsBox, deviceId: 'test-device-id');
    });

    tearDown(() async {
      await Hive.close();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // Windows sometimes holds the file briefly after close; ignore.
      }
    });

    test(
        'append returns an event whose ULID is lexicographically greater than the previous',
        () async {
      String prev = '';
      for (var i = 0; i < 10; i++) {
        final event = await log.append(
          type: EventTypes.supplementAdded,
          payload: {'i': i},
        );
        expect(event.id.compareTo(prev) > 0, isTrue,
            reason: 'ULID $i (${event.id}) is not > previous ($prev)');
        prev = event.id;
      }
    });

    test('since(null) returns all events in insertion order', () async {
      for (var i = 0; i < 5; i++) {
        await log.append(
          type: EventTypes.hrSample,
          payload: {'bpm': 60 + i},
        );
      }
      final all = await log.since(null);
      expect(all.length, 5);
      for (var i = 1; i < all.length; i++) {
        expect(all[i - 1].id.compareTo(all[i].id) < 0, isTrue);
      }
      for (var i = 0; i < 5; i++) {
        expect(all[i].payload['bpm'], 60 + i);
      }
    });

    test('since(eventId) returns only events strictly after the given ID',
        () async {
      final events = <BiovoltEvent>[];
      for (var i = 0; i < 5; i++) {
        events.add(await log.append(
          type: EventTypes.hrSample,
          payload: {'i': i},
        ));
      }
      final after2 = await log.since(events[2].id);
      expect(after2.length, 2);
      expect(after2.map((e) => e.payload['i']).toList(), [3, 4]);
    });

    test('query filters by type', () async {
      await log.append(
          type: EventTypes.supplementAdded, payload: {'name': 'GlyNAC'});
      await log.append(
          type: EventTypes.hrSample, payload: {'bpm': 72});
      await log.append(
          type: EventTypes.supplementAdded, payload: {'name': 'Creatine'});
      await log.append(
          type: EventTypes.sessionStarted, payload: {'type': 'breathwork'});

      final supplements =
          await log.query(type: EventTypes.supplementAdded);
      expect(supplements.length, 2);
      expect(
        supplements.map((e) => e.payload['name']).toList(),
        ['GlyNAC', 'Creatine'],
      );
    });

    test('latest returns the most recent event of a given type', () async {
      await log.append(
          type: EventTypes.supplementAdded, payload: {'name': 'A'});
      await log.append(
          type: EventTypes.hrSample, payload: {'bpm': 70});
      await log.append(
          type: EventTypes.supplementAdded, payload: {'name': 'B'});
      final latest = await log.latest(EventTypes.supplementAdded);
      expect(latest, isNotNull);
      expect(latest!.payload['name'], 'B');
    });

    test('events box persists the full record across close/reopen',
        () async {
      final appended = await log.append(
        type: EventTypes.profileBloodworkAdded,
        payload: {'id': 'bw-1', 'hdl': 55.0},
        schemaVersion: 2,
      );
      await eventsBox.close();
      final reopened =
          await Hive.openBox<BiovoltEvent>(EventLog.boxName);
      final roundTrip = reopened.get(appended.id);
      expect(roundTrip, isNotNull);
      expect(roundTrip!.type, EventTypes.profileBloodworkAdded);
      expect(roundTrip.deviceId, 'test-device-id');
      expect(roundTrip.schemaVersion, 2);
      expect(roundTrip.payload['id'], 'bw-1');
      expect(roundTrip.payload['hdl'], 55.0);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 2: StorageService two-write refactor
  // ---------------------------------------------------------------------------

  group('StorageService two-write refactor', () {
    late Directory tempDir;
    late StorageService storage;

    setUp(() async {
      tempDir = Directory.systemTemp
          .createTempSync('biovolt_events_storage_');
      storage = StorageService();
      await storage.initForTest(tempDir.path);
    });

    tearDown(() async {
      await storage.resetForTest();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('saveBloodwork writes to both bloodwork and events boxes',
        () async {
      final bw = Bloodwork(
        id: 'bw-test-1',
        labDate: DateTime(2026, 4, 15),
        crp: 0.3,
        hdl: 62.0,
      );
      await storage.saveBloodwork(bw);

      // State write
      final stored = storage.getBloodwork('bw-test-1');
      expect(stored, isNotNull);
      expect(stored!.id, 'bw-test-1');

      // Event write
      final events = await storage.eventLog
          .query(type: EventTypes.profileBloodworkAdded);
      expect(events.length, 1);
      expect(events.first.payload['id'], 'bw-test-1');
      expect(events.first.payload['hdl'], 62.0);
    });

    test('saveActiveProtocol writes to both protocols and events boxes',
        () async {
      final p = ActiveProtocol(
        id: 'proto-test-1',
        name: 'BPC-157',
        type: 'peptide',
        startDate: DateTime(2026, 4, 1),
        cycleLengthDays: 30,
        doseMcg: 250,
        route: 'sub-q',
        isActive: true,
      );
      await storage.saveActiveProtocol(p);

      // State write
      final stored = storage.getActiveProtocol('proto-test-1');
      expect(stored, isNotNull);
      expect(stored!.name, 'BPC-157');

      // Event write
      final events = await storage.eventLog
          .query(type: EventTypes.protocolItemAdded);
      expect(events.length, 1);
      expect(events.first.payload['id'], 'proto-test-1');
      expect(events.first.payload['name'], 'BPC-157');
    });
  });

  // ---------------------------------------------------------------------------
  // Group 3: Events box survives a schema-version wipe of state boxes
  // ---------------------------------------------------------------------------

  group('events box schema-bump survival', () {
    setUpAll(() {
      if (!Hive.isAdapterRegistered(42)) {
        Hive.registerAdapter(BiovoltEventAdapter());
      }
    });

    test('events survive a wipe that clears state boxes', () async {
      final tempDir = Directory.systemTemp
          .createTempSync('biovolt_events_survival_');
      Hive.init(tempDir.path);

      final events =
          await Hive.openBox<BiovoltEvent>(EventLog.boxName);
      final log = EventLog(
          eventsBox: events, deviceId: 'survival-device');
      await log.append(
          type: EventTypes.supplementAdded, payload: {'x': 1});

      // A state box that WOULD be wiped on a schema bump.
      final stateBox = await Hive.openBox<String>('bloodwork');
      await stateBox.put('k', 'v');

      // Simulate the schema-bump wipe: only the boxes in the state-box
      // list are deleted; the events box is exempt.
      await stateBox.close();
      await Hive.deleteBoxFromDisk('bloodwork');

      // Reopen the wiped state box and the untouched events box.
      final reopenedState = await Hive.openBox<String>('bloodwork');
      final reopenedEvents =
          await Hive.openBox<BiovoltEvent>(EventLog.boxName);
      final survivingLog = EventLog(
          eventsBox: reopenedEvents, deviceId: 'survival-device');

      expect(reopenedState.isEmpty, isTrue);

      final surviving = await survivingLog.since(null);
      expect(surviving.length, 1);
      expect(surviving.first.type, EventTypes.supplementAdded);
      expect(surviving.first.payload['x'], 1);

      await Hive.close();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });
  });
}
