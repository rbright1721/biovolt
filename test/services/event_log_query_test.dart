import 'dart:io';

import 'package:biovolt/models/biovolt_event.dart';
import 'package:biovolt/services/event_log.dart';
import 'package:biovolt/services/event_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  group('EventLog.query extended filters', () {
    late Directory tempDir;
    late Box<BiovoltEvent> eventsBox;

    setUpAll(() {
      if (!Hive.isAdapterRegistered(42)) {
        Hive.registerAdapter(BiovoltEventAdapter());
      }
    });

    setUp(() async {
      tempDir = Directory.systemTemp
          .createTempSync('biovolt_events_query_test_');
      Hive.init(tempDir.path);
      eventsBox = await Hive.openBox<BiovoltEvent>(EventLog.boxName);
    });

    tearDown(() async {
      await Hive.close();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    Future<void> seedEventsFrom(String deviceId, List<String> types) async {
      final log = EventLog(eventsBox: eventsBox, deviceId: deviceId);
      for (final t in types) {
        await log.append(type: t, payload: {'device': deviceId});
      }
    }

    test('types set filters to union of matching types', () async {
      await seedEventsFrom('dev-1', [
        EventTypes.supplementAdded,
        EventTypes.hrSample,
        EventTypes.profileBloodworkAdded,
        EventTypes.sessionStarted,
      ]);
      final log = EventLog(eventsBox: eventsBox, deviceId: 'dev-1');

      final result = await log.query(types: {
        EventTypes.supplementAdded,
        EventTypes.profileBloodworkAdded,
      });

      expect(result.length, 2);
      expect(result.map((e) => e.type).toSet(), {
        EventTypes.supplementAdded,
        EventTypes.profileBloodworkAdded,
      });
    });

    test('sources set filters to events from matching deviceIds', () async {
      await seedEventsFrom('dev-1', [
        EventTypes.hrSample,
        EventTypes.hrSample,
      ]);
      await seedEventsFrom('dev-2', [
        EventTypes.hrSample,
      ]);
      await seedEventsFrom('dev-3', [
        EventTypes.hrSample,
      ]);
      final reader = EventLog(eventsBox: eventsBox, deviceId: 'dev-1');

      final onlyDev1And3 = await reader.query(sources: {'dev-1', 'dev-3'});

      expect(onlyDev1And3.length, 3);
      expect(onlyDev1And3.map((e) => e.deviceId).toSet(), {'dev-1', 'dev-3'});
    });

    test('types, sources, and time range compose as intersection', () async {
      final logDev1 = EventLog(eventsBox: eventsBox, deviceId: 'dev-1');
      final logDev2 = EventLog(eventsBox: eventsBox, deviceId: 'dev-2');

      // Seed 6 events: 2 types x 3 devices mix, but Hive stores only what
      // we append. We rely on event.timestamp == DateTime.now() at append
      // time. Space them out so we can pin time-range semantics.
      await logDev1.append(type: EventTypes.hrSample, payload: {'i': 1});
      await logDev1.append(type: EventTypes.supplementAdded, payload: {'i': 2});
      await logDev2.append(type: EventTypes.hrSample, payload: {'i': 3});
      await logDev2.append(type: EventTypes.supplementAdded, payload: {'i': 4});

      final now = DateTime.now();
      final from = now.subtract(const Duration(minutes: 5));
      final to = now.add(const Duration(minutes: 5));

      final result = await logDev1.query(
        types: {EventTypes.supplementAdded},
        sources: {'dev-1'},
        from: from,
        to: to,
      );

      expect(result.length, 1);
      expect(result.first.type, EventTypes.supplementAdded);
      expect(result.first.deviceId, 'dev-1');
      expect(result.first.payload['i'], 2);
    });

    test('legacy String? type still works alongside types set (union)',
        () async {
      await seedEventsFrom('dev-1', [
        EventTypes.supplementAdded,
        EventTypes.hrSample,
        EventTypes.sessionStarted,
      ]);
      final log = EventLog(eventsBox: eventsBox, deviceId: 'dev-1');

      final result = await log.query(
        type: EventTypes.hrSample,
        types: {EventTypes.sessionStarted},
      );

      expect(result.length, 2);
      expect(result.map((e) => e.type).toSet(), {
        EventTypes.hrSample,
        EventTypes.sessionStarted,
      });
    });

    test('empty types set is treated as "no type filter", not "no results"',
        () async {
      await seedEventsFrom('dev-1', [
        EventTypes.hrSample,
        EventTypes.supplementAdded,
      ]);
      final log = EventLog(eventsBox: eventsBox, deviceId: 'dev-1');

      final result = await log.query(types: const <String>{});

      expect(result.length, 2);
    });

    test('empty sources set is treated as "no source filter"', () async {
      await seedEventsFrom('dev-1', [EventTypes.hrSample]);
      await seedEventsFrom('dev-2', [EventTypes.hrSample]);
      final log = EventLog(eventsBox: eventsBox, deviceId: 'dev-1');

      final result = await log.query(sources: const <String>{});

      expect(result.length, 2);
    });

    test('no filters returns all events, sorted oldest-first', () async {
      await seedEventsFrom('dev-1', [
        EventTypes.hrSample,
        EventTypes.supplementAdded,
        EventTypes.sessionStarted,
      ]);
      final log = EventLog(eventsBox: eventsBox, deviceId: 'dev-1');

      final result = await log.query();

      expect(result.length, 3);
      for (var i = 1; i < result.length; i++) {
        expect(result[i - 1].id.compareTo(result[i].id) < 0, isTrue);
      }
    });

    test('limit caps the result length (oldest kept)', () async {
      await seedEventsFrom('dev-1', List.filled(5, EventTypes.hrSample));
      final log = EventLog(eventsBox: eventsBox, deviceId: 'dev-1');

      final result = await log.query(limit: 2);
      expect(result.length, 2);
    });
  });
}
