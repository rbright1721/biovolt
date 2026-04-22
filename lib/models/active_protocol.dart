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

  /// When the protocol actually ended. Set by [StorageService.endProtocol]
  /// and by any flow that retires a protocol early. Null while the
  /// protocol is still running.
  ///
  /// Pairs with [endReason] (added in HiveField 15 below) — [endDate]
  /// captures WHEN, [endReason] captures WHY. The classifier's context
  /// bundle reads [effectiveEndDate], which falls back to
  /// [plannedEndDate] when this is null.
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

  // ---------------------------------------------------------------------------
  // Extension fields added for Part 2.5's real classifier.
  //
  // All new fields are NULLABLE so records serialized before this session
  // deserialize cleanly with safe defaults. See
  // `test/models/active_protocol_migration_test.dart` for the contract.
  // ---------------------------------------------------------------------------

  /// Human-readable dose as entered or parsed. Source of truth for
  /// display. Examples: "250mcg", "2 capsules", "1 scoop", "500mg".
  /// [doseMcg] remains the numeric backing where quantifiable. Null for
  /// records created before this field was added — the classifier
  /// synthesises a display from [doseMcg] + [route] in that case.
  @HiveField(10)
  final String? doseDisplay;

  /// Dose schedule. String-as-enum so new values (e.g. 'three_times_daily')
  /// can land without a Hive schema bump. Known values:
  ///   'once_daily', 'twice_daily', 'three_times_daily',
  ///   'weekly', 'as_needed', 'custom'.
  /// Free-text detail for 'custom' lives in [frequencyCustom].
  @HiveField(11)
  final String? frequency;

  /// Free-text when [frequency] == 'custom'. Examples: "Monday and
  /// Thursday only", "every other day".
  @HiveField(12)
  final String? frequencyCustom;

  /// Scheduled dose times as minutes-since-midnight. `[420, 1200]`
  /// means 7:00am and 8:00pm. Null means unscheduled / no specific
  /// time.
  @HiveField(13)
  final List<int>? timesOfDayMinutes;

  /// Raw backing store for [isOngoing]. Stored nullable so records
  /// created before this field was added deserialize cleanly — the
  /// generated Hive adapter passes null for absent fields, which
  /// would otherwise fail a `as bool` cast.
  ///
  /// Name + publicness chosen for hive_generator compatibility: the
  /// generated `read(...)` code maps each HiveField to a constructor
  /// named parameter by NAME, and private (underscore-prefixed) names
  /// can't appear as named parameters in Dart. `isOngoingFlag` is
  /// therefore the name both the field and the constructor param use,
  /// while consumers read normalized state via the [isOngoing] getter.
  ///
  /// This is a NOVEL nullable-backing pattern for this codebase. When
  /// adding a non-nullable bool semantic to a mature model in future
  /// sessions, follow the same shape: `bool? someFieldFlag` (stored)
  /// + `bool get someField => someFieldFlag ?? false` (normalized).
  @HiveField(14)
  final bool? isOngoingFlag;

  /// Why the protocol ended. Set alongside [endDate] when a protocol
  /// is retired. Distinct from [endDate] in that [endDate] captures
  /// WHEN and this captures WHY. Known values:
  ///   'completed', 'abandoned_side_effects',
  ///   'abandoned_ineffective', 'abandoned_other', 'paused'.
  @HiveField(15)
  final String? endReason;

  /// Expected effects the user wants to track while this protocol is
  /// active. The classifier uses this to prioritize matching
  /// measurements in downstream analysis. Known values:
  ///   'hrv', 'sleep_quality', 'resting_hr', 'energy', 'recovery',
  ///   'inflammation', 'blood_glucose', 'body_composition', 'mood',
  ///   'focus', 'other'.
  /// Null and empty-list are semantically equivalent — both mean
  /// "user hasn't specified targets yet".
  @HiveField(16)
  final List<String>? measurementTargets;

  /// Free-text elaboration of expected effects — used alongside
  /// [measurementTargets]. Example: "hoping for better deep sleep in
  /// the first half of the night".
  @HiveField(17)
  final String? measurementTargetsNotes;

  // ---------------------------------------------------------------------------
  // Constructor.
  //
  // New fields are optional named params with null defaults (or, for
  // isOngoing, a bool param that gets stored in the private backing
  // field). The existing call-site contract for fields 0-9 is preserved.
  // ---------------------------------------------------------------------------

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
    this.doseDisplay,
    this.frequency,
    this.frequencyCustom,
    this.timesOfDayMinutes,
    this.isOngoingFlag,
    this.endReason,
    this.measurementTargets,
    this.measurementTargetsNotes,
  });

  // ---------------------------------------------------------------------------
  // Computed getters.
  // ---------------------------------------------------------------------------

  /// 1-based day within the current cycle, clamped so that 0-length
  /// windows and pre-start timestamps still return something valid.
  int get currentCycleDay {
    final days = DateTime.now().difference(startDate).inDays + 1;
    return days.clamp(1, cycleLengthDays == 0 ? 1 : cycleLengthDays);
  }

  /// True when "now" is within the active cycle window (or the
  /// protocol is declared ongoing). False when the protocol hasn't
  /// started yet, has already completed, or is not active at all.
  ///
  /// Used by [statusLabel] to distinguish 'active' (running now) from
  /// 'scheduled' (starts in the future).
  bool get isOnCycle {
    if (!isActive) return false;
    final now = DateTime.now();
    if (now.isBefore(startDate)) return false;
    if (isOngoing) return true;
    if (cycleLengthDays <= 0) return true;
    final planned = startDate.add(Duration(days: cycleLengthDays));
    return !now.isAfter(planned);
  }

  /// Non-null public view of the [isOngoingFlag] backing field. Old
  /// records (missing this field entirely) read as null from the
  /// adapter; the getter coerces to false so downstream code can
  /// treat this as a plain bool.
  bool get isOngoing => isOngoingFlag ?? false;

  /// Scheduled end of this cycle, or null when the protocol runs
  /// indefinitely. Derived from [startDate] + [cycleLengthDays], NOT
  /// from [endDate] — that field captures the ACTUAL end, which may
  /// precede or follow the plan.
  DateTime? get plannedEndDate =>
      isOngoing ? null : startDate.add(Duration(days: cycleLengthDays));

  /// Single accessor callers should prefer when rendering "when did
  /// this end". Actual end (via [endDate]) wins; otherwise the
  /// planned end. Null for ongoing protocols with no actual end yet.
  DateTime? get effectiveEndDate => endDate ?? plannedEndDate;

  /// Days until the planned end of cycle, or null when not meaningful
  /// (ongoing / inactive / missing a plan). May be negative if we've
  /// already passed the planned end without a retirement.
  int? get daysRemaining {
    if (isOngoing || !isActive) return null;
    final planned = plannedEndDate;
    if (planned == null) return null;
    return planned.difference(DateTime.now()).inDays;
  }

  bool get isCompleted => !isActive && endReason == 'completed';

  /// Short label used by timeline and profile UIs to summarize state
  /// without branching on multiple fields.
  String get statusLabel {
    if (isActive && isOnCycle) return 'active';
    if (isActive && !isOnCycle) return 'scheduled';
    if (!isActive && isCompleted) return 'completed';
    if (!isActive) return 'ended';
    return 'unknown';
  }

  // ---------------------------------------------------------------------------
  // Serialization.
  // ---------------------------------------------------------------------------

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
        'doseDisplay': doseDisplay,
        'frequency': frequency,
        'frequencyCustom': frequencyCustom,
        'timesOfDayMinutes': timesOfDayMinutes,
        'isOngoing': isOngoingFlag,
        'endReason': endReason,
        'measurementTargets': measurementTargets,
        'measurementTargetsNotes': measurementTargetsNotes,
      };

  factory ActiveProtocol.fromJson(Map<String, dynamic> json) => ActiveProtocol(
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
        // All reads below are null-safe so v1 Firestore / JSON blobs
        // that predate these fields deserialize cleanly.
        doseDisplay: json['doseDisplay'] as String?,
        frequency: json['frequency'] as String?,
        frequencyCustom: json['frequencyCustom'] as String?,
        timesOfDayMinutes:
            (json['timesOfDayMinutes'] as List?)?.cast<int>(),
        isOngoingFlag: json['isOngoing'] as bool?,
        endReason: json['endReason'] as String?,
        measurementTargets:
            (json['measurementTargets'] as List?)?.cast<String>(),
        measurementTargetsNotes:
            json['measurementTargetsNotes'] as String?,
      );

  /// Returns a new [ActiveProtocol] with the given fields replaced.
  /// Null arguments preserve the existing value — to explicitly clear
  /// a nullable field, construct via the regular constructor.
  ///
  /// `isOngoing` here is a `bool?` view: passing `true`/`false`
  /// overrides, passing `null` keeps the prior [isOngoingFlag] value
  /// verbatim (including a stored-null, so pre-migration records stay
  /// as stored-null and continue reading as `false` through the
  /// getter).
  ActiveProtocol copyWith({
    String? id,
    String? name,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    int? cycleLengthDays,
    double? doseMcg,
    String? route,
    String? notes,
    bool? isActive,
    String? doseDisplay,
    String? frequency,
    String? frequencyCustom,
    List<int>? timesOfDayMinutes,
    bool? isOngoing,
    String? endReason,
    List<String>? measurementTargets,
    String? measurementTargetsNotes,
  }) =>
      ActiveProtocol(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        cycleLengthDays: cycleLengthDays ?? this.cycleLengthDays,
        doseMcg: doseMcg ?? this.doseMcg,
        route: route ?? this.route,
        notes: notes ?? this.notes,
        isActive: isActive ?? this.isActive,
        doseDisplay: doseDisplay ?? this.doseDisplay,
        frequency: frequency ?? this.frequency,
        frequencyCustom: frequencyCustom ?? this.frequencyCustom,
        timesOfDayMinutes: timesOfDayMinutes ?? this.timesOfDayMinutes,
        isOngoingFlag: isOngoing ?? isOngoingFlag,
        endReason: endReason ?? this.endReason,
        measurementTargets: measurementTargets ?? this.measurementTargets,
        measurementTargetsNotes:
            measurementTargetsNotes ?? this.measurementTargetsNotes,
      );
}
