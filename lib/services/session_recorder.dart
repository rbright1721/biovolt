import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../connectors/connector_registry.dart';
import 'auth_service.dart';
import '../models/ai_analysis.dart';
import '../models/biometric_records.dart';
import '../models/device_capability.dart';
import '../models/interventions.dart';
import '../models/normalized_record.dart';
import '../models/session.dart';
import 'ai_service.dart';
import 'firestore_sync.dart';
import 'prompt_builder.dart';
import 'storage_service.dart';
import 'widget_service.dart';

/// How the recorder is currently collecting data for the active session.
///
/// Driven entirely by [ConnectorRegistry.availableCapabilities] — no
/// per-connector name checks. Mode can change mid-session if a live
/// connector drops while a summary-only connector remains.
enum SessionMode {
  /// At least one connected connector streams live heart rate. Buffer
  /// samples, persist every 10s, run quick coach.
  streaming,

  /// No live HR, but a summary connector (e.g. Oura) can backfill
  /// averages after the session ends. UI should show the enrich-later
  /// banner; the recorder stores the session skeleton and queues an
  /// enrichment request at stopSession time.
  enrichLater,

  /// No live streams and no summary backfill available. Purely manual
  /// session — subjective scores only.
  manual,
}

/// Manages the full lifecycle of an active biofeedback session.
///
/// Subscribes to the connector registry's merged live stream, buffers
/// metrics in a rolling 60-second window, periodically persists to
/// [StorageService], and runs real-time AI coaching every 10 seconds.
class SessionRecorder {
  final StorageService _storage;
  final AiService _aiService;
  final PromptBuilder _promptBuilder;
  final ConnectorRegistry _connectorRegistry;

  Session? _activeSession;
  StreamSubscription? _sensorSubscription;
  StreamSubscription? _capabilitySubscription;
  Timer? _persistTimer;
  Timer? _coachTimer;

  SessionMode _mode = SessionMode.manual;

  bool _coachRunning = false;

  /// Rolling 60-second window of raw NormalizedRecords.
  final _recordBuffer = ListQueue<NormalizedRecord>();
  static const _bufferWindowSeconds = 60;

  /// Full session record buffer for final metrics computation.
  final _fullSessionRecords = <NormalizedRecord>[];

  /// Emits real-time coaching strings during a session.
  final _coachController = StreamController<String>.broadcast();
  Stream<String> get coachStream => _coachController.stream;

  /// Emits incremental metric snapshots for UI display.
  final _metricsController = StreamController<Map<String, double>>.broadcast();
  Stream<Map<String, double>> get metricsStream => _metricsController.stream;

  /// Emits when post-session deep analysis completes.
  final _analysisCompleteController =
      StreamController<AiAnalysis>.broadcast();
  Stream<AiAnalysis> get analysisCompleteStream =>
      _analysisCompleteController.stream;

  /// Emits whenever the current [SessionMode] changes — typically when
  /// a live connector drops mid-session and the recorder falls back to
  /// enrich-later, or when a device reconnects and streaming resumes.
  final _modeController = StreamController<SessionMode>.broadcast();
  Stream<SessionMode> get modeStream => _modeController.stream;

  /// Current session mode. Valid during an active session; read as
  /// [SessionMode.manual] when idle.
  SessionMode get mode => _mode;

  /// Pure capability → mode mapping. Extracted so tests can exercise
  /// the decision without spinning up the full recorder.
  @visibleForTesting
  static SessionMode modeForCapabilities(Set<DeviceCapability> caps) {
    if (caps.contains(DeviceCapability.liveHeartRate)) {
      return SessionMode.streaming;
    }
    if (caps.contains(DeviceCapability.summaryHeartRate)) {
      return SessionMode.enrichLater;
    }
    return SessionMode.manual;
  }

  SessionRecorder({
    required StorageService storage,
    required AiService aiService,
    required PromptBuilder promptBuilder,
    required ConnectorRegistry connectorRegistry,
  })  : _storage = storage,
        _aiService = aiService,
        _promptBuilder = promptBuilder,
        _connectorRegistry = connectorRegistry;

  /// Whether a session is currently being recorded.
  bool get isRecording => _activeSession != null;

  /// The currently active session, or null.
  Session? get activeSession => _activeSession;

  // ---------------------------------------------------------------------------
  // Start
  // ---------------------------------------------------------------------------

  /// Start recording a new session.
  ///
  /// Returns the generated sessionId.
  String startSession(SessionContext context, [Interventions? interventions]) {
    final now = DateTime.now();
    final sessionId = now.millisecondsSinceEpoch.toString();

    // Data sources reflect whatever's actually connected right now.
    final connectedIds = _connectorRegistry
        .getConnected()
        .map((c) => c.connectorId)
        .toList();

    _activeSession = Session(
      sessionId: sessionId,
      userId: AuthService().currentUserId ?? 'anonymous',
      createdAt: now,
      timezone: now.timeZoneName,
      dataSources: connectedIds,
      context: context,
      interventions: interventions,
    );

    _recordBuffer.clear();
    _fullSessionRecords.clear();

    // Let every connected connector reset per-session baselines
    // (ESP32 rebuilds its GSR tonic zero here; others no-op).
    for (final c in _connectorRegistry.getConnected()) {
      unawaited(c.prepareForSession().catchError(
          (e) => debugPrint('prepareForSession failed for ${c.connectorId}: $e')));
    }

    // Capability-driven mode selection. Re-evaluate whenever the
    // registry reports a change so a mid-session disconnect can
    // transition streaming → enrich-later without restarting.
    _applyMode(
        modeForCapabilities(_connectorRegistry.availableCapabilities()));
    _capabilitySubscription =
        _connectorRegistry.capabilityStream.listen((caps) {
      _applyMode(modeForCapabilities(caps));
    });

    // Subscribe to merged live stream from all connectors. In enrich-
    // later / manual modes this stream is either empty or sparse; it's
    // still safe to listen because nothing will arrive.
    _sensorSubscription =
        _connectorRegistry.mergedLiveStream.listen(_onRecord);

    // Persist every 10 seconds
    _persistTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _persistCurrentState();
    });

    // Coach every 10 seconds (if AI key configured and we have live data)
    _coachTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_mode == SessionMode.streaming) _runQuickCoach();
    });

    // Initial persist
    _persistCurrentState();

    return sessionId;
  }

  void _applyMode(SessionMode next) {
    if (next == _mode && isRecording) return;
    _mode = next;
    _modeController.add(next);
  }

  /// Stub hook for post-session Oura/summary enrichment. Invoked at
  /// stopSession time when the recorder ran in enrich-later mode.
  /// Actual backfill logic is a future session — this just records
  /// intent so the rest of the wiring can be exercised end-to-end.
  Future<void> _queueEnrichment(String sessionId) async {
    debugPrint(
        'SessionRecorder: queued summary enrichment for session $sessionId (stub)');
  }

  // ---------------------------------------------------------------------------
  // Stop
  // ---------------------------------------------------------------------------

  /// Stop the active session, finalize metrics, save, and trigger analysis.
  ///
  /// Returns the completed [Session].
  Future<Session> stopSession() async {
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _capabilitySubscription?.cancel();
    _capabilitySubscription = null;
    _persistTimer?.cancel();
    _persistTimer = null;
    _coachTimer?.cancel();
    _coachTimer = null;

    final base = _activeSession;
    if (base == null) {
      throw StateError('No active session to stop');
    }

    final durationSeconds =
        DateTime.now().difference(base.createdAt).inSeconds;
    final computed = _buildComputedMetrics(_fullSessionRecords);
    final esp32 = _buildEsp32Metrics(_fullSessionRecords);
    final chestStrap = _buildChestStrapMetrics(_fullSessionRecords);

    final finalSession = Session(
      sessionId: base.sessionId,
      userId: base.userId,
      createdAt: base.createdAt,
      timezone: base.timezone,
      durationSeconds: durationSeconds,
      dataSources: base.dataSources,
      context: base.context,
      biometrics: SessionBiometrics(
        esp32: esp32,
        polarH10: chestStrap,
        computed: computed,
      ),
      interventions: base.interventions,
    );

    await _storage.saveSession(finalSession);
    unawaited(FirestoreSync().writeSession(finalSession, _storage));
    unawaited(WidgetService.updateWidget());

    // If we ran in enrich-later mode, queue the summary backfill stub
    // so the session eventually gets Oura-derived averages once the
    // next daily sync lands.
    if (_mode == SessionMode.enrichLater) {
      unawaited(_queueEnrichment(finalSession.sessionId));
    }

    _activeSession = null;
    _mode = SessionMode.manual;
    _recordBuffer.clear();
    _fullSessionRecords.clear();

    // Trigger deep analysis asynchronously
    _runDeepAnalysis(finalSession.sessionId)
        .catchError((e) => debugPrint('Analysis failed: $e'));

    return finalSession;
  }

  // ---------------------------------------------------------------------------
  // Record handling
  // ---------------------------------------------------------------------------

  void _onRecord(NormalizedRecord record) {
    _fullSessionRecords.add(record);

    // Maintain rolling 60s window
    _recordBuffer.addLast(record);
    final cutoff = DateTime.now()
        .subtract(const Duration(seconds: _bufferWindowSeconds));
    while (_recordBuffer.isNotEmpty &&
        _recordBuffer.first.timestamp.isBefore(cutoff)) {
      _recordBuffer.removeFirst();
    }

    // Emit current metrics snapshot
    _metricsController.add(_currentMetrics());
  }

  Map<String, double> _currentMetrics() {
    final metrics = <String, double>{};
    double? lastOfType<T extends NormalizedRecord>(
        double Function(T) extract) {
      for (var i = _recordBuffer.length - 1; i >= 0; i--) {
        final r = _recordBuffer.elementAt(i);
        if (r is T) return extract(r);
      }
      return null;
    }

    final hr = lastOfType<HeartRateReading>((r) => r.bpm);
    if (hr != null) metrics['heartRate'] = hr;

    final hrv = lastOfType<HRVReading>((r) => r.rmssdMs);
    if (hrv != null) metrics['hrv'] = hrv;

    final gsr = lastOfType<EDAReading>((r) => r.microSiemens);
    if (gsr != null) metrics['gsr'] = gsr;

    final spo2 = lastOfType<SpO2Reading>((r) => r.percent);
    if (spo2 != null) metrics['spo2'] = spo2;

    final temp = lastOfType<TemperatureReading>((r) => r.celsius);
    if (temp != null) metrics['temperature'] = temp;

    return metrics;
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  void _persistCurrentState() {
    final session = _activeSession;
    if (session == null) return;

    final durationSeconds =
        DateTime.now().difference(session.createdAt).inSeconds;
    final computed = _buildComputedMetrics(_fullSessionRecords);
    final esp32 = _buildEsp32Metrics(_fullSessionRecords);
    final chestStrap = _buildChestStrapMetrics(_fullSessionRecords);

    final updated = Session(
      sessionId: session.sessionId,
      userId: session.userId,
      createdAt: session.createdAt,
      timezone: session.timezone,
      durationSeconds: durationSeconds,
      dataSources: session.dataSources,
      context: session.context,
      biometrics: SessionBiometrics(
        esp32: esp32,
        polarH10: chestStrap,
        computed: computed,
      ),
      interventions: session.interventions,
    );

    _storage.saveSession(updated);
    unawaited(WidgetService.updateWidget());
  }

  // ---------------------------------------------------------------------------
  // AI coaching
  // ---------------------------------------------------------------------------

  Future<void> _runQuickCoach() async {
    if (_activeSession == null || _coachRunning) return;

    final hasKey = await _aiService.hasValidKey();
    if (!hasKey) return;

    _coachRunning = true;
    try {
      final prompt = await _promptBuilder.buildQuickCoachPrompt(
        _activeSession!,
        _currentMetrics(),
      );
      final result = await _aiService.quickCoach(
        prompt,
        systemPrompt: _promptBuilder.quickCoachSystemPrompt,
      );
      if (result.isNotEmpty) {
        _coachController.add(result);
      }
    } catch (e) {
      // Fail silently — don't interrupt session for coaching errors
      debugPrint('Quick coach error: $e');
    } finally {
      _coachRunning = false;
    }
  }

  Future<void> _runDeepAnalysis(String sessionId) async {
    final hasKey = await _aiService.hasValidKey();
    if (!hasKey) return;

    try {
      final prompt = await _promptBuilder.buildSessionPrompt(sessionId);
      final analysis = await _aiService.analyzeSession(
        sessionId,
        prompt,
        systemPrompt: PromptBuilder.systemPrompt,
        ouraContextUsed: _promptBuilder.lastPromptUsedOura,
      );
      _analysisCompleteController.add(analysis);
    } catch (e, stack) {
      debugPrint('_runDeepAnalysis unexpected error: $e');
      debugPrint('Stack: $stack');
      // Emit a fallback analysis so the UI stops spinning.
      final fallback = AiAnalysis(
        sessionId: sessionId,
        generatedAt: DateTime.now(),
        provider: 'anthropic',
        model: 'claude-sonnet-4-5',
        promptVersion: '1.0.0',
        insights: const [],
        anomalies: const [],
        correlationsDetected: const [],
        protocolRecommendations: const [],
        flags: ['Deep analysis failed: $e'],
        trendSummary: null,
        confidence: 0.0,
        ouraContextUsed: false,
      );
      await _storage.saveAiAnalysis(fallback);
      unawaited(FirestoreSync().writeAiAnalysis(fallback));
      _analysisCompleteController.add(fallback);
    }
  }

  // ---------------------------------------------------------------------------
  // Metrics computation
  // ---------------------------------------------------------------------------

  ComputedMetrics? _buildComputedMetrics(List<NormalizedRecord> records) {
    final hrReadings =
        records.whereType<HeartRateReading>().map((r) => r.bpm).toList();
    final hrvReadings =
        records.whereType<HRVReading>().map((r) => r.rmssdMs).toList();
    final hasEcg = records.whereType<ECGRecord>().isNotEmpty;

    if (hrReadings.isEmpty && hrvReadings.isEmpty) return null;

    return ComputedMetrics(
      hrSource: hasEcg ? 'Polar_ECG' : 'ESP32_PPG',
      hrvSource: hasEcg ? 'Polar_ECG' : 'ESP32_PPG',
      heartRateMeanBpm: hrReadings.isNotEmpty
          ? hrReadings.reduce((a, b) => a + b) / hrReadings.length
          : null,
      heartRateMinBpm: hrReadings.isNotEmpty
          ? hrReadings.reduce((a, b) => a < b ? a : b)
          : null,
      heartRateMaxBpm: hrReadings.isNotEmpty
          ? hrReadings.reduce((a, b) => a > b ? a : b)
          : null,
      hrvRmssdMs: hrvReadings.isNotEmpty
          ? hrvReadings.reduce((a, b) => a + b) / hrvReadings.length
          : null,
    );
  }

  /// Flatten every [RrIntervalSample] received during the session into a
  /// single [PolarMetrics] bundle, restricted to chest-strap-origin
  /// records so ESP32 pseudo-RRs never leak in here.
  @visibleForTesting
  static PolarMetrics? buildChestStrapMetrics(List<NormalizedRecord> records) =>
      _buildChestStrapMetrics(records);

  static PolarMetrics? _buildChestStrapMetrics(List<NormalizedRecord> records) {
    final chestStrapRrs = records
        .whereType<RrIntervalSample>()
        .where((r) => r.connectorId == 'chest_strap')
        .expand((r) => r.rrIntervalsMs)
        .toList();
    if (chestStrapRrs.isEmpty) return null;

    final chestStrapHr = records
        .whereType<HeartRateReading>()
        .where((r) => r.connectorId == 'chest_strap')
        .map((r) => r.bpm)
        .toList();
    final chestStrapHrv = records
        .whereType<HRVReading>()
        .where((r) => r.connectorId == 'chest_strap')
        .toList();

    double? avg(List<double> vals) =>
        vals.isEmpty ? null : vals.reduce((a, b) => a + b) / vals.length;

    return PolarMetrics(
      heartRateBpm: avg(chestStrapHr),
      hrvRmssdMs: avg(chestStrapHrv.map((r) => r.rmssdMs).toList()),
      hrvSdnnMs: avg(
          chestStrapHrv.map((r) => r.sdnnMs).whereType<double>().toList()),
      rrIntervalsMs: chestStrapRrs,
    );
  }

  Esp32Metrics? _buildEsp32Metrics(List<NormalizedRecord> records) {
    final hrReadings =
        records.whereType<HeartRateReading>().map((r) => r.bpm).toList();
    final hrvReadings =
        records.whereType<HRVReading>().map((r) => r.rmssdMs).toList();
    final gsrReadings =
        records.whereType<EDAReading>().map((r) => r.microSiemens).toList();
    final spo2Readings =
        records.whereType<SpO2Reading>().map((r) => r.percent).toList();
    final tempReadings =
        records.whereType<TemperatureReading>().map((r) => r.celsius).toList();

    if (hrReadings.isEmpty &&
        gsrReadings.isEmpty &&
        tempReadings.isEmpty) {
      return null;
    }

    double? avg(List<double> vals) =>
        vals.isEmpty ? null : vals.reduce((a, b) => a + b) / vals.length;

    return Esp32Metrics(
      heartRateBpm: avg(hrReadings),
      hrvRmssdMs: avg(hrvReadings),
      spo2Percent: avg(spo2Readings),
      gsrMeanUs: avg(gsrReadings),
      skinTempC: avg(tempReadings),
    );
  }

  /// Clean up resources.
  void dispose() {
    _sensorSubscription?.cancel();
    _capabilitySubscription?.cancel();
    _persistTimer?.cancel();
    _coachTimer?.cancel();
    _coachController.close();
    _metricsController.close();
    _analysisCompleteController.close();
    _modeController.close();
  }
}
