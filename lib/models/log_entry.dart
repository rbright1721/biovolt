// =============================================================================
// Hive TypeAdapter IDs used in this file:
//  43  — LogEntry
// =============================================================================

import 'package:hive/hive.dart';

part 'log_entry.g.dart';

/// Raw user observation (voice or text) captured as a single timeline
/// entry. Starts life as an unclassified 'other' record, then gets
/// upgraded by the classifier worker into a typed entry (dose, meal,
/// symptom, etc.) with a structured payload.
///
/// Field tiers:
///   * Immutable capture:  [id], [loggedAt], [rawText], [rawAudioPath]
///   * Classifier state:   [type], [structured], [classificationStatus],
///                         [classificationConfidence],
///                         [classificationAttempts], [classificationError]
///   * User-editable:      [occurredAt], [userNotes], [tags]
///   * Vitals snapshot:    [hrBpm], [hrvMs], [gsrUs], [skinTempF],
///                         [spo2Percent], [ecgHrBpm]
///
/// The vitals fields inline the same shape as [VitalsBookmark]. A future
/// refactor will hoist them into a shared `VitalsSnapshot` type.
@HiveType(typeId: 43)
class LogEntry {
  /// UUID.
  @HiveField(0)
  final String id;

  /// When the event actually happened. User-editable so backdated entries
  /// ("I ate lunch an hour ago") can land in the right spot on the
  /// timeline. Drives chronological ordering.
  @HiveField(1)
  final DateTime occurredAt;

  /// When the entry was captured by the app. Never edited. For audit.
  @HiveField(2)
  final DateTime loggedAt;

  /// Exactly what the user said or typed. Immutable — [userNotes] holds
  /// any after-the-fact annotations.
  @HiveField(3)
  final String rawText;

  /// Optional local path to the captured audio file, if the entry came
  /// from a voice recording.
  ///
  /// **DEPRECATED (2026-04-22 cleanup)** — no production code path
  /// currently writes this field; the voice-capture flow was deferred.
  /// Kept in the Hive schema (HiveField 4) because removing it would
  /// require a schema-version bump and would drop existing LogEntry
  /// data on update. The Dart `@Deprecated` annotation is intentionally
  /// omitted to avoid `deprecated_member_use_from_same_package`
  /// warnings at the generated `.g.dart` adapter and the
  /// `firestore_sync.dart` payload — those references are correct
  /// (they preserve serialization symmetry) and not actionable.
  /// Re-evaluate on the next schema migration.
  @HiveField(4)
  final String? rawAudioPath;

  /// Classifier verdict. Defaults to 'other' (unclassified). Known
  /// types: 'other', 'note', 'dose', 'meal', 'symptom', 'mood',
  /// 'bowel_movement', 'training', 'sleep_subjective', 'bookmark'.
  @HiveField(5)
  final String type;

  /// Classifier-extracted structured fields. Schema-free — keys depend
  /// on [type] (e.g., dose → {compound, amountMg, route}; meal →
  /// {description, macros}).
  @HiveField(6)
  final Map<String, dynamic>? structured;

  /// 0-1. Null until the classifier has run.
  @HiveField(7)
  final double? classificationConfidence;

  /// Worker state machine — see [LogEntryWorker] for transitions:
  ///   'pending'            initial state, ready for worker
  ///   'classified'         worker succeeded; [type] holds the result
  ///   'skipped'            worker couldn't proceed (e.g. not signed
  ///                        in); re-queues next launch or next watch
  ///                        event; does NOT count against attempts
  ///   'failed'             last attempt failed; will retry as long as
  ///                        [classificationAttempts] < 3
  ///   'permanently_failed' exhausted retries OR server reported an
  ///                        invalid-argument error; never retried
  ///                        automatically, user must reclassify
  ///   'user_corrected'     user manually fixed the classification
  @HiveField(8)
  final String classificationStatus;

  /// Last classifier error message if [classificationStatus] == 'failed'.
  @HiveField(9)
  final String? classificationError;

  /// Retry count. The worker bumps this each attempt and gives up
  /// after a threshold (see StorageService.getPendingClassification).
  @HiveField(10)
  final int classificationAttempts;

  // -- Vitals snapshot at occurredAt (or loggedAt if backdated) --

  @HiveField(11)
  final double? hrBpm;

  @HiveField(12)
  final double? hrvMs;

  @HiveField(13)
  final double? gsrUs;

  @HiveField(14)
  final double? skinTempF;

  @HiveField(15)
  final double? spo2Percent;

  @HiveField(16)
  final double? ecgHrBpm;

  /// ID of any [ActiveProtocol] in effect at [occurredAt], so the
  /// timeline can correlate log entries with protocol context.
  @HiveField(17)
  final String? protocolIdAtTime;

  /// User-added tags.
  ///
  /// **DEPRECATED (2026-04-22 cleanup)** — no production code path
  /// currently writes this field. Kept in the Hive schema
  /// (HiveField 18) for backwards compatibility; removing it would
  /// require a schema-version bump and drop existing data. See the
  /// note on [rawAudioPath] for why the `@Deprecated` annotation is
  /// intentionally omitted.
  @HiveField(18)
  final List<String>? tags;

  /// User annotations added after the fact. Kept separate from
  /// [rawText], which is immutable.
  ///
  /// **DEPRECATED (2026-04-22 cleanup)** — no production code path
  /// currently writes this field. Kept in the Hive schema
  /// (HiveField 19) for backwards compatibility; removing it would
  /// require a schema-version bump and drop existing data. See the
  /// note on [rawAudioPath] for why the `@Deprecated` annotation is
  /// intentionally omitted.
  @HiveField(19)
  final String? userNotes;

  /// Version tag of the classifier that produced the current
  /// classification. Null until classified. Examples:
  ///   'stub-v0'                        — Part 2 stub
  ///   'claude-sonnet-4-5-prompt-v1'    — Part 2.5 real classifier, prompt v1
  ///   'user_corrected'                 — user manually set classification
  ///                                      (future feature)
  ///
  /// Required for rollback, A/B analysis, and data provenance:
  /// knowing which classifier produced a verdict lets us invalidate
  /// and reclassify in batch when a prompt regresses.
  @HiveField(20)
  final String? classificationModelVersion;

  // Private constructor — used by the factory below and by the
  // generated Hive adapter (via the public `LogEntry(...)` factory,
  // which forwards through here with both timestamps already resolved).
  const LogEntry._({
    required this.id,
    required this.occurredAt,
    required this.loggedAt,
    required this.rawText,
    required this.rawAudioPath,
    required this.type,
    required this.structured,
    required this.classificationConfidence,
    required this.classificationStatus,
    required this.classificationError,
    required this.classificationAttempts,
    required this.hrBpm,
    required this.hrvMs,
    required this.gsrUs,
    required this.skinTempF,
    required this.spo2Percent,
    required this.ecgHrBpm,
    required this.protocolIdAtTime,
    required this.tags,
    required this.userNotes,
    required this.classificationModelVersion,
  });

  /// Unnamed factory — resolves timestamp defaults so that when both
  /// [occurredAt] and [loggedAt] are omitted, the two fields share the
  /// same instant (not two back-to-back `DateTime.now()` calls that
  /// drift by a tick).
  ///
  /// The generated Hive adapter calls `LogEntry(id: ..., occurredAt:
  /// ..., loggedAt: ..., ...)` with all fields non-null on read, so the
  /// resolution logic is a no-op in that path.
  factory LogEntry({
    required String id,
    required String rawText,
    DateTime? occurredAt,
    DateTime? loggedAt,
    String? rawAudioPath,
    String type = 'other',
    Map<String, dynamic>? structured,
    double? classificationConfidence,
    String classificationStatus = 'pending',
    String? classificationError,
    int classificationAttempts = 0,
    double? hrBpm,
    double? hrvMs,
    double? gsrUs,
    double? skinTempF,
    double? spo2Percent,
    double? ecgHrBpm,
    String? protocolIdAtTime,
    List<String>? tags,
    String? userNotes,
    String? classificationModelVersion,
  }) {
    final resolvedLoggedAt = loggedAt ?? DateTime.now();
    final resolvedOccurredAt = occurredAt ?? resolvedLoggedAt;
    return LogEntry._(
      id: id,
      occurredAt: resolvedOccurredAt,
      loggedAt: resolvedLoggedAt,
      rawText: rawText,
      rawAudioPath: rawAudioPath,
      type: type,
      structured: structured,
      classificationConfidence: classificationConfidence,
      classificationStatus: classificationStatus,
      classificationError: classificationError,
      classificationAttempts: classificationAttempts,
      hrBpm: hrBpm,
      hrvMs: hrvMs,
      gsrUs: gsrUs,
      skinTempF: skinTempF,
      spo2Percent: spo2Percent,
      ecgHrBpm: ecgHrBpm,
      protocolIdAtTime: protocolIdAtTime,
      tags: tags,
      userNotes: userNotes,
      classificationModelVersion: classificationModelVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'occurredAt': occurredAt.toIso8601String(),
        'loggedAt': loggedAt.toIso8601String(),
        'rawText': rawText,
        'rawAudioPath': rawAudioPath,
        'type': type,
        'structured': structured,
        'classificationConfidence': classificationConfidence,
        'classificationStatus': classificationStatus,
        'classificationError': classificationError,
        'classificationAttempts': classificationAttempts,
        'hrBpm': hrBpm,
        'hrvMs': hrvMs,
        'gsrUs': gsrUs,
        'skinTempF': skinTempF,
        'spo2Percent': spo2Percent,
        'ecgHrBpm': ecgHrBpm,
        'protocolIdAtTime': protocolIdAtTime,
        'tags': tags,
        'userNotes': userNotes,
        'classificationModelVersion': classificationModelVersion,
      };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        id: json['id'] as String,
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        loggedAt: DateTime.parse(json['loggedAt'] as String),
        rawText: json['rawText'] as String,
        rawAudioPath: json['rawAudioPath'] as String?,
        type: json['type'] as String? ?? 'other',
        structured: (json['structured'] as Map?)?.cast<String, dynamic>(),
        classificationConfidence:
            (json['classificationConfidence'] as num?)?.toDouble(),
        classificationStatus:
            json['classificationStatus'] as String? ?? 'pending',
        classificationError: json['classificationError'] as String?,
        classificationAttempts:
            json['classificationAttempts'] as int? ?? 0,
        hrBpm: (json['hrBpm'] as num?)?.toDouble(),
        hrvMs: (json['hrvMs'] as num?)?.toDouble(),
        gsrUs: (json['gsrUs'] as num?)?.toDouble(),
        skinTempF: (json['skinTempF'] as num?)?.toDouble(),
        spo2Percent: (json['spo2Percent'] as num?)?.toDouble(),
        ecgHrBpm: (json['ecgHrBpm'] as num?)?.toDouble(),
        protocolIdAtTime: json['protocolIdAtTime'] as String?,
        tags: (json['tags'] as List?)?.map((e) => e as String).toList(),
        userNotes: json['userNotes'] as String?,
        // Null-safe read — v1 records predating this field parse cleanly.
        classificationModelVersion:
            json['classificationModelVersion'] as String?,
      );

  /// Returns a new [LogEntry] with fields replaced by the provided
  /// non-null arguments. Used by the classifier worker to update
  /// classification state without rebuilding the whole object.
  ///
  /// Passing `null` for an already-nullable field keeps the existing
  /// value (Dart can't distinguish "omitted" from "explicit null" in
  /// optional named params). To clear a field, construct directly.
  LogEntry copyWith({
    String? id,
    DateTime? occurredAt,
    DateTime? loggedAt,
    String? rawText,
    String? rawAudioPath,
    String? type,
    Map<String, dynamic>? structured,
    double? classificationConfidence,
    String? classificationStatus,
    String? classificationError,
    int? classificationAttempts,
    double? hrBpm,
    double? hrvMs,
    double? gsrUs,
    double? skinTempF,
    double? spo2Percent,
    double? ecgHrBpm,
    String? protocolIdAtTime,
    List<String>? tags,
    String? userNotes,
    String? classificationModelVersion,
  }) =>
      LogEntry._(
        id: id ?? this.id,
        occurredAt: occurredAt ?? this.occurredAt,
        loggedAt: loggedAt ?? this.loggedAt,
        rawText: rawText ?? this.rawText,
        rawAudioPath: rawAudioPath ?? this.rawAudioPath,
        type: type ?? this.type,
        structured: structured ?? this.structured,
        classificationConfidence:
            classificationConfidence ?? this.classificationConfidence,
        classificationStatus:
            classificationStatus ?? this.classificationStatus,
        classificationError:
            classificationError ?? this.classificationError,
        classificationAttempts:
            classificationAttempts ?? this.classificationAttempts,
        hrBpm: hrBpm ?? this.hrBpm,
        hrvMs: hrvMs ?? this.hrvMs,
        gsrUs: gsrUs ?? this.gsrUs,
        skinTempF: skinTempF ?? this.skinTempF,
        spo2Percent: spo2Percent ?? this.spo2Percent,
        ecgHrBpm: ecgHrBpm ?? this.ecgHrBpm,
        protocolIdAtTime: protocolIdAtTime ?? this.protocolIdAtTime,
        tags: tags ?? this.tags,
        userNotes: userNotes ?? this.userNotes,
        classificationModelVersion:
            classificationModelVersion ?? this.classificationModelVersion,
      );
}
