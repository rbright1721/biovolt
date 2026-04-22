import 'package:biovolt/bloc/sensors/sensors_bloc.dart';
import 'package:biovolt/bloc/sensors/sensors_state.dart';
import 'package:biovolt/config/theme.dart';
import 'package:biovolt/models/log_entry.dart';
import 'package:biovolt/services/firestore_sync.dart';
import 'package:biovolt/services/storage_service.dart';
import 'package:biovolt/widgets/log_entry_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dart lets any class be `implements`-ed; combined with noSuchMethod
/// this gives us lightweight stubs without the library-private
/// constructors of [StorageService] / [FirestoreSync] / [SensorsBloc].
///
/// Only the single method the sheet actually calls is implemented; any
/// accidental dependency on another method fails loudly (null cast).
class _FakeStorage implements StorageService {
  final List<LogEntry> saved = [];

  @override
  Future<void> saveLogEntry(LogEntry entry) async {
    saved.add(entry);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeSync implements FirestoreSync {
  final List<LogEntry> written = [];

  @override
  Future<void> writeLogEntry(LogEntry entry) async {
    written.add(entry);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Stub SensorsBloc that returns a fixed state. The sheet uses
/// `context.read<SensorsBloc>().state` inside `initState` — it never
/// subscribes to the stream, so returning a one-shot Stream.value is
/// enough to satisfy the `StateStreamable` interface Provider needs.
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

  late _FakeStorage storage;
  late _FakeSync sync;
  late SensorsState sensorState;

  setUp(() {
    storage = _FakeStorage();
    sync = _FakeSync();
    sensorState = const SensorsState(
      isConnected: true,
      heartRate: 64,
      hrv: 48,
      gsr: 2.3,
      temperature: 97.8,
      spo2: 98,
    );
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: BlocProvider<SensorsBloc>.value(
          value: _StubSensorsBloc(sensorState),
          child: Scaffold(
            backgroundColor: BioVoltColors.background,
            body: LogEntrySheet(
              storage: storage,
              firestoreSync: sync,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('sheet opens with empty text field and Log button enabled',
      (tester) async {
    await pumpSheet(tester);

    final field = find.byKey(const Key('log_entry_sheet_text_field'));
    expect(field, findsOneWidget);
    expect(tester.widget<TextField>(field).controller?.text, '');

    final logBtn = find.byKey(const Key('log_entry_sheet_log_button'));
    expect(logBtn, findsOneWidget);
    expect(tester.widget<GestureDetector>(logBtn).onTap, isNotNull);

    // Chips render as RichText with nested TextSpans — `findRichText`
    // tells the finder to traverse span trees rather than matching
    // only flat Text widgets.
    expect(find.textContaining('64 bpm', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('48 ms', findRichText: true),
        findsOneWidget);
  });

  testWidgets('typing updates the text field', (tester) async {
    await pumpSheet(tester);

    await tester.enterText(
        find.byKey(const Key('log_entry_sheet_text_field')),
        'took 250mcg BPC-157');
    await tester.pump();

    expect(find.text('took 250mcg BPC-157'), findsOneWidget);
  });

  testWidgets('Log with text saves a LogEntry with trimmed rawText',
      (tester) async {
    await pumpSheet(tester);

    await tester.enterText(
        find.byKey(const Key('log_entry_sheet_text_field')),
        '  took 500mg NAC  ');
    await tester.pump();

    await tester.tap(find.byKey(const Key('log_entry_sheet_log_button')));
    await tester.pump();
    await tester.pump();

    expect(storage.saved, hasLength(1));
    final e = storage.saved.single;
    expect(e.rawText, 'took 500mg NAC');
    expect(e.type, 'other');
    expect(e.classificationStatus, 'pending');
    expect(e.classificationAttempts, 0);
    expect(e.hrBpm, 64);
    expect(e.hrvMs, 48);
    expect(e.gsrUs, 2.3);
    expect(e.skinTempF, 97.8);
    expect(e.spo2Percent, 98);
    expect(e.ecgHrBpm, isNull);
    expect(e.structured, isNull);
    // Firestore fire-and-forget got the same entry.
    expect(sync.written, hasLength(1));
    expect(sync.written.single.id, e.id);
  });

  testWidgets('Log with empty text still saves a pure vitals-snapshot entry',
      (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.byKey(const Key('log_entry_sheet_log_button')));
    await tester.pump();
    await tester.pump();

    expect(storage.saved, hasLength(1));
    final e = storage.saved.single;
    expect(e.rawText, '');
    expect(e.type, 'other');
    expect(e.classificationStatus, 'pending');
    expect(e.hrBpm, 64);
  });

  testWidgets('Cancel does not save', (tester) async {
    await pumpSheet(tester);

    await tester.enterText(
        find.byKey(const Key('log_entry_sheet_text_field')),
        'never mind');
    await tester.pump();

    await tester.tap(find.byKey(const Key('log_entry_sheet_cancel_button')));
    await tester.pump();

    expect(storage.saved, isEmpty);
    expect(sync.written, isEmpty);
  });

  testWidgets('vitals chips show em-dash when sensor value is 0',
      (tester) async {
    sensorState = const SensorsState(
      isConnected: false,
      // All zeros → sheet treats them as unavailable.
    );
    await pumpSheet(tester);

    // Five vitals, each shows '—' when unavailable. `findRichText`
    // flag again since the chip is a RichText with TextSpans.
    expect(
        find.textContaining('—', findRichText: true), findsNWidgets(5));

    // Saving from an all-zero state persists nulls for all vitals.
    await tester.tap(find.byKey(const Key('log_entry_sheet_log_button')));
    await tester.pump();
    await tester.pump();

    expect(storage.saved, hasLength(1));
    final e = storage.saved.single;
    expect(e.hrBpm, isNull);
    expect(e.hrvMs, isNull);
    expect(e.gsrUs, isNull);
    expect(e.skinTempF, isNull);
    expect(e.spo2Percent, isNull);
  });
}
