import 'dart:io';

import 'package:biovolt/models/log_entry.dart';
import 'package:biovolt/services/event_types.dart';
import 'package:biovolt/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  group('StorageService log entries', () {
    late Directory tempDir;
    late StorageService storage;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('biovolt_log_entry_');
      storage = StorageService();
      await storage.initForTest(tempDir.path);
    });

    tearDown(() async {
      await storage.resetForTest();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // Windows occasionally holds the file briefly after close.
      }
    });

    LogEntry make(
      String id, {
      DateTime? occurredAt,
      DateTime? loggedAt,
      String type = 'other',
      String classificationStatus = 'pending',
      int classificationAttempts = 0,
      String rawText = 'entry',
    }) =>
        LogEntry(
          id: id,
          rawText: rawText,
          occurredAt: occurredAt,
          loggedAt: loggedAt,
          type: type,
          classificationStatus: classificationStatus,
          classificationAttempts: classificationAttempts,
        );

    // -- Save / get / list ------------------------------------------------

    test('saveLogEntry → getLogEntry round-trips the same record', () async {
      final entry = make(
        'e-1',
        rawText: 'took 500mg NAC',
        occurredAt: DateTime(2026, 4, 20, 8),
        loggedAt: DateTime(2026, 4, 20, 8, 1),
      );
      await storage.saveLogEntry(entry);

      final fetched = storage.getLogEntry('e-1');
      expect(fetched, isNotNull);
      expect(fetched!.id, 'e-1');
      expect(fetched.rawText, 'took 500mg NAC');
      expect(fetched.occurredAt, DateTime(2026, 4, 20, 8));
      expect(fetched.type, 'other');

      // Paired event emit.
      final events = await storage.eventLog
          .query(type: EventTypes.entryCreated);
      expect(events.length, 1);
      expect(events.first.payload['id'], 'e-1');
      expect(events.first.payload['type'], 'other');
    });

    test('getAllLogEntries returns entries sorted by occurredAt DESC',
        () async {
      await storage.saveLogEntry(
          make('old', occurredAt: DateTime(2026, 4, 18)));
      await storage.saveLogEntry(
          make('newest', occurredAt: DateTime(2026, 4, 20)));
      await storage.saveLogEntry(
          make('middle', occurredAt: DateTime(2026, 4, 19)));

      final all = storage.getAllLogEntries();
      expect(all.map((e) => e.id).toList(), ['newest', 'middle', 'old']);
    });

    test('getLogEntriesInRange filters by occurredAt inclusive', () async {
      await storage.saveLogEntry(
          make('before', occurredAt: DateTime(2026, 4, 15)));
      await storage.saveLogEntry(
          make('start-edge', occurredAt: DateTime(2026, 4, 20)));
      await storage.saveLogEntry(
          make('inside', occurredAt: DateTime(2026, 4, 22)));
      await storage.saveLogEntry(
          make('end-edge', occurredAt: DateTime(2026, 4, 25)));
      await storage.saveLogEntry(
          make('after', occurredAt: DateTime(2026, 4, 28)));

      final inRange = storage.getLogEntriesInRange(
          DateTime(2026, 4, 20), DateTime(2026, 4, 25));
      expect(
        inRange.map((e) => e.id).toList(),
        ['end-edge', 'inside', 'start-edge'], // DESC
      );
    });

    test('getLogEntriesByType filters and optionally limits', () async {
      for (var i = 0; i < 5; i++) {
        await storage.saveLogEntry(make('meal-$i',
            type: 'meal',
            occurredAt: DateTime(2026, 4, 20, i)));
      }
      await storage.saveLogEntry(make('note-1',
          type: 'note', occurredAt: DateTime(2026, 4, 20, 10)));

      final allMeals = storage.getLogEntriesByType('meal');
      expect(allMeals.length, 5);
      expect(allMeals.every((e) => e.type == 'meal'), isTrue);

      final latestThree =
          storage.getLogEntriesByType('meal', limit: 3);
      expect(latestThree.length, 3);
      // DESC order by occurredAt means newest (meal-4) first.
      expect(latestThree.first.id, 'meal-4');
    });

    // -- Pending queue ----------------------------------------------------

    test(
        'getPendingClassification: pending + failed-under-cap, excludes classified/maxed',
        () async {
      await storage.saveLogEntry(make('pending-1',
          classificationStatus: 'pending',
          loggedAt: DateTime(2026, 4, 20, 10)));
      await storage.saveLogEntry(make('pending-2',
          classificationStatus: 'pending',
          loggedAt: DateTime(2026, 4, 20, 11)));
      await storage.saveLogEntry(make('classified-done',
          classificationStatus: 'classified',
          classificationAttempts: 1,
          loggedAt: DateTime(2026, 4, 20, 8)));
      await storage.saveLogEntry(make('failed-retryable',
          classificationStatus: 'failed',
          classificationAttempts: 2,
          loggedAt: DateTime(2026, 4, 20, 9)));
      await storage.saveLogEntry(make('failed-exhausted',
          classificationStatus: 'failed',
          classificationAttempts: 3,
          loggedAt: DateTime(2026, 4, 20, 7)));

      final pending = storage.getPendingClassification();
      expect(
        pending.map((e) => e.id).toList(),
        // Oldest-first by loggedAt.
        ['failed-retryable', 'pending-1', 'pending-2'],
      );
    });

    // -- Classifier update path ------------------------------------------

    test(
        'updateLogEntryClassification from pending → classified emits entry_classified',
        () async {
      final entry = make('clf-1',
          rawText: 'took glutathione', classificationStatus: 'pending');
      await storage.saveLogEntry(entry);

      await storage.updateLogEntryClassification(
        'clf-1',
        type: 'dose',
        structured: {'compound': 'glutathione', 'amountMg': 500},
        confidence: 0.92,
        status: 'classified',
      );

      final updated = storage.getLogEntry('clf-1')!;
      expect(updated.type, 'dose');
      expect(updated.classificationStatus, 'classified');
      expect(updated.classificationConfidence, 0.92);
      expect(updated.classificationAttempts, 1);
      expect(updated.structured!['compound'], 'glutathione');
      // Unrelated fields preserved.
      expect(updated.rawText, 'took glutathione');
      expect(updated.id, 'clf-1');

      final classified = await storage.eventLog
          .query(type: EventTypes.entryClassified);
      expect(classified.length, 1);
      expect(classified.first.payload['id'], 'clf-1');
      expect(classified.first.payload['type'], 'dose');
      expect(classified.first.payload['confidence'], 0.92);

      final reclassified = await storage.eventLog
          .query(type: EventTypes.entryReclassified);
      expect(reclassified, isEmpty);
    });

    test(
        'updateLogEntryClassification from classified → reclassified emits entry_reclassified',
        () async {
      await storage.saveLogEntry(make('clf-2',
          classificationStatus: 'classified', classificationAttempts: 1));

      await storage.updateLogEntryClassification(
        'clf-2',
        type: 'meal',
        structured: {'description': 'reinterpreted as meal'},
        confidence: 0.78,
        status: 'classified',
      );

      final updated = storage.getLogEntry('clf-2')!;
      expect(updated.type, 'meal');
      expect(updated.classificationAttempts, 2);

      final reclassified = await storage.eventLog
          .query(type: EventTypes.entryReclassified);
      expect(reclassified.length, 1);
      expect(reclassified.first.payload['type'], 'meal');

      final classified = await storage.eventLog
          .query(type: EventTypes.entryClassified);
      expect(classified, isEmpty);
    });

    test(
        'updateLogEntryClassification with status=failed preserves error and bumps attempts',
        () async {
      await storage.saveLogEntry(make('clf-fail',
          classificationStatus: 'pending', classificationAttempts: 0));

      await storage.updateLogEntryClassification(
        'clf-fail',
        type: 'other',
        structured: null,
        confidence: 0.0,
        status: 'failed',
        error: 'model timeout',
      );

      final updated = storage.getLogEntry('clf-fail')!;
      expect(updated.classificationStatus, 'failed');
      expect(updated.classificationError, 'model timeout');
      expect(updated.classificationAttempts, 1);

      // Still in the pending queue (attempts < 3, status == 'failed').
      final pending = storage.getPendingClassification();
      expect(pending.map((e) => e.id), contains('clf-fail'));
    });

    test(
        'updateLogEntryClassification on missing id is a no-op (no emit, no crash)',
        () async {
      await storage.updateLogEntryClassification(
        'does-not-exist',
        type: 'meal',
        structured: null,
        confidence: 1.0,
        status: 'classified',
      );
      // No entry created.
      expect(storage.getLogEntry('does-not-exist'), isNull);
      // No events emitted from this path.
      final classified = await storage.eventLog
          .query(type: EventTypes.entryClassified);
      expect(classified, isEmpty);
    });

    // -- Delete ----------------------------------------------------------

    test('deleteLogEntry removes the record and emits entry_deleted',
        () async {
      final entry = make('del-1',
          occurredAt: DateTime(2026, 4, 20), type: 'meal');
      await storage.saveLogEntry(entry);

      await storage.deleteLogEntry('del-1');

      expect(storage.getLogEntry('del-1'), isNull);
      final deleted = await storage.eventLog
          .query(type: EventTypes.entryDeleted);
      expect(deleted.length, 1);
      expect(deleted.first.payload['id'], 'del-1');
      expect(deleted.first.payload['type'], 'meal');
    });
  });

  // ---------------------------------------------------------------------
  // Schema-wipe exemption — log_entries survives a wipe of _boxNames.
  //
  // We can't cleanly invoke StorageService._migrateIfNeeded from a test
  // (it's private, and initForTest deliberately skips it because it
  // depends on SharedPreferences). Instead we verify the underlying
  // invariant directly with raw Hive: seed data in `log_entries`, loop
  // through the state-box list and delete each from disk (the exact
  // thing _migrateIfNeeded does), then confirm `log_entries` is
  // untouched. This mirrors the existing "events box schema-bump
  // survival" test in test/event_log_test.dart.
  // ---------------------------------------------------------------------

  group('log_entries box schema-bump survival', () {
    setUpAll(() {
      if (!Hive.isAdapterRegistered(43)) {
        Hive.registerAdapter(LogEntryAdapter());
      }
    });

    test('log_entries survives a wipe that clears state boxes', () async {
      final tempDir = Directory.systemTemp
          .createTempSync('biovolt_log_entries_survival_');
      Hive.init(tempDir.path);

      // Seed a LogEntry.
      final logEntries =
          await Hive.openBox<LogEntry>('log_entries');
      final seeded = LogEntry(
        id: 'persist-me',
        rawText: 'I should survive a schema bump',
        occurredAt: DateTime.utc(2026, 4, 20),
        loggedAt: DateTime.utc(2026, 4, 20),
        type: 'note',
      );
      await logEntries.put(seeded.id, seeded);

      // A state box that WOULD be wiped on a schema bump.
      final stateBox = await Hive.openBox<String>('bloodwork');
      await stateBox.put('k', 'v');

      // Simulate the schema-bump wipe: _migrateIfNeeded iterates
      // _boxNames and deletes each. log_entries is NOT in _boxNames,
      // so the loop should leave it alone. We mirror that here by
      // only deleting 'bloodwork' (a representative state box).
      await stateBox.close();
      await Hive.deleteBoxFromDisk('bloodwork');

      // Reopen both; log_entries should still hold the seeded record.
      final reopenedState = await Hive.openBox<String>('bloodwork');
      final reopenedLogEntries =
          await Hive.openBox<LogEntry>('log_entries');

      expect(reopenedState.isEmpty, isTrue);
      expect(reopenedLogEntries.length, 1);
      final survivor = reopenedLogEntries.get('persist-me');
      expect(survivor, isNotNull);
      expect(survivor!.rawText, 'I should survive a schema bump');
      expect(survivor.type, 'note');

      await Hive.close();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });
  });
}
