// =============================================================================
// Hive TypeAdapter IDs used in this file:
//  34  — SensorSnapshot
// =============================================================================

import 'package:hive/hive.dart';

part 'sensor_snapshot.g.dart';

@HiveType(typeId: 34)
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

  Map<String, dynamic> toJson() => {
        'timestampMs': timestampMs,
        'heartRate': heartRate,
        'hrv': hrv,
        'gsr': gsr,
        'temperature': temperature,
        'spo2': spo2,
        'lfHfRatio': lfHfRatio,
        'coherence': coherence,
      };

  factory SensorSnapshot.fromJson(Map<String, dynamic> json) =>
      SensorSnapshot(
        timestampMs: json['timestampMs'] as int,
        heartRate: (json['heartRate'] as num).toDouble(),
        hrv: (json['hrv'] as num).toDouble(),
        gsr: (json['gsr'] as num).toDouble(),
        temperature: (json['temperature'] as num).toDouble(),
        spo2: (json['spo2'] as num).toDouble(),
        lfHfRatio: (json['lfHfRatio'] as num).toDouble(),
        coherence: (json['coherence'] as num).toDouble(),
      );
}
