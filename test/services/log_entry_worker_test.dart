import 'dart:async';
import 'dart:io';

import 'package:biovolt/models/active_protocol.dart';
import 'package:biovolt/models/log_entry.dart';
import 'package:biovolt/services/context_inferrer.dart';
import 'package:biovolt/services/firestore_sync.dart';
import 'package:biovolt/services/log_entry_classifier.dart';
import 'package:biovolt/services/log_entry_worker.dart';
import 'package:biovolt/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

// -----------------------------------------------------------------------------
// Test doubles.
// -----------------------------------------------------------------------------

/// Fake classifier queued with pre-canned responses. Each call pops the
/// next result (or next exception). Use this to script the exact
/// sequence the worker will see.
class _FakeClassifier implements LogEntryClassifier {
  _FakeClassifier(this._responses);
  final List<_Response> _responses;
  final List<String> calls = [];

  @override
  Future<ClassificationResult> classify({
    required LogEntry entry,
    required ClassificationContext context,
  }) async {
    calls.add(entry.id);
    if (_responses.isEmpty) {
      throw StateError(
          'Fake classifier got a call but no response was queued '
          '(entry ${entry.id}).');
    }
    final next = _responses.removeAt(0);
    if (next.error != null) throw next.error!;
    return next.result!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response {
  _Response.ok(this.result) : error = null;
  _Response.err(this.error) : result = null;
  final ClassificationResult? result;
  final Object? error;
}

/// Classifier that captures the last context it received, so tests can
/// assert the context bundle built from the inferrer flowed through.
class _RecordingClassifier implements LogEntryClassifier {
  _RecordingClassifier({required ClassificationResult ok}) : _ok = ok;
  final ClassificationResult _ok;
  ClassificationContext? lastContext;

  @override
  Future<ClassificationResult> classify({
    required LogEntry entry,
    required ClassificationContext context,
  }) async {
    lastContext = context;
    return _ok;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

ClassificationResult _stubResult(
  String id, {
  String type = 'other',
  double confidence = 0.0,
}) =>
    ClassificationResult(
      logEntryId: id,
      type: type,
      structured: null,
      confidence: confidence,
      modelVersion: 'stub-v0',
      classifiedAt: DateTime.utc(2026, 4, 20, 12),
    );

/// Minimal ContextInferrer stub — the worker only needs `.infer()` to
/// return something with `activeProtocols` and `fastingHours`.
class _StubInferrer implements ContextInferrer {
  _StubInferrer({
    this.activeProtocols = const <ActiveProtocol>[],
    this.fastingHours,
  });

  final List<ActiveProtocol> activeProtocols;
  final double? fastingHours;

  @override
  InferredContext infer({String? sessionType}) {
    return InferredContext(
      activeProtocols: activeProtocols,
      fastingHours: fastingHours,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Firestore-sync stub — swallow writeLogEntry so nothing touches real
/// Firebase. Records calls for assertion.
class _StubSync implements FirestoreSync {
  final List<String> writtenIds = [];

  @override
  Future<void> writeLogEntry(LogEntry entry) async {
    writtenIds.add(entry.id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// -----------------------------------------------------------------------------
// Shared setup.
// -----------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late StorageService storage;

  // Workers leak across tests if we don't explicitly dispose them in
  // teardown — the StorageService singleton closes its boxes on
  // resetForTest(), but any in-flight processPending or pending debounce
  // timer from a previous test can still reach into the (now closed)
  // box. Track every worker we build and tear them all down before the
  // next test's initForTest runs.
  final workers = <LogEntryWorker>[];

  setUp(() async {
    tempDir =
        Directory.systemTemp.createTempSync('biovolt_log_entry_worker_');
    storage = StorageService();
    await storage.initForTest(tempDir.path);
    workers.clear();
  });

  tearDown(() async {
    for (final w in workers) {
      await w.dispose();
    }
    workers.clear();
    // Let any fire-and-forget writes that dispose triggered drain
    // before we close boxes.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await storage.resetForTest();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// Seed a log entry directly into storage. `loggedAt` drives FIFO
  /// order in [StorageService.getPendingClassification].
  Future<LogEntry> seed({
    required String id,
    required DateTime loggedAt,
    String rawText = 'sample',
    String classificationStatus = 'pending',
    int classificationAttempts = 0,
  }) async {
    final entry = LogEntry(
      id: id,
      rawText: rawText,
      occurredAt: loggedAt,
      loggedAt: loggedAt,
      classificationStatus: classificationStatus,
      classificationAttempts: classificationAttempts,
    );
    await storage.saveLogEntry(entry);
    return entry;
  }

  LogEntryWorker buildWorker({
    required LogEntryClassifier classifier,
    _StubInferrer? inferrer,
    _StubSync? sync,
    Duration debounce = const Duration(milliseconds: 50),
  }) {
    final worker = LogEntryWorker(
      storage: storage,
      classifier: classifier,
      contextInferrer: inferrer ?? _StubInferrer(),
      firestoreSync: sync ?? _StubSync(),
      debounce: debounce,
    );
    workers.add(worker);
    return worker;
  }

  // ---------------------------------------------------------------------------
  // processPending — the hot path. Driving it directly skips the
  // Future.microtask dance in start() and makes assertions deterministic.
  // ---------------------------------------------------------------------------

  group('processPending', () {
    test('empty queue returns cleanly', () async {
      final worker = buildWorker(classifier: _FakeClassifier([]));
      await worker.processPending();
      // No crash.
    });

    test('processes entries in FIFO (loggedAt ASC)', () async {
      await seed(
          id: 'second', loggedAt: DateTime.utc(2026, 4, 20, 11));
      await seed(id: 'first', loggedAt: DateTime.utc(2026, 4, 20, 10));
      await seed(id: 'third', loggedAt: DateTime.utc(2026, 4, 20, 12));

      final classifier = _FakeClassifier([
        _Response.ok(_stubResult('first', type: 'meal')),
        _Response.ok(_stubResult('second', type: 'note')),
        _Response.ok(_stubResult('third', type: 'dose')),
      ]);
      final worker = buildWorker(classifier: classifier);

      await worker.processPending();

      expect(classifier.calls, ['first', 'second', 'third']);
      expect(storage.getLogEntry('first')!.type, 'meal');
      expect(storage.getLogEntry('second')!.type, 'note');
      expect(storage.getLogEntry('third')!.type, 'dose');
      for (final id in ['first', 'second', 'third']) {
        expect(storage.getLogEntry(id)!.classificationStatus, 'classified');
      }
    });

    test('success → classified + Firestore sync fires, inferrer context '
        'flows through to the classifier', () async {
      await seed(id: 'e-1', loggedAt: DateTime.utc(2026, 4, 20));
      final classifier = _RecordingClassifier(
          ok: _stubResult('e-1', type: 'dose', confidence: 0.9));
      final sync = _StubSync();
      final worker = LogEntryWorker(
        storage: storage,
        classifier: classifier,
        contextInferrer: _StubInferrer(
          activeProtocols: [
            ActiveProtocol(
              id: 'p-1',
              name: 'GlyNAC',
              type: 'supplement',
              startDate: DateTime.utc(2026, 4, 1),
              cycleLengthDays: 0,
              doseMcg: 0,
              route: 'oral',
              isActive: true,
            ),
          ],
          fastingHours: 12.5,
        ),
        firestoreSync: sync,
      );
      workers.add(worker);

      await worker.processPending();

      final updated = storage.getLogEntry('e-1')!;
      expect(updated.classificationStatus, 'classified');
      expect(updated.type, 'dose');
      expect(updated.classificationConfidence, 0.9);
      expect(updated.classificationAttempts, 1);
      // Fire-and-forget — give the microtask a moment to land.
      await Future<void>.delayed(Duration.zero);
      expect(sync.writtenIds, ['e-1']);
      // Context inferrer's values reached the classifier.
      expect(classifier.lastContext?.fastingHours, 12.5);
      expect(classifier.lastContext?.activeProtocols.single.name, 'GlyNAC');
    });

    test('ClassifierUnauthenticatedException → skipped, attempts unchanged, '
        'loop breaks', () async {
      await seed(
          id: 'e-1', loggedAt: DateTime.utc(2026, 4, 20, 10));
      await seed(
          id: 'e-2', loggedAt: DateTime.utc(2026, 4, 20, 11));

      final classifier = _FakeClassifier([
        _Response.err(const ClassifierUnauthenticatedException('no auth')),
        // Second response should never be consumed — loop breaks.
        _Response.ok(_stubResult('e-2')),
      ]);
      final worker = buildWorker(classifier: classifier);

      await worker.processPending();

      expect(classifier.calls, ['e-1']);
      final e1 = storage.getLogEntry('e-1')!;
      expect(e1.classificationStatus, 'skipped');
      expect(e1.classificationAttempts, 0,
          reason: 'skipped must not count against attempts');
      final e2 = storage.getLogEntry('e-2')!;
      expect(e2.classificationStatus, 'pending',
          reason: 'second entry must not be processed after an auth block');
    });

    test('ClassifierInvalidArgumentException → permanently_failed, '
        'loop continues to next entry', () async {
      await seed(id: 'e-bad', loggedAt: DateTime.utc(2026, 4, 20, 10));
      await seed(id: 'e-ok', loggedAt: DateTime.utc(2026, 4, 20, 11));

      final classifier = _FakeClassifier([
        _Response.err(
            const ClassifierInvalidArgumentException('bad payload')),
        _Response.ok(_stubResult('e-ok', type: 'note')),
      ]);
      final worker = buildWorker(classifier: classifier);

      await worker.processPending();

      expect(classifier.calls, ['e-bad', 'e-ok']);
      final bad = storage.getLogEntry('e-bad')!;
      expect(bad.classificationStatus, 'permanently_failed');
      expect(bad.classificationError, 'bad payload');
      final ok = storage.getLogEntry('e-ok')!;
      expect(ok.classificationStatus, 'classified');
      expect(ok.type, 'note');
    });

    test('ClassifierTransientException on fresh entry → failed, '
        'attempts incremented, loop breaks', () async {
      await seed(id: 'e-1', loggedAt: DateTime.utc(2026, 4, 20, 10));
      await seed(id: 'e-2', loggedAt: DateTime.utc(2026, 4, 20, 11));

      final classifier = _FakeClassifier([
        _Response.err(
            const ClassifierTransientException('network hiccup')),
        _Response.ok(_stubResult('e-2')),
      ]);
      final worker = buildWorker(classifier: classifier);

      await worker.processPending();

      expect(classifier.calls, ['e-1']);
      final e1 = storage.getLogEntry('e-1')!;
      expect(e1.classificationStatus, 'failed');
      expect(e1.classificationAttempts, 1);
      final e2 = storage.getLogEntry('e-2')!;
      expect(e2.classificationStatus, 'pending');
    });

    test('ClassifierTransientException at attempts=2 crosses ceiling → '
        'permanently_failed', () async {
      await seed(
        id: 'e-burn',
        loggedAt: DateTime.utc(2026, 4, 20),
        classificationStatus: 'failed',
        classificationAttempts: 2,
      );

      final classifier = _FakeClassifier([
        _Response.err(const ClassifierTransientException('still flaky')),
      ]);
      final worker = buildWorker(classifier: classifier);

      await worker.processPending();

      final e = storage.getLogEntry('e-burn')!;
      expect(e.classificationStatus, 'permanently_failed');
      expect(e.classificationAttempts, 3);
    });

    test('reentrancy guard — a second processPending returns immediately',
        () async {
      await seed(id: 'e-1', loggedAt: DateTime.utc(2026, 4, 20));

      // Classifier blocks on the first call so we can kick a second
      // processPending() while the first is in flight.
      final firstCallGate = Completer<void>();
      final classifier = _GateClassifier(
        onCall: (id) => firstCallGate.future.then((_) => _stubResult(id)),
      );
      final worker = LogEntryWorker(
        storage: storage,
        classifier: classifier,
        contextInferrer: _StubInferrer(),
        firestoreSync: _StubSync(),
      );
      workers.add(worker);

      final first = worker.processPending();
      // Yield so the first pass reaches the classifier call.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(worker.isProcessingForTest, isTrue);

      final second = worker.processPending();
      expect(worker.isProcessingForTest, isTrue);

      firstCallGate.complete();
      await Future.wait([first, second]);

      expect(classifier.callCount, 1,
          reason: 'second processPending must not double-process');
      expect(storage.getLogEntry('e-1')!.classificationStatus,
          'classified');
    });

    test('skipped entries re-enter the queue on the next pass regardless of '
        'attempts', () async {
      await seed(
        id: 'e-skipped',
        loggedAt: DateTime.utc(2026, 4, 20),
        classificationStatus: 'skipped',
        classificationAttempts: 0,
      );

      final classifier = _FakeClassifier(
          [_Response.ok(_stubResult('e-skipped', type: 'note'))]);
      final worker = buildWorker(classifier: classifier);

      await worker.processPending();

      expect(classifier.calls, ['e-skipped']);
      expect(storage.getLogEntry('e-skipped')!.classificationStatus,
          'classified');
    });

    test('permanently_failed entries are NOT re-processed', () async {
      await seed(
        id: 'e-burned',
        loggedAt: DateTime.utc(2026, 4, 20),
        classificationStatus: 'permanently_failed',
        classificationAttempts: 3,
      );

      final classifier = _FakeClassifier([]);
      final worker = buildWorker(classifier: classifier);

      await worker.processPending();

      expect(classifier.calls, isEmpty);
      expect(storage.getLogEntry('e-burned')!.classificationStatus,
          'permanently_failed');
    });

    test('classified entries are NOT re-processed', () async {
      await seed(
        id: 'e-done',
        loggedAt: DateTime.utc(2026, 4, 20),
        classificationStatus: 'classified',
        classificationAttempts: 1,
      );

      final classifier = _FakeClassifier([]);
      final worker = buildWorker(classifier: classifier);

      await worker.processPending();

      expect(classifier.calls, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Lifecycle — start/stop/dispose and the watch-driven debounce.
  // ---------------------------------------------------------------------------

  group('lifecycle', () {
    test('start() kicks off a catch-up pass on the microtask queue',
        () async {
      await seed(id: 'catch-up', loggedAt: DateTime.utc(2026, 4, 20));
      final classifier = _FakeClassifier(
          [_Response.ok(_stubResult('catch-up', type: 'meal'))]);
      final worker = buildWorker(classifier: classifier);

      worker.start();
      // Poll for the storage-side effect, not `classifier.calls`: the
      // calls list is populated at the top of classifier.classify, but
      // the update/Firestore-sync chain still has to settle. If we end
      // the test before updateLogEntryClassification completes,
      // teardown's resetForTest closes the box while the worker is
      // still writing to it.
      await _waitFor(() =>
          storage.getLogEntry('catch-up')?.classificationStatus ==
          'classified');

      expect(classifier.calls, ['catch-up']);
      expect(storage.getLogEntry('catch-up')!.type, 'meal');
      worker.stop();
    });

    test('watch event triggers a debounced processPending', () async {
      final classifier = _FakeClassifier([
        // Catch-up pass finds nothing.
        // After seed → box.watch emits → debounce → this response fires.
        _Response.ok(_stubResult('streamed')),
      ]);
      final worker = buildWorker(
        classifier: classifier,
        debounce: const Duration(milliseconds: 50),
      );
      worker.start();
      await _pumpEventLoop(); // catch-up with empty queue

      await seed(id: 'streamed', loggedAt: DateTime.utc(2026, 4, 20));
      // Debounce is 50ms; poll on the storage-side effect so we don't
      // end the test before updateLogEntryClassification has completed
      // (teardown would then resetForTest a box the worker is still
      // writing to).
      await _waitFor(() =>
          storage.getLogEntry('streamed')?.classificationStatus ==
          'classified');

      expect(classifier.calls, ['streamed']);
      worker.stop();
    });

    test('rapid watch events debounce — multiple saves within the window '
        'collapse to a single processPending batch', () async {
      final classifier = _FakeClassifier([
        _Response.ok(_stubResult('burst-1')),
        _Response.ok(_stubResult('burst-2')),
      ]);
      // A long debounce + stop() before it fires proves the three
      // pre-stop saves didn't kick three separate processPending
      // calls — no timing windows, no test-runner load sensitivity.
      final worker = buildWorker(
        classifier: classifier,
        debounce: const Duration(seconds: 5),
      );
      worker.start();
      await _pumpEventLoop();

      await seed(id: 'burst-1', loggedAt: DateTime.utc(2026, 4, 20, 10));
      await seed(id: 'burst-2', loggedAt: DateTime.utc(2026, 4, 20, 11));
      await seed(
          id: 'burst-3',
          loggedAt: DateTime.utc(2026, 4, 20, 12),
          classificationStatus: 'classified');

      // No classifier call yet — the 5s debounce hasn't fired.
      expect(classifier.calls, isEmpty);

      // Cancel the debounce by stopping before it fires, then kick
      // processPending directly. This confirms a single pass drains
      // all eligible entries in FIFO — i.e. what a single debounced
      // firing would do.
      worker.stop();
      await worker.processPending();

      expect(classifier.calls, ['burst-1', 'burst-2']);
    });

    test('stop() cancels watch and debounce — subsequent saves are ignored',
        () async {
      final classifier = _FakeClassifier([]);
      final worker = buildWorker(
        classifier: classifier,
        debounce: const Duration(milliseconds: 50),
      );
      worker.start();
      await _pumpEventLoop();
      expect(worker.hasWatchSubscriptionForTest, isTrue);

      worker.stop();
      expect(worker.hasWatchSubscriptionForTest, isFalse);

      await seed(id: 'after-stop', loggedAt: DateTime.utc(2026, 4, 20));
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(classifier.calls, isEmpty);
    });

    test('dispose() is idempotent and prevents start()', () async {
      final worker = buildWorker(classifier: _FakeClassifier([]));

      await worker.dispose();
      await worker.dispose();

      expect(() => worker.start(), throwsA(isA<StateError>()));
    });
  });
}

// -----------------------------------------------------------------------------
// _GateClassifier — lets a test delay the first call's completion so
// we can test the reentrancy guard.
// -----------------------------------------------------------------------------

class _GateClassifier implements LogEntryClassifier {
  _GateClassifier({required this.onCall});
  final Future<ClassificationResult> Function(String id) onCall;
  int callCount = 0;

  @override
  Future<ClassificationResult> classify({
    required LogEntry entry,
    required ClassificationContext context,
  }) async {
    callCount += 1;
    return onCall(entry.id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _pumpEventLoop() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Poll a predicate for up to [timeout], yielding between checks so
/// pending microtasks can run. More reliable than a fixed pump count
/// in tests that depend on `Future.microtask` + `async` chains —
/// under test-runner load the microtask queue can lag.
Future<void> _waitFor(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 2),
  Duration interval = const Duration(milliseconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException(
          '_waitFor predicate never satisfied within $timeout');
    }
    await Future<void>.delayed(interval);
  }
}
