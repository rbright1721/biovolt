// =============================================================================
// Hive TypeAdapter IDs used in this file:
//  31  — UserProfile
//  32  — ConnectorState
// =============================================================================

import 'package:hive/hive.dart';
import 'normalized_record.dart';

part 'user_profile.g.dart';

// ---------------------------------------------------------------------------
// ConnectorState
// ---------------------------------------------------------------------------

@HiveType(typeId: 32)
class ConnectorState {
  @HiveField(0)
  final String connectorId;

  @HiveField(1)
  final ConnectorStatus status;

  @HiveField(2)
  final DateTime? lastSync;

  @HiveField(3)
  final bool isAuthenticated;

  ConnectorState({
    required this.connectorId,
    required this.status,
    this.lastSync,
    required this.isAuthenticated,
  });

  Map<String, dynamic> toJson() => {
        'connectorId': connectorId,
        'status': status.name,
        'lastSync': lastSync?.toIso8601String(),
        'isAuthenticated': isAuthenticated,
      };

  factory ConnectorState.fromJson(Map<String, dynamic> json) =>
      ConnectorState(
        connectorId: json['connectorId'] as String,
        status:
            ConnectorStatus.values.byName(json['status'] as String),
        lastSync: json['lastSync'] != null
            ? DateTime.parse(json['lastSync'] as String)
            : null,
        isAuthenticated: json['isAuthenticated'] as bool,
      );
}

// ---------------------------------------------------------------------------
// UserProfile
// ---------------------------------------------------------------------------

@HiveType(typeId: 31)
class UserProfile {
  @HiveField(0)
  final String userId;

  @HiveField(1)
  final DateTime createdAt;

  @HiveField(2)
  final String? biologicalSex;

  @HiveField(3)
  final DateTime? dateOfBirth;

  @HiveField(4)
  final double? heightCm;

  @HiveField(5)
  final double? weightKg;

  @HiveField(6)
  final List<String> healthGoals;

  @HiveField(7)
  final List<String> knownConditions;

  @HiveField(8)
  final bool baselineEstablished;

  @HiveField(9)
  final String? aiProvider;

  @HiveField(10)
  final String? aiModel;

  @HiveField(11)
  final String preferredUnits;

  @HiveField(12)
  final String? aiCoachingStyle;

  @HiveField(13)
  final String? mthfr;

  @HiveField(14)
  final String? apoe;

  @HiveField(15)
  final String? comt;

  @HiveField(16)
  final String? fastingType;

  @HiveField(17)
  final int? eatWindowStartHour;

  @HiveField(18)
  final int? eatWindowEndHour;

  @HiveField(19)
  final DateTime? lastMealTime;

  UserProfile({
    required this.userId,
    required this.createdAt,
    this.biologicalSex,
    this.dateOfBirth,
    this.heightCm,
    this.weightKg,
    required this.healthGoals,
    required this.knownConditions,
    required this.baselineEstablished,
    this.aiProvider,
    this.aiModel,
    required this.preferredUnits,
    this.aiCoachingStyle,
    this.mthfr,
    this.apoe,
    this.comt,
    this.fastingType,
    this.eatWindowStartHour,
    this.eatWindowEndHour,
    this.lastMealTime,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'createdAt': createdAt.toIso8601String(),
        'biologicalSex': biologicalSex,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'heightCm': heightCm,
        'weightKg': weightKg,
        'healthGoals': healthGoals,
        'knownConditions': knownConditions,
        'baselineEstablished': baselineEstablished,
        'aiProvider': aiProvider,
        'aiModel': aiModel,
        'preferredUnits': preferredUnits,
        'aiCoachingStyle': aiCoachingStyle,
        'mthfr': mthfr,
        'apoe': apoe,
        'comt': comt,
        'fastingType': fastingType,
        'eatWindowStartHour': eatWindowStartHour,
        'eatWindowEndHour': eatWindowEndHour,
        'lastMealTime': lastMealTime?.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        userId: json['userId'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        biologicalSex: json['biologicalSex'] as String?,
        dateOfBirth: json['dateOfBirth'] != null
            ? DateTime.parse(json['dateOfBirth'] as String)
            : null,
        heightCm: (json['heightCm'] as num?)?.toDouble(),
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        healthGoals: (json['healthGoals'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        knownConditions: (json['knownConditions'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        baselineEstablished: json['baselineEstablished'] as bool,
        aiProvider: json['aiProvider'] as String?,
        aiModel: json['aiModel'] as String?,
        preferredUnits: json['preferredUnits'] as String,
        aiCoachingStyle: json['aiCoachingStyle'] as String?,
        mthfr: json['mthfr'] as String?,
        apoe: json['apoe'] as String?,
        comt: json['comt'] as String?,
        fastingType: json['fastingType'] as String?,
        eatWindowStartHour: json['eatWindowStartHour'] as int?,
        eatWindowEndHour: json['eatWindowEndHour'] as int?,
        lastMealTime: json['lastMealTime'] != null
            ? DateTime.parse(json['lastMealTime'] as String)
            : null,
      );
}
