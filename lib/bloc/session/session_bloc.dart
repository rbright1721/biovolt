import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/sensors/sensors_bloc.dart';
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
    final session = state.activeSession;
    if (session != null) {
      // Store retention times directly on the session for persistence
      session.retentionHoldSeconds?.addAll(event.retentionSeconds);
    }
  }

  void _onStarted(SessionStarted event, Emitter<SessionState> emit) {
    final type = state.selectedType;
    if (type == null) return;

    final session = Session(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      startTimeMs: DateTime.now().millisecondsSinceEpoch,
      breathworkPatternId: state.breathworkPatternId,
      retentionHoldSeconds:
          state.breathworkPatternId == 'wimHof' ? [] : null,
    );

    emit(state.copyWith(
      status: SessionStatus.active,
      activeSession: session,
      elapsed: Duration.zero,
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

    final session = state.activeSession;
    if (session != null) {
      session.endTimeMs = DateTime.now().millisecondsSinceEpoch;
      await storage.saveSession(session);
    }

    final history = storage.getAllSessions();

    emit(state.copyWith(
      status: SessionStatus.idle,
      clearActiveSession: true,
      clearBreathworkPattern: true,
      history: history,
      elapsed: Duration.zero,
    ));
  }

  void _onSnapshotRecorded(
      SessionSnapshotRecorded event, Emitter<SessionState> emit) {
    state.activeSession?.snapshots.add(event.snapshot);
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
        final elapsed = Duration(
          milliseconds: DateTime.now().millisecondsSinceEpoch -
              state.activeSession!.startTimeMs,
        );
        add(SessionElapsedTick(elapsed));
      }
    });
  }

  @override
  Future<void> close() {
    _recordTimer?.cancel();
    _elapsedTimer?.cancel();
    return super.close();
  }
}
