import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/log_entry.dart';
import 'context_inferrer.dart';
import 'firestore_sync.dart';
import 'log_entry_classifier.dart';
import 'storage_service.dart';

// =============================================================================
// LogEntryWorker.
//
// Consumes the classification backlog. On [start]:
//   * fires an immediate catch-up pass for any entries that landed in
//     'pending' / 'skipped' / retryable-'failed' before the app launched,
//   * subscribes to [StorageService.watchLogEntries] so any new entry
//     (or classifier-state update) kicks off another pass after a short
//     debounce.
//
// Sequential, FIFO. No parallelism — even if the backlog is large, a
// real classifier call takes ~1–3s and the user experience doesn't
// benefit from concurrent requests against a single Cloud Run instance.
//
// Lifetime: app foreground only. No WorkManager, no BGTaskScheduler.
// The catch-up pass on launch is the only "background-adjacent"
// behavior.
//
// Retry policy is encoded here, not in [LogEntryClassifier] — the
// classifier is a pure callable wrapper. See the status transitions
// in [_markFailure] and [_handleResult] for the full state machine.
// =============================================================================

class LogEntryWorker {
  LogEntryWorker({
    required StorageService storage,
    required LogEntryClassifier classifier,
    required ContextInferrer contextInferrer,
    FirestoreSync? firestoreSync,
    Duration debounce = const Duration(milliseconds: 500),
  })  : _storage = storage,
        _classifier = classifier,
        _contextInferrer = contextInferrer,
        _sync = firestoreSync ?? FirestoreSync(),
        _debounce = debounce;

  final StorageService _storage;
  final LogEntryClassifier _classifier;
  final ContextInferrer _contextInferrer;
  final FirestoreSync _sync;
  final Duration _debounce;

  // Ceiling must stay in sync with `_maxClassificationAttempts` in
  // StorageService — that's the source of truth for the queue query,
  // and this is the source of truth for the transition to
  // `permanently_failed`. Both need to agree.
  static const int _maxAttempts = 3;

  /// Maximum number of already-classified entries to include in the
  /// context bundle. Trades off prompt length against the classifier
  /// having enough conversational history. Tuned for the stub; Part
  /// 2.5 may want to revisit once real Claude prompts land.
  static const int _recentEntryWindow = 5;

  StreamSubscription<BoxEvent>? _watchSub;
  Timer? _debounceTimer;
  bool _processing = false;
  bool _disposed = false;

  /// Start the worker. Idempotent — calling twice without [stop] first
  /// replaces the subscription rather than doubling up.
  void start() {
    if (_disposed) {
      throw StateError('LogEntryWorker cannot be start()ed after dispose.');
    }
    _watchSub?.cancel();
    _watchSub = _storage.watchLogEntries().listen((_) {
      _scheduleProcessingAfterDebounce();
    });

    // Fire the catch-up pass on the next event-loop tick so main() can
    // finish wiring before we start hammering Firestore.
    Future.microtask(() {
      if (_disposed) return;
      unawaited(processPending());
    });
  }

  /// Stop processing. Cancels the watch subscription and any pending
  /// debounce timer. Any in-flight classify call races to completion
  /// on the current event loop turn — its result update may or may not
  /// land depending on timing, and that's fine: the entry stays
  /// `pending` and re-enters the queue on the next launch.
  void stop() {
    _watchSub?.cancel();
    _watchSub = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Fully tear down. After this the worker cannot be restarted — a
  /// new instance must be created. Safe to call multiple times.
  Future<void> dispose() async {
    _disposed = true;
    stop();
  }

  /// Manually kick a processing pass. Safe to call from tests, from
  /// UI retry buttons, or from lifecycle hooks — the reentrancy guard
  /// makes this idempotent while a pass is already running.
  Future<void> processPending() async {
    if (_processing || _disposed) return;
    _processing = true;

    try {
      while (!_disposed) {
        final queue = _storage.getPendingClassification();
        if (queue.isEmpty) break;

        final entry = queue.first;
        final shouldStopEarly = await _classifyOne(entry);
        if (shouldStopEarly) {
          // Environmental or network-wide issue — don't hammer the
          // remaining queue with the same failure. Next watch event or
          // next launch will retry.
          break;
        }
      }
    } finally {
      _processing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // One-entry pipeline. Returns `true` if the caller should stop
  // processing the rest of the queue (unauthenticated, transient
  // network-wide failure).
  // ---------------------------------------------------------------------------

  Future<bool> _classifyOne(LogEntry entry) async {
    final context = _buildContext();

    try {
      final result = await _classifier.classify(
        entry: entry,
        context: context,
      );
      // Dispose-aware: if the app is tearing down while a call was in
      // flight, don't write to a closing Hive box.
      if (_disposed) return true;
      await _handleSuccess(entry.id, result);
      return false;
    } on ClassifierUnauthenticatedException catch (e) {
      if (_disposed) return true;
      debugPrint(
          'LogEntryWorker: unauthenticated — marking ${entry.id} skipped');
      await _safeUpdate(() =>
          _storage.markLogEntrySkipped(entry.id, error: e.message));
      return true;
    } on ClassifierInvalidArgumentException catch (e) {
      if (_disposed) return false;
      debugPrint(
          'LogEntryWorker: invalid-argument — permanently_failing '
          '${entry.id}: ${e.message}');
      await _markFailure(
        entry: entry,
        status: 'permanently_failed',
        error: e.message,
      );
      // Continue — this is entry-specific, the next entry may succeed.
      return false;
    } on ClassifierTransientException catch (e) {
      if (_disposed) return true;
      final willExhaust =
          entry.classificationAttempts + 1 >= _maxAttempts;
      final status = willExhaust ? 'permanently_failed' : 'failed';
      debugPrint(
          'LogEntryWorker: transient — ${entry.id} → $status '
          '(attempt ${entry.classificationAttempts + 1}/$_maxAttempts): '
          '${e.message}');
      await _markFailure(
        entry: entry,
        status: status,
        error: e.message,
      );
      return true;
    } catch (e, stack) {
      if (_disposed) return true;
      // Defense-in-depth: LogEntryClassifier should have wrapped
      // anything it throws, but just in case — treat as transient.
      debugPrint('LogEntryWorker: unexpected error on ${entry.id}: $e');
      debugPrint('$stack');
      await _markFailure(
        entry: entry,
        status: entry.classificationAttempts + 1 >= _maxAttempts
            ? 'permanently_failed'
            : 'failed',
        error: 'unexpected: $e',
      );
      return true;
    }
  }

  /// Swallow HiveErrors from storage writes during teardown. When the
  /// app disposes (or tests call resetForTest) while a classify call
  /// was in flight, the storage box closes underneath us. Propagating
  /// those errors would crash the event loop; they're safe to eat here
  /// because the entry stays in its prior state and will retry on the
  /// next launch.
  Future<void> _safeUpdate(Future<void> Function() update) async {
    try {
      await update();
    } catch (e) {
      if (_disposed) {
        debugPrint(
            'LogEntryWorker: suppressing post-dispose storage error: $e');
        return;
      }
      rethrow;
    }
  }

  Future<void> _handleSuccess(
      String id, ClassificationResult result) async {
    await _safeUpdate(() => _storage.updateLogEntryClassification(
          id,
          type: result.type,
          structured: result.structured,
          confidence: result.confidence,
          status: 'classified',
        ));
    if (_disposed) return;

    // Match the existing bookmark sync pattern (Step 6 — Option B):
    // FirestoreSync lives at the call site, not inside StorageService,
    // mirroring how saveBookmark is written to Hive in storage and
    // synced from the capture sheet. Read the freshly-written entry
    // back so the synced payload reflects the classifier update.
    final updated = _storage.getLogEntry(id);
    if (updated != null) {
      unawaited(_sync.writeLogEntry(updated));
    }
  }

  Future<void> _markFailure({
    required LogEntry entry,
    required String status,
    required String error,
  }) async {
    await _safeUpdate(() => _storage.updateLogEntryClassification(
          entry.id,
          // Keep the existing type — a failed classify shouldn't
          // overwrite a previous classifier's verdict (edge case:
          // transient after a user_corrected entry).
          type: entry.type,
          // Same reasoning — preserve any prior structured data.
          structured: entry.structured,
          confidence: 0.0,
          status: status,
          error: error,
        ));
    // No Firestore sync on failure — the server already knows the
    // request was malformed or dropped; writing a "failed" record on
    // top of the existing doc would just overwrite good prior state
    // with a transient error. Next success will re-sync.
  }

  ClassificationContext _buildContext() {
    final inferred = _contextInferrer.infer();
    final recent = _storage
        .getAllLogEntries()
        .where((e) => e.classificationStatus == 'classified')
        .take(_recentEntryWindow)
        .toList();
    return ClassificationContext(
      activeProtocols: inferred.activeProtocols,
      fastingHours: inferred.fastingHours,
      recentEntries: recent,
    );
  }

  void _scheduleProcessingAfterDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      if (_disposed) return;
      unawaited(processPending());
    });
  }

  // ---------------------------------------------------------------------------
  // Test-only accessors.
  // ---------------------------------------------------------------------------

  @visibleForTesting
  bool get isProcessingForTest => _processing;

  @visibleForTesting
  bool get hasWatchSubscriptionForTest => _watchSub != null;
}
