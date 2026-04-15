import 'package:equatable/equatable.dart';
import '../../models/ai_analysis.dart';
import '../../models/sensor_snapshot.dart';
import '../../models/session_type.dart';

abstract class SessionEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SessionTypeSelected extends SessionEvent {
  final SessionType type;
  SessionTypeSelected(this.type);
  @override
  List<Object?> get props => [type];
}

class SessionStarted extends SessionEvent {}

class SessionPaused extends SessionEvent {}

class SessionResumed extends SessionEvent {}

class SessionStopped extends SessionEvent {}

class SessionSnapshotRecorded extends SessionEvent {
  final SensorSnapshot snapshot;
  SessionSnapshotRecorded(this.snapshot);
  @override
  List<Object?> get props => [snapshot.timestampMs];
}

class SessionHistoryLoaded extends SessionEvent {}

class SessionElapsedTick extends SessionEvent {
  final Duration elapsed;
  SessionElapsedTick(this.elapsed);
  @override
  List<Object?> get props => [elapsed];
}

class BreathworkPatternSelected extends SessionEvent {
  final String patternId;
  BreathworkPatternSelected(this.patternId);
  @override
  List<Object?> get props => [patternId];
}

class WimHofRetentionRecorded extends SessionEvent {
  final List<int> retentionSeconds;
  WimHofRetentionRecorded(this.retentionSeconds);
  @override
  List<Object?> get props => [retentionSeconds];
}

class SessionCoachReceived extends SessionEvent {
  final String message;
  SessionCoachReceived(this.message);
  @override
  List<Object?> get props => [message];
}

class SessionAnalysisReceived extends SessionEvent {
  final AiAnalysis analysis;
  SessionAnalysisReceived(this.analysis);
  @override
  List<Object?> get props => [analysis.sessionId];
}
