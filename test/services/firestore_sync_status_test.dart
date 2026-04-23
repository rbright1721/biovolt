import 'package:biovolt/services/firestore_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatSyncStatus (pure formatter)', () {
    final now = DateTime.utc(2026, 4, 22, 12, 0);

    test('returns "No sync yet" when no ops have run', () {
      final s = formatSyncStatus(
        lastError: null,
        lastErrorAt: null,
        lastSuccessfulSyncAt: null,
        now: now,
      );
      expect(s, 'No sync yet');
    });

    test('returns OK with seconds-precision when sync was just now', () {
      final s = formatSyncStatus(
        lastError: null,
        lastErrorAt: null,
        lastSuccessfulSyncAt:
            now.subtract(const Duration(seconds: 5)),
        now: now,
      );
      expect(s, 'OK · last sync 5s ago');
    });

    test('returns OK with minute precision past 60s', () {
      final s = formatSyncStatus(
        lastError: null,
        lastErrorAt: null,
        lastSuccessfulSyncAt:
            now.subtract(const Duration(minutes: 3)),
        now: now,
      );
      expect(s, 'OK · last sync 3m ago');
    });

    test('returns OK with hour precision past 60m', () {
      final s = formatSyncStatus(
        lastError: null,
        lastErrorAt: null,
        lastSuccessfulSyncAt:
            now.subtract(const Duration(hours: 4)),
        now: now,
      );
      expect(s, 'OK · last sync 4h ago');
    });

    test('returns Error message + age when last op failed', () {
      final s = formatSyncStatus(
        lastError: 'PERMISSION_DENIED',
        lastErrorAt: now.subtract(const Duration(minutes: 2)),
        lastSuccessfulSyncAt:
            now.subtract(const Duration(hours: 1)),
        now: now,
      );
      expect(s, 'Error · PERMISSION_DENIED (2m ago)');
    });
  });

  group('FirestoreSync state tracking', () {
    setUp(() {
      FirestoreSync().resetSyncStatusForTest();
    });

    test('successful op sets lastSuccessfulSyncAt', () {
      final at = DateTime.utc(2026, 4, 22, 12);
      FirestoreSync().recordSuccessForTest(at);
      expect(FirestoreSync().lastSuccessfulSyncAt, at);
      expect(FirestoreSync().lastError, isNull);
    });

    test('failed op sets lastError + lastErrorAt', () {
      final at = DateTime.utc(2026, 4, 22, 12);
      FirestoreSync().recordErrorForTest('NetworkError', at);
      expect(FirestoreSync().lastError, 'NetworkError');
      expect(FirestoreSync().lastErrorAt, at);
    });

    test('success after failure clears the stale error', () {
      final errAt = DateTime.utc(2026, 4, 22, 12, 0);
      final okAt = DateTime.utc(2026, 4, 22, 12, 5);
      FirestoreSync().recordErrorForTest('boom', errAt);
      FirestoreSync().recordSuccessForTest(okAt);
      expect(FirestoreSync().lastError, isNull);
      expect(FirestoreSync().lastErrorAt, isNull);
      expect(FirestoreSync().lastSuccessfulSyncAt, okAt);
    });

    test('older success does NOT clear a newer error', () {
      // Edge case: clock skew or out-of-order callback delivery —
      // the success timestamp is before the error timestamp.
      final okAt = DateTime.utc(2026, 4, 22, 12, 0);
      final errAt = DateTime.utc(2026, 4, 22, 12, 5);
      FirestoreSync().recordSuccessForTest(okAt);
      FirestoreSync().recordErrorForTest('later boom', errAt);
      // recordError doesn't clear success — error stays visible.
      expect(FirestoreSync().lastError, 'later boom');
      expect(FirestoreSync().lastErrorAt, errAt);
      expect(FirestoreSync().lastSuccessfulSyncAt, okAt);
    });

    test('statusDescription reflects the latest state', () {
      final at = DateTime.now().subtract(const Duration(seconds: 2));
      FirestoreSync().recordSuccessForTest(at);
      expect(FirestoreSync().statusDescription, startsWith('OK · last sync'));
    });
  });
}
