// =============================================================================
// Hive TypeAdapter IDs used in this file:
//  41  — ActiveProtocol
// =============================================================================

import 'package:hive/hive.dart';

part 'active_protocol.g.dart';

@HiveType(typeId: 41)
class ActiveProtocol {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String type;

  @HiveField(3)
  final DateTime startDate;

  @HiveField(4)
  final DateTime? endDate;

  @HiveField(5)
  final int cycleLengthDays;

  @HiveField(6)
  final double doseMcg;

  @HiveField(7)
  final String route;

  @HiveField(8)
  final String? notes;

  @HiveField(9)
  final bool isActive;

  ActiveProtocol({
    required this.id,
    required this.name,
    required this.type,
    required this.startDate,
    this.endDate,
    required this.cycleLengthDays,
    required this.doseMcg,
    required this.route,
    this.notes,
    required this.isActive,
  });

  int get currentCycleDay {
    final days = DateTime.now().difference(startDate).inDays + 1;
    return days.clamp(1, cycleLengthDays);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'cycleLengthDays': cycleLengthDays,
        'doseMcg': doseMcg,
        'route': route,
        'notes': notes,
        'isActive': isActive,
      };

  factory ActiveProtocol.fromJson(Map<String, dynamic> json) =>
      ActiveProtocol(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null,
        cycleLengthDays: json['cycleLengthDays'] as int,
        doseMcg: (json['doseMcg'] as num).toDouble(),
        route: json['route'] as String,
        notes: json['notes'] as String?,
        isActive: json['isActive'] as bool,
      );
}
