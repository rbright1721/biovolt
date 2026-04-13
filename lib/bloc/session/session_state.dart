import 'package:equatable/equatable.dart';
import '../../models/session.dart';

enum SessionStatus { idle, active, paused, completed }

class SessionState extends Equatable {
  final SessionStatus status;
  final SessionType? selectedType;
  final Session? activeSession;
  final List<Session> history;
  final Duration elapsed;

  /// ID of the selected breathwork pattern (for breathwork sessions).
  final String? breathworkPatternId;

  const SessionState({
    this.status = SessionStatus.idle,
    this.selectedType,
    this.activeSession,
    this.history = const [],
    this.elapsed = Duration.zero,
    this.breathworkPatternId,
  });

  SessionState copyWith({
    SessionStatus? status,
    SessionType? selectedType,
    Session? activeSession,
    List<Session>? history,
    Duration? elapsed,
    bool clearActiveSession = false,
    String? breathworkPatternId,
    bool clearBreathworkPattern = false,
  }) {
    return SessionState(
      status: status ?? this.status,
      selectedType: selectedType ?? this.selectedType,
      activeSession:
          clearActiveSession ? null : (activeSession ?? this.activeSession),
      history: history ?? this.history,
      elapsed: elapsed ?? this.elapsed,
      breathworkPatternId: clearBreathworkPattern
          ? null
          : (breathworkPatternId ?? this.breathworkPatternId),
    );
  }

  @override
  List<Object?> get props => [
        status,
        selectedType,
        activeSession?.id,
        history.length,
        elapsed,
        breathworkPatternId,
      ];
}
