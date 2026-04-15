import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/sensors/sensors_bloc.dart';
import '../../models/sensor_snapshot.dart';
import '../../models/session.dart';
import '../../services/session_storage.dart';
import 'session_event.dart';
import 'session_state.dart';

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final SensorsBloc sensorsBloc;
  final SessionStorage storage;
  Timer? _recordTimer;
  Timer? _elapsedTimer;

  SessionBloc({required this.sensorsBloc, required this.storage})
      : super(const SessionState()) {
    on<SessionTypeSelected>(_onTypeSelected);
    on<SessionStarted>(_onStarted);
    on<SessionPaused>(_onPaused);
    on<SessionResumed>(_onResumed);
    on<SessionStopped>(_onStopped);
    on<SessionSnapshotRecorded>(_onSnapshotRecorded);
    on<SessionHistoryLoaded>(_onHistoryLoaded);
    on<SessionElapsedTick>(_onElapsedTick);
    on<BreathworkPatternSelected>(_onBreathworkPatternSelected);
    on<WimHofRetentionRecorded>(_onWimHofRetentionRecorded);
  }

  void _onTypeSelected(
      SessionTypeSelected event, Emitter<SessionState> emit) {
    emit(state.copyWith(selectedType: event.type));
  }

  void _onBreathworkPatternSelected(
      BreathworkPatternSelected event, Emitter<SessionState> emit) {
    emit(state.copyWith(breathworkPatternId: event.patternId));
  }

  void _onWimHofRetentionRecorded(
      WimHofRetentionRecorded event, Emitter<SessionState> emit) {
    final updated = [...state.retentionHoldSeconds, ...event.retentionSeconds];
    emit(state.copyWith(retentionHoldSeconds: updated));
  }

  void _onStarted(SessionStarted event, Emitter<SessionState> emit) {
    final type = state.selectedType;
    if (type == null) return;

    final now = DateTime.now();
    final session = Session(
      sessionId: now.millisecondsSinceEpoch.toString(),
      userId: 'local',
      createdAt: now,
      timezone: now.timeZoneName,
      dataSources: ['esp32'],
      context: SessionContext(
        activities: [
          SessionActivity(
            type: type.name,
            subtype: state.breathworkPatternId,
            startOffsetSeconds: 0,
          ),
        ],
      ),
    );

    emit(state.copyWith(
      status: SessionStatus.active,
      activeSession: session,
      snapshots: [],
      elapsed: Duration.zero,
      retentionHoldSeconds: state.breathworkPatternId == 'wimHof' ? [] : null,
    ));

    _startRecording();
    _startElapsedTimer();
  }

  void _onPaused(SessionPaused event, Emitter<SessionState> emit) {
    _recordTimer?.cancel();
    _elapsedTimer?.cancel();
    emit(state.copyWith(status: SessionStatus.paused));
  }

  void _onResumed(SessionResumed event, Emitter<SessionState> emit) {
    emit(state.copyWith(status: SessionStatus.active));
    _startRecording();
    _startElapsedTimer();
  }

  void _onStopped(SessionStopped event, Emitter<SessionState> emit) async {
    _recordTimer?.cancel();
    _elapsedTimer?.cancel();

    final baseSession = state.activeSession;
    if (baseSession != null) {
      final finalSession = _buildFinalSession(baseSession, state.snapshots);
      await storage.saveSession(finalSession);
    }

    final history = storage.getAllSessions();

    emit(state.copyWith(
      status: SessionStatus.idle,
      clearActiveSession: true,
      clearBreathworkPattern: true,
      snapshots: const [],
      history: history,
      elapsed: Duration.zero,
      retentionHoldSeconds: const [],
    ));
  }

  void _onSnapshotRecorded(
      SessionSnapshotRecorded event, Emitter<SessionState> emit) {
    emit(state.copyWith(snapshots: [...state.snapshots, event.snapshot]));
  }

  void _onHistoryLoaded(
      SessionHistoryLoaded event, Emitter<SessionState> emit) {
    emit(state.copyWith(history: storage.getAllSessions()));
  }

  void _startRecording() {
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final sensorState = sensorsBloc.state;
      add(SessionSnapshotRecorded(SensorSnapshot(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        heartRate: sensorState.heartRate,
        hrv: sensorState.hrv,
        gsr: sensorState.gsr,
        temperature: sensorState.temperature,
        spo2: sensorState.spo2,
        lfHfRatio: sensorState.lfHfRatio,
        coherence: sensorState.coherence,
      )));
    });
  }

  void _onElapsedTick(
      SessionElapsedTick event, Emitter<SessionState> emit) {
    emit(state.copyWith(elapsed: event.elapsed));
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.activeSession != null) {
        final elapsed = DateTime.now().difference(state.activeSession!.createdAt);
        add(SessionElapsedTick(elapsed));
      }
    });
  }

  /// Build the final persisted [Session] with computed biometrics from
  /// the collected [SensorSnapshot] list.
  Session _buildFinalSession(
      Session base, List<SensorSnapshot> snapshots) {
    final durationSeconds = state.elapsed.inSeconds;

    Esp32Metrics? esp32;
    ComputedMetrics? computed;

    if (snapshots.isNotEmpty) {
      double avg(double Function(SensorSnapshot) f) =>
          snapshots.map(f).reduce((a, b) => a + b) / snapshots.length;

      esp32 = Esp32Metrics(
        heartRateBpm: avg((s) => s.heartRate),
        hrvRmssdMs: avg((s) => s.hrv),
        spo2Percent: avg((s) => s.spo2),
        gsrMeanUs: avg((s) => s.gsr),
        skinTempC: avg((s) => s.temperature),
      );

      final hrs = snapshots.map((s) => s.heartRate).toList();
      computed = ComputedMetrics(
        hrSource: 'esp32',
        hrvSource: 'esp32',
        heartRateMeanBpm: avg((s) => s.heartRate),
        heartRateMinBpm: hrs.reduce((a, b) => a < b ? a : b),
        heartRateMaxBpm: hrs.reduce((a, b) => a > b ? a : b),
        hrvRmssdMs: avg((s) => s.hrv),
        coherenceScore: avg((s) => s.coherence),
        lfHfProxy: avg((s) => s.lfHfRatio),
      );
    }

    return Session(
      sessionId: base.sessionId,
      userId: base.userId,
      createdAt: base.createdAt,
      timezone: base.timezone,
      durationSeconds: durationSeconds,
      dataSources: base.dataSources,
      context: base.context,
      biometrics: SessionBiometrics(
        esp32: esp32,
        computed: computed,
      ),
    );
  }

  @override
  Future<void> close() {
    _recordTimer?.cancel();
    _elapsedTimer?.cancel();
    return super.close();
  }
}
