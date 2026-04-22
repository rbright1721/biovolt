import 'package:biovolt/models/log_entry.dart';
import 'package:biovolt/services/firestore_sync.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke test for the LogEntry Firestore payload shape.
///
/// We deliberately don't stand up a Firebase test harness here — the
/// full sync flow is covered by manual verification (see Step 9 of
/// the Part 1 prompt) and the payload builder is a pure function
/// pulled out of [FirestoreSync] for exactly this kind of unit check.
void main() {
  test('buildLogEntryFirestorePayload contains all LogEntry fields plus syncedAt',
      () {
    final entry = LogEntry(
      id: 'fx-1',
      rawText: 'took 500mg NAC',
      occurredAt: DateTime.utc(2026, 4, 20, 8),
      loggedAt: DateTime.utc(2026, 4, 20, 8, 1),
      rawAudioPath: '/tmp/a.m4a',
      type: 'dose',
      structured: {'compound': 'NAC', 'amountMg': 500},
      classificationConfidence: 0.91,
      classificationStatus: 'classified',
      classificationError: null,
      classificationAttempts: 1,
      hrBpm: 62,
      hrvMs: 48,
      gsrUs: 2.1,
      skinTempF: 97.8,
      spo2Percent: 98,
      ecgHrBpm: 63,
      protocolIdAtTime: 'proto-glynac',
      tags: ['post-fast'],
      userNotes: 'felt great',
    );

    final payload = buildLogEntryFirestorePayload(entry);

    expect(payload['id'], 'fx-1');
    expect(payload['rawText'], 'took 500mg NAC');
    expect(payload['occurredAt'], entry.occurredAt.toIso8601String());
    expect(payload['loggedAt'], entry.loggedAt.toIso8601String());
    expect(payload['rawAudioPath'], '/tmp/a.m4a');
    expect(payload['type'], 'dose');
    expect(payload['structured'],
        {'compound': 'NAC', 'amountMg': 500});
    expect(payload['classificationConfidence'], 0.91);
    expect(payload['classificationStatus'], 'classified');
    expect(payload['classificationError'], isNull);
    expect(payload['classificationAttempts'], 1);
    expect(payload['hrBpm'], 62);
    expect(payload['hrvMs'], 48);
    expect(payload['gsrUs'], 2.1);
    expect(payload['skinTempF'], 97.8);
    expect(payload['spo2Percent'], 98);
    expect(payload['ecgHrBpm'], 63);
    expect(payload['protocolIdAtTime'], 'proto-glynac');
    expect(payload['tags'], ['post-fast']);
    expect(payload['userNotes'], 'felt great');

    // syncedAt uses Firestore's server-timestamp sentinel.
    expect(payload['syncedAt'], isA<FieldValue>());

    // All 20 model fields + syncedAt = 21 keys, nothing extra.
    expect(payload.length, 21);
  });

  test('payload preserves nulls rather than dropping missing fields',
      () {
    final bare = LogEntry(
      id: 'fx-2',
      rawText: '',
      occurredAt: DateTime.utc(2026, 4, 20),
      loggedAt: DateTime.utc(2026, 4, 20),
    );
    final payload = buildLogEntryFirestorePayload(bare);

    expect(payload['rawText'], '');
    expect(payload['rawAudioPath'], isNull);
    expect(payload['structured'], isNull);
    expect(payload['classificationConfidence'], isNull);
    expect(payload['hrBpm'], isNull);
    expect(payload['protocolIdAtTime'], isNull);
    expect(payload['tags'], isNull);
    expect(payload['userNotes'], isNull);
    // Classifier defaults from the model stick around.
    expect(payload['type'], 'other');
    expect(payload['classificationStatus'], 'pending');
    expect(payload['classificationAttempts'], 0);
    // Same 21 keys — missing values become nulls, not omissions.
    expect(payload.length, 21);
  });
}
