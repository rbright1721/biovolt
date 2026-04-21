import 'package:biovolt/models/log_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogEntry construction', () {
    test('required-only fields get sensible defaults', () {
      final entry = LogEntry(id: 'id-1', rawText: 'took 500mg NAC');

      expect(entry.id, 'id-1');
      expect(entry.rawText, 'took 500mg NAC');
      // When neither is supplied, loggedAt defaults to now and
      // occurredAt mirrors it exactly — the factory computes `now` once
      // so the two share a single DateTime instance rather than
      // drifting by a tick.
      expect(entry.occurredAt, entry.loggedAt);
      expect(entry.type, 'other');
      expect(entry.classificationStatus, 'pending');
      expect(entry.classificationAttempts, 0);
      expect(entry.classificationConfidence, isNull);
      expect(entry.classificationError, isNull);
      expect(entry.structured, isNull);
      expect(entry.rawAudioPath, isNull);
      expect(entry.hrBpm, isNull);
      expect(entry.hrvMs, isNull);
      expect(entry.gsrUs, isNull);
      expect(entry.skinTempF, isNull);
      expect(entry.spo2Percent, isNull);
      expect(entry.ecgHrBpm, isNull);
      expect(entry.protocolIdAtTime, isNull);
      expect(entry.tags, isNull);
      expect(entry.userNotes, isNull);
    });

    test(
        'occurredAt defaults to the supplied loggedAt when only loggedAt given',
        () {
      final t = DateTime(2026, 4, 20, 12, 0);
      final entry =
          LogEntry(id: 'id-2', rawText: 'x', loggedAt: t);
      expect(entry.loggedAt, t);
      expect(entry.occurredAt, t);
    });

    test('occurredAt and loggedAt stay independent when both supplied', () {
      final occurred = DateTime(2026, 4, 20, 9, 0);
      final logged = DateTime(2026, 4, 20, 12, 30);
      final entry = LogEntry(
        id: 'id-3',
        rawText: 'backdated note',
        occurredAt: occurred,
        loggedAt: logged,
      );
      expect(entry.occurredAt, occurred);
      expect(entry.loggedAt, logged);
    });
  });

  group('LogEntry JSON round-trip', () {
    test('all fields including structured Map<String,dynamic> preserved', () {
      final original = LogEntry(
        id: 'roundtrip-1',
        rawText: 'ate 3 eggs and avocado',
        occurredAt: DateTime.utc(2026, 4, 20, 8, 30),
        loggedAt: DateTime.utc(2026, 4, 20, 8, 32),
        rawAudioPath: '/tmp/audio.m4a',
        type: 'meal',
        structured: {
          'description': '3 eggs, 1 avocado',
          'proteinG': 21,
          'fatG': 30,
          'mealKind': 'breakfast',
          'nested': {'kcal': 450},
        },
        classificationConfidence: 0.87,
        classificationStatus: 'classified',
        classificationError: null,
        classificationAttempts: 1,
        hrBpm: 62.4,
        hrvMs: 55.0,
        gsrUs: 1.2,
        skinTempF: 97.8,
        spo2Percent: 98.0,
        ecgHrBpm: 63.1,
        protocolIdAtTime: 'protocol-glynac',
        tags: ['fasted-broken', 'breakfast'],
        userNotes: 'felt hungry earlier than usual',
      );

      final roundTripped = LogEntry.fromJson(original.toJson());

      expect(roundTripped.id, original.id);
      expect(roundTripped.rawText, original.rawText);
      expect(roundTripped.occurredAt, original.occurredAt);
      expect(roundTripped.loggedAt, original.loggedAt);
      expect(roundTripped.rawAudioPath, original.rawAudioPath);
      expect(roundTripped.type, original.type);
      expect(roundTripped.structured, original.structured);
      // Sanity: nested map survives.
      expect(
          (roundTripped.structured!['nested'] as Map)['kcal'], 450);
      expect(roundTripped.classificationConfidence,
          original.classificationConfidence);
      expect(roundTripped.classificationStatus,
          original.classificationStatus);
      expect(roundTripped.classificationError,
          original.classificationError);
      expect(roundTripped.classificationAttempts,
          original.classificationAttempts);
      expect(roundTripped.hrBpm, original.hrBpm);
      expect(roundTripped.hrvMs, original.hrvMs);
      expect(roundTripped.gsrUs, original.gsrUs);
      expect(roundTripped.skinTempF, original.skinTempF);
      expect(roundTripped.spo2Percent, original.spo2Percent);
      expect(roundTripped.ecgHrBpm, original.ecgHrBpm);
      expect(roundTripped.protocolIdAtTime, original.protocolIdAtTime);
      expect(roundTripped.tags, original.tags);
      expect(roundTripped.userNotes, original.userNotes);
    });

    test('defaults are preserved when fields omitted in JSON', () {
      final minimal = {
        'id': 'min-1',
        'occurredAt': '2026-04-20T10:00:00.000Z',
        'loggedAt': '2026-04-20T10:00:00.000Z',
        'rawText': 'x',
      };
      final parsed = LogEntry.fromJson(minimal);
      expect(parsed.type, 'other');
      expect(parsed.classificationStatus, 'pending');
      expect(parsed.classificationAttempts, 0);
    });
  });

  group('LogEntry.copyWith', () {
    test('classification updates leave other fields untouched', () {
      final original = LogEntry(
        id: 'cw-1',
        rawText: 'original text',
        occurredAt: DateTime(2026, 4, 20),
        loggedAt: DateTime(2026, 4, 20),
        tags: ['original'],
        userNotes: 'original notes',
        hrBpm: 60.0,
      );

      final updated = original.copyWith(
        type: 'meal',
        classificationStatus: 'classified',
        classificationConfidence: 0.9,
        classificationAttempts: 1,
        structured: {'description': 'eggs'},
      );

      // Classifier-touched fields changed.
      expect(updated.type, 'meal');
      expect(updated.classificationStatus, 'classified');
      expect(updated.classificationConfidence, 0.9);
      expect(updated.classificationAttempts, 1);
      expect(updated.structured, {'description': 'eggs'});

      // Everything else preserved.
      expect(updated.id, original.id);
      expect(updated.rawText, original.rawText);
      expect(updated.occurredAt, original.occurredAt);
      expect(updated.loggedAt, original.loggedAt);
      expect(updated.tags, original.tags);
      expect(updated.userNotes, original.userNotes);
      expect(updated.hrBpm, original.hrBpm);
    });
  });
}
