// =============================================================================
// Hive TypeAdapter IDs used in this file:
//  35  — Bloodwork
// =============================================================================

import 'package:hive/hive.dart';

part 'bloodwork.g.dart';

@HiveType(typeId: 35)
class Bloodwork {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime labDate;

  @HiveField(2)
  final double? fastingHours;

  @HiveField(3)
  final String? protocolContext;

  @HiveField(4)
  final String? notes;

  // -- Inflammation --
  @HiveField(5)
  final double? crp;

  @HiveField(6)
  final double? il6;

  @HiveField(7)
  final double? homocysteine;

  // -- Metabolic --
  @HiveField(8)
  final double? glucoseFasting;

  @HiveField(9)
  final double? hba1c;

  @HiveField(10)
  final double? insulinFasting;

  @HiveField(11)
  final double? homaIr;

  // -- Hormonal --
  @HiveField(12)
  final double? testosteroneTotal;

  @HiveField(13)
  final double? testosteroneFree;

  @HiveField(14)
  final double? dheaS;

  @HiveField(15)
  final double? cortisolAm;

  @HiveField(16)
  final double? igf1;

  @HiveField(17)
  final double? estradiol;

  @HiveField(18)
  final double? shbg;

  // -- Thyroid --
  @HiveField(19)
  final double? tsh;

  @HiveField(20)
  final double? freeT3;

  @HiveField(21)
  final double? freeT4;

  // -- Lipids --
  @HiveField(22)
  final double? totalCholesterol;

  @HiveField(23)
  final double? ldl;

  @HiveField(24)
  final double? hdl;

  @HiveField(25)
  final double? triglycerides;

  @HiveField(26)
  final double? apoB;

  // -- Nutrients --
  @HiveField(27)
  final double? vitaminD;

  @HiveField(28)
  final double? magnesiumRbc;

  @HiveField(29)
  final double? omega3Index;

  @HiveField(30)
  final double? ferritin;

  @HiveField(31)
  final double? b12;

  Bloodwork({
    required this.id,
    required this.labDate,
    this.fastingHours,
    this.protocolContext,
    this.notes,
    this.crp,
    this.il6,
    this.homocysteine,
    this.glucoseFasting,
    this.hba1c,
    this.insulinFasting,
    this.homaIr,
    this.testosteroneTotal,
    this.testosteroneFree,
    this.dheaS,
    this.cortisolAm,
    this.igf1,
    this.estradiol,
    this.shbg,
    this.tsh,
    this.freeT3,
    this.freeT4,
    this.totalCholesterol,
    this.ldl,
    this.hdl,
    this.triglycerides,
    this.apoB,
    this.vitaminD,
    this.magnesiumRbc,
    this.omega3Index,
    this.ferritin,
    this.b12,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'labDate': labDate.toIso8601String(),
        'fastingHours': fastingHours,
        'protocolContext': protocolContext,
        'notes': notes,
        'crp': crp,
        'il6': il6,
        'homocysteine': homocysteine,
        'glucoseFasting': glucoseFasting,
        'hba1c': hba1c,
        'insulinFasting': insulinFasting,
        'homaIr': homaIr,
        'testosteroneTotal': testosteroneTotal,
        'testosteroneFree': testosteroneFree,
        'dheaS': dheaS,
        'cortisolAm': cortisolAm,
        'igf1': igf1,
        'estradiol': estradiol,
        'shbg': shbg,
        'tsh': tsh,
        'freeT3': freeT3,
        'freeT4': freeT4,
        'totalCholesterol': totalCholesterol,
        'ldl': ldl,
        'hdl': hdl,
        'triglycerides': triglycerides,
        'apoB': apoB,
        'vitaminD': vitaminD,
        'magnesiumRbc': magnesiumRbc,
        'omega3Index': omega3Index,
        'ferritin': ferritin,
        'b12': b12,
      };

  factory Bloodwork.fromJson(Map<String, dynamic> json) => Bloodwork(
        id: json['id'] as String,
        labDate: DateTime.parse(json['labDate'] as String),
        fastingHours: (json['fastingHours'] as num?)?.toDouble(),
        protocolContext: json['protocolContext'] as String?,
        notes: json['notes'] as String?,
        crp: (json['crp'] as num?)?.toDouble(),
        il6: (json['il6'] as num?)?.toDouble(),
        homocysteine: (json['homocysteine'] as num?)?.toDouble(),
        glucoseFasting: (json['glucoseFasting'] as num?)?.toDouble(),
        hba1c: (json['hba1c'] as num?)?.toDouble(),
        insulinFasting: (json['insulinFasting'] as num?)?.toDouble(),
        homaIr: (json['homaIr'] as num?)?.toDouble(),
        testosteroneTotal: (json['testosteroneTotal'] as num?)?.toDouble(),
        testosteroneFree: (json['testosteroneFree'] as num?)?.toDouble(),
        dheaS: (json['dheaS'] as num?)?.toDouble(),
        cortisolAm: (json['cortisolAm'] as num?)?.toDouble(),
        igf1: (json['igf1'] as num?)?.toDouble(),
        estradiol: (json['estradiol'] as num?)?.toDouble(),
        shbg: (json['shbg'] as num?)?.toDouble(),
        tsh: (json['tsh'] as num?)?.toDouble(),
        freeT3: (json['freeT3'] as num?)?.toDouble(),
        freeT4: (json['freeT4'] as num?)?.toDouble(),
        totalCholesterol: (json['totalCholesterol'] as num?)?.toDouble(),
        ldl: (json['ldl'] as num?)?.toDouble(),
        hdl: (json['hdl'] as num?)?.toDouble(),
        triglycerides: (json['triglycerides'] as num?)?.toDouble(),
        apoB: (json['apoB'] as num?)?.toDouble(),
        vitaminD: (json['vitaminD'] as num?)?.toDouble(),
        magnesiumRbc: (json['magnesiumRbc'] as num?)?.toDouble(),
        omega3Index: (json['omega3Index'] as num?)?.toDouble(),
        ferritin: (json['ferritin'] as num?)?.toDouble(),
        b12: (json['b12'] as num?)?.toDouble(),
      );

  /// Count of non-null biomarker fields.
  int get filledCount {
    int c = 0;
    if (crp != null) c++;
    if (il6 != null) c++;
    if (homocysteine != null) c++;
    if (glucoseFasting != null) c++;
    if (hba1c != null) c++;
    if (insulinFasting != null) c++;
    if (homaIr != null) c++;
    if (testosteroneTotal != null) c++;
    if (testosteroneFree != null) c++;
    if (dheaS != null) c++;
    if (cortisolAm != null) c++;
    if (igf1 != null) c++;
    if (estradiol != null) c++;
    if (shbg != null) c++;
    if (tsh != null) c++;
    if (freeT3 != null) c++;
    if (freeT4 != null) c++;
    if (totalCholesterol != null) c++;
    if (ldl != null) c++;
    if (hdl != null) c++;
    if (triglycerides != null) c++;
    if (apoB != null) c++;
    if (vitaminD != null) c++;
    if (magnesiumRbc != null) c++;
    if (omega3Index != null) c++;
    if (ferritin != null) c++;
    if (b12 != null) c++;
    return c;
  }
}
