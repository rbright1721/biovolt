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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

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
  }) async {
    final ble = BleService();
    addTearDown(ble.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: BioVoltTheme.dark,
      home: TimelineScreen(
        bleService: ble,
        initialItems: items ?? buildTestItems(),
      ),
    ));
    // Settle the post-frame auto-scroll callback without holding open
    // any infinite animations.
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
}
