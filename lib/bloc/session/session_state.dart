import 'package:equatable/equatable.dart';
import '../../models/sensor_snapshot.dart';
import '../../models/session.dart';
import '../../models/session_type.dart';

enum SessionStatus { idle, active, paused, completed }

class SessionState extends Equatable {
  final SessionStatus status;
  final SessionType? selectedType;
  final Session? activeSession;
  final List<SensorSnapshot> snapshots;
  final List<Session> history;
  final Duration elapsed;

  /// ID of the selected breathwork pattern (for breathwork sessions).
  final String? breathworkPatternId;

  /// Wim Hof retention hold durations in seconds, one per round.
  final List<int> retentionHoldSeconds;

  const SessionState({
    this.status = SessionStatus.idle,
    this.selectedType,
    this.activeSession,
    this.snapshots = const [],
    this.history = const [],
    this.elapsed = Duration.zero,
    this.breathworkPatternId,
    this.retentionHoldSeconds = const [],
  });

  SessionState copyWith({
    SessionStatus? status,
    SessionType? selectedType,
    Session? activeSession,
    List<SensorSnapshot>? snapshots,
    List<Session>? history,
    Duration? elapsed,
    bool clearActiveSession = false,
    String? breathworkPatternId,
    bool clearBreathworkPattern = false,
    List<int>? retentionHoldSeconds,
  }) {
    return SessionState(
      status: status ?? this.status,
      selectedType: selectedType ?? this.selectedType,
      activeSession:
          clearActiveSession ? null : (activeSession ?? this.activeSession),
      snapshots: snapshots ?? this.snapshots,
      history: history ?? this.history,
      elapsed: elapsed ?? this.elapsed,
      breathworkPatternId: clearBreathworkPattern
          ? null
          : (breathworkPatternId ?? this.breathworkPatternId),
      retentionHoldSeconds: retentionHoldSeconds ?? this.retentionHoldSeconds,
    );
  }

  @override
  List<Object?> get props => [
        status,
        selectedType,
        activeSession?.sessionId,
        snapshots.length,
        history.length,
        elapsed,
        breathworkPatternId,
        retentionHoldSeconds.length,
      ];
}
