import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../models/active_protocol.dart';
import '../models/log_entry.dart';

// =============================================================================
// classifyLogEntry client wrapper.
//
// Pure callable — no queue, no retry, no state. Given a [LogEntry] and
// [ClassificationContext], invoke the deployed `classifyLogEntry` Cloud
// Function and return a [ClassificationResult] or throw one of the
// [LogEntryClassifierException] subclasses.
//
// Retry and status-machine bookkeeping live in [LogEntryWorker]. Keeping
// them separate lets Part 2.5 swap the server-side stub for a real
// Claude classifier without touching the worker, and lets tests for each
// layer stay tight.
//
// Request/response contract is frozen in Part 2 — see the stub at
// `functions/classify_log_entry.js` for the server side.
// =============================================================================

/// Context bundle sent alongside the entry. The classifier uses this to
/// disambiguate ("was this BPC-157 dose intentional, or a note about
/// soreness?") and to recognize meals inside an eat-window.
class ClassificationContext {
  const ClassificationContext({
    required this.activeProtocols,
    this.fastingHours,
    this.recentEntries = const [],
  });

  final List<ActiveProtocol> activeProtocols;

  /// Hours since last meal. Null when the app can't infer it.
  final double? fastingHours;

  /// Most recent classified entries — up to ~5 — so the classifier has
  /// conversational history for cross-reference.
  final List<LogEntry> recentEntries;
}

/// Parsed success response from the Cloud Function.
class ClassificationResult {
  const ClassificationResult({
    required this.logEntryId,
    required this.type,
    required this.structured,
    required this.confidence,
    required this.modelVersion,
    required this.classifiedAt,
  });

  final String logEntryId;
  final String type;
  final Map<String, dynamic>? structured;
  final double confidence;
  final String modelVersion;
  final DateTime classifiedAt;

  /// Parse the raw map returned by `HttpsCallable.call()`. Throws
  /// [FormatException] if any required field is missing or wrong-typed;
  /// the calling classifier wraps that into a
  /// [ClassifierTransientException] so the worker treats parse failure
  /// the same as a network hiccup.
  factory ClassificationResult.fromResponse(Map<String, dynamic> r) {
    final logEntryId = r['logEntryId'];
    final type = r['type'];
    final confidence = r['confidence'];
    final modelVersion = r['modelVersion'];
    final classifiedAt = r['classifiedAt'];

    if (logEntryId is! String || logEntryId.isEmpty) {
      throw const FormatException(
          'classifyLogEntry response missing logEntryId');
    }
    if (type is! String || type.isEmpty) {
      throw const FormatException('classifyLogEntry response missing type');
    }
    if (confidence is! num) {
      throw const FormatException(
          'classifyLogEntry response missing confidence');
    }
    if (modelVersion is! String) {
      throw const FormatException(
          'classifyLogEntry response missing modelVersion');
    }
    if (classifiedAt is! String) {
      throw const FormatException(
          'classifyLogEntry response missing classifiedAt');
    }
    final parsedTs = DateTime.tryParse(classifiedAt);
    if (parsedTs == null) {
      throw FormatException(
          'classifyLogEntry classifiedAt is not ISO-8601: $classifiedAt');
    }

    final rawStructured = r['structured'];
    Map<String, dynamic>? structured;
    if (rawStructured == null) {
      structured = null;
    } else if (rawStructured is Map) {
      // The callable plugin may return nested maps as `Map<Object?,
      // Object?>` on Android — re-cast explicitly so downstream readers
      // can index with String keys.
      structured = Map<String, dynamic>.from(
          rawStructured.map((k, v) => MapEntry(k.toString(), v)));
    } else {
      throw const FormatException(
          'classifyLogEntry response "structured" must be an object or null');
    }

    return ClassificationResult(
      logEntryId: logEntryId,
      type: type,
      structured: structured,
      confidence: confidence.toDouble(),
      modelVersion: modelVersion,
      classifiedAt: parsedTs,
    );
  }
}

// -----------------------------------------------------------------------------
// Exception hierarchy.
// -----------------------------------------------------------------------------

abstract class LogEntryClassifierException implements Exception {
  const LogEntryClassifierException(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

/// Server returned `unauthenticated`. Worker marks entry `skipped`,
/// does NOT increment attempts, and stops processing — the rest of the
/// queue will hit the same wall.
class ClassifierUnauthenticatedException
    extends LogEntryClassifierException {
  const ClassifierUnauthenticatedException([
    super.message = 'Classifier: not signed in.',
  ]);
}

/// Server returned `invalid-argument`. The request will always fail
/// the same way. Worker marks entry `permanently_failed` immediately.
class ClassifierInvalidArgumentException
    extends LogEntryClassifierException {
  const ClassifierInvalidArgumentException(super.message);
}

/// Network error, timeout, internal server error, parse failure,
/// unknown status code. Worker marks entry `failed` and retries until
/// `classificationAttempts >= 3`, at which point it becomes
/// `permanently_failed`.
class ClassifierTransientException extends LogEntryClassifierException {
  const ClassifierTransientException(super.message);
}

// -----------------------------------------------------------------------------
// LogEntryClassifier.
// -----------------------------------------------------------------------------

class LogEntryClassifier {
  LogEntryClassifier({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: _region);

  static const _region = 'us-central1';
  static const _functionName = 'classifyLogEntry';

  // Callable timeout matches the server-side 30s timeoutSeconds declared
  // in functions/classify_log_entry.js. Part 2.5's real Claude call may
  // need this bumped — revisit when the stub comes out.
  static const Duration _callTimeout = Duration(seconds: 30);

  final FirebaseFunctions _functions;

  Future<ClassificationResult> classify({
    required LogEntry entry,
    required ClassificationContext context,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        _functionName,
        options: HttpsCallableOptions(timeout: _callTimeout),
      );

      final payload = _buildPayload(entry: entry, context: context);
      final result = await callable.call(payload);

      final rawData = result.data;
      if (rawData is! Map) {
        throw const ClassifierTransientException(
            'classifyLogEntry returned a non-map response.');
      }
      // The callable plugin sometimes returns `Map<Object?, Object?>`
      // on Android; re-cast to String keys so the parser can index.
      final data = Map<String, dynamic>.from(
          rawData.map((k, v) => MapEntry(k.toString(), v)));

      try {
        return ClassificationResult.fromResponse(data);
      } on FormatException catch (e) {
        // A malformed payload is a server-side bug, not user-recoverable
        // per-entry. Treating it as transient lets the worker retry if
        // it's a flake, and eventually permanently_fail if it's
        // persistent.
        throw ClassifierTransientException(
            'Malformed classifier response: ${e.message}');
      }
    } on FirebaseFunctionsException catch (e) {
      throw _mapFirebaseError(e);
    } on TimeoutException catch (e) {
      throw ClassifierTransientException('Classifier timed out: $e');
    } on PlatformException catch (e) {
      // The callable plugin surfaces some failures (e.g., no network,
      // platform channel issues) as PlatformException rather than
      // FirebaseFunctionsException. Treat as transient.
      throw ClassifierTransientException(
          'Classifier platform error: ${e.code} ${e.message ?? ''}');
    } on LogEntryClassifierException {
      rethrow;
    } catch (e) {
      throw ClassifierTransientException('Classifier error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Request payload — matches the Part 2 committed schema verbatim.
  //
  //   logEntryId      non-empty string
  //   rawText         string (may be empty)
  //   occurredAt      ISO-8601
  //   vitals          object of number-or-null fields
  //   context.activeProtocols   list of protocol objects (see note below)
  //   context.fastingHours      number or null
  //   context.recentEntries     list of {type, rawText, occurredAt}
  //
  // ActiveProtocol note: the model doesn't carry `doseDisplay`,
  // `frequency`, or `measurementTargets`. We synthesize `doseDisplay`
  // from `doseMcg`+`route`, set the others to empty/empty-list. Part
  // 2's server validator only checks `activeProtocols` is an array;
  // item-level shape is loose, so this sends cleanly. Part 2.5 may
  // want real values here — tracked as follow-up.
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildPayload({
    required LogEntry entry,
    required ClassificationContext context,
  }) {
    return <String, dynamic>{
      'logEntryId': entry.id,
      'rawText': entry.rawText,
      'occurredAt': entry.occurredAt.toIso8601String(),
      'vitals': <String, dynamic>{
        'hrBpm': entry.hrBpm,
        'hrvMs': entry.hrvMs,
        'gsrUs': entry.gsrUs,
        'skinTempF': entry.skinTempF,
        'spo2Percent': entry.spo2Percent,
        'ecgHrBpm': entry.ecgHrBpm,
      },
      'context': <String, dynamic>{
        'activeProtocols': context.activeProtocols
            .map((p) => <String, dynamic>{
                  'id': p.id,
                  'name': p.name,
                  'type': p.type,
                  'cycleDay': p.currentCycleDay,
                  'cycleLength': p.cycleLengthDays,
                  'doseDisplay': _synthesizeDoseDisplay(p),
                  'route': p.route,
                  'frequency': '',
                  'measurementTargets': const <String>[],
                })
            .toList(),
        'fastingHours': context.fastingHours,
        'recentEntries': context.recentEntries
            .map((e) => <String, dynamic>{
                  'type': e.type,
                  'rawText': e.rawText,
                  'occurredAt': e.occurredAt.toIso8601String(),
                })
            .toList(),
      },
    };
  }

  static String _synthesizeDoseDisplay(ActiveProtocol p) {
    if (p.doseMcg <= 0) return '';
    final amount = p.doseMcg >= 1000
        ? '${(p.doseMcg / 1000).toStringAsFixed(2)}mg'
        : '${p.doseMcg.toStringAsFixed(0)}mcg';
    return '$amount ${p.route}'.trim();
  }

  LogEntryClassifierException _mapFirebaseError(
      FirebaseFunctionsException e) {
    final msg = e.message ?? e.code;
    switch (e.code) {
      case 'unauthenticated':
        return ClassifierUnauthenticatedException(msg);
      case 'invalid-argument':
        return ClassifierInvalidArgumentException(msg);
      case 'internal':
      case 'deadline-exceeded':
      case 'unavailable':
      case 'resource-exhausted':
      case 'cancelled':
      case 'unknown':
      default:
        return ClassifierTransientException(
            'Classifier ${e.code}: $msg');
    }
  }
}
