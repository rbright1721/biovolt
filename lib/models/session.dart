// =============================================================================
// Hive TypeAdapter IDs used in this file:
//  16  — Session
//  17  — SessionContext
//  18  — SessionActivity
//  19  — SessionBiometrics
//  20  — Esp32Metrics
//  21  — PolarMetrics
//  22  — ComputedMetrics
//  23  — SessionSubjective
//  24  — SubjectiveScores
// =============================================================================

import 'package:hive/hive.dart';
import 'interventions.dart';

part 'session.g.dart';

// ---------------------------------------------------------------------------
// SubjectiveScores
// ---------------------------------------------------------------------------

@HiveType(typeId: 24)
class SubjectiveScores {
  @HiveField(0)
  final int? energy;

  @HiveField(1)
  final int? mood;

  @HiveField(2)
  final int? focus;

  @HiveField(3)
  final int? anxiety;

  @HiveField(4)
  final int? physicalSoreness;

  @HiveField(5)
  final int? motivation;

  @HiveField(6)
  final int? calm;

  @HiveField(7)
  final int? physicalFeeling;

  @HiveField(8)
  final int? sessionQuality;

  @HiveField(9)
  final String? notableEffects;

  @HiveField(10)
  final String? sideEffects;

  @HiveField(11)
  final String? notes;

  SubjectiveScores({
    this.energy,
    this.mood,
    this.focus,
    this.anxiety,
    this.physicalSoreness,
    this.motivation,
    this.calm,
    this.physicalFeeling,
    this.sessionQuality,
    this.notableEffects,
    this.sideEffects,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'energy': energy,
        'mood': mood,
        'focus': focus,
        'anxiety': anxiety,
        'physicalSoreness': physicalSoreness,
        'motivation': motivation,
        'calm': calm,
        'physicalFeeling': physicalFeeling,
        'sessionQuality': sessionQuality,
        'notableEffects': notableEffects,
        'sideEffects': sideEffects,
        'notes': notes,
      };

  factory SubjectiveScores.fromJson(Map<String, dynamic> json) =>
      SubjectiveScores(
        energy: json['energy'] as int?,
        mood: json['mood'] as int?,
        focus: json['focus'] as int?,
        anxiety: json['anxiety'] as int?,
        physicalSoreness: json['physicalSoreness'] as int?,
        motivation: json['motivation'] as int?,
        calm: json['calm'] as int?,
        physicalFeeling: json['physicalFeeling'] as int?,
        sessionQuality: json['sessionQuality'] as int?,
        notableEffects: json['notableEffects'] as String?,
        sideEffects: json['sideEffects'] as String?,
        notes: json['notes'] as String?,
      );
}

// ---------------------------------------------------------------------------
// SessionSubjective
// ---------------------------------------------------------------------------

@HiveType(typeId: 23)
class SessionSubjective {
  @HiveField(0)
  final SubjectiveScores? preSession;

  @HiveField(1)
  final SubjectiveScores? postSession;

  SessionSubjective({
    this.preSession,
    this.postSession,
  });

  Map<String, dynamic> toJson() => {
        'preSession': preSession?.toJson(),
        'postSession': postSession?.toJson(),
      };

  factory SessionSubjective.fromJson(Map<String, dynamic> json) =>
      SessionSubjective(
        preSession: json['preSession'] != null
            ? SubjectiveScores.fromJson(
                json['preSession'] as Map<String, dynamic>)
            : null,
        postSession: json['postSession'] != null
            ? SubjectiveScores.fromJson(
                json['postSession'] as Map<String, dynamic>)
            : null,
      );
}

// ---------------------------------------------------------------------------
// Esp32Metrics
// ---------------------------------------------------------------------------

@HiveType(typeId: 20)
class Esp32Metrics {
  @HiveField(0)
  final double? heartRateBpm;

  @HiveField(1)
  final double? hrvRmssdMs;

  @HiveField(2)
  final double? spo2Percent;

  @HiveField(3)
  final double? gsrMeanUs;

  @HiveField(4)
  final double? gsrBaselineShiftUs;

  @HiveField(5)
  final double? skinTempC;

  @HiveField(6)
  final String? ppgRedWaveformPath;

  @HiveField(7)
  final String? ppgIrWaveformPath;

  @HiveField(8)
  final String? ecgWaveformPath;

  @HiveField(9)
  final String? gsrTracePath;

  Esp32Metrics({
    this.heartRateBpm,
    this.hrvRmssdMs,
    this.spo2Percent,
    this.gsrMeanUs,
    this.gsrBaselineShiftUs,
    this.skinTempC,
    this.ppgRedWaveformPath,
    this.ppgIrWaveformPath,
    this.ecgWaveformPath,
    this.gsrTracePath,
  });

  Map<String, dynamic> toJson() => {
        'heartRateBpm': heartRateBpm,
        'hrvRmssdMs': hrvRmssdMs,
        'spo2Percent': spo2Percent,
        'gsrMeanUs': gsrMeanUs,
        'gsrBaselineShiftUs': gsrBaselineShiftUs,
        'skinTempC': skinTempC,
        'ppgRedWaveformPath': ppgRedWaveformPath,
        'ppgIrWaveformPath': ppgIrWaveformPath,
        'ecgWaveformPath': ecgWaveformPath,
        'gsrTracePath': gsrTracePath,
      };

  factory Esp32Metrics.fromJson(Map<String, dynamic> json) => Esp32Metrics(
        heartRateBpm: (json['heartRateBpm'] as num?)?.toDouble(),
        hrvRmssdMs: (json['hrvRmssdMs'] as num?)?.toDouble(),
        spo2Percent: (json['spo2Percent'] as num?)?.toDouble(),
        gsrMeanUs: (json['gsrMeanUs'] as num?)?.toDouble(),
        gsrBaselineShiftUs:
            (json['gsrBaselineShiftUs'] as num?)?.toDouble(),
        skinTempC: (json['skinTempC'] as num?)?.toDouble(),
        ppgRedWaveformPath: json['ppgRedWaveformPath'] as String?,
        ppgIrWaveformPath: json['ppgIrWaveformPath'] as String?,
        ecgWaveformPath: json['ecgWaveformPath'] as String?,
        gsrTracePath: json['gsrTracePath'] as String?,
      );
}

// ---------------------------------------------------------------------------
// PolarMetrics
// ---------------------------------------------------------------------------

@HiveType(typeId: 21)
class PolarMetrics {
  @HiveField(0)
  final double? heartRateBpm;

  @HiveField(1)
  final double? hrvRmssdMs;

  @HiveField(2)
  final double? hrvSdnnMs;

  @HiveField(3)
  final double? hrvPnn50Percent;

  @HiveField(4)
  final List<int>? rrIntervalsMs;

  @HiveField(5)
  final double? ecgQualityScore;

  @HiveField(6)
  final String? ecgWaveformPath;

  PolarMetrics({
    this.heartRateBpm,
    this.hrvRmssdMs,
    this.hrvSdnnMs,
    this.hrvPnn50Percent,
    this.rrIntervalsMs,
    this.ecgQualityScore,
    this.ecgWaveformPath,
  });

  Map<String, dynamic> toJson() => {
        'heartRateBpm': heartRateBpm,
        'hrvRmssdMs': hrvRmssdMs,
        'hrvSdnnMs': hrvSdnnMs,
        'hrvPnn50Percent': hrvPnn50Percent,
        'rrIntervalsMs': rrIntervalsMs,
        'ecgQualityScore': ecgQualityScore,
        'ecgWaveformPath': ecgWaveformPath,
      };

  factory PolarMetrics.fromJson(Map<String, dynamic> json) => PolarMetrics(
        heartRateBpm: (json['heartRateBpm'] as num?)?.toDouble(),
        hrvRmssdMs: (json['hrvRmssdMs'] as num?)?.toDouble(),
        hrvSdnnMs: (json['hrvSdnnMs'] as num?)?.toDouble(),
        hrvPnn50Percent: (json['hrvPnn50Percent'] as num?)?.toDouble(),
        rrIntervalsMs: (json['rrIntervalsMs'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList(),
        ecgQualityScore: (json['ecgQualityScore'] as num?)?.toDouble(),
        ecgWaveformPath: json['ecgWaveformPath'] as String?,
      );
}

// ---------------------------------------------------------------------------
// ComputedMetrics
// ---------------------------------------------------------------------------

@HiveType(typeId: 22)
class ComputedMetrics {
  @HiveField(0)
  final String? hrSource;

  @HiveField(1)
  final String? hrvSource;

  @HiveField(2)
  final double? heartRateMeanBpm;

  @HiveField(3)
  final double? heartRateMinBpm;

  @HiveField(4)
  final double? heartRateMaxBpm;

  @HiveField(5)
  final double? hrvRmssdMs;

  @HiveField(6)
  final double? coherenceScore;

  @HiveField(7)
  final double? lfHfProxy;

  ComputedMetrics({
    this.hrSource,
    this.hrvSource,
    this.heartRateMeanBpm,
    this.heartRateMinBpm,
    this.heartRateMaxBpm,
    this.hrvRmssdMs,
    this.coherenceScore,
    this.lfHfProxy,
  });

  Map<String, dynamic> toJson() => {
        'hrSource': hrSource,
        'hrvSource': hrvSource,
        'heartRateMeanBpm': heartRateMeanBpm,
        'heartRateMinBpm': heartRateMinBpm,
        'heartRateMaxBpm': heartRateMaxBpm,
        'hrvRmssdMs': hrvRmssdMs,
        'coherenceScore': coherenceScore,
        'lfHfProxy': lfHfProxy,
      };

  factory ComputedMetrics.fromJson(Map<String, dynamic> json) =>
      ComputedMetrics(
        hrSource: json['hrSource'] as String?,
        hrvSource: json['hrvSource'] as String?,
        heartRateMeanBpm: (json['heartRateMeanBpm'] as num?)?.toDouble(),
        heartRateMinBpm: (json['heartRateMinBpm'] as num?)?.toDouble(),
        heartRateMaxBpm: (json['heartRateMaxBpm'] as num?)?.toDouble(),
        hrvRmssdMs: (json['hrvRmssdMs'] as num?)?.toDouble(),
        coherenceScore: (json['coherenceScore'] as num?)?.toDouble(),
        lfHfProxy: (json['lfHfProxy'] as num?)?.toDouble(),
      );
}

// ---------------------------------------------------------------------------
// SessionBiometrics
// ---------------------------------------------------------------------------

@HiveType(typeId: 19)
class SessionBiometrics {
  @HiveField(0)
  final Esp32Metrics? esp32;

  @HiveField(1)
  final PolarMetrics? polarH10;

  @HiveField(2)
  final ComputedMetrics? computed;

  SessionBiometrics({
    this.esp32,
    this.polarH10,
    this.computed,
  });

  Map<String, dynamic> toJson() => {
        'esp32': esp32?.toJson(),
        'polarH10': polarH10?.toJson(),
        'computed': computed?.toJson(),
      };

  factory SessionBiometrics.fromJson(Map<String, dynamic> json) =>
      SessionBiometrics(
        esp32: json['esp32'] != null
            ? Esp32Metrics.fromJson(json['esp32'] as Map<String, dynamic>)
            : null,
        polarH10: json['polarH10'] != null
            ? PolarMetrics.fromJson(
                json['polarH10'] as Map<String, dynamic>)
            : null,
        computed: json['computed'] != null
            ? ComputedMetrics.fromJson(
                json['computed'] as Map<String, dynamic>)
            : null,
      );
}

// ---------------------------------------------------------------------------
// SessionActivity
// ---------------------------------------------------------------------------

@HiveType(typeId: 18)
class SessionActivity {
  @HiveField(0)
  final String type;

  @HiveField(1)
  final String? subtype;

  @HiveField(2)
  final int startOffsetSeconds;

  @HiveField(3)
  final int? durationSeconds;

  @HiveField(4)
  final Map<String, dynamic>? parameters;

  SessionActivity({
    required this.type,
    this.subtype,
    required this.startOffsetSeconds,
    this.durationSeconds,
    this.parameters,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'subtype': subtype,
        'startOffsetSeconds': startOffsetSeconds,
        'durationSeconds': durationSeconds,
        'parameters': parameters,
      };

  factory SessionActivity.fromJson(Map<String, dynamic> json) =>
      SessionActivity(
        type: json['type'] as String,
        subtype: json['subtype'] as String?,
        startOffsetSeconds: json['startOffsetSeconds'] as int,
        durationSeconds: json['durationSeconds'] as int?,
        parameters: json['parameters'] != null
            ? Map<String, dynamic>.from(json['parameters'] as Map)
            : null,
      );
}

// ---------------------------------------------------------------------------
// SessionContext
// ---------------------------------------------------------------------------

@HiveType(typeId: 17)
class SessionContext {
  @HiveField(0)
  final List<SessionActivity> activities;

  @HiveField(1)
  final double? fastingHours;

  @HiveField(2)
  final double? timeSinceWakeHours;

  @HiveField(3)
  final double? sleepLastNightHours;

  @HiveField(4)
  final String? stressContext;

  @HiveField(5)
  final String? notes;

  SessionContext({
    required this.activities,
    this.fastingHours,
    this.timeSinceWakeHours,
    this.sleepLastNightHours,
    this.stressContext,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'activities': activities.map((a) => a.toJson()).toList(),
        'fastingHours': fastingHours,
        'timeSinceWakeHours': timeSinceWakeHours,
        'sleepLastNightHours': sleepLastNightHours,
        'stressContext': stressContext,
        'notes': notes,
      };

  factory SessionContext.fromJson(Map<String, dynamic> json) =>
      SessionContext(
        activities: (json['activities'] as List<dynamic>)
            .map((e) =>
                SessionActivity.fromJson(e as Map<String, dynamic>))
            .toList(),
        fastingHours: (json['fastingHours'] as num?)?.toDouble(),
        timeSinceWakeHours:
            (json['timeSinceWakeHours'] as num?)?.toDouble(),
        sleepLastNightHours:
            (json['sleepLastNightHours'] as num?)?.toDouble(),
        stressContext: json['stressContext'] as String?,
        notes: json['notes'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Session
// ---------------------------------------------------------------------------

@HiveType(typeId: 16)
class Session {
  @HiveField(0)
  final String sessionId;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  final String timezone;

  @HiveField(4)
  final int? durationSeconds;

  @HiveField(5)
  final List<String> dataSources;

  @HiveField(6)
  final SessionContext? context;

  @HiveField(7)
  final SessionBiometrics? biometrics;

  @HiveField(8)
  final SessionSubjective? subjective;

  @HiveField(9)
  final Interventions? interventions;

  Session({
    required this.sessionId,
    required this.userId,
    required this.createdAt,
    required this.timezone,
    this.durationSeconds,
    required this.dataSources,
    this.context,
    this.biometrics,
    this.subjective,
    this.interventions,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'userId': userId,
        'createdAt': createdAt.toIso8601String(),
        'timezone': timezone,
        'durationSeconds': durationSeconds,
        'dataSources': dataSources,
        'context': context?.toJson(),
        'biometrics': biometrics?.toJson(),
        'subjective': subjective?.toJson(),
        'interventions': interventions?.toJson(),
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        sessionId: json['sessionId'] as String,
        userId: json['userId'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        timezone: json['timezone'] as String,
        durationSeconds: json['durationSeconds'] as int?,
        dataSources: (json['dataSources'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        context: json['context'] != null
            ? SessionContext.fromJson(
                json['context'] as Map<String, dynamic>)
            : null,
        biometrics: json['biometrics'] != null
            ? SessionBiometrics.fromJson(
                json['biometrics'] as Map<String, dynamic>)
            : null,
        subjective: json['subjective'] != null
            ? SessionSubjective.fromJson(
                json['subjective'] as Map<String, dynamic>)
            : null,
        interventions: json['interventions'] != null
            ? Interventions.fromJson(
                json['interventions'] as Map<String, dynamic>)
            : null,
      );
}
