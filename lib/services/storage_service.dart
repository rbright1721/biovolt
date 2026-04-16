import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_analysis.dart';
import '../models/biometric_records.dart';
import '../models/bloodwork.dart';
import '../models/interventions.dart';
import '../models/normalized_record.dart';
import '../models/oura_daily.dart';
import '../models/sensor_snapshot.dart';
import '../models/session.dart';
import '../models/session_type.dart';
import '../models/sleep_record.dart';
import '../models/active_protocol.dart';
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

  // Bump this whenever TypeAdapter IDs or model shapes change.
  // Forces a full Hive wipe on devices with stale data.
  static const _schemaVersion = 3;
  static const _schemaKey = 'hive_schema_version';

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

    _initialized = true;
  }

  /// Wipe all Hive box files if the schema version has changed.
  Future<void> _migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_schemaKey) ?? 0;

    if (stored < _schemaVersion) {
      debugPrint(
          'Schema upgrade: $stored \u2192 $_schemaVersion \u2014 wiping Hive boxes');
      // Delete each box individually — more reliable than deleteFromDisk
      for (final name in _boxNames) {
        try {
          if (await Hive.boxExists(name)) {
            await Hive.deleteBoxFromDisk(name);
          }
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
    } catch (e) {
      // Nuclear option — if boxes are corrupt, wipe everything and retry
      debugPrint('Hive box open failed: $e \u2014 nuking all data');
      for (final name in _boxNames) {
        try {
          await Hive.deleteBoxFromDisk(name);
        } catch (_) {}
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_schemaKey, _schemaVersion);
    }
  }

  void _registerAdapters() {
    // -- Enums (normalized_record.dart): IDs 1-4 --
    Hive.registerAdapter(DataSourceAdapter());       // 1
    Hive.registerAdapter(DataQualityAdapter());      // 2
    Hive.registerAdapter(ConnectorTypeAdapter());    // 3
    Hive.registerAdapter(ConnectorStatusAdapter());  // 4

    // -- Biometric records: IDs 5-11 --
    Hive.registerAdapter(HeartRateReadingAdapter()); // 5
    Hive.registerAdapter(HRVReadingAdapter());       // 6
    Hive.registerAdapter(EDAReadingAdapter());       // 7
    Hive.registerAdapter(SpO2ReadingAdapter());      // 8
    Hive.registerAdapter(TemperatureReadingAdapter()); // 9
    Hive.registerAdapter(ECGRecordAdapter());        // 10
    Hive.registerAdapter(TemperaturePlacementAdapter()); // 11

    // -- Sleep: IDs 12-14 --
    Hive.registerAdapter(SleepRecordAdapter());      // 12
    Hive.registerAdapter(SleepContributorsAdapter()); // 13
    Hive.registerAdapter(ReadinessContributorsAdapter()); // 14

    // -- Oura daily: ID 15 --
    Hive.registerAdapter(OuraDailyRecordAdapter());  // 15

    // -- Session: IDs 16-24 --
    Hive.registerAdapter(SessionAdapter());          // 16
    Hive.registerAdapter(SessionContextAdapter());   // 17
    Hive.registerAdapter(SessionActivityAdapter());  // 18
    Hive.registerAdapter(SessionBiometricsAdapter()); // 19
    Hive.registerAdapter(Esp32MetricsAdapter());     // 20
    Hive.registerAdapter(PolarMetricsAdapter());     // 21
    Hive.registerAdapter(ComputedMetricsAdapter());  // 22
    Hive.registerAdapter(SessionSubjectiveAdapter()); // 23
    Hive.registerAdapter(SubjectiveScoresAdapter()); // 24

    // -- AI analysis: ID 25 --
    Hive.registerAdapter(AiAnalysisAdapter());       // 25

    // -- Interventions: IDs 26-30 --
    Hive.registerAdapter(InterventionsAdapter());    // 26
    Hive.registerAdapter(PeptideLogAdapter());       // 27
    Hive.registerAdapter(SupplementLogAdapter());    // 28
    Hive.registerAdapter(NutritionLogAdapter());     // 29
    Hive.registerAdapter(HydrationLogAdapter());     // 30

    // -- User profile: IDs 31-32 --
    Hive.registerAdapter(UserProfileAdapter());      // 31
    Hive.registerAdapter(ConnectorStateAdapter());   // 32

    // -- Session type + Snapshot: IDs 33-34 --
    Hive.registerAdapter(SessionTypeAdapter());      // 33
    Hive.registerAdapter(SensorSnapshotAdapter());   // 34

    // -- Bloodwork: ID 35 --
    Hive.registerAdapter(BloodworkAdapter());        // 35

    // -- Session templates: ID 40 --
    Hive.registerAdapter(SessionTemplateAdapter());  // 40

    // -- Active protocols: ID 41 --
    Hive.registerAdapter(ActiveProtocolAdapter());   // 41
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
    ];

    for (final (id, name) in adapters) {
      if (ids.containsKey(id)) {
        debugPrint(
            'ADAPTER ID COLLISION: $id used by both ${ids[id]} and $name');
      }
      ids[id] = name;
    }

    debugPrint('Hive adapters registered: ${ids.length} (IDs 1-35, no collisions)');
  }

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  Future<void> saveSession(Session session) async {
    await _sessionsBox?.put(session.sessionId, session);
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
    await _sessionsBox?.delete(sessionId);
  }

  // ---------------------------------------------------------------------------
  // AI Analysis
  // ---------------------------------------------------------------------------

  Future<void> saveAiAnalysis(AiAnalysis analysis) async {
    await _aiAnalysesBox?.put(analysis.sessionId, analysis);
  }

  AiAnalysis? getAiAnalysis(String sessionId) =>
      _aiAnalysesBox?.get(sessionId);

  // ---------------------------------------------------------------------------
  // Oura Daily Records
  // ---------------------------------------------------------------------------

  Future<void> saveOuraDailyRecord(OuraDailyRecord record) async {
    final key = record.date.toIso8601String().substring(0, 10);
    await _dailyRecordsBox?.put(key, record);
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

  Future<void> saveUserProfile(UserProfile profile) async {
    await _userProfileBox?.put('profile', profile);
  }

  UserProfile? getUserProfile() => _userProfileBox?.get('profile');

  Future<void> updateLastMealTime() async {
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
      lastMealTime: DateTime.now(),
    );
    await saveUserProfile(updated);
  }

  // ---------------------------------------------------------------------------
  // Connector States
  // ---------------------------------------------------------------------------

  Future<void> saveConnectorState(ConnectorState state) async {
    await _connectorStatesBox?.put(state.connectorId, state);
  }

  ConnectorState? getConnectorState(String connectorId) =>
      _connectorStatesBox?.get(connectorId);

  List<ConnectorState> getAllConnectorStates() =>
      _connectorStatesBox?.values.toList() ?? [];

  // ---------------------------------------------------------------------------
  // Bloodwork
  // ---------------------------------------------------------------------------

  Future<void> saveBloodwork(Bloodwork bloodwork) async {
    await _bloodworkBox?.put(bloodwork.id, bloodwork);
  }

  Bloodwork? getBloodwork(String id) => _bloodworkBox?.get(id);

  List<Bloodwork> getAllBloodwork() {
    if (_bloodworkBox == null) return [];
    final list = _bloodworkBox!.values.toList();
    list.sort((a, b) => b.labDate.compareTo(a.labDate));
    return list;
  }

  Future<void> deleteBloodwork(String id) async {
    await _bloodworkBox?.delete(id);
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
  }

  // ---------------------------------------------------------------------------
  // Session Templates
  // ---------------------------------------------------------------------------

  Future<void> saveTemplate(SessionTemplate template) async {
    await _sessionTemplatesBox?.put(template.id, template);
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
    await _sessionTemplatesBox?.delete(id);
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
  }

  // ---------------------------------------------------------------------------
  // Active Protocols
  // ---------------------------------------------------------------------------

  Future<void> saveActiveProtocol(ActiveProtocol protocol) async {
    await _activeProtocolsBox?.put(protocol.id, protocol);
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
  }

  Future<void> deleteActiveProtocol(String id) async {
    await _activeProtocolsBox?.delete(id);
  }
}
