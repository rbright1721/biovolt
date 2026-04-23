import 'dart:io';

import 'package:biovolt/bloc/sensors/sensors_bloc.dart';
import 'package:biovolt/bloc/sensors/sensors_state.dart';
import 'package:biovolt/config/theme.dart';
import 'package:biovolt/models/active_protocol.dart';
import 'package:biovolt/models/log_entry.dart';
import 'package:biovolt/models/session.dart';
import 'package:biovolt/models/vitals_bookmark.dart';
import 'package:biovolt/screens/timeline/items/timeline_day_header.dart';
import 'package:biovolt/screens/timeline/items/timeline_expected_dose_tile.dart';
import 'package:biovolt/screens/timeline/items/timeline_now_marker_card.dart';
import 'package:biovolt/screens/timeline/items/timeline_session_tile.dart';
import 'package:biovolt/screens/timeline/timeline_item.dart';
import 'package:biovolt/screens/timeline_screen.dart';
import 'package:biovolt/services/ble_service.dart';
import 'package:biovolt/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Stub SensorsBloc that returns a fixed state. Mirrors the pattern in
/// log_entry_sheet_test.dart — TimelineNowMarkerCard reads sensor
/// state via a BlocBuilder, so any test that pumps a NOW marker needs
/// this provider in scope.
class _StubSensorsBloc implements SensorsBloc {
  _StubSensorsBloc(this._state);
  final SensorsState _state;

  @override
  SensorsState get state => _state;

  @override
  Stream<SensorsState> get stream => Stream<SensorsState>.value(_state);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // ---------------------------------------------------------------------------
  // Fixtures
  // ---------------------------------------------------------------------------

  final fixedNow = DateTime(2026, 4, 22, 12);

  ActiveProtocol mkProtocol({
    String id = 'p1',
    String name = 'BPC-157',
    bool isOngoing = false,
    int cycleLengthDays = 30,
    String? doseDisplay,
  }) {
    return ActiveProtocol(
      id: id,
      name: name,
      type: 'peptide',
      startDate: fixedNow.subtract(const Duration(days: 4)),
      cycleLengthDays: cycleLengthDays,
      doseMcg: 250,
      route: 'sc',
      isActive: true,
      doseDisplay: doseDisplay,
      isOngoingFlag: isOngoing,
    );
  }

  LogEntry mkLog({
    required String id,
    String rawText = 'sample',
    String type = 'other',
    String classificationStatus = 'pending',
    DateTime? occurredAt,
  }) {
    return LogEntry(
      id: id,
      rawText: rawText,
      occurredAt: occurredAt ?? fixedNow.subtract(const Duration(hours: 1)),
      loggedAt: occurredAt ?? fixedNow.subtract(const Duration(hours: 1)),
      type: type,
      classificationStatus: classificationStatus,
    );
  }

  /// Hand-rolled list with one of each subtype, spread over three days
  /// to exercise the day-grouping path.
  List<TimelineItem> buildTestItems() {
    final yesterday = fixedNow.subtract(const Duration(days: 1));
    final twoDaysAgo = fixedNow.subtract(const Duration(days: 2));
    final tomorrow = fixedNow.add(const Duration(days: 1));
    return <TimelineItem>[
      // Future — tomorrow
      TimelineExpectedDose(
        protocol: mkProtocol(doseDisplay: '250mcg'),
        expectedTime: tomorrow.copyWith(hour: 8, minute: 0),
      ),
      TimelineFastingWindow(
        endTime: fixedNow.add(const Duration(hours: 4)),
        fastingType: '16:8',
      ),
      TimelineCycleDayMarker(
        protocol: mkProtocol(),
        date: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        cycleDay: 6,
      ),
      // NOW
      TimelineNowMarker(
        time: fixedNow,
        activeProtocols: [mkProtocol()],
      ),
      // Past — today
      TimelineLogEntry(mkLog(
        id: 'today-log',
        rawText: 'felt clear after walk',
        occurredAt: fixedNow.subtract(const Duration(hours: 2)),
      )),
      // Past — yesterday
      TimelineSession(Session(
        sessionId: 'sess-1',
        userId: 'u',
        createdAt: yesterday.copyWith(hour: 9, minute: 30),
        timezone: 'UTC',
        durationSeconds: 480,
        dataSources: const [],
      )),
      TimelineBookmark(VitalsBookmark(
        id: 'bm-1',
        timestamp: yesterday.copyWith(hour: 7, minute: 0),
        note: 'morning vitals',
      )),
      // Past — two days ago
      TimelineLogEntry(mkLog(
        id: 'old-log',
        rawText: 'dose taken',
        type: 'dose',
        classificationStatus: 'classified',
        occurredAt: twoDaysAgo.copyWith(hour: 8, minute: 15),
      )),
    ];
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<TimelineItem>? items,
    SensorsState? sensorState,
  }) async {
    final ble = BleService();
    addTearDown(ble.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: BioVoltTheme.dark,
      home: BlocProvider<SensorsBloc>.value(
        value: _StubSensorsBloc(sensorState ?? const SensorsState()),
        child: TimelineScreen(
          bleService: ble,
          initialItems: items ?? buildTestItems(),
        ),
      ),
    ));
    // Settle the post-frame auto-scroll callback without holding open
    // any infinite animations.
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// Pump the screen against a real [StorageService] (no [initialItems])
  /// so the watchLogEntries subscription is live. Used by reactivity
  /// tests that exercise the Hive box → debounce → setState path.
  Future<void> pumpReactiveScreen(WidgetTester tester) async {
    final ble = BleService();
    addTearDown(ble.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: BioVoltTheme.dark,
      home: BlocProvider<SensorsBloc>.value(
        value: _StubSensorsBloc(const SensorsState()),
        child: TimelineScreen(bleService: ble),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 350));
  }

  // ===========================================================================
  // Tests
  // ===========================================================================

  testWidgets('empty list still renders the NOW marker', (tester) async {
    await pumpScreen(tester, items: [
      TimelineNowMarker(time: fixedNow, activeProtocols: const []),
    ]);
    expect(find.byType(TimelineNowMarkerCard), findsOneWidget);
    expect(find.text('NOW'), findsOneWidget);
  });

  testWidgets('LogEntry rawText renders as primary text', (tester) async {
    await pumpScreen(tester, items: [
      TimelineNowMarker(time: fixedNow, activeProtocols: const []),
      TimelineLogEntry(mkLog(id: '1', rawText: 'test entry')),
    ]);
    expect(find.text('test entry'), findsOneWidget);
  });

  testWidgets('LogEntry with empty rawText shows vitals snapshot text',
      (tester) async {
    await pumpScreen(tester, items: [
      TimelineNowMarker(time: fixedNow, activeProtocols: const []),
      TimelineLogEntry(mkLog(id: '1', rawText: '')),
    ]);
    expect(find.text('(vitals snapshot)'), findsOneWidget);
  });

  testWidgets('classified LogEntry chip shows uppercase type', (tester) async {
    await pumpScreen(tester, items: [
      TimelineNowMarker(time: fixedNow, activeProtocols: const []),
      TimelineLogEntry(mkLog(
        id: '1',
        rawText: 'BPC dose',
        type: 'dose',
        classificationStatus: 'classified',
      )),
    ]);
    expect(find.text('DOSE'), findsOneWidget);
  });

  testWidgets('unclassified LogEntry chip shows LOG', (tester) async {
    await pumpScreen(tester, items: [
      TimelineNowMarker(time: fixedNow, activeProtocols: const []),
      TimelineLogEntry(
          mkLog(id: '1', rawText: 'just noting', type: 'other')),
    ]);
    expect(find.text('LOG'), findsOneWidget);
  });

  testWidgets('TimelineSession renders activity type and duration',
      (tester) async {
    await pumpScreen(tester, items: [
      TimelineNowMarker(time: fixedNow, activeProtocols: const []),
      TimelineSession(Session(
        sessionId: 's1',
        userId: 'u',
        createdAt: fixedNow.subtract(const Duration(hours: 2)),
        timezone: 'UTC',
        durationSeconds: 300,
        dataSources: const [],
      )),
    ]);
    // Default activity-less session falls back to 'Session · 05:00'.
    expect(find.textContaining('05:00'), findsOneWidget);
    expect(find.byType(TimelineSessionTile), findsOneWidget);
  });

  testWidgets('TimelineBookmark shows note when present', (tester) async {
    await pumpScreen(tester, items: [
      TimelineNowMarker(time: fixedNow, activeProtocols: const []),
      TimelineBookmark(VitalsBookmark(
        id: 'b1',
        timestamp: fixedNow.subtract(const Duration(hours: 3)),
        note: 'pre-fast vitals',
      )),
    ]);
    expect(find.text('pre-fast vitals'), findsOneWidget);
  });

  testWidgets('TimelineBookmark falls back to Vitals snapshot when no note',
      (tester) async {
    await pumpScreen(tester, items: [
      TimelineNowMarker(time: fixedNow, activeProtocols: const []),
      TimelineBookmark(VitalsBookmark(
        id: 'b1',
        timestamp: fixedNow.subtract(const Duration(hours: 3)),
      )),
    ]);
    expect(find.text('Vitals snapshot'), findsOneWidget);
  });

  testWidgets('TimelineExpectedDose renders ghosted with expected text',
      (tester) async {
    await pumpScreen(tester, items: [
      TimelineExpectedDose(
        protocol: mkProtocol(doseDisplay: '250mcg'),
        expectedTime: fixedNow.add(const Duration(hours: 5)),
      ),
      TimelineNowMarker(time: fixedNow, activeProtocols: const []),
    ]);
    expect(find.byType(TimelineExpectedDoseTile), findsOneWidget);
    expect(find.textContaining('expected'), findsOneWidget);
    final opacity = tester.widget<Opacity>(find
        .descendant(
          of: find.byType(TimelineExpectedDoseTile),
          matching: find.byType(Opacity),
        )
        .first);
    expect(opacity.opacity, closeTo(0.55, 0.0001));
  });

  testWidgets('TimelineFastingWindow shows Fast ends', (tester) async {
    await pumpScreen(tester, items: [
      TimelineFastingWindow(
        endTime: fixedNow.add(const Duration(hours: 4)),
        fastingType: '16:8',
      ),
      TimelineNowMarker(time: fixedNow, activeProtocols: const []),
    ]);
    expect(find.textContaining('Fast ends'), findsOneWidget);
  });

  testWidgets('TimelineCycleDayMarker shows Day N starts', (tester) async {
    await pumpScreen(tester, items: [
      TimelineCycleDayMarker(
        protocol: mkProtocol(name: 'NMN'),
        date: DateTime(fixedNow.year, fixedNow.month, fixedNow.day + 1),
        cycleDay: 6,
      ),
      TimelineNowMarker(time: fixedNow, activeProtocols: const []),
    ]);
    expect(find.text('NMN Day 6 starts'), findsOneWidget);
  });

  testWidgets('day grouping renders headers across multiple days',
      (tester) async {
    await pumpScreen(tester);
    final headers =
        tester.widgetList<TimelineDayHeader>(find.byType(TimelineDayHeader));
    expect(headers.length, greaterThanOrEqualTo(3));
  });

  group('formatDayHeader', () {
    test('today/tomorrow/yesterday relative labels', () {
      final now = DateTime(2026, 4, 22, 10);
      expect(formatDayHeader(now, now: now), 'Today');
      expect(
        formatDayHeader(now.add(const Duration(days: 1)), now: now),
        'Tomorrow',
      );
      expect(
        formatDayHeader(now.subtract(const Duration(days: 1)), now: now),
        'Yesterday',
      );
    });

    test('older/newer dates fall back to weekday + month + day', () {
      final now = DateTime(2026, 4, 22, 10); // Wednesday
      // 5 days ago = 2026-04-17 = Friday
      final older = now.subtract(const Duration(days: 5));
      expect(formatDayHeader(older, now: now), 'Friday Apr 17');
    });
  });

  testWidgets('NOW marker key is findable', (tester) async {
    await pumpScreen(tester);
    expect(find.byType(TimelineNowMarkerCard), findsOneWidget);
  });

  testWidgets('quick log pill is visible', (tester) async {
    await pumpScreen(tester);
    expect(find.byKey(const Key('timeline-quick-log-pill')), findsOneWidget);
    expect(find.text('Quick log'), findsOneWidget);
  });

  testWidgets('play FAB is visible as floatingActionButton', (tester) async {
    await pumpScreen(tester);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.floatingActionButton, isA<FloatingActionButton>());
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  // ===========================================================================
  // formatNowMarkerBiometrics — pure helper, fast unit tests.
  // ===========================================================================

  group('formatNowMarkerBiometrics', () {
    test('all-zero state renders dashes for every reading', () {
      final s = formatNowMarkerBiometrics(const SensorsState());
      expect(s, 'HR —  ·  HRV —  ·  GSR —  ·  Temp —  ·  SpO₂ —');
    });

    test('populated state uses fixed-decimal numbers and units', () {
      final s = formatNowMarkerBiometrics(const SensorsState(
        isConnected: true,
        heartRate: 64,
        hrv: 48,
        gsr: 3.14,
        temperature: 97.83,
        spo2: 97,
      ));
      expect(s, 'HR 64  ·  HRV 48ms  ·  GSR 3.1µS  ·  Temp 97.8°F  ·  SpO₂ 97%');
    });

    test('mixed nulls/values: zeros become em-dashes selectively', () {
      final s = formatNowMarkerBiometrics(const SensorsState(
        heartRate: 70,
        hrv: 0, // → dash
        gsr: 2.5,
        temperature: 0, // → dash
        spo2: 98,
      ));
      expect(
        s,
        'HR 70  ·  HRV —  ·  GSR 2.5µS  ·  Temp —  ·  SpO₂ 98%',
      );
    });
  });

  // ===========================================================================
  // Reactivity — driven by Hive box events from a real StorageService.
  // ===========================================================================

  group('reactive rebuild', () {
    late Directory tempDir;
    late StorageService storage;

    setUp(() async {
      tempDir =
          Directory.systemTemp.createTempSync('biovolt_timeline_screen_');
      storage = StorageService();
      await storage.initForTest(tempDir.path);
    });

    tearDown(() async {
      await storage.resetForTest();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('new LogEntry appears after Hive event + debounce',
        (tester) async {
      await pumpReactiveScreen(tester);
      expect(find.text('first save'), findsNothing);

      // Hive's BoxEvent stream uses real-world async, so the save +
      // initial event propagation must run in tester.runAsync to
      // escape the fake-time zone. Then we hand back to fake-time
      // pumps to drive the screen's debounce timer.
      await tester.runAsync(() async {
        await storage.saveLogEntry(LogEntry(
          id: 'reactive-1',
          rawText: 'first save',
          occurredAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });

      // Inside the debounce window — no rebuild yet.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('first save'), findsNothing);

      // Past the 250ms debounce — setState fires and the entry renders.
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('first save'), findsOneWidget);
    });

    testWidgets('rapid saves collapse into one final render',
        (tester) async {
      await pumpReactiveScreen(tester);
      final occurredAt =
          DateTime.now().subtract(const Duration(minutes: 5));

      // Three rapid saves within ~30ms of each other — the screen's
      // debounce should reset on each box event, then fire once.
      await tester.runAsync(() async {
        await storage.saveLogEntry(LogEntry(
          id: 'a',
          rawText: 'entry-a',
          occurredAt: occurredAt,
        ));
        await storage.saveLogEntry(LogEntry(
          id: 'b',
          rawText: 'entry-b',
          occurredAt: occurredAt.add(const Duration(seconds: 1)),
        ));
        await storage.saveLogEntry(LogEntry(
          id: 'c',
          rawText: 'entry-c',
          occurredAt: occurredAt.add(const Duration(seconds: 2)),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });

      // Past the 250ms debounce — one rebuild renders all three.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('entry-a'), findsOneWidget);
      expect(find.text('entry-b'), findsOneWidget);
      expect(find.text('entry-c'), findsOneWidget);
    });

    testWidgets('subscription is cancelled on dispose without throwing',
        (tester) async {
      await pumpReactiveScreen(tester);

      // Replace the screen with an unrelated widget — triggers
      // _TimelineScreenState.dispose().
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      // Subsequent saves should NOT cause a setState-after-dispose
      // crash. The assertion here is the absence of a thrown error.
      await tester.runAsync(() async {
        await storage.saveLogEntry(LogEntry(
          id: 'after-dispose',
          rawText: 'should not crash',
          occurredAt: DateTime.now(),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  // ===========================================================================
  // Live biometric strip — verify BlocBuilder wires through.
  // ===========================================================================

  testWidgets('NOW marker biometric strip reflects SensorsBloc state',
      (tester) async {
    await pumpScreen(
      tester,
      items: [
        TimelineNowMarker(time: fixedNow, activeProtocols: const []),
      ],
      sensorState: const SensorsState(
        isConnected: true,
        heartRate: 62,
        hrv: 51,
        gsr: 2.7,
        temperature: 98.1,
        spo2: 97,
      ),
    );
    expect(
      find.text(
          'HR 62  ·  HRV 51ms  ·  GSR 2.7µS  ·  Temp 98.1°F  ·  SpO₂ 97%'),
      findsOneWidget,
    );
  });

  testWidgets(
      'NOW marker biometric strip shows dashes when state is empty',
      (tester) async {
    await pumpScreen(
      tester,
      items: [
        TimelineNowMarker(time: fixedNow, activeProtocols: const []),
      ],
    );
    expect(
      find.text('HR —  ·  HRV —  ·  GSR —  ·  Temp —  ·  SpO₂ —'),
      findsOneWidget,
    );
  });
}
