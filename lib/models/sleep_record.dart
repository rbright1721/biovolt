// =============================================================================
// Hive TypeAdapter IDs used in this file:
//  12  — SleepRecord
//  13  — SleepContributors
//  14  — ReadinessContributors
// =============================================================================

import 'package:hive/hive.dart';
import 'normalized_record.dart';

part 'sleep_record.g.dart';

// ---------------------------------------------------------------------------
// SleepContributors
// ---------------------------------------------------------------------------

@HiveType(typeId: 13)
class SleepContributors {
  @HiveField(0)
  final int? deepSleep;

  @HiveField(1)
  final int? efficiency;

  @HiveField(2)
  final int? latency;

  @HiveField(3)
  final int? remSleep;

  @HiveField(4)
  final int? restfulness;

  @HiveField(5)
  final int? timing;

  @HiveField(6)
  final int? totalSleep;

  SleepContributors({
    this.deepSleep,
    this.efficiency,
    this.latency,
    this.remSleep,
    this.restfulness,
    this.timing,
    this.totalSleep,
  });

  Map<String, dynamic> toJson() => {
        'deepSleep': deepSleep,
        'efficiency': efficiency,
        'latency': latency,
        'remSleep': remSleep,
        'restfulness': restfulness,
        'timing': timing,
        'totalSleep': totalSleep,
      };

  factory SleepContributors.fromJson(Map<String, dynamic> json) =>
      SleepContributors(
        deepSleep: json['deepSleep'] as int?,
        efficiency: json['efficiency'] as int?,
        latency: json['latency'] as int?,
        remSleep: json['remSleep'] as int?,
        restfulness: json['restfulness'] as int?,
        timing: json['timing'] as int?,
        totalSleep: json['totalSleep'] as int?,
      );
}

// ---------------------------------------------------------------------------
// ReadinessContributors
// ---------------------------------------------------------------------------

@HiveType(typeId: 14)
class ReadinessContributors {
  @HiveField(0)
  final int? activityBalance;

  @HiveField(1)
  final int? bodyTemperature;

  @HiveField(2)
  final int? hrvBalance;

  @HiveField(3)
  final int? previousDayActivity;

  @HiveField(4)
  final int? previousNight;

  @HiveField(5)
  final int? recoveryIndex;

  @HiveField(6)
  final int? restingHeartRate;

  @HiveField(7)
  final int? sleepBalance;

  ReadinessContributors({
    this.activityBalance,
    this.bodyTemperature,
    this.hrvBalance,
    this.previousDayActivity,
    this.previousNight,
    this.recoveryIndex,
    this.restingHeartRate,
    this.sleepBalance,
  });

  Map<String, dynamic> toJson() => {
        'activityBalance': activityBalance,
        'bodyTemperature': bodyTemperature,
        'hrvBalance': hrvBalance,
        'previousDayActivity': previousDayActivity,
        'previousNight': previousNight,
        'recoveryIndex': recoveryIndex,
        'restingHeartRate': restingHeartRate,
        'sleepBalance': sleepBalance,
      };

  factory ReadinessContributors.fromJson(Map<String, dynamic> json) =>
      ReadinessContributors(
        activityBalance: json['activityBalance'] as int?,
        bodyTemperature: json['bodyTemperature'] as int?,
        hrvBalance: json['hrvBalance'] as int?,
        previousDayActivity: json['previousDayActivity'] as int?,
        previousNight: json['previousNight'] as int?,
        recoveryIndex: json['recoveryIndex'] as int?,
        restingHeartRate: json['restingHeartRate'] as int?,
        sleepBalance: json['sleepBalance'] as int?,
      );
}

// ---------------------------------------------------------------------------
// SleepRecord
// ---------------------------------------------------------------------------

@HiveType(typeId: 12)
class SleepRecord extends NormalizedRecord {
  @HiveField(0)
  final DateTime bedtimeStart;

  @HiveField(1)
  final DateTime bedtimeEnd;

  @HiveField(2)
  final int totalSleepSeconds;

  @HiveField(3)
  final int deepSleepSeconds;

  @HiveField(4)
  final int remSleepSeconds;

  @HiveField(5)
  final int lightSleepSeconds;

  @HiveField(6)
  final int timeInBedSeconds;

  @HiveField(7)
  final int? latencySeconds;

  @HiveField(8)
  final double? efficiency;

  @HiveField(9)
  final int? lowestHrBpm;

  @HiveField(10)
  final int? restlessPeriods;

  @HiveField(11)
  final double? overnightHrvRmssdMs;

  @HiveField(12)
  final double? skinTempDeviationC;

  @HiveField(13)
  final int? readinessScore;

  @HiveField(14)
  final int? sleepScore;

  @HiveField(15)
  final String? sleepPhaseSequence;

  @HiveField(16)
  final SleepContributors? sleepContributors;

  @HiveField(17)
  final ReadinessContributors? readinessContributors;

  @HiveField(18)
  @override
  final String connectorId;

  @HiveField(19)
  @override
  final DateTime timestamp;

  @HiveField(20)
  @override
  final DataQuality quality;

  SleepRecord({
    required this.bedtimeStart,
    required this.bedtimeEnd,
    required this.totalSleepSeconds,
    required this.deepSleepSeconds,
    required this.remSleepSeconds,
    required this.lightSleepSeconds,
    required this.timeInBedSeconds,
    this.latencySeconds,
    this.efficiency,
    this.lowestHrBpm,
    this.restlessPeriods,
    this.overnightHrvRmssdMs,
    this.skinTempDeviationC,
    this.readinessScore,
    this.sleepScore,
    this.sleepPhaseSequence,
    this.sleepContributors,
    this.readinessContributors,
    required this.connectorId,
    required this.timestamp,
    required this.quality,
  }) : super(
          connectorId: connectorId,
          timestamp: timestamp,
          quality: quality,
        );

  @override
  Map<String, dynamic> toJson() => {
        'bedtimeStart': bedtimeStart.toIso8601String(),
        'bedtimeEnd': bedtimeEnd.toIso8601String(),
        'totalSleepSeconds': totalSleepSeconds,
        'deepSleepSeconds': deepSleepSeconds,
        'remSleepSeconds': remSleepSeconds,
        'lightSleepSeconds': lightSleepSeconds,
        'timeInBedSeconds': timeInBedSeconds,
        'latencySeconds': latencySeconds,
        'efficiency': efficiency,
        'lowestHrBpm': lowestHrBpm,
        'restlessPeriods': restlessPeriods,
        'overnightHrvRmssdMs': overnightHrvRmssdMs,
        'skinTempDeviationC': skinTempDeviationC,
        'readinessScore': readinessScore,
        'sleepScore': sleepScore,
        'sleepPhaseSequence': sleepPhaseSequence,
        'sleepContributors': sleepContributors?.toJson(),
        'readinessContributors': readinessContributors?.toJson(),
        'connectorId': connectorId,
        'timestamp': timestamp.toIso8601String(),
        'quality': quality.name,
      };

  factory SleepRecord.fromJson(Map<String, dynamic> json) => SleepRecord(
        bedtimeStart: DateTime.parse(json['bedtimeStart'] as String),
        bedtimeEnd: DateTime.parse(json['bedtimeEnd'] as String),
        totalSleepSeconds: json['totalSleepSeconds'] as int,
        deepSleepSeconds: json['deepSleepSeconds'] as int,
        remSleepSeconds: json['remSleepSeconds'] as int,
        lightSleepSeconds: json['lightSleepSeconds'] as int,
        timeInBedSeconds: json['timeInBedSeconds'] as int,
        latencySeconds: json['latencySeconds'] as int?,
        efficiency: (json['efficiency'] as num?)?.toDouble(),
        lowestHrBpm: json['lowestHrBpm'] as int?,
        restlessPeriods: json['restlessPeriods'] as int?,
        overnightHrvRmssdMs:
            (json['overnightHrvRmssdMs'] as num?)?.toDouble(),
        skinTempDeviationC:
            (json['skinTempDeviationC'] as num?)?.toDouble(),
        readinessScore: json['readinessScore'] as int?,
        sleepScore: json['sleepScore'] as int?,
        sleepPhaseSequence: json['sleepPhaseSequence'] as String?,
        sleepContributors: json['sleepContributors'] != null
            ? SleepContributors.fromJson(
                json['sleepContributors'] as Map<String, dynamic>)
            : null,
        readinessContributors: json['readinessContributors'] != null
            ? ReadinessContributors.fromJson(
                json['readinessContributors'] as Map<String, dynamic>)
            : null,
        connectorId: json['connectorId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        quality: DataQuality.values.byName(json['quality'] as String),
      );
}
