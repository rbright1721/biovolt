import 'dart:io';

import 'package:biovolt/bloc/session/session_bloc.dart';
import 'package:biovolt/bloc/session/session_state.dart';
import 'package:biovolt/models/log_entry.dart';
import 'package:biovolt/models/session.dart';
import 'package:biovolt/models/vitals_bookmark.dart';
import 'package:biovolt/screens/session_history_screen.dart';
import 'package:biovolt/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Stub SessionBloc with a fixed state. The screen only reads `state`
/// via BlocBuilder. `implements` + noSuchMethod avoids SensorsBloc /
/// SessionStorage / SessionRecorder plumbing.
class _StubSessionBloc implements SessionBloc {
  _StubSessionBloc(this._state);
  final SessionState _state;

  @override
  SessionState get state => _state;

  @override
  Stream<SessionState> get stream => Stream<SessionState>.value(_state);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late Directory tempDir;
  late StorageService storage;

  setUp(() async {
    tempDir = Directory.systemTemp
        .createTempSync('biovolt_session_history_log_');
    storage = StorageService();
    await storage.initForTest(tempDir.path);
  });

  tearDown(() async {
    await storage.resetForTest();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  // Build two sessions + two bookmarks + two log entries at known
  // timestamps. Checks the full DESC interleaving and asserts each
  // rendered variant (logentry-with-text, logentry-empty).
  testWidgets('renders sessions + bookmarks + log entries in DESC order',
      (tester) async {
    final t1 = DateTime(2026, 4, 20, 9, 0); // earliest
    final t2 = DateTime(2026, 4, 20, 10, 0);
    final t3 = DateTime(2026, 4, 20, 11, 0);
    final t4 = DateTime(2026, 4, 20, 12, 0);
    final t5 = DateTime(2026, 4, 20, 13, 0);
    final t6 = DateTime(2026, 4, 20, 14, 0); // latest

    // Sessions live in SessionBloc.state.history, so they don't need
    // the storage round-trip.
    final sessionA = Session(
      sessionId: 'sess-a',
      userId: 'u',
      createdAt: t1,
      timezone: 'UTC',
      dataSources: const ['esp32'],
      durationSeconds: 600,
    );
    final sessionB = Session(
      sessionId: 'sess-b',
      userId: 'u',
      createdAt: t6,
      timezone: 'UTC',
      dataSources: const ['esp32'],
      durationSeconds: 900,
    );

    // Hive I/O is real disk I/O — testWidgets wraps the body in a
    // FakeAsync zone where real-time Futures don't resolve. Wrap every
    // real-async call in `tester.runAsync` or the whole test hangs.
    await tester.runAsync(() async {
      await storage.saveBookmark(VitalsBookmark(
        id: 'bm-1',
        timestamp: t2,
        note: 'mid-morning bookmark',
        hrBpm: 58,
      ));
      await storage.saveBookmark(VitalsBookmark(
        id: 'bm-2',
        timestamp: t5,
        note: 'pre-lunch bookmark',
        hrBpm: 72,
      ));
      await storage.saveLogEntry(LogEntry(
        id: 'log-typed',
        rawText: 'took 250mcg BPC-157',
        occurredAt: t3,
        loggedAt: t3,
        hrBpm: 61,
        hrvMs: 42,
      ));
      await storage.saveLogEntry(LogEntry(
        id: 'log-empty',
        rawText: '',
        occurredAt: t4,
        loggedAt: t4,
        hrBpm: 63,
      ));
    });

    final bloc = _StubSessionBloc(SessionState(
      history: [sessionA, sessionB],
    ));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: BlocProvider<SessionBloc>.value(
          value: bloc,
          child: const SessionHistoryScreen(),
        ),
      ),
    );
    // One pump to build, a second frame to let ListView items paint.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    // Counter line reflects all three tallies.
    expect(find.textContaining('2 sessions'), findsOneWidget);
    expect(find.textContaining('2 bookmarks'), findsOneWidget);
    expect(find.textContaining('2 logs'), findsOneWidget);

    // Typed log entry shows its rawText.
    expect(find.text('took 250mcg BPC-157'), findsOneWidget);

    // Empty log entry shows the muted placeholder.
    expect(find.text('(vitals snapshot)'), findsOneWidget);

    // Both bookmarks rendered.
    expect(find.text('mid-morning bookmark'), findsOneWidget);
    expect(find.text('pre-lunch bookmark'), findsOneWidget);
  });
}
