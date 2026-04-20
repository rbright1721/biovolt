import 'dart:io';

import 'package:biovolt/config/theme.dart';
import 'package:biovolt/models/biovolt_event.dart';
import 'package:biovolt/services/event_log.dart';
import 'package:biovolt/services/event_types.dart';
import 'package:biovolt/ui/timeline/protocol_timeline_view.dart';
import 'package:biovolt/ui/timeline/timeline_event_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

class _DirectAppendLog {
  _DirectAppendLog(this.box);
  final Box<BiovoltEvent> box;

  Future<void> put(BiovoltEvent e) => box.put(e.id, e);
}

BiovoltEvent makeEvent({
  required String id,
  required String type,
  required DateTime at,
  Map<String, dynamic>? payload,
  String deviceId = 'dev-1',
}) {
  // Deterministic ULID-shaped ids for ordering. Real ULIDs are 26 chars.
  return BiovoltEvent(
    id: id.padRight(26, 'z'),
    timestamp: at,
    deviceId: deviceId,
    type: type,
    payload: payload ?? const {},
    schemaVersion: 1,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<BiovoltEvent> eventsBox;
  late EventLog eventLog;
  late _DirectAppendLog directLog;

  setUpAll(() {
    if (!Hive.isAdapterRegistered(42)) {
      Hive.registerAdapter(BiovoltEventAdapter());
    }
    // Prevent GoogleFonts from making network calls during tests — the
    // fetch otherwise hangs the test environment on CI and on clean
    // machines without the fonts cached.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    tempDir = Directory.systemTemp
        .createTempSync('biovolt_timeline_view_test_');
    Hive.init(tempDir.path);
    eventsBox = await Hive.openBox<BiovoltEvent>(EventLog.boxName);
    eventLog = EventLog(eventsBox: eventsBox, deviceId: 'dev-1');
    directLog = _DirectAppendLog(eventsBox);
  });

  tearDown(() async {
    await Hive.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> pumpView(
    WidgetTester tester, {
    TimelineRendererRegistry? registry,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BioVoltTheme.dark,
        home: Scaffold(
          backgroundColor: BioVoltColors.background,
          body: ProtocolTimelineView(
            eventLogOverride: eventLog,
            registry: registry,
          ),
        ),
      ),
    );
    // Avoid pumpAndSettle — the loading-state CircularProgressIndicator
    // animates indefinitely and would never settle. Pump a few frames to
    // let _load()'s microtasks resolve and the final list render.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('groups events by day with newest day first',
      (tester) async {
    final now = DateTime.now();
    final today = now.subtract(const Duration(hours: 2));
    final yesterday = now.subtract(const Duration(days: 1, hours: 2));
    final twoDaysAgo = now.subtract(const Duration(days: 2, hours: 2));
    await directLog.put(makeEvent(
        id: 'a', type: EventTypes.sessionEnded, at: twoDaysAgo,
        payload: {'durationSeconds': 600}));
    await directLog.put(makeEvent(
        id: 'b', type: EventTypes.journalEntryAdded, at: yesterday,
        payload: {'conversationId': 'c1'}));
    await directLog.put(makeEvent(
        id: 'c', type: EventTypes.profileBloodworkAdded, at: today,
        payload: {'id': 'bw-1', 'labDate': today.toIso8601String(),
                  'hdl': 55.0}));

    await pumpView(tester);

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
    expect(find.text('Session ended'), findsOneWidget);
    expect(find.text('Journal entry added'), findsOneWidget);
    expect(find.text('Bloodwork added'), findsOneWidget);
  });

  testWidgets('five rapid same-type same-source events render as single '
      'collapsed row, and tapping expands them', (tester) async {
    final base = DateTime.now().subtract(const Duration(hours: 1));
    for (var i = 0; i < 5; i++) {
      await directLog.put(makeEvent(
        id: 'dsc-$i',
        type: EventTypes.deviceStateChanged,
        at: base.add(Duration(seconds: i * 30)),
        payload: {'connectorId': 'esp32', 'status': 'connected'},
      ));
    }

    await pumpView(tester);

    expect(find.text('5 Device state changed events'), findsOneWidget);
    // Individual rows not yet rendered
    expect(find.text('Device state changed'), findsNothing);

    await tester.tap(find.text('5 Device state changed events'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    // All 5 individual rows now visible inside the expanded run.
    expect(find.text('Device state changed'), findsNWidgets(5));
  });

  testWidgets('tapping a non-collapsed row reveals payload key/value list',
      (tester) async {
    final at = DateTime.now().subtract(const Duration(hours: 1));
    await directLog.put(makeEvent(
      id: 'bw-a',
      type: EventTypes.profileBloodworkAdded,
      at: at,
      payload: {
        'id': 'bw-1',
        'labDate': at.toIso8601String(),
        'hdl': 55.0,
        'ldl': 100.0,
      },
    ));

    await pumpView(tester);

    expect(find.text('hdl'), findsNothing);
    await tester.tap(find.text('Bloodwork added'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('hdl'), findsOneWidget);
    expect(find.text('55.0'), findsOneWidget);
    expect(find.text('ldl'), findsOneWidget);
    expect(find.text('100.0'), findsOneWidget);
  });

  testWidgets('empty state renders when no events in range', (tester) async {
    await pumpView(tester);
    expect(find.text('No events in this range'), findsOneWidget);
  });
}
