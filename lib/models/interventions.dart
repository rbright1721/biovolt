// =============================================================================
// Hive TypeAdapter IDs used in this file:
//  26  — Interventions
//  27  — PeptideLog
//  28  — SupplementLog
//  29  — NutritionLog
//  30  — HydrationLog
// =============================================================================

import 'package:hive/hive.dart';

part 'interventions.g.dart';

// ---------------------------------------------------------------------------
// PeptideLog
// ---------------------------------------------------------------------------

@HiveType(typeId: 27)
class PeptideLog {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final double doseMcg;

  @HiveField(2)
  final String route;

  @HiveField(3)
  final int? cycleDay;

  @HiveField(4)
  final int? cycleTotalDays;

  @HiveField(5)
  final String? stackId;

  @HiveField(6)
  final DateTime loggedAt;

  PeptideLog({
    required this.name,
    required this.doseMcg,
    required this.route,
    this.cycleDay,
    this.cycleTotalDays,
    this.stackId,
    required this.loggedAt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'doseMcg': doseMcg,
        'route': route,
        'cycleDay': cycleDay,
        'cycleTotalDays': cycleTotalDays,
        'stackId': stackId,
        'loggedAt': loggedAt.toIso8601String(),
      };

  factory PeptideLog.fromJson(Map<String, dynamic> json) => PeptideLog(
        name: json['name'] as String,
        doseMcg: (json['doseMcg'] as num).toDouble(),
        route: json['route'] as String,
        cycleDay: json['cycleDay'] as int?,
        cycleTotalDays: json['cycleTotalDays'] as int?,
        stackId: json['stackId'] as String?,
        loggedAt: DateTime.parse(json['loggedAt'] as String),
      );
}

// ---------------------------------------------------------------------------
// SupplementLog
// ---------------------------------------------------------------------------

@HiveType(typeId: 28)
class SupplementLog {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final double doseMg;

  @HiveField(2)
  final String? form;

  @HiveField(3)
  final String? timing;

  @HiveField(4)
  final DateTime loggedAt;

  SupplementLog({
    required this.name,
    required this.doseMg,
    this.form,
    this.timing,
    required this.loggedAt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'doseMg': doseMg,
        'form': form,
        'timing': timing,
        'loggedAt': loggedAt.toIso8601String(),
      };

  factory SupplementLog.fromJson(Map<String, dynamic> json) =>
      SupplementLog(
        name: json['name'] as String,
        doseMg: (json['doseMg'] as num).toDouble(),
        form: json['form'] as String?,
        timing: json['timing'] as String?,
        loggedAt: DateTime.parse(json['loggedAt'] as String),
      );
}

// ---------------------------------------------------------------------------
// NutritionLog
// ---------------------------------------------------------------------------

@HiveType(typeId: 29)
class NutritionLog {
  @HiveField(0)
  final double? mealTimingHoursBefore;

  @HiveField(1)
  final bool fasted;

  @HiveField(2)
  final String? quality;

  @HiveField(3)
  final String? notes;

  NutritionLog({
    this.mealTimingHoursBefore,
    required this.fasted,
    this.quality,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'mealTimingHoursBefore': mealTimingHoursBefore,
        'fasted': fasted,
        'quality': quality,
        'notes': notes,
      };

  factory NutritionLog.fromJson(Map<String, dynamic> json) => NutritionLog(
        mealTimingHoursBefore:
            (json['mealTimingHoursBefore'] as num?)?.toDouble(),
        fasted: json['fasted'] as bool,
        quality: json['quality'] as String?,
        notes: json['notes'] as String?,
      );
}

// ---------------------------------------------------------------------------
// HydrationLog
// ---------------------------------------------------------------------------

@HiveType(typeId: 30)
class HydrationLog {
  @HiveField(0)
  final double? waterMlToday;

  @HiveField(1)
  final bool electrolytes;

  HydrationLog({
    this.waterMlToday,
    required this.electrolytes,
  });

  Map<String, dynamic> toJson() => {
        'waterMlToday': waterMlToday,
        'electrolytes': electrolytes,
      };

  factory HydrationLog.fromJson(Map<String, dynamic> json) => HydrationLog(
        waterMlToday: (json['waterMlToday'] as num?)?.toDouble(),
        electrolytes: json['electrolytes'] as bool,
      );
}

// ---------------------------------------------------------------------------
// Interventions
// ---------------------------------------------------------------------------

@HiveType(typeId: 26)
class Interventions {
  @HiveField(0)
  final List<PeptideLog> peptides;

  @HiveField(1)
  final List<SupplementLog> supplements;

  @HiveField(2)
  final NutritionLog? nutrition;

  @HiveField(3)
  final HydrationLog? hydration;

  Interventions({
    required this.peptides,
    required this.supplements,
    this.nutrition,
    this.hydration,
  });

  Map<String, dynamic> toJson() => {
        'peptides': peptides.map((p) => p.toJson()).toList(),
        'supplements': supplements.map((s) => s.toJson()).toList(),
        'nutrition': nutrition?.toJson(),
        'hydration': hydration?.toJson(),
      };

  factory Interventions.fromJson(Map<String, dynamic> json) =>
      Interventions(
        peptides: (json['peptides'] as List<dynamic>)
            .map((e) => PeptideLog.fromJson(e as Map<String, dynamic>))
            .toList(),
        supplements: (json['supplements'] as List<dynamic>)
            .map((e) => SupplementLog.fromJson(e as Map<String, dynamic>))
            .toList(),
        nutrition: json['nutrition'] != null
            ? NutritionLog.fromJson(
                json['nutrition'] as Map<String, dynamic>)
            : null,
        hydration: json['hydration'] != null
            ? HydrationLog.fromJson(
                json['hydration'] as Map<String, dynamic>)
            : null,
      );
}
