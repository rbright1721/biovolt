// =============================================================================
// Hive TypeAdapter IDs used in this file:
//  40  — SessionTemplate
// =============================================================================

import 'package:hive/hive.dart';

part 'session_template.g.dart';

@HiveType(typeId: 40)
class SessionTemplate {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String sessionType;

  @HiveField(3)
  final String? breathworkPattern;

  @HiveField(4)
  final int? breathworkRounds;

  @HiveField(5)
  final int? breathHoldTargetSec;

  @HiveField(6)
  final double? coldTempF;

  @HiveField(7)
  final int? coldDurationMin;

  @HiveField(8)
  final String? notes;

  @HiveField(9)
  final DateTime lastUsedAt;

  @HiveField(10)
  final int useCount;

  SessionTemplate({
    required this.id,
    required this.name,
    required this.sessionType,
    this.breathworkPattern,
    this.breathworkRounds,
    this.breathHoldTargetSec,
    this.coldTempF,
    this.coldDurationMin,
    this.notes,
    required this.lastUsedAt,
    required this.useCount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sessionType': sessionType,
        'breathworkPattern': breathworkPattern,
        'breathworkRounds': breathworkRounds,
        'breathHoldTargetSec': breathHoldTargetSec,
        'coldTempF': coldTempF,
        'coldDurationMin': coldDurationMin,
        'notes': notes,
        'lastUsedAt': lastUsedAt.toIso8601String(),
        'useCount': useCount,
      };

  factory SessionTemplate.fromJson(Map<String, dynamic> json) =>
      SessionTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        sessionType: json['sessionType'] as String,
        breathworkPattern: json['breathworkPattern'] as String?,
        breathworkRounds: json['breathworkRounds'] as int?,
        breathHoldTargetSec: json['breathHoldTargetSec'] as int?,
        coldTempF: (json['coldTempF'] as num?)?.toDouble(),
        coldDurationMin: json['coldDurationMin'] as int?,
        notes: json['notes'] as String?,
        lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
        useCount: json['useCount'] as int,
      );
}
