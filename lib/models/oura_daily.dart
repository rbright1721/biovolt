// =============================================================================
// Hive TypeAdapter IDs used in this file:
//  15  — OuraDailyRecord
// =============================================================================

import 'package:hive/hive.dart';
import 'sleep_record.dart';

part 'oura_daily.g.dart';

@HiveType(typeId: 15)
class OuraDailyRecord {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final DateTime syncedAt;

  @HiveField(2)
  final int? readinessScore;

  @HiveField(3)
  final ReadinessContributors? readinessContributors;

  @HiveField(4)
  final int? sleepScore;

  @HiveField(5)
  final SleepContributors? sleepContributors;

  @HiveField(6)
  final double? temperatureDeviationC;

  @HiveField(7)
  final double? temperatureTrendDeviationC;

  @HiveField(8)
  final List<double>? overnightHrvSamples;

  @HiveField(9)
  final double? overnightHrvAverageMs;

  @HiveField(10)
  final List<double>? overnightHrSamplesBpm;

  @HiveField(11)
  final double? spo2AveragePercent;

  @HiveField(12)
  final double? breathingDisturbanceIndex;

  @HiveField(13)
  final int? highStressSeconds;

  @HiveField(14)
  final int? highRecoverySeconds;

  @HiveField(15)
  final String? stressDaySummary;

  @HiveField(16)
  final String? resilienceLevel;

  @HiveField(17)
  final double? vo2Max;

  @HiveField(18)
  final int? cardiovascularAge;

  OuraDailyRecord({
    required this.date,
    required this.syncedAt,
    this.readinessScore,
    this.readinessContributors,
    this.sleepScore,
    this.sleepContributors,
    this.temperatureDeviationC,
    this.temperatureTrendDeviationC,
    this.overnightHrvSamples,
    this.overnightHrvAverageMs,
    this.overnightHrSamplesBpm,
    this.spo2AveragePercent,
    this.breathingDisturbanceIndex,
    this.highStressSeconds,
    this.highRecoverySeconds,
    this.stressDaySummary,
    this.resilienceLevel,
    this.vo2Max,
    this.cardiovascularAge,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'syncedAt': syncedAt.toIso8601String(),
        'readinessScore': readinessScore,
        'readinessContributors': readinessContributors?.toJson(),
        'sleepScore': sleepScore,
        'sleepContributors': sleepContributors?.toJson(),
        'temperatureDeviationC': temperatureDeviationC,
        'temperatureTrendDeviationC': temperatureTrendDeviationC,
        'overnightHrvSamples': overnightHrvSamples,
        'overnightHrvAverageMs': overnightHrvAverageMs,
        'overnightHrSamplesBpm': overnightHrSamplesBpm,
        'spo2AveragePercent': spo2AveragePercent,
        'breathingDisturbanceIndex': breathingDisturbanceIndex,
        'highStressSeconds': highStressSeconds,
        'highRecoverySeconds': highRecoverySeconds,
        'stressDaySummary': stressDaySummary,
        'resilienceLevel': resilienceLevel,
        'vo2Max': vo2Max,
        'cardiovascularAge': cardiovascularAge,
      };

  factory OuraDailyRecord.fromJson(Map<String, dynamic> json) =>
      OuraDailyRecord(
        date: DateTime.parse(json['date'] as String),
        syncedAt: DateTime.parse(json['syncedAt'] as String),
        readinessScore: json['readinessScore'] as int?,
        readinessContributors: json['readinessContributors'] != null
            ? ReadinessContributors.fromJson(
                json['readinessContributors'] as Map<String, dynamic>)
            : null,
        sleepScore: json['sleepScore'] as int?,
        sleepContributors: json['sleepContributors'] != null
            ? SleepContributors.fromJson(
                json['sleepContributors'] as Map<String, dynamic>)
            : null,
        temperatureDeviationC:
            (json['temperatureDeviationC'] as num?)?.toDouble(),
        temperatureTrendDeviationC:
            (json['temperatureTrendDeviationC'] as num?)?.toDouble(),
        overnightHrvSamples: (json['overnightHrvSamples'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList(),
        overnightHrvAverageMs:
            (json['overnightHrvAverageMs'] as num?)?.toDouble(),
        overnightHrSamplesBpm:
            (json['overnightHrSamplesBpm'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble())
                .toList(),
        spo2AveragePercent:
            (json['spo2AveragePercent'] as num?)?.toDouble(),
        breathingDisturbanceIndex:
            (json['breathingDisturbanceIndex'] as num?)?.toDouble(),
        highStressSeconds: json['highStressSeconds'] as int?,
        highRecoverySeconds: json['highRecoverySeconds'] as int?,
        stressDaySummary: json['stressDaySummary'] as String?,
        resilienceLevel: json['resilienceLevel'] as String?,
        vo2Max: (json['vo2Max'] as num?)?.toDouble(),
        cardiovascularAge: json['cardiovascularAge'] as int?,
      );
}
