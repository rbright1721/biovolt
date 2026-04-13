import 'package:hive/hive.dart';

part 'session.g.dart';

@HiveType(typeId: 0)
enum SessionType {
  @HiveField(0)
  breathwork,
  @HiveField(1)
  coldExposure,
  @HiveField(2)
  meditation,
  @HiveField(3)
  fastingCheck,
  @HiveField(4)
  grounding,
}

extension SessionTypeInfo on SessionType {
  String get displayName => switch (this) {
        SessionType.breathwork => 'Breathwork',
        SessionType.coldExposure => 'Cold Exposure',
        SessionType.meditation => 'Meditation',
        SessionType.fastingCheck => 'Fasting Check',
        SessionType.grounding => 'Grounding',
      };

  String get description => switch (this) {
        SessionType.breathwork => 'Box breathing with HRV & GSR tracking',
        SessionType.coldExposure => 'Temperature & HRV during cold exposure',
        SessionType.meditation => 'GSR & coherence for calm monitoring',
        SessionType.fastingCheck => 'Full biometric snapshot vs baseline',
        SessionType.grounding => 'GSR & temperature before/after grounding',
      };

  String get focusSignals => switch (this) {
        SessionType.breathwork => 'HRV + GSR + ECG',
        SessionType.coldExposure => 'Temp + HRV + ECG',
        SessionType.meditation => 'GSR + Coherence + ECG',
        SessionType.fastingCheck => 'All Signals',
        SessionType.grounding => 'GSR + Temp',
      };

  String get estimatedDuration => switch (this) {
        SessionType.breathwork => '5-20 min',
        SessionType.coldExposure => '2-10 min',
        SessionType.meditation => '10-30 min',
        SessionType.fastingCheck => '1 min',
        SessionType.grounding => '10-20 min',
      };

  String get iconChar => switch (this) {
        SessionType.breathwork => '\u{1F32C}',
        SessionType.coldExposure => '\u{2744}',
        SessionType.meditation => '\u{1F9D8}',
        SessionType.fastingCheck => '\u{1F50D}',
        SessionType.grounding => '\u{1F333}',
      };
}

@HiveType(typeId: 1)
class SensorSnapshot {
  @HiveField(0)
  final int timestampMs;
  @HiveField(1)
  final double heartRate;
  @HiveField(2)
  final double hrv;
  @HiveField(3)
  final double gsr;
  @HiveField(4)
  final double temperature;
  @HiveField(5)
  final double spo2;
  @HiveField(6)
  final double lfHfRatio;
  @HiveField(7)
  final double coherence;

  SensorSnapshot({
    required this.timestampMs,
    required this.heartRate,
    required this.hrv,
    required this.gsr,
    required this.temperature,
    required this.spo2,
    required this.lfHfRatio,
    required this.coherence,
  });
}

@HiveType(typeId: 2)
class Session {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final SessionType type;
  @HiveField(2)
  final int startTimeMs;
  @HiveField(3)
  int? endTimeMs;
  @HiveField(4)
  final List<SensorSnapshot> snapshots;

  /// ID of the breathwork pattern used (null for non-breathwork sessions).
  @HiveField(5)
  final String? breathworkPatternId;

  /// Wim Hof retention hold durations in seconds, one per round.
  @HiveField(6)
  final List<int>? retentionHoldSeconds;

  Session({
    required this.id,
    required this.type,
    required this.startTimeMs,
    this.endTimeMs,
    List<SensorSnapshot>? snapshots,
    this.breathworkPatternId,
    this.retentionHoldSeconds,
  }) : snapshots = snapshots ?? [];

  Duration get duration {
    final end = endTimeMs ?? DateTime.now().millisecondsSinceEpoch;
    return Duration(milliseconds: end - startTimeMs);
  }

  bool get isCompleted => endTimeMs != null;

  String get durationFormatted {
    final d = duration;
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Average of a metric across all snapshots.
  double avgMetric(double Function(SensorSnapshot) selector) {
    if (snapshots.isEmpty) return 0;
    return snapshots.map(selector).reduce((a, b) => a + b) / snapshots.length;
  }

  /// Change from first to last reading of a metric (percentage).
  double metricChange(double Function(SensorSnapshot) selector) {
    if (snapshots.length < 2) return 0;
    final first = selector(snapshots.first);
    final last = selector(snapshots.last);
    if (first == 0) return 0;
    return ((last - first) / first) * 100;
  }
}
