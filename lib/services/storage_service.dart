import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'event_log.dart';
import 'event_types.dart';
import 'widget_service.dart';

import '../models/ai_analysis.dart';
import '../models/biometric_records.dart';
import '../models/biovolt_event.dart';
import '../models/bloodwork.dart';
import '../models/interventions.dart';
import '../models/normalized_record.dart';
import '../models/oura_daily.dart';
import '../models/sensor_snapshot.dart';
import '../models/session.dart';
import '../models/session_type.dart';
import '../models/sleep_record.dart';
import '../models/active_protocol.dart';
import '../models/health_journal_entry.dart';
import '../models/vitals_bookmark.dart';
import '../models/session_template.dart';
import '../models/user_profile.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Box<Session>? _sessionsBox;
  Box<OuraDailyRecord>? _dailyRecordsBox;
  Box<AiAnalysis>? _aiAnalysesBox;
  Box<Interventions>? _interventionsBox;
  Box<UserProfile>? _userProfileBox;
  Box<ConnectorState>? _connectorStatesBox;
  Box? _biometricRecordsBox;
  Box<Bloodwork>? _bloodworkBox;
  Box<SessionTemplate>? _sessionTemplatesBox;
  Box<ActiveProtocol>? _activeProtocolsBox;
  Box<String>? _bookmarksBox;
  Box<String>? _journalBox;
  Box<BiovoltEvent>? _eventsBox;
  Box<String>? _deviceIdentityBox;

  EventLog? _eventLog;

  /// Append-only event log. Mutations emit events in parallel with
  /// their state writes. See [EventLog].
  EventLog get eventLog {
    final log = _eventLog;
    if (log == null) {
      throw StateError(
          'StorageService.init() must complete before eventLog is used');
    }
    return log;
  }

  // Bump this whenever TypeAdapter IDs or model shapes change.
  // Forces a full Hive wipe on devices with stale data.
  static const _schemaVersion = 3;
  static const _schemaKey = 'hive_schema_version';

  // Boxes wiped on a schema-version bump or during the nuclear
  // corrupt-recovery path. The `events` and `device_identity` boxes
  // are deliberately NOT in this list — the append-only event log and
  // the per-install device UUID must survive schema migrations.
  static const _boxNames = [
    'sessions',
    'daily_records',
    'ai_analyses',
    'interventions',
    'user_profile',
    'connector_states',
    'biometric_records',
    'bloodwork',
    'session_templates',
    'active_protocols',
    'vitals_bookmarks',
    'health_journal',
  ];

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    // -- Register all adapters FIRST (before any box operations) --
    _registerAdapters();

    // -- Debug: verify no TypeAdapter ID collisions --
    if (kDebugMode) _debugVerifyAdapterIds();

    // -- Check schema version and wipe stale data if needed --
    await _migrateIfNeeded();

    // -- Open boxes --
    await _openAllBoxes();

    // -- Open event log + device identity (exempt from schema wipe) --
    await _openEventLog();

    _initialized = true;
  }

  /// Test-only initializer that bypasses `Hive.initFlutter` and the
  /// SharedPreferences-backed migration step. Callers are responsible
  /// for calling [resetForTest] afterwards.
  @visibleForTesting
  Future<void> initForTest(String hivePath) async {
    if (_initialized) return;
    Hive.init(hivePath);
    _registerAdapters();
    await _openAllBoxes();
    await _openEventLog();
    _initialized = true;
  }

  /// Test-only teardown. Closes all boxes, clears internal references,
  /// and allows another [initForTest] call. Registered TypeAdapters
  /// persist — the next init is a no-op on registration thanks to the
  /// idempotent guard in [_registerAdapters].
  @visibleForTesting
  Future<void> resetForTest() async {
    await Hive.close();
    _sessionsBox = null;
    _dailyRecordsBox = null;
    _aiAnalysesBox = null;
    _interventionsBox = null;
    _userProfileBox = null;
    _connectorStatesBox = null;
    _biometricRecordsBox = null;
    _bloodworkBox = null;
    _sessionTemplatesBox = null;
    _activeProtocolsBox = null;
    _bookmarksBox = null;
    _journalBox = null;
    _eventsBox = null;
    _deviceIdentityBox = null;
    _eventLog = null;
    _initialized = false;
  }

  Future<void> _openEventLog() async {
    _deviceIdentityBox = await Hive.openBox<String>(
        EventLog.deviceIdentityBoxName);
    var deviceId = _deviceIdentityBox!.get(EventLog.deviceIdentityKey);
    if (deviceId == null) {
      deviceId = _generateUuidV4();
      await _deviceIdentityBox!.put(EventLog.deviceIdentityKey, deviceId);
    }
    _eventsBox = await Hive.openBox<BiovoltEvent>(EventLog.boxName);
    _eventLog = EventLog(eventsBox: _eventsBox!, deviceId: deviceId);
  }

  static String _generateUuidV4() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// Wipe all Hive box files if the schema version has changed.
  Future<void> _migrateIfNeeded() async {
    // On web, Hive uses IndexedDB — deleteBoxFromDisk and untyped
    // open+clear both conflict with subsequent typed opens.
    // Skip migration on web; boxes are ephemeral per browser session anyway.
    if (kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_schemaKey) ?? 0;

    if (stored < _schemaVersion) {
      debugPrint(
          'Schema upgrade: $stored \u2192 $_schemaVersion \u2014 wiping Hive boxes');
      for (final name in _boxNames) {
        try {
          await Hive.deleteBoxFromDisk(name);
        } catch (e) {
          debugPrint('Failed to delete box $name: $e');
        }
      }
      await prefs.setInt(_schemaKey, _schemaVersion);
    }
  }

  Future<void> _openAllBoxes() async {
    try {
      _sessionsBox = await Hive.openBox<Session>('sessions');
      _dailyRecordsBox =
          await Hive.openBox<OuraDailyRecord>('daily_records');
      _aiAnalysesBox = await Hive.openBox<AiAnalysis>('ai_analyses');
      _interventionsBox = await Hive.openBox<Interventions>('interventions');
      _userProfileBox = await Hive.openBox<UserProfile>('user_profile');
      _connectorStatesBox =
          await Hive.openBox<ConnectorState>('connector_states');
      _biometricRecordsBox = await Hive.openBox('biometric_records');
      _bloodworkBox = await Hive.openBox<Bloodwork>('bloodwork');
      _sessionTemplatesBox =
          await Hive.openBox<SessionTemplate>('session_templates');
      _activeProtocolsBox =
          await Hive.openBox<ActiveProtocol>('active_protocols');
      _bookmarksBox = await Hive.openBox<String>('vitals_bookmarks');
      _journalBox = await Hive.openBox<String>('health_journal');
    } catch (e) {
      // Nuclear option — if boxes are corrupt, wipe everything and retry
      debugPrint('Hive box open failed: $e \u2014 nuking all data');
      if (!kIsWeb) {
        for (final name in _boxNames) {
          try {
            await Hive.deleteBoxFromDisk(name);
          } catch (_) {}
        }
      }
      // Retry opens — these will create fresh empty boxes
      _sessionsBox = await Hive.openBox<Session>('sessions');
      _dailyRecordsBox =
          await Hive.openBox<OuraDailyRecord>('daily_records');
      _aiAnalysesBox = await Hive.openBox<AiAnalysis>('ai_analyses');
      _interventionsBox = await Hive.openBox<Interventions>('interventions');
      _userProfileBox = await Hive.openBox<UserProfile>('user_profile');
      _connectorStatesBox =
          await Hive.openBox<ConnectorState>('connector_states');
      _biometricRecordsBox = await Hive.openBox('biometric_records');
      _bloodworkBox = await Hive.openBox<Bloodwork>('bloodwork');
      _sessionTemplatesBox =
          await Hive.openBox<SessionTemplate>('session_templates');
      _activeProtocolsBox =
          await Hive.openBox<ActiveProtocol>('active_protocols');
      _bookmarksBox = await Hive.openBox<String>('vitals_bookmarks');
      _journalBox = await Hive.openBox<String>('health_journal');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_schemaKey, _schemaVersion);
    }
  }

  void _registerAdapters() {
    // Per-adapter idempotency guard so tests that re-init or that
    // pre-register some adapters don't collide. In production this
    // runs exactly once, so the check is a cheap no-op.
    void reg<T>(int id, TypeAdapter<T> adapter) {
      if (!Hive.isAdapterRegistered(id)) Hive.registerAdapter(adapter);
    }

    // -- Enums (normalized_record.dart): IDs 1-4 --
    reg(1, DataSourceAdapter());
    reg(2, DataQualityAdapter());
    reg(3, ConnectorTypeAdapter());
    reg(4, ConnectorStatusAdapter());

    // -- Biometric records: IDs 5-11 --
    reg(5, HeartRateReadingAdapter());
    reg(6, HRVReadingAdapter());
    reg(7, EDAReadingAdapter());
    reg(8, SpO2ReadingAdapter());
    reg(9, TemperatureReadingAdapter());
    reg(10, ECGRecordAdapter());
    reg(11, TemperaturePlacementAdapter());

    // -- Sleep: IDs 12-14 --
    reg(12, SleepRecordAdapter());
    reg(13, SleepContributorsAdapter());
    reg(14, ReadinessContributorsAdapter());

    // -- Oura daily: ID 15 --
    reg(15, OuraDailyRecordAdapter());

    // -- Session: IDs 16-24 --
    reg(16, SessionAdapter());
    reg(17, SessionContextAdapter());
    reg(18, SessionActivityAdapter());
    reg(19, SessionBiometricsAdapter());
    reg(20, Esp32MetricsAdapter());
    reg(21, PolarMetricsAdapter());
    reg(22, ComputedMetricsAdapter());
    reg(23, SessionSubjectiveAdapter());
    reg(24, SubjectiveScoresAdapter());

    // -- AI analysis: ID 25 --
    reg(25, AiAnalysisAdapter());

    // -- Interventions: IDs 26-30 --
    reg(26, InterventionsAdapter());
    reg(27, PeptideLogAdapter());
    reg(28, SupplementLogAdapter());
    reg(29, NutritionLogAdapter());
    reg(30, HydrationLogAdapter());

    // -- User profile: IDs 31-32 --
    reg(31, UserProfileAdapter());
    reg(32, ConnectorStateAdapter());

    // -- Session type + Snapshot: IDs 33-34 --
    reg(33, SessionTypeAdapter());
    reg(34, SensorSnapshotAdapter());

    // -- Bloodwork: ID 35 --
    reg(35, BloodworkAdapter());

    // -- Session templates: ID 40 --
    reg(40, SessionTemplateAdapter());

    // -- Active protocols: ID 41 --
    reg(41, ActiveProtocolAdapter());

    // -- BiovoltEvent: ID 42 --
    reg(42, BiovoltEventAdapter());
  }

  /// In debug mode, verify that all registered adapters have unique typeIds.
  void _debugVerifyAdapterIds() {
    final ids = <int, String>{};
    final adapters = <(int, String)>[
      (1, 'DataSource'), (2, 'DataQuality'), (3, 'ConnectorType'),
      (4, 'ConnectorStatus'), (5, 'HeartRateReading'), (6, 'HRVReading'),
      (7, 'EDAReading'), (8, 'SpO2Reading'), (9, 'TemperatureReading'),
      (10, 'ECGRecord'), (11, 'TemperaturePlacement'),
      (12, 'SleepRecord'), (13, 'SleepContributors'),
      (14, 'ReadinessContributors'), (15, 'OuraDailyRecord'),
      (16, 'Session'), (17, 'SessionContext'), (18, 'SessionActivity'),
      (19, 'SessionBiometrics'), (20, 'Esp32Metrics'),
      (21, 'PolarMetrics'), (22, 'ComputedMetrics'),
      (23, 'SessionSubjective'), (24, 'SubjectiveScores'),
      (25, 'AiAnalysis'), (26, 'Interventions'), (27, 'PeptideLog'),
      (28, 'SupplementLog'), (29, 'NutritionLog'), (30, 'HydrationLog'),
      (31, 'UserProfile'), (32, 'ConnectorState'),
      (33, 'SessionType'), (34, 'SensorSnapshot'), (35, 'Bloodwork'),
      (40, 'SessionTemplate'), (41, 'ActiveProtocol'),
      (42, 'BiovoltEvent'),
    ];

    for (final (id, name) in adapters) {
      if (ids.containsKey(id)) {
        debugPrint(
            'ADAPTER ID COLLISION: $id used by both ${ids[id]} and $name');
      }
      ids[id] = name;
    }

    debugPrint(
        'Hive adapters registered: ${ids.length} (IDs 1-42, no collisions)');
  }

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  Future<void> saveSession(Session session) async {
    await _sessionsBox?.put(session.sessionId, session);
    await eventLog.append(
      type: EventTypes.sessionEnded,
      payload: {
        'sessionId': session.sessionId,
        'createdAt': session.createdAt.toIso8601String(),
        'durationSeconds': session.durationSeconds,
      },
    );
  }

  Session? getSession(String sessionId) => _sessionsBox?.get(sessionId);

  List<Session> getAllSessions() {
    if (_sessionsBox == null) return [];
    final sessions = _sessionsBox!.values.toList();
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  List<Session> getSessionsInRange(DateTime from, DateTime to) {
    if (_sessionsBox == null) return [];
    return _sessionsBox!.values
        .where((s) =>
            !s.createdAt.isBefore(from) && !s.createdAt.isAfter(to))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> deleteSession(String sessionId) async {
    final prior = _sessionsBox?.get(sessionId);
    await _sessionsBox?.delete(sessionId);
    await eventLog.append(
      type: EventTypes.sessionDiscarded,
      payload: {
        'sessionId': sessionId,
        if (prior != null)
          'createdAt': prior.createdAt.toIso8601String(),
        if (prior?.durationSeconds != null)
          'durationSeconds': prior!.durationSeconds,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // AI Analysis
  // ---------------------------------------------------------------------------

  Future<void> saveAiAnalysis(AiAnalysis analysis) async {
    await _aiAnalysesBox?.put(analysis.sessionId, analysis);
    await eventLog.append(
      type: EventTypes.analysisCompleted,
      payload: {
        'sessionId': analysis.sessionId,
      },
    );
  }

  AiAnalysis? getAiAnalysis(String sessionId) =>
      _aiAnalysesBox?.get(sessionId);

  Future<void> deleteAiAnalysis(String sessionId) async {
    await _aiAnalysesBox?.delete(sessionId);
    await eventLog.append(
      type: EventTypes.analysisDiscarded,
      payload: {'sessionId': sessionId},
    );
  }

  // ---------------------------------------------------------------------------
  // Oura Daily Records
  // ---------------------------------------------------------------------------

  Future<void> saveOuraDailyRecord(OuraDailyRecord record) async {
    final key = record.date.toIso8601String().substring(0, 10);
    await _dailyRecordsBox?.put(key, record);
    // Batch import: one event per logical sub-domain populated by this
    // save. Oura daily records bundle sleep + readiness (and sometimes
    // neither — e.g. offline days). Missing sub-domains don't get an
    // event since nothing new arrived in that area.
    final hasSleep =
        record.sleepScore != null || record.sleepContributors != null;
    final hasReadiness = record.readinessScore != null ||
        record.readinessContributors != null;
    if (hasSleep) {
      await eventLog.append(
        type: EventTypes.ouraSleepImported,
        payload: {
          'date': key,
          'sleepScore': record.sleepScore,
        },
      );
    }
    if (hasReadiness) {
      await eventLog.append(
        type: EventTypes.ouraReadinessImported,
        payload: {
          'date': key,
          'readinessScore': record.readinessScore,
        },
      );
    }
    // Emit the activity event when neither of the specific sub-domains
    // applies but the record still brought in activity-adjacent signals
    // (vo2Max, cardiovascularAge, stressDaySummary). Keeps the log
    // invariant "one import → at least one event" intact.
    if (!hasSleep && !hasReadiness) {
      await eventLog.append(
        type: EventTypes.ouraActivityImported,
        payload: {
          'date': key,
          'vo2Max': record.vo2Max,
          'cardiovascularAge': record.cardiovascularAge,
          'resilienceLevel': record.resilienceLevel,
        },
      );
    }
  }

  OuraDailyRecord? getOuraDailyRecord(DateTime date) {
    final key = date.toIso8601String().substring(0, 10);
    return _dailyRecordsBox?.get(key);
  }

  List<OuraDailyRecord> getOuraRecordsInRange(DateTime from, DateTime to) {
    if (_dailyRecordsBox == null) return [];
    return _dailyRecordsBox!.values
        .where((r) => !r.date.isBefore(from) && !r.date.isAfter(to))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  // ---------------------------------------------------------------------------
  // User Profile
  // ---------------------------------------------------------------------------

  /// Low-level profile put without event emission. Used by the meal-
  /// time updaters so they can emit their own domain-specific event
  /// (`meal.logged`) instead of the generic profile-change event.
  Future<void> _putProfile(UserProfile profile) async {
    await _userProfileBox?.put('profile', profile);
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    await _putProfile(profile);
    await eventLog.append(
      type: EventTypes.profileFieldChanged,
      payload: profile.toJson(),
    );
  }

  UserProfile? getUserProfile() => _userProfileBox?.get('profile');

  Future<void> updateLastMealTime() async {
    final existing = getUserProfile();
    if (existing == null) return;

    final mealTime = DateTime.now();
    final updated = UserProfile(
      userId: existing.userId,
      createdAt: existing.createdAt,
      biologicalSex: existing.biologicalSex,
      dateOfBirth: existing.dateOfBirth,
      heightCm: existing.heightCm,
      weightKg: existing.weightKg,
      healthGoals: existing.healthGoals,
      knownConditions: existing.knownConditions,
      baselineEstablished: existing.baselineEstablished,
      aiProvider: existing.aiProvider,
      aiModel: existing.aiModel,
      preferredUnits: existing.preferredUnits,
      aiCoachingStyle: existing.aiCoachingStyle,
      mthfr: existing.mthfr,
      apoe: existing.apoe,
      comt: existing.comt,
      fastingType: existing.fastingType,
      eatWindowStartHour: existing.eatWindowStartHour,
      eatWindowEndHour: existing.eatWindowEndHour,
      lastMealTime: mealTime,
    );
    await _putProfile(updated);
    await eventLog.append(
      type: EventTypes.mealLogged,
      payload: {'loggedAt': mealTime.toIso8601String()},
    );
    unawaited(WidgetService.updateWidget());
  }

  /// Set the stored last-meal time to an explicit value. Used when the
  /// home-screen widget's "I ate" button fires while the app is closed —
  /// WidgetService reads the epoch written to SharedPreferences by the
  /// broadcast receiver and mirrors it back into Hive.
  Future<void> updateLastMealTimeExplicit(DateTime mealTime) async {
    final existing = getUserProfile();
    if (existing == null) return;

    final updated = UserProfile(
      userId: existing.userId,
      createdAt: existing.createdAt,
      biologicalSex: existing.biologicalSex,
      dateOfBirth: existing.dateOfBirth,
      heightCm: existing.heightCm,
      weightKg: existing.weightKg,
      healthGoals: existing.healthGoals,
      knownConditions: existing.knownConditions,
      baselineEstablished: existing.baselineEstablished,
      aiProvider: existing.aiProvider,
      aiModel: existing.aiModel,
      preferredUnits: existing.preferredUnits,
      aiCoachingStyle: existing.aiCoachingStyle,
      mthfr: existing.mthfr,
      apoe: existing.apoe,
      comt: existing.comt,
      fastingType: existing.fastingType,
      eatWindowStartHour: existing.eatWindowStartHour,
      eatWindowEndHour: existing.eatWindowEndHour,
      lastMealTime: mealTime,
    );
    await _putProfile(updated);
    await eventLog.append(
      type: EventTypes.mealLogged,
      payload: {
        'loggedAt': mealTime.toIso8601String(),
        'source': 'widget',
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Connector States
  // ---------------------------------------------------------------------------

  Future<void> saveConnectorState(ConnectorState state) async {
    await _connectorStatesBox?.put(state.connectorId, state);
    // Intentionally emits the generic state-changed event rather than
    // device.connected/disconnected: this path is driven by internal
    // connector-registry bookkeeping (automatic reconnects, sync
    // completion), not explicit user pairing actions. The specific
    // types are reserved for user-initiated flows layered on top.
    await eventLog.append(
      type: EventTypes.deviceStateChanged,
      payload: state.toJson(),
    );
  }

  ConnectorState? getConnectorState(String connectorId) =>
      _connectorStatesBox?.get(connectorId);

  List<ConnectorState> getAllConnectorStates() =>
      _connectorStatesBox?.values.toList() ?? [];

  // ---------------------------------------------------------------------------
  // Bloodwork
  // ---------------------------------------------------------------------------

  // Reference refactor (1/2): chosen as the "single-field simple write"
  // example for the two-write pattern. Every bloodwork record is a
  // discrete profile-level addition with a clean existing toJson, so the
  // event payload piggybacks on the model directly.
  Future<void> saveBloodwork(Bloodwork bloodwork) async {
    await _bloodworkBox?.put(bloodwork.id, bloodwork);
    await eventLog.append(
      type: EventTypes.profileBloodworkAdded,
      payload: bloodwork.toJson(),
    );
  }

  Bloodwork? getBloodwork(String id) => _bloodworkBox?.get(id);

  List<Bloodwork> getAllBloodwork() {
    if (_bloodworkBox == null) return [];
    final list = _bloodworkBox!.values.toList();
    list.sort((a, b) => b.labDate.compareTo(a.labDate));
    return list;
  }

  Future<void> deleteBloodwork(String id) async {
    final prior = _bloodworkBox?.get(id);
    await _bloodworkBox?.delete(id);
    await eventLog.append(
      type: EventTypes.profileBloodworkRemoved,
      payload: {
        'id': id,
        if (prior != null) 'labDate': prior.labDate.toIso8601String(),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  Future<void> clearAll() async {
    await _sessionsBox?.clear();
    await _dailyRecordsBox?.clear();
    await _aiAnalysesBox?.clear();
    await _interventionsBox?.clear();
    await _userProfileBox?.clear();
    await _connectorStatesBox?.clear();
    await _biometricRecordsBox?.clear();
    await _bloodworkBox?.clear();
    await _sessionTemplatesBox?.clear();
    await _activeProtocolsBox?.clear();
    await _bookmarksBox?.clear();
    await _journalBox?.clear();
    // One summary event for the whole batch — per-box events would be
    // noise and there's no per-record context to preserve. The events
    // box survives clearAll, so this record sticks around.
    await eventLog.append(
      type: EventTypes.appDataCleared,
      payload: {'boxes': List<String>.from(_boxNames)},
    );
  }

  // ---------------------------------------------------------------------------
  // Session Templates
  // ---------------------------------------------------------------------------

  Future<void> saveTemplate(SessionTemplate template) async {
    await _sessionTemplatesBox?.put(template.id, template);
    await eventLog.append(
      type: EventTypes.sessionTemplateSaved,
      payload: {
        'id': template.id,
        'name': template.name,
        'sessionType': template.sessionType,
      },
    );
  }

  SessionTemplate? getTemplate(String id) =>
      _sessionTemplatesBox?.get(id);

  List<SessionTemplate> getAllTemplates() {
    if (_sessionTemplatesBox == null) return [];
    final list = _sessionTemplatesBox!.values.toList();
    list.sort((a, b) => b.useCount.compareTo(a.useCount));
    return list;
  }

  Future<void> deleteTemplate(String id) async {
    final prior = _sessionTemplatesBox?.get(id);
    await _sessionTemplatesBox?.delete(id);
    await eventLog.append(
      type: EventTypes.sessionTemplateDeleted,
      payload: {
        'id': id,
        if (prior != null) 'name': prior.name,
      },
    );
  }

  Future<void> incrementTemplateUseCount(String id) async {
    final existing = _sessionTemplatesBox?.get(id);
    if (existing == null) return;

    final updated = SessionTemplate(
      id: existing.id,
      name: existing.name,
      sessionType: existing.sessionType,
      breathworkPattern: existing.breathworkPattern,
      breathworkRounds: existing.breathworkRounds,
      breathHoldTargetSec: existing.breathHoldTargetSec,
      coldTempF: existing.coldTempF,
      coldDurationMin: existing.coldDurationMin,
      notes: existing.notes,
      lastUsedAt: DateTime.now(),
      useCount: existing.useCount + 1,
    );
    await _sessionTemplatesBox?.put(id, updated);
    await eventLog.append(
      type: EventTypes.sessionTemplateUsed,
      payload: {
        'id': id,
        'name': existing.name,
        'useCount': updated.useCount,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Active Protocols
  // ---------------------------------------------------------------------------

  // Reference refactor (2/2): chosen as the "frequent entity write"
  // example. Active protocols are added/modified multiple times per
  // day once the protocol-builder flow is live — this is the closest
  // existing analog to the high-frequency sample writes that the rest
  // of the refactor pass will target.
  Future<void> saveActiveProtocol(ActiveProtocol protocol) async {
    await _activeProtocolsBox?.put(protocol.id, protocol);
    await eventLog.append(
      type: EventTypes.protocolItemAdded,
      payload: protocol.toJson(),
    );
  }

  ActiveProtocol? getActiveProtocol(String id) =>
      _activeProtocolsBox?.get(id);

  List<ActiveProtocol> getAllActiveProtocols() {
    if (_activeProtocolsBox == null) return [];
    return _activeProtocolsBox!.values
        .where((p) => p.isActive)
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  List<ActiveProtocol> getAllProtocols() {
    if (_activeProtocolsBox == null) return [];
    return _activeProtocolsBox!.values.toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  Future<void> endProtocol(String id) async {
    final existing = _activeProtocolsBox?.get(id);
    if (existing == null) return;

    final updated = ActiveProtocol(
      id: existing.id,
      name: existing.name,
      type: existing.type,
      startDate: existing.startDate,
      endDate: DateTime.now(),
      cycleLengthDays: existing.cycleLengthDays,
      doseMcg: existing.doseMcg,
      route: existing.route,
      notes: existing.notes,
      isActive: false,
    );
    await _activeProtocolsBox?.put(id, updated);
    await eventLog.append(
      type: EventTypes.protocolItemModified,
      payload: {
        'id': id,
        'name': updated.name,
        'isActive': false,
        'endDate': updated.endDate!.toIso8601String(),
      },
    );
  }

  Future<void> deleteActiveProtocol(String id) async {
    final prior = _activeProtocolsBox?.get(id);
    await _activeProtocolsBox?.delete(id);
    await eventLog.append(
      type: EventTypes.protocolItemRemoved,
      payload: {
        'id': id,
        if (prior != null) 'name': prior.name,
        if (prior != null) 'type': prior.type,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Vitals Bookmarks
  // ---------------------------------------------------------------------------

  Future<void> saveBookmark(VitalsBookmark bookmark) async {
    final json = jsonEncode(bookmark.toJson());
    await _bookmarksBox?.put(bookmark.id, json);
    await eventLog.append(
      type: EventTypes.bookmarkAdded,
      payload: bookmark.toJson(),
    );
  }

  List<VitalsBookmark> getAllBookmarks() {
    if (_bookmarksBox == null) return [];
    return _bookmarksBox!.values
        .map((s) => VitalsBookmark.fromJson(
            jsonDecode(s) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  List<VitalsBookmark> getBookmarksInRange(DateTime from, DateTime to) {
    return getAllBookmarks()
        .where(
            (b) => !b.timestamp.isBefore(from) && !b.timestamp.isAfter(to))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Health Journal
  // ---------------------------------------------------------------------------

  Future<void> saveJournalEntry(HealthJournalEntry entry) async {
    await _journalBox!.put(entry.id, jsonEncode(entry.toJson()));
    await eventLog.append(
      type: EventTypes.journalEntryAdded,
      payload: {
        'id': entry.id,
        'conversationId': entry.conversationId,
        'timestamp': entry.timestamp.toIso8601String(),
      },
    );
  }

  List<HealthJournalEntry> getAllJournalEntries() {
    return _journalBox!.values
        .map((s) => HealthJournalEntry.fromJson(
            jsonDecode(s) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  List<HealthJournalEntry> getJournalEntriesInRange(
      DateTime from, DateTime to) {
    return getAllJournalEntries()
        .where((e) =>
            !e.timestamp.isBefore(from) && !e.timestamp.isAfter(to))
        .toList();
  }

  Future<void> updateJournalEntry(HealthJournalEntry entry) async {
    await _journalBox!.put(entry.id, jsonEncode(entry.toJson()));
    await eventLog.append(
      type: EventTypes.journalEntryEdited,
      payload: {
        'id': entry.id,
        'conversationId': entry.conversationId,
        'timestamp': entry.timestamp.toIso8601String(),
      },
    );
  }

  List<HealthJournalEntry> getEntriesForConversation(
      String conversationId) {
    return getAllJournalEntries()
        .where((e) => e.conversationId == conversationId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// All unique conversation IDs with their latest entry timestamp and a
  /// display title derived from the conversation's first user message.
  List<({String id, String title, DateTime lastUpdated})>
      getAllConversations() {
    final entries = getAllJournalEntries();
    final Map<String, HealthJournalEntry> latest = {};
    final Map<String, HealthJournalEntry> earliest = {};
    for (final e in entries) {
      if (!latest.containsKey(e.conversationId) ||
          e.timestamp.isAfter(latest[e.conversationId]!.timestamp)) {
        latest[e.conversationId] = e;
      }
      if (!earliest.containsKey(e.conversationId) ||
          e.timestamp.isBefore(earliest[e.conversationId]!.timestamp)) {
        earliest[e.conversationId] = e;
      }
    }
    return latest.entries.map((kv) => (
          id: kv.key,
          title: _conversationTitle(
              kv.key, earliest[kv.key]!.userMessage),
          lastUpdated: kv.value.timestamp,
        ))
        .toList()
      ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
  }

  String _conversationTitle(String id, String firstMessage) {
    if (id == 'default') return 'General';
    final clean = firstMessage.replaceAll('\n', ' ').trim();
    return clean.length > 40 ? '${clean.substring(0, 40)}...' : clean;
  }

  Future<String> createNewConversation() async {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
