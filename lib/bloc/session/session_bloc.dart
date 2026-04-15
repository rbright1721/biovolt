import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/sensors/sensors_bloc.dart';
import '../../models/sensor_snapshot.dart';
import '../../models/session.dart';
import '../../services/session_recorder.dart';
import '../../services/session_storage.dart';
import 'session_event.dart';
import 'session_state.dart';

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final SensorsBloc sensorsBloc;
  final SessionStorage storage;
  final SessionRecorder sessionRecorder;
  Timer? _recordTimer;
  Timer? _elapsedTimer;
  StreamSubscription? _coachSub;
  StreamSubscription? _analysisSub;

  SessionBloc({
    required this.sensorsBloc,
    required this.storage,
    required this.sessionRecorder,
  }) : super(const SessionState()) {
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
    on<SessionCoachReceived>(_onCoachReceived);
    on<SessionAnalysisReceived>(_onAnalysisReceived);
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

    // Build SessionContext from the selected type
    final context = SessionContext(
      activities: [
        SessionActivity(
          type: type.name,
          subtype: state.breathworkPatternId,
          startOffsetSeconds: 0,
        ),
      ],
    );

    // Start the recorder — it subscribes to connector live streams
    final sessionId = sessionRecorder.startSession(context);

    // Subscribe to coach stream
    _coachSub?.cancel();
    _coachSub = sessionRecorder.coachStream.listen((msg) {
      add(SessionCoachReceived(msg));
    });

    // Subscribe to analysis complete stream
    _analysisSub?.cancel();
    _analysisSub = sessionRecorder.analysisCompleteStream.listen((analysis) {
      add(SessionAnalysisReceived(analysis));
    });

    // Get the active session from the recorder
    final session = sessionRecorder.activeSession;

    emit(state.copyWith(
      status: SessionStatus.active,
      activeSession: session,
      snapshots: [],
      elapsed: Duration.zero,
      retentionHoldSeconds: state.breathworkPatternId == 'wimHof' ? [] : null,
      clearCoachMessage: true,
      clearAnalysis: true,
    ));

    _startRecording();
    _startElapsedTimer(sessionId);
  }

  void _onPaused(SessionPaused event, Emitter<SessionState> emit) {
    _recordTimer?.cancel();
    _elapsedTimer?.cancel();
    emit(state.copyWith(status: SessionStatus.paused));
  }

  void _onResumed(SessionResumed event, Emitter<SessionState> emit) {
    emit(state.copyWith(status: SessionStatus.active));
    _startRecording();
    if (state.activeSession != null) {
      _startElapsedTimer(state.activeSession!.sessionId);
    }
  }

  void _onStopped(SessionStopped event, Emitter<SessionState> emit) async {
    _recordTimer?.cancel();
    _elapsedTimer?.cancel();

    if (sessionRecorder.isRecording) {
      // Emit stopping state while analysis runs in background
      emit(state.copyWith(status: SessionStatus.stopping));

      final finalSession = await sessionRecorder.stopSession();

      final history = storage.getAllSessions();

      emit(state.copyWith(
        status: SessionStatus.idle,
        clearActiveSession: true,
        clearBreathworkPattern: true,
        activeSession: finalSession,
        snapshots: const [],
        history: history,
        elapsed: Duration.zero,
        retentionHoldSeconds: const [],
        clearCoachMessage: true,
      ));

      // Clear the stashed final session from state after a tick
      emit(state.copyWith(clearActiveSession: true));
    } else {
      // Fallback: no recorder active, just reset
      emit(state.copyWith(
        status: SessionStatus.idle,
        clearActiveSession: true,
        clearBreathworkPattern: true,
        snapshots: const [],
        history: storage.getAllSessions(),
        elapsed: Duration.zero,
        retentionHoldSeconds: const [],
        clearCoachMessage: true,
      ));
    }
  }

  void _onCoachReceived(
      SessionCoachReceived event, Emitter<SessionState> emit) {
    emit(state.copyWith(coachMessage: event.message));
  }

  void _onAnalysisReceived(
      SessionAnalysisReceived event, Emitter<SessionState> emit) {
    emit(state.copyWith(
      status: SessionStatus.completed,
      analysis: event.analysis,
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

  void _startElapsedTimer(String sessionId) {
    _elapsedTimer?.cancel();
    final session = sessionRecorder.activeSession;
    final startTime = session?.createdAt ?? DateTime.now();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = DateTime.now().difference(startTime);
      add(SessionElapsedTick(elapsed));
    });
  }

  @override
  Future<void> close() {
    _recordTimer?.cancel();
    _elapsedTimer?.cancel();
    _coachSub?.cancel();
    _analysisSub?.cancel();
    return super.close();
  }
}
