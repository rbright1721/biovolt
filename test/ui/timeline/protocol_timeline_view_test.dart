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

// Hive writes are real disk I/O. testWidgets wraps the test body in a
// FakeAsync zone where real-time Futures never resolve — any seeding or
// box.put call outside tester.runAsync(...) will hang forever.

BiovoltEvent makeEvent({
  required String id,
  required String type,
  required DateTime at,
  Map<String, dynamic>? payload,
  String deviceId = 'dev-1',
}) {
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

  setUpAll(() {
    if (!Hive.isAdapterRegistered(42)) {
      Hive.registerAdapter(BiovoltEventAdapter());
    }
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    tempDir = Directory.systemTemp
        .createTempSync('biovolt_timeline_view_test_');
    Hive.init(tempDir.path);
    eventsBox = await Hive.openBox<BiovoltEvent>(EventLog.boxName);
    eventLog = EventLog(eventsBox: eventsBox, deviceId: 'dev-1');
  });

  tearDown(() async {
    await Hive.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> seed(WidgetTester tester, List<BiovoltEvent> events) async {
    await tester.runAsync(() async {
      for (final e in events) {
        await eventsBox.put(e.id, e);
      }
    });
  }

  Future<void> pumpView(
    WidgetTester tester, {
    TimelineRendererRegistry? registry,
  }) async {
    // A bare MaterialApp (no BioVoltTheme) is used intentionally — the
    // real theme invokes GoogleFonts, which can't load in the test
    // environment. The timeline widgets use plain TextStyles that
    // inherit fontFamily from the ambient theme, so the production
    // app still renders JetBrainsMono.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: BioVoltColors.background,
          body: ProtocolTimelineView(
            eventLogOverride: eventLog,
            registry: registry,
          ),
        ),
      ),
    );
    // Let initState's _load() future resolve on the real event loop.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }

  testWidgets('empty state renders when no events in range', (tester) async {
await pumpView(tester);
    expect(find.text('No events in this range'), findsOneWidget);
  });

  testWidgets('groups events by day with newest day first', (tester) async {
final now = DateTime.now();
    final today = now.subtract(const Duration(hours: 2));
    final yesterday = now.subtract(const Duration(days: 1, hours: 2));
    final twoDaysAgo = now.subtract(const Duration(days: 2, hours: 2));
    await seed(tester, [
      makeEvent(
          id: 'a', type: EventTypes.sessionEnded, at: twoDaysAgo,
          payload: {'durationSeconds': 600}),
      makeEvent(
          id: 'b', type: EventTypes.journalEntryAdded, at: yesterday,
          payload: {'conversationId': 'c1'}),
      makeEvent(
          id: 'c', type: EventTypes.profileBloodworkAdded, at: today,
          payload: {
            'id': 'bw-1',
            'labDate': today.toIso8601String(),
            'hdl': 55.0,
          }),
    ]);

    await pumpView(tester);

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
    expect(find.text('Session ended'), findsOneWidget);
    expect(find.text('Journal entry added'), findsOneWidget);
    expect(find.text('Bloodwork added'), findsOneWidget);
  });

  testWidgets('five rapid same-type same-source events render as a single '
      'collapsed row that expands on tap', (tester) async {
final base = DateTime.now().subtract(const Duration(hours: 1));
    await seed(tester, [
      for (var i = 0; i < 5; i++)
        makeEvent(
          id: 'dsc-$i',
          type: EventTypes.deviceStateChanged,
          at: base.add(Duration(seconds: i * 30)),
          payload: {'connectorId': 'esp32', 'status': 'connected'},
        ),
    ]);

    await pumpView(tester);

    expect(find.text('5 Device state changed events'), findsOneWidget);
    expect(find.text('Device state changed'), findsNothing);

    await tester.tap(find.text('5 Device state changed events'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Device state changed'), findsNWidgets(5));
  });

  testWidgets('tapping a non-collapsed row reveals payload key/value list',
      (tester) async {
final at = DateTime.now().subtract(const Duration(hours: 1));
    await seed(tester, [
      makeEvent(
        id: 'bw-a',
        type: EventTypes.profileBloodworkAdded,
        at: at,
        payload: {
          'id': 'bw-1',
          'labDate': at.toIso8601String(),
          'hdl': 55.0,
          'ldl': 100.0,
        },
      ),
    ]);

    await pumpView(tester);

    expect(find.text('hdl'), findsNothing);
    await tester.tap(find.text('Bloodwork added'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('hdl'), findsOneWidget);
    expect(find.text('55.0'), findsOneWidget);
    expect(find.text('ldl'), findsOneWidget);
    expect(find.text('100.0'), findsOneWidget);
  });

}
