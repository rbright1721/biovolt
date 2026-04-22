import 'dart:async';

import 'package:biovolt/models/active_protocol.dart';
import 'package:biovolt/models/log_entry.dart';
import 'package:biovolt/services/log_entry_classifier.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// -----------------------------------------------------------------------------
// Fakes — `implements` + noSuchMethod lets us stub FirebaseFunctions without
// the platform-channel plumbing that a real instance requires.
// -----------------------------------------------------------------------------

class _FakeResult implements HttpsCallableResult {
  _FakeResult(this._data);
  final Object? _data;

  @override
  dynamic get data => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeCallable implements HttpsCallable {
  _FakeCallable({this.responseData, this.error});

  final Object? responseData;
  final Object? error;

  List<Object?> calls = [];

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    calls.add(parameters);
    if (error != null) throw error!;
    return _FakeResult(responseData) as HttpsCallableResult<T>;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeFunctions implements FirebaseFunctions {
  _FakeFunctions({this.callable});
  _FakeCallable? callable;
  String? lastName;
  HttpsCallableOptions? lastOptions;

  @override
  HttpsCallable httpsCallable(String name,
      {HttpsCallableOptions? options}) {
    lastName = name;
    lastOptions = options;
    return callable ?? _FakeCallable(responseData: <String, dynamic>{});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// -----------------------------------------------------------------------------
// Fixtures.
// -----------------------------------------------------------------------------

LogEntry _entry({
  String id = 'e-1',
  String rawText = 'took 500mg NAC',
}) =>
    LogEntry(
      id: id,
      rawText: rawText,
      occurredAt: DateTime.utc(2026, 4, 20, 12),
      loggedAt: DateTime.utc(2026, 4, 20, 12),
      hrBpm: 62,
      hrvMs: 48,
      gsrUs: 2.1,
      skinTempF: 97.8,
      spo2Percent: 98,
    );

ClassificationContext _ctx({
  List<ActiveProtocol>? activeProtocols,
  double? fastingHours,
  List<LogEntry>? recentEntries,
}) =>
    ClassificationContext(
      activeProtocols: activeProtocols ?? const [],
      fastingHours: fastingHours,
      recentEntries: recentEntries ?? const [],
    );

Map<String, dynamic> _validResponse({
  String id = 'e-1',
  String type = 'other',
  Map<String, dynamic>? structured,
  double confidence = 0.0,
  String modelVersion = 'stub-v0',
  String? classifiedAt,
}) =>
    <String, dynamic>{
      'logEntryId': id,
      'type': type,
      'structured': structured,
      'confidence': confidence,
      'modelVersion': modelVersion,
      'classifiedAt': classifiedAt ?? '2026-04-20T12:00:01.000Z',
    };

void main() {
  group('LogEntryClassifier happy path', () {
    test('valid response parses into ClassificationResult', () async {
      final callable = _FakeCallable(responseData: _validResponse(
        id: 'e-42',
        type: 'dose',
        structured: {'compound': 'NAC', 'amountMg': 500},
        confidence: 0.87,
        modelVersion: 'stub-v0',
      ));
      final classifier =
          LogEntryClassifier(functions: _FakeFunctions(callable: callable));

      final result = await classifier.classify(
        entry: _entry(id: 'e-42'),
        context: _ctx(),
      );

      expect(result.logEntryId, 'e-42');
      expect(result.type, 'dose');
      expect(result.structured, {'compound': 'NAC', 'amountMg': 500});
      expect(result.confidence, 0.87);
      expect(result.modelVersion, 'stub-v0');
      expect(result.classifiedAt.isUtc, isTrue);
    });

    test('payload contains all committed schema fields', () async {
      final callable = _FakeCallable(responseData: _validResponse());
      final functions = _FakeFunctions(callable: callable);
      final classifier = LogEntryClassifier(functions: functions);

      final protocol = ActiveProtocol(
        id: 'p-1',
        name: 'BPC-157',
        type: 'peptide',
        startDate: DateTime(2026, 4, 1),
        cycleLengthDays: 30,
        doseMcg: 250,
        route: 'sub-q',
        isActive: true,
      );
      final recent = _entry(id: 'recent-1', rawText: 'ate eggs');

      await classifier.classify(
        entry: _entry(),
        context: _ctx(
          activeProtocols: [protocol],
          fastingHours: 16.0,
          recentEntries: [recent],
        ),
      );

      expect(functions.lastName, 'classifyLogEntry');
      expect(functions.lastOptions?.timeout, const Duration(seconds: 30));

      final sent = callable.calls.single as Map;
      expect(sent['logEntryId'], 'e-1');
      expect(sent['rawText'], 'took 500mg NAC');
      expect(sent['occurredAt'], '2026-04-20T12:00:00.000Z');

      final vitals = sent['vitals'] as Map;
      expect(vitals['hrBpm'], 62);
      expect(vitals['hrvMs'], 48);
      expect(vitals['gsrUs'], 2.1);
      expect(vitals['skinTempF'], 97.8);
      expect(vitals['spo2Percent'], 98);
      expect(vitals.containsKey('ecgHrBpm'), isTrue);

      final context = sent['context'] as Map;
      expect(context['fastingHours'], 16.0);

      final protocols = context['activeProtocols'] as List;
      expect(protocols, hasLength(1));
      final p = protocols.single as Map;
      expect(p['id'], 'p-1');
      expect(p['name'], 'BPC-157');
      expect(p['type'], 'peptide');
      expect(p['cycleLength'], 30);
      // doseDisplay is synthesized — see note in classifier.
      expect((p['doseDisplay'] as String).contains('250mcg'), isTrue);
      expect(p['measurementTargets'], const <String>[]);

      final recents = context['recentEntries'] as List;
      expect(recents, hasLength(1));
      expect((recents.single as Map)['rawText'], 'ate eggs');
    });

    // -----------------------------------------------------------------
    // Schema extension payload — real fields vs. synthesis fallback.
    // -----------------------------------------------------------------

    test('payload prefers real doseDisplay when set', () async {
      final callable = _FakeCallable(responseData: _validResponse());
      final classifier =
          LogEntryClassifier(functions: _FakeFunctions(callable: callable));

      final protocol = ActiveProtocol(
        id: 'p-real',
        name: 'NAC',
        type: 'supplement',
        startDate: DateTime(2026, 4, 1),
        cycleLengthDays: 30,
        doseMcg: 500,
        route: 'oral',
        isActive: true,
        doseDisplay: '2 capsules',
      );
      await classifier.classify(
          entry: _entry(), context: _ctx(activeProtocols: [protocol]));

      final sent = callable.calls.single as Map;
      final p = (sent['context']['activeProtocols'] as List).single
          as Map;
      expect(p['doseDisplay'], '2 capsules',
          reason: 'real field wins over synthesis');
    });

    test('payload falls back to synthesized doseDisplay when the real field '
        'is null', () async {
      final callable = _FakeCallable(responseData: _validResponse());
      final classifier =
          LogEntryClassifier(functions: _FakeFunctions(callable: callable));

      final protocol = ActiveProtocol(
        id: 'p-synth',
        name: 'BPC-157',
        type: 'peptide',
        startDate: DateTime(2026, 4, 1),
        cycleLengthDays: 30,
        doseMcg: 250,
        route: 'sub-q',
        isActive: true,
        // doseDisplay intentionally unset → synthesis path.
      );
      await classifier.classify(
          entry: _entry(), context: _ctx(activeProtocols: [protocol]));

      final sent = callable.calls.single as Map;
      final p = (sent['context']['activeProtocols'] as List).single
          as Map;
      expect((p['doseDisplay'] as String).contains('250mcg'), isTrue,
          reason: 'synthesised fallback from doseMcg + route');
      expect((p['doseDisplay'] as String).contains('sub-q'), isTrue);
    });

    test('payload sends real measurementTargets when set', () async {
      final callable = _FakeCallable(responseData: _validResponse());
      final classifier =
          LogEntryClassifier(functions: _FakeFunctions(callable: callable));

      final protocol = ActiveProtocol(
        id: 'p-mt',
        name: 'Creatine',
        type: 'supplement',
        startDate: DateTime(2026, 4, 1),
        cycleLengthDays: 0,
        doseMcg: 5000,
        route: 'oral',
        isActive: true,
        measurementTargets: const ['recovery', 'energy'],
        frequency: 'once_daily',
      );
      await classifier.classify(
          entry: _entry(), context: _ctx(activeProtocols: [protocol]));

      final sent = callable.calls.single as Map;
      final p = (sent['context']['activeProtocols'] as List).single
          as Map;
      expect(p['measurementTargets'], ['recovery', 'energy']);
      expect(p['frequency'], 'once_daily');
    });

    test('payload sends empty array / empty string when extension '
        'fields are null', () async {
      final callable = _FakeCallable(responseData: _validResponse());
      final classifier =
          LogEntryClassifier(functions: _FakeFunctions(callable: callable));

      final protocol = ActiveProtocol(
        id: 'p-legacy',
        name: 'legacy',
        type: 'supplement',
        startDate: DateTime(2026, 4, 1),
        cycleLengthDays: 30,
        doseMcg: 100,
        route: 'oral',
        isActive: true,
        // measurementTargets and frequency intentionally null.
      );
      await classifier.classify(
          entry: _entry(), context: _ctx(activeProtocols: [protocol]));

      final sent = callable.calls.single as Map;
      final p = (sent['context']['activeProtocols'] as List).single
          as Map;
      expect(p['measurementTargets'], const <String>[]);
      expect(p['frequency'], '');
    });

    test('null structured in response maps to null', () async {
      final callable = _FakeCallable(
          responseData: _validResponse(structured: null));
      final classifier =
          LogEntryClassifier(functions: _FakeFunctions(callable: callable));

      final result =
          await classifier.classify(entry: _entry(), context: _ctx());
      expect(result.structured, isNull);
    });
  });

  group('LogEntryClassifier error mapping', () {
    Future<void> expectExceptionType(
      Object thrown,
      Type expectedType,
    ) async {
      final callable = _FakeCallable(error: thrown);
      final classifier =
          LogEntryClassifier(functions: _FakeFunctions(callable: callable));

      await expectLater(
        classifier.classify(entry: _entry(), context: _ctx()),
        throwsA(isA<LogEntryClassifierException>().having(
          (e) => e.runtimeType,
          'runtimeType',
          expectedType,
        )),
      );
    }

    test('FirebaseFunctionsException code=unauthenticated → '
        'ClassifierUnauthenticatedException', () async {
      await expectExceptionType(
        FirebaseFunctionsException(
            code: 'unauthenticated', message: 'Must be signed in.'),
        ClassifierUnauthenticatedException,
      );
    });

    test('FirebaseFunctionsException code=invalid-argument → '
        'ClassifierInvalidArgumentException', () async {
      await expectExceptionType(
        FirebaseFunctionsException(
            code: 'invalid-argument', message: 'logEntryId is required'),
        ClassifierInvalidArgumentException,
      );
    });

    test('FirebaseFunctionsException code=internal → ClassifierTransient',
        () async {
      await expectExceptionType(
        FirebaseFunctionsException(
            code: 'internal', message: 'server exploded'),
        ClassifierTransientException,
      );
    });

    test('FirebaseFunctionsException code=deadline-exceeded → transient',
        () async {
      await expectExceptionType(
        FirebaseFunctionsException(
            code: 'deadline-exceeded', message: 'too slow'),
        ClassifierTransientException,
      );
    });

    test('FirebaseFunctionsException unknown code → transient', () async {
      await expectExceptionType(
        FirebaseFunctionsException(
            code: 'some-new-code', message: 'new thing'),
        ClassifierTransientException,
      );
    });

    test('PlatformException → transient', () async {
      await expectExceptionType(
        PlatformException(code: 'channel-error', message: 'no channel'),
        ClassifierTransientException,
      );
    });

    test('TimeoutException → transient', () async {
      await expectExceptionType(
        TimeoutException('timed out'),
        ClassifierTransientException,
      );
    });

    test('generic Exception → transient', () async {
      await expectExceptionType(
        Exception('oops'),
        ClassifierTransientException,
      );
    });

    test('non-map response → transient', () async {
      final callable = _FakeCallable(responseData: 'not a map');
      final classifier =
          LogEntryClassifier(functions: _FakeFunctions(callable: callable));

      await expectLater(
        classifier.classify(entry: _entry(), context: _ctx()),
        throwsA(isA<ClassifierTransientException>()),
      );
    });

    test('missing logEntryId in response → transient', () async {
      final bad = _validResponse();
      bad.remove('logEntryId');
      final callable = _FakeCallable(responseData: bad);
      final classifier =
          LogEntryClassifier(functions: _FakeFunctions(callable: callable));

      await expectLater(
        classifier.classify(entry: _entry(), context: _ctx()),
        throwsA(isA<ClassifierTransientException>().having(
          (e) => e.message,
          'message',
          contains('logEntryId'),
        )),
      );
    });

    test('unparseable classifiedAt → transient', () async {
      final callable = _FakeCallable(responseData: _validResponse(
        classifiedAt: 'not a date',
      ));
      final classifier =
          LogEntryClassifier(functions: _FakeFunctions(callable: callable));

      await expectLater(
        classifier.classify(entry: _entry(), context: _ctx()),
        throwsA(isA<ClassifierTransientException>().having(
          (e) => e.message,
          'message',
          contains('classifiedAt'),
        )),
      );
    });

    test('confidence as string (wrong type) → transient', () async {
      final bad = _validResponse();
      bad['confidence'] = 'not a number';
      final callable = _FakeCallable(responseData: bad);
      final classifier =
          LogEntryClassifier(functions: _FakeFunctions(callable: callable));

      await expectLater(
        classifier.classify(entry: _entry(), context: _ctx()),
        throwsA(isA<ClassifierTransientException>()),
      );
    });
  });
}
