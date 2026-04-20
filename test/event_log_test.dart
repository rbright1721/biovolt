import 'dart:io';

import 'package:biovolt/models/active_protocol.dart';
import 'package:biovolt/models/ai_analysis.dart';
import 'package:biovolt/models/biovolt_event.dart';
import 'package:biovolt/models/bloodwork.dart';
import 'package:biovolt/models/health_journal_entry.dart';
import 'package:biovolt/models/normalized_record.dart';
import 'package:biovolt/models/oura_daily.dart';
import 'package:biovolt/models/session.dart';
import 'package:biovolt/models/session_template.dart';
import 'package:biovolt/models/user_profile.dart';
import 'package:biovolt/models/vitals_bookmark.dart';
import 'package:biovolt/services/event_log.dart';
import 'package:biovolt/services/event_types.dart';
import 'package:biovolt/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Group 1: EventLog in isolation
  // ---------------------------------------------------------------------------

  group('EventLog', () {
    late Directory tempDir;
    late Box<BiovoltEvent> eventsBox;
    late EventLog log;

    setUpAll(() {
      if (!Hive.isAdapterRegistered(42)) {
        Hive.registerAdapter(BiovoltEventAdapter());
      }
    });

    setUp(() async {
      tempDir = Directory.systemTemp
          .createTempSync('biovolt_events_log_');
      Hive.init(tempDir.path);
      eventsBox = await Hive.openBox<BiovoltEvent>(EventLog.boxName);
      log = EventLog(eventsBox: eventsBox, deviceId: 'test-device-id');
    });

    tearDown(() async {
      await Hive.close();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // Windows sometimes holds the file briefly after close; ignore.
      }
    });

    test(
        'append returns an event whose ULID is lexicographically greater than the previous',
        () async {
      String prev = '';
      for (var i = 0; i < 10; i++) {
        final event = await log.append(
          type: EventTypes.supplementAdded,
          payload: {'i': i},
        );
        expect(event.id.compareTo(prev) > 0, isTrue,
            reason: 'ULID $i (${event.id}) is not > previous ($prev)');
        prev = event.id;
      }
    });

    test('since(null) returns all events in insertion order', () async {
      for (var i = 0; i < 5; i++) {
        await log.append(
          type: EventTypes.hrSample,
          payload: {'bpm': 60 + i},
        );
      }
      final all = await log.since(null);
      expect(all.length, 5);
      for (var i = 1; i < all.length; i++) {
        expect(all[i - 1].id.compareTo(all[i].id) < 0, isTrue);
      }
      for (var i = 0; i < 5; i++) {
        expect(all[i].payload['bpm'], 60 + i);
      }
    });

    test('since(eventId) returns only events strictly after the given ID',
        () async {
      final events = <BiovoltEvent>[];
      for (var i = 0; i < 5; i++) {
        events.add(await log.append(
          type: EventTypes.hrSample,
          payload: {'i': i},
        ));
      }
      final after2 = await log.since(events[2].id);
      expect(after2.length, 2);
      expect(after2.map((e) => e.payload['i']).toList(), [3, 4]);
    });

    test('query filters by type', () async {
      await log.append(
          type: EventTypes.supplementAdded, payload: {'name': 'GlyNAC'});
      await log.append(
          type: EventTypes.hrSample, payload: {'bpm': 72});
      await log.append(
          type: EventTypes.supplementAdded, payload: {'name': 'Creatine'});
      await log.append(
          type: EventTypes.sessionStarted, payload: {'type': 'breathwork'});

      final supplements =
          await log.query(type: EventTypes.supplementAdded);
      expect(supplements.length, 2);
      expect(
        supplements.map((e) => e.payload['name']).toList(),
        ['GlyNAC', 'Creatine'],
      );
    });

    test('latest returns the most recent event of a given type', () async {
      await log.append(
          type: EventTypes.supplementAdded, payload: {'name': 'A'});
      await log.append(
          type: EventTypes.hrSample, payload: {'bpm': 70});
      await log.append(
          type: EventTypes.supplementAdded, payload: {'name': 'B'});
      final latest = await log.latest(EventTypes.supplementAdded);
      expect(latest, isNotNull);
      expect(latest!.payload['name'], 'B');
    });

    test('events box persists the full record across close/reopen',
        () async {
      final appended = await log.append(
        type: EventTypes.profileBloodworkAdded,
        payload: {'id': 'bw-1', 'hdl': 55.0},
        schemaVersion: 2,
      );
      await eventsBox.close();
      final reopened =
          await Hive.openBox<BiovoltEvent>(EventLog.boxName);
      final roundTrip = reopened.get(appended.id);
      expect(roundTrip, isNotNull);
      expect(roundTrip!.type, EventTypes.profileBloodworkAdded);
      expect(roundTrip.deviceId, 'test-device-id');
      expect(roundTrip.schemaVersion, 2);
      expect(roundTrip.payload['id'], 'bw-1');
      expect(roundTrip.payload['hdl'], 55.0);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 2: StorageService two-write refactor
  // ---------------------------------------------------------------------------

  group('StorageService two-write refactor', () {
    late Directory tempDir;
    late StorageService storage;

    setUp(() async {
      tempDir = Directory.systemTemp
          .createTempSync('biovolt_events_storage_');
      storage = StorageService();
      await storage.initForTest(tempDir.path);
    });

    tearDown(() async {
      await storage.resetForTest();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('saveBloodwork writes to both bloodwork and events boxes',
        () async {
      final bw = Bloodwork(
        id: 'bw-test-1',
        labDate: DateTime(2026, 4, 15),
        crp: 0.3,
        hdl: 62.0,
      );
      await storage.saveBloodwork(bw);

      // State write
      final stored = storage.getBloodwork('bw-test-1');
      expect(stored, isNotNull);
      expect(stored!.id, 'bw-test-1');

      // Event write
      final events = await storage.eventLog
          .query(type: EventTypes.profileBloodworkAdded);
      expect(events.length, 1);
      expect(events.first.payload['id'], 'bw-test-1');
      expect(events.first.payload['hdl'], 62.0);
    });

    test('saveActiveProtocol writes to both protocols and events boxes',
        () async {
      final p = ActiveProtocol(
        id: 'proto-test-1',
        name: 'BPC-157',
        type: 'peptide',
        startDate: DateTime(2026, 4, 1),
        cycleLengthDays: 30,
        doseMcg: 250,
        route: 'sub-q',
        isActive: true,
      );
      await storage.saveActiveProtocol(p);

      // State write
      final stored = storage.getActiveProtocol('proto-test-1');
      expect(stored, isNotNull);
      expect(stored!.name, 'BPC-157');

      // Event write
      final events = await storage.eventLog
          .query(type: EventTypes.protocolItemAdded);
      expect(events.length, 1);
      expect(events.first.payload['id'], 'proto-test-1');
      expect(events.first.payload['name'], 'BPC-157');
    });

    // -- Sessions ---------------------------------------------------------

    test('saveSession emits session.ended', () async {
      final s = Session(
        sessionId: 's-1',
        userId: 'u-1',
        createdAt: DateTime(2026, 4, 20, 9),
        timezone: 'UTC',
        dataSources: ['esp32'],
        durationSeconds: 600,
      );
      await storage.saveSession(s);

      expect(storage.getSession('s-1'), isNotNull);
      final events =
          await storage.eventLog.query(type: EventTypes.sessionEnded);
      expect(events.length, 1);
      expect(events.first.payload['sessionId'], 's-1');
      expect(events.first.payload['durationSeconds'], 600);
    });

    test('deleteSession emits session.discarded with prior context',
        () async {
      final s = Session(
        sessionId: 's-del',
        userId: 'u-1',
        createdAt: DateTime(2026, 4, 20),
        timezone: 'UTC',
        dataSources: [],
        durationSeconds: 300,
      );
      await storage.saveSession(s);
      await storage.deleteSession('s-del');

      expect(storage.getSession('s-del'), isNull);
      final events =
          await storage.eventLog.query(type: EventTypes.sessionDiscarded);
      expect(events.length, 1);
      expect(events.first.payload['sessionId'], 's-del');
      expect(events.first.payload['durationSeconds'], 300);
    });

    // -- AI analysis ------------------------------------------------------

    test('saveAiAnalysis emits analysis.completed', () async {
      final a = AiAnalysis(
        sessionId: 'sess-a',
        generatedAt: DateTime(2026, 4, 20),
        provider: 'anthropic',
        model: 'claude',
        promptVersion: 'v1',
        insights: const [],
        anomalies: const [],
        correlationsDetected: const [],
        protocolRecommendations: const [],
        flags: const [],
        confidence: 0.9,
        ouraContextUsed: false,
      );
      await storage.saveAiAnalysis(a);

      expect(storage.getAiAnalysis('sess-a'), isNotNull);
      final events = await storage.eventLog
          .query(type: EventTypes.analysisCompleted);
      expect(events.length, 1);
      expect(events.first.payload['sessionId'], 'sess-a');
    });

    test('deleteAiAnalysis emits analysis.discarded', () async {
      await storage.deleteAiAnalysis('sess-none');
      final events = await storage.eventLog
          .query(type: EventTypes.analysisDiscarded);
      expect(events.length, 1);
      expect(events.first.payload['sessionId'], 'sess-none');
    });

    // -- Oura daily record ------------------------------------------------

    test(
        'saveOuraDailyRecord emits one event per populated sub-domain',
        () async {
      final sleepOnly = OuraDailyRecord(
        date: DateTime(2026, 4, 18),
        syncedAt: DateTime(2026, 4, 19),
        sleepScore: 82,
      );
      await storage.saveOuraDailyRecord(sleepOnly);

      final both = OuraDailyRecord(
        date: DateTime(2026, 4, 19),
        syncedAt: DateTime(2026, 4, 20),
        sleepScore: 90,
        readinessScore: 78,
      );
      await storage.saveOuraDailyRecord(both);

      final sleepEvents = await storage.eventLog
          .query(type: EventTypes.ouraSleepImported);
      final readinessEvents = await storage.eventLog
          .query(type: EventTypes.ouraReadinessImported);
      // Two sleep-bearing records → two sleep events; one readiness
      // record → one readiness event.
      expect(sleepEvents.length, 2);
      expect(readinessEvents.length, 1);
    });

    // -- User profile + meal time -----------------------------------------

    test('saveUserProfile emits profile.field_changed', () async {
      final p = UserProfile(
        userId: 'u-1',
        createdAt: DateTime(2026, 1, 1),
        healthGoals: const [],
        knownConditions: const [],
        baselineEstablished: true,
        preferredUnits: 'imperial',
      );
      await storage.saveUserProfile(p);

      expect(storage.getUserProfile(), isNotNull);
      final events = await storage.eventLog
          .query(type: EventTypes.profileFieldChanged);
      expect(events.length, 1);
      expect(events.first.payload['userId'], 'u-1');
    });

    test(
        'updateLastMealTimeExplicit emits meal.logged without a redundant profile.field_changed',
        () async {
      // Seed an existing profile so the updater has something to work on.
      final seed = UserProfile(
        userId: 'u-1',
        createdAt: DateTime(2026, 1, 1),
        healthGoals: const [],
        knownConditions: const [],
        baselineEstablished: true,
        preferredUnits: 'imperial',
      );
      await storage.saveUserProfile(seed);

      // Only count profile.field_changed events created AFTER seeding.
      final beforeProfileCount = (await storage.eventLog
              .query(type: EventTypes.profileFieldChanged))
          .length;

      final mealTime = DateTime(2026, 4, 20, 13, 15);
      await storage.updateLastMealTimeExplicit(mealTime);

      final meals = await storage.eventLog
          .query(type: EventTypes.mealLogged);
      expect(meals.length, 1);
      expect(meals.first.payload['loggedAt'], mealTime.toIso8601String());
      expect(meals.first.payload['source'], 'widget');

      final afterProfileCount = (await storage.eventLog
              .query(type: EventTypes.profileFieldChanged))
          .length;
      expect(afterProfileCount, beforeProfileCount,
          reason:
              'meal update should NOT double-emit profile.field_changed');
    });

    // -- Connector state --------------------------------------------------

    test('saveConnectorState emits device.state_changed', () async {
      final cs = ConnectorState(
        connectorId: 'esp32',
        status: ConnectorStatus.connected,
        isAuthenticated: true,
      );
      await storage.saveConnectorState(cs);

      final events = await storage.eventLog
          .query(type: EventTypes.deviceStateChanged);
      expect(events.length, 1);
      expect(events.first.payload['connectorId'], 'esp32');
      expect(events.first.payload['status'], 'connected');
    });

    // -- Bloodwork delete -------------------------------------------------

    test('deleteBloodwork emits profile.bloodwork_removed', () async {
      final bw = Bloodwork(id: 'bw-x', labDate: DateTime(2026, 3, 1));
      await storage.saveBloodwork(bw);
      await storage.deleteBloodwork('bw-x');

      expect(storage.getBloodwork('bw-x'), isNull);
      final events = await storage.eventLog
          .query(type: EventTypes.profileBloodworkRemoved);
      expect(events.length, 1);
      expect(events.first.payload['id'], 'bw-x');
    });

    // -- Session templates ------------------------------------------------

    test('saveTemplate emits session.template_saved', () async {
      final t = SessionTemplate(
        id: 't-1',
        name: 'Morning breathwork',
        sessionType: 'breathwork',
        lastUsedAt: DateTime(2026, 4, 1),
        useCount: 0,
      );
      await storage.saveTemplate(t);

      expect(storage.getTemplate('t-1'), isNotNull);
      final events = await storage.eventLog
          .query(type: EventTypes.sessionTemplateSaved);
      expect(events.length, 1);
      expect(events.first.payload['id'], 't-1');
      expect(events.first.payload['name'], 'Morning breathwork');
    });

    test('deleteTemplate emits session.template_deleted', () async {
      final t = SessionTemplate(
        id: 't-del',
        name: 'Retired',
        sessionType: 'cold',
        lastUsedAt: DateTime(2026, 1, 1),
        useCount: 5,
      );
      await storage.saveTemplate(t);
      await storage.deleteTemplate('t-del');

      final events = await storage.eventLog
          .query(type: EventTypes.sessionTemplateDeleted);
      expect(events.length, 1);
      expect(events.first.payload['id'], 't-del');
      expect(events.first.payload['name'], 'Retired');
    });

    test(
        'incrementTemplateUseCount emits session.template_used with updated count',
        () async {
      final t = SessionTemplate(
        id: 't-use',
        name: 'Used',
        sessionType: 'meditation',
        lastUsedAt: DateTime(2026, 1, 1),
        useCount: 2,
      );
      await storage.saveTemplate(t);
      await storage.incrementTemplateUseCount('t-use');

      final events = await storage.eventLog
          .query(type: EventTypes.sessionTemplateUsed);
      expect(events.length, 1);
      expect(events.first.payload['useCount'], 3);
    });

    // -- Protocol end / delete --------------------------------------------

    test('endProtocol emits protocol.item_modified with isActive=false',
        () async {
      final p = ActiveProtocol(
        id: 'p-end',
        name: 'To end',
        type: 'peptide',
        startDate: DateTime(2026, 3, 1),
        cycleLengthDays: 30,
        doseMcg: 100,
        route: 'oral',
        isActive: true,
      );
      await storage.saveActiveProtocol(p);
      await storage.endProtocol('p-end');

      final events = await storage.eventLog
          .query(type: EventTypes.protocolItemModified);
      expect(events.length, 1);
      expect(events.first.payload['id'], 'p-end');
      expect(events.first.payload['isActive'], false);
      expect(storage.getActiveProtocol('p-end')!.isActive, false);
    });

    test('deleteActiveProtocol emits protocol.item_removed', () async {
      final p = ActiveProtocol(
        id: 'p-gone',
        name: 'To delete',
        type: 'supplement',
        startDate: DateTime(2026, 3, 1),
        cycleLengthDays: 14,
        doseMcg: 50,
        route: 'oral',
        isActive: true,
      );
      await storage.saveActiveProtocol(p);
      await storage.deleteActiveProtocol('p-gone');

      expect(storage.getActiveProtocol('p-gone'), isNull);
      final events = await storage.eventLog
          .query(type: EventTypes.protocolItemRemoved);
      expect(events.length, 1);
      expect(events.first.payload['id'], 'p-gone');
      expect(events.first.payload['name'], 'To delete');
    });

    // -- Vitals bookmark --------------------------------------------------

    test('saveBookmark emits bookmark.added', () async {
      final b = VitalsBookmark(
        id: 'bm-1',
        timestamp: DateTime(2026, 4, 20, 14),
        note: 'Post-cold',
        hrBpm: 58,
        hrvMs: 72,
      );
      await storage.saveBookmark(b);

      final events = await storage.eventLog
          .query(type: EventTypes.bookmarkAdded);
      expect(events.length, 1);
      expect(events.first.payload['id'], 'bm-1');
      expect(events.first.payload['note'], 'Post-cold');
    });

    // -- Journal entries --------------------------------------------------

    test('saveJournalEntry emits journal.entry_added', () async {
      final e = HealthJournalEntry(
        id: 'j-1',
        timestamp: DateTime(2026, 4, 20),
        userMessage: 'feeling good',
        aiResponse: 'ok',
        conversationId: 'c-1',
      );
      await storage.saveJournalEntry(e);

      final events = await storage.eventLog
          .query(type: EventTypes.journalEntryAdded);
      expect(events.length, 1);
      expect(events.first.payload['id'], 'j-1');
      expect(events.first.payload['conversationId'], 'c-1');
    });

    test('updateJournalEntry emits journal.entry_edited', () async {
      final e = HealthJournalEntry(
        id: 'j-2',
        timestamp: DateTime(2026, 4, 20),
        userMessage: 'first',
        aiResponse: 'a',
        conversationId: 'c-1',
      );
      await storage.saveJournalEntry(e);
      await storage.updateJournalEntry(e);

      final edits = await storage.eventLog
          .query(type: EventTypes.journalEntryEdited);
      expect(edits.length, 1);
      expect(edits.first.payload['id'], 'j-2');
    });

    // -- clearAll ---------------------------------------------------------

    test('clearAll emits a single app.data_cleared event', () async {
      // Seed some state so the clear actually removes something.
      await storage.saveBloodwork(
          Bloodwork(id: 'bw-pre', labDate: DateTime(2026, 1, 1)));
      await storage.clearAll();

      expect(storage.getBloodwork('bw-pre'), isNull);
      final events = await storage.eventLog
          .query(type: EventTypes.appDataCleared);
      expect(events.length, 1);
      expect(events.first.payload['boxes'], isA<List<dynamic>>());
      expect(
        (events.first.payload['boxes'] as List).contains('bloodwork'),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Group 2.5: Source-scan enforcement of the two-write invariant
  // ---------------------------------------------------------------------------

  group('StorageService two-write invariant', () {
    // Methods whose state-box writes are intentionally not paired with
    // an event. These are either infrastructure (init / migration /
    // adapter registration) or private helpers whose callers emit.
    const exemptMethods = <String>{
      'init',
      'initForTest',
      'resetForTest',
      '_openEventLog',
      '_openAllBoxes',
      '_migrateIfNeeded',
      '_registerAdapters',
      // `_putProfile` is deliberately unpaired — its public callers
      // (saveUserProfile, updateLastMealTime, updateLastMealTimeExplicit)
      // each emit their own, more-specific event. If _putProfile emitted
      // too, every meal update would double-log.
      '_putProfile',
    };

    test(
        'every state-box write lives in a method that also emits an event',
        () async {
      final source = await File('lib/services/storage_service.dart')
          .readAsString();
      final lines = source.split('\n');

      // A class-method header at 2-space indent. Captures the method
      // name. Covers both block-body (`{`) and arrow-body (`=>`) forms.
      final headerRe = RegExp(
        r'^  (?:@\w+(?:\([^)]*\))?\s+)*'
        r'(?:static\s+)?'
        r'(?:[A-Za-z_][\w<>?, ]*\s+)?'
        r'(_?[A-Za-z]\w*)\s*\([^)]*\)\s*'
        r'(?:async\s*)?(\{|=>)',
      );
      final methodEndRe = RegExp(r'^  \}\s*$');

      // A state-box mutation: put/delete/clear on a `_xxxBox` field,
      // excluding the event log's own infrastructure boxes.
      final writeRe = RegExp(r'_[A-Za-z]+Box\??\.(put|delete|clear)\(');
      const infraBoxes = ['_eventsBox', '_deviceIdentityBox'];

      bool isStateWrite(String line) {
        if (!writeRe.hasMatch(line)) return false;
        for (final e in infraBoxes) {
          if (line.contains(e)) return false;
        }
        return true;
      }

      // First pass: for each line, compute enclosing method name.
      final enclosing = List<String?>.filled(lines.length, null);
      String? current;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final m = headerRe.firstMatch(line);
        if (m != null) {
          current = m.group(1);
        }
        enclosing[i] = current;
        if (methodEndRe.hasMatch(line)) {
          current = null;
        }
      }

      // For each method that contains a state write, verify it also
      // contains `eventLog.append` somewhere in its body.
      final methodWriteLines = <String, List<int>>{};
      for (var i = 0; i < lines.length; i++) {
        final method = enclosing[i];
        if (method == null) continue;
        if (!isStateWrite(lines[i])) continue;
        methodWriteLines.putIfAbsent(method, () => []).add(i);
      }

      bool methodEmits(String methodName) {
        // Find all line ranges where enclosing == methodName.
        for (var i = 0; i < lines.length; i++) {
          if (enclosing[i] != methodName) continue;
          if (lines[i].contains('eventLog.append')) return true;
        }
        return false;
      }

      final violations = <String>[];
      for (final entry in methodWriteLines.entries) {
        if (exemptMethods.contains(entry.key)) continue;
        if (!methodEmits(entry.key)) {
          violations.add(
              '${entry.key} (writes at lines ${entry.value.map((i) => i + 1).toList()})');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Methods writing to a state box without emitting an '
            'event: $violations. Either emit eventLog.append or add '
            'the method to exemptMethods with a justification.',
      );
    });

    test('every line-level state-box write is covered by the scanner',
        () async {
      // Safety check on the scanner itself: if the raw count of write
      // lines doesn't match the count found via the header-aware scan,
      // the scanner has drifted from the source.
      final source = await File('lib/services/storage_service.dart')
          .readAsString();
      final rawLines = source.split('\n').where((l) {
        if (!RegExp(r'_[A-Za-z]+Box\??\.(put|delete|clear)\(')
            .hasMatch(l)) {
          return false;
        }
        return !(l.contains('_eventsBox') ||
            l.contains('_deviceIdentityBox'));
      }).toList();

      // We expect at least the writes enumerated in the audit; if this
      // count drops unexpectedly the source has diverged.
      expect(rawLines.length, greaterThanOrEqualTo(25),
          reason:
              'Expected >=25 state-box writes in StorageService; scanner may be broken.');
    });
  });

  // ---------------------------------------------------------------------------
  // Group 3: Events box survives a schema-version wipe of state boxes
  // ---------------------------------------------------------------------------

  group('events box schema-bump survival', () {
    setUpAll(() {
      if (!Hive.isAdapterRegistered(42)) {
        Hive.registerAdapter(BiovoltEventAdapter());
      }
    });

    test('events survive a wipe that clears state boxes', () async {
      final tempDir = Directory.systemTemp
          .createTempSync('biovolt_events_survival_');
      Hive.init(tempDir.path);

      final events =
          await Hive.openBox<BiovoltEvent>(EventLog.boxName);
      final log = EventLog(
          eventsBox: events, deviceId: 'survival-device');
      await log.append(
          type: EventTypes.supplementAdded, payload: {'x': 1});

      // A state box that WOULD be wiped on a schema bump.
      final stateBox = await Hive.openBox<String>('bloodwork');
      await stateBox.put('k', 'v');

      // Simulate the schema-bump wipe: only the boxes in the state-box
      // list are deleted; the events box is exempt.
      await stateBox.close();
      await Hive.deleteBoxFromDisk('bloodwork');

      // Reopen the wiped state box and the untouched events box.
      final reopenedState = await Hive.openBox<String>('bloodwork');
      final reopenedEvents =
          await Hive.openBox<BiovoltEvent>(EventLog.boxName);
      final survivingLog = EventLog(
          eventsBox: reopenedEvents, deviceId: 'survival-device');

      expect(reopenedState.isEmpty, isTrue);

      final surviving = await survivingLog.since(null);
      expect(surviving.length, 1);
      expect(surviving.first.type, EventTypes.supplementAdded);
      expect(surviving.first.payload['x'], 1);

      await Hive.close();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });
  });
}
