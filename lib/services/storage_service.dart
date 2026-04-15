import 'package:hive_flutter/hive_flutter.dart';

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
import '../models/user_profile.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late Box<Session> _sessionsBox;
  late Box<OuraDailyRecord> _dailyRecordsBox;
  late Box<AiAnalysis> _aiAnalysesBox;
  late Box<Interventions> _interventionsBox;
  late Box<UserProfile> _userProfileBox;
  late Box<ConnectorState> _connectorStatesBox;
  late Box _biometricRecordsBox;
  late Box<Bloodwork> _bloodworkBox;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    // -- Enums (normalized_record.dart) --
    Hive.registerAdapter(DataSourceAdapter());
    Hive.registerAdapter(DataQualityAdapter());
    Hive.registerAdapter(ConnectorTypeAdapter());
    Hive.registerAdapter(ConnectorStatusAdapter());

    // -- Biometric records --
    Hive.registerAdapter(HeartRateReadingAdapter());
    Hive.registerAdapter(HRVReadingAdapter());
    Hive.registerAdapter(EDAReadingAdapter());
    Hive.registerAdapter(SpO2ReadingAdapter());
    Hive.registerAdapter(TemperatureReadingAdapter());
    Hive.registerAdapter(ECGRecordAdapter());
    Hive.registerAdapter(TemperaturePlacementAdapter());

    // -- Sleep --
    Hive.registerAdapter(SleepRecordAdapter());
    Hive.registerAdapter(SleepContributorsAdapter());
    Hive.registerAdapter(ReadinessContributorsAdapter());

    // -- Oura daily --
    Hive.registerAdapter(OuraDailyRecordAdapter());

    // -- Session --
    Hive.registerAdapter(SessionAdapter());
    Hive.registerAdapter(SessionContextAdapter());
    Hive.registerAdapter(SessionActivityAdapter());
    Hive.registerAdapter(SessionBiometricsAdapter());
    Hive.registerAdapter(Esp32MetricsAdapter());
    Hive.registerAdapter(PolarMetricsAdapter());
    Hive.registerAdapter(ComputedMetricsAdapter());
    Hive.registerAdapter(SessionSubjectiveAdapter());
    Hive.registerAdapter(SubjectiveScoresAdapter());

    // -- AI analysis --
    Hive.registerAdapter(AiAnalysisAdapter());

    // -- Interventions --
    Hive.registerAdapter(InterventionsAdapter());
    Hive.registerAdapter(PeptideLogAdapter());
    Hive.registerAdapter(SupplementLogAdapter());
    Hive.registerAdapter(NutritionLogAdapter());
    Hive.registerAdapter(HydrationLogAdapter());

    // -- User profile --
    Hive.registerAdapter(UserProfileAdapter());
    Hive.registerAdapter(ConnectorStateAdapter());

    // -- Bloodwork --
    Hive.registerAdapter(BloodworkAdapter());

    // -- Legacy / real-time types --
    Hive.registerAdapter(SessionTypeAdapter());
    Hive.registerAdapter(SensorSnapshotAdapter());

    // -- Open boxes --
    _sessionsBox = await Hive.openBox<Session>('sessions');
    _dailyRecordsBox = await Hive.openBox<OuraDailyRecord>('daily_records');
    _aiAnalysesBox = await Hive.openBox<AiAnalysis>('ai_analyses');
    _interventionsBox = await Hive.openBox<Interventions>('interventions');
    _userProfileBox = await Hive.openBox<UserProfile>('user_profile');
    _connectorStatesBox =
        await Hive.openBox<ConnectorState>('connector_states');
    _biometricRecordsBox = await Hive.openBox('biometric_records');
    _bloodworkBox = await Hive.openBox<Bloodwork>('bloodwork');

    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  Future<void> saveSession(Session session) async {
    await _sessionsBox.put(session.sessionId, session);
  }

  Session? getSession(String sessionId) => _sessionsBox.get(sessionId);

  List<Session> getAllSessions() {
    final sessions = _sessionsBox.values.toList();
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  List<Session> getSessionsInRange(DateTime from, DateTime to) {
    return _sessionsBox.values
        .where((s) =>
            !s.createdAt.isBefore(from) && !s.createdAt.isAfter(to))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> deleteSession(String sessionId) async {
    await _sessionsBox.delete(sessionId);
  }

  // ---------------------------------------------------------------------------
  // AI Analysis
  // ---------------------------------------------------------------------------

  Future<void> saveAiAnalysis(AiAnalysis analysis) async {
    await _aiAnalysesBox.put(analysis.sessionId, analysis);
  }

  AiAnalysis? getAiAnalysis(String sessionId) =>
      _aiAnalysesBox.get(sessionId);

  // ---------------------------------------------------------------------------
  // Oura Daily Records
  // ---------------------------------------------------------------------------

  Future<void> saveOuraDailyRecord(OuraDailyRecord record) async {
    final key = record.date.toIso8601String().substring(0, 10);
    await _dailyRecordsBox.put(key, record);
  }

  OuraDailyRecord? getOuraDailyRecord(DateTime date) {
    final key = date.toIso8601String().substring(0, 10);
    return _dailyRecordsBox.get(key);
  }

  List<OuraDailyRecord> getOuraRecordsInRange(DateTime from, DateTime to) {
    return _dailyRecordsBox.values
        .where((r) => !r.date.isBefore(from) && !r.date.isAfter(to))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  // ---------------------------------------------------------------------------
  // User Profile
  // ---------------------------------------------------------------------------

  Future<void> saveUserProfile(UserProfile profile) async {
    await _userProfileBox.put('profile', profile);
  }

  UserProfile? getUserProfile() => _userProfileBox.get('profile');

  // ---------------------------------------------------------------------------
  // Connector States
  // ---------------------------------------------------------------------------

  Future<void> saveConnectorState(ConnectorState state) async {
    await _connectorStatesBox.put(state.connectorId, state);
  }

  ConnectorState? getConnectorState(String connectorId) =>
      _connectorStatesBox.get(connectorId);

  List<ConnectorState> getAllConnectorStates() =>
      _connectorStatesBox.values.toList();

  // ---------------------------------------------------------------------------
  // Bloodwork
  // ---------------------------------------------------------------------------

  Future<void> saveBloodwork(Bloodwork bloodwork) async {
    await _bloodworkBox.put(bloodwork.id, bloodwork);
  }

  Bloodwork? getBloodwork(String id) => _bloodworkBox.get(id);

  List<Bloodwork> getAllBloodwork() {
    final list = _bloodworkBox.values.toList();
    list.sort((a, b) => b.labDate.compareTo(a.labDate));
    return list;
  }

  Future<void> deleteBloodwork(String id) async {
    await _bloodworkBox.delete(id);
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  Future<void> clearAll() async {
    await _sessionsBox.clear();
    await _dailyRecordsBox.clear();
    await _aiAnalysesBox.clear();
    await _interventionsBox.clear();
    await _userProfileBox.clear();
    await _connectorStatesBox.clear();
    await _biometricRecordsBox.clear();
    await _bloodworkBox.clear();
  }
}
