// =============================================================================
// Hive TypeAdapter IDs used in this file:
//   5  — HeartRateReading
//   6  — HRVReading
//   7  — EDAReading
//   8  — SpO2Reading
//   9  — TemperatureReading
//  10  — ECGRecord
//  11  — TemperaturePlacement
// =============================================================================

import 'package:hive/hive.dart';
import 'normalized_record.dart';

part 'biometric_records.g.dart';

// ---------------------------------------------------------------------------
// TemperaturePlacement enum
// ---------------------------------------------------------------------------

@HiveType(typeId: 11)
enum TemperaturePlacement {
  @HiveField(0)
  skin,

  @HiveField(1)
  ambient,

  @HiveField(2)
  core,
}

// ---------------------------------------------------------------------------
// HeartRateReading
// ---------------------------------------------------------------------------

@HiveType(typeId: 5)
class HeartRateReading extends NormalizedRecord {
  @HiveField(0)
  final double bpm;

  @HiveField(1)
  final DataSource source;

  @HiveField(2)
  @override
  final DataQuality quality;

  @HiveField(3)
  @override
  final String connectorId;

  @HiveField(4)
  @override
  final DateTime timestamp;

  HeartRateReading({
    required this.bpm,
    required this.source,
    required this.quality,
    required this.connectorId,
    required this.timestamp,
  }) : super(
          connectorId: connectorId,
          timestamp: timestamp,
          quality: quality,
        );

  @override
  Map<String, dynamic> toJson() => {
        'bpm': bpm,
        'source': source.name,
        'quality': quality.name,
        'connectorId': connectorId,
        'timestamp': timestamp.toIso8601String(),
      };

  factory HeartRateReading.fromJson(Map<String, dynamic> json) =>
      HeartRateReading(
        bpm: (json['bpm'] as num).toDouble(),
        source: DataSource.values.byName(json['source'] as String),
        quality: DataQuality.values.byName(json['quality'] as String),
        connectorId: json['connectorId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

// ---------------------------------------------------------------------------
// HRVReading
// ---------------------------------------------------------------------------

@HiveType(typeId: 6)
class HRVReading extends NormalizedRecord {
  @HiveField(0)
  final double rmssdMs;

  @HiveField(1)
  final double? sdnnMs;

  @HiveField(2)
  final double? pnn50Percent;

  @HiveField(3)
  final DataSource source;

  @HiveField(4)
  @override
  final DataQuality quality;

  @HiveField(5)
  @override
  final String connectorId;

  @HiveField(6)
  @override
  final DateTime timestamp;

  HRVReading({
    required this.rmssdMs,
    this.sdnnMs,
    this.pnn50Percent,
    required this.source,
    required this.quality,
    required this.connectorId,
    required this.timestamp,
  }) : super(
          connectorId: connectorId,
          timestamp: timestamp,
          quality: quality,
        );

  @override
  Map<String, dynamic> toJson() => {
        'rmssdMs': rmssdMs,
        'sdnnMs': sdnnMs,
        'pnn50Percent': pnn50Percent,
        'source': source.name,
        'quality': quality.name,
        'connectorId': connectorId,
        'timestamp': timestamp.toIso8601String(),
      };

  factory HRVReading.fromJson(Map<String, dynamic> json) => HRVReading(
        rmssdMs: (json['rmssdMs'] as num).toDouble(),
        sdnnMs: (json['sdnnMs'] as num?)?.toDouble(),
        pnn50Percent: (json['pnn50Percent'] as num?)?.toDouble(),
        source: DataSource.values.byName(json['source'] as String),
        quality: DataQuality.values.byName(json['quality'] as String),
        connectorId: json['connectorId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

// ---------------------------------------------------------------------------
// EDAReading
// ---------------------------------------------------------------------------

@HiveType(typeId: 7)
class EDAReading extends NormalizedRecord {
  @HiveField(0)
  final double microSiemens;

  @HiveField(1)
  final double? baselineShiftUs;

  @HiveField(2)
  @override
  final String connectorId;

  @HiveField(3)
  @override
  final DateTime timestamp;

  @HiveField(4)
  @override
  final DataQuality quality;

  EDAReading({
    required this.microSiemens,
    this.baselineShiftUs,
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
        'microSiemens': microSiemens,
        'baselineShiftUs': baselineShiftUs,
        'connectorId': connectorId,
        'timestamp': timestamp.toIso8601String(),
        'quality': quality.name,
      };

  factory EDAReading.fromJson(Map<String, dynamic> json) => EDAReading(
        microSiemens: (json['microSiemens'] as num).toDouble(),
        baselineShiftUs: (json['baselineShiftUs'] as num?)?.toDouble(),
        connectorId: json['connectorId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        quality: DataQuality.values.byName(json['quality'] as String),
      );
}

// ---------------------------------------------------------------------------
// SpO2Reading
// ---------------------------------------------------------------------------

@HiveType(typeId: 8)
class SpO2Reading extends NormalizedRecord {
  @HiveField(0)
  final double percent;

  @HiveField(1)
  final double? perfusionIndex;

  @HiveField(2)
  @override
  final String connectorId;

  @HiveField(3)
  @override
  final DateTime timestamp;

  @HiveField(4)
  @override
  final DataQuality quality;

  SpO2Reading({
    required this.percent,
    this.perfusionIndex,
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
        'percent': percent,
        'perfusionIndex': perfusionIndex,
        'connectorId': connectorId,
        'timestamp': timestamp.toIso8601String(),
        'quality': quality.name,
      };

  factory SpO2Reading.fromJson(Map<String, dynamic> json) => SpO2Reading(
        percent: (json['percent'] as num).toDouble(),
        perfusionIndex: (json['perfusionIndex'] as num?)?.toDouble(),
        connectorId: json['connectorId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        quality: DataQuality.values.byName(json['quality'] as String),
      );
}

// ---------------------------------------------------------------------------
// TemperatureReading
// ---------------------------------------------------------------------------

@HiveType(typeId: 9)
class TemperatureReading extends NormalizedRecord {
  @HiveField(0)
  final double celsius;

  @HiveField(1)
  final TemperaturePlacement placement;

  @HiveField(2)
  @override
  final String connectorId;

  @HiveField(3)
  @override
  final DateTime timestamp;

  @HiveField(4)
  @override
  final DataQuality quality;

  TemperatureReading({
    required this.celsius,
    required this.placement,
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
        'celsius': celsius,
        'placement': placement.name,
        'connectorId': connectorId,
        'timestamp': timestamp.toIso8601String(),
        'quality': quality.name,
      };

  factory TemperatureReading.fromJson(Map<String, dynamic> json) =>
      TemperatureReading(
        celsius: (json['celsius'] as num).toDouble(),
        placement:
            TemperaturePlacement.values.byName(json['placement'] as String),
        connectorId: json['connectorId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        quality: DataQuality.values.byName(json['quality'] as String),
      );
}

// ---------------------------------------------------------------------------
// RrIntervalSample
// ---------------------------------------------------------------------------

/// A batch of raw R-R intervals (ms) emitted per chest-strap notification.
///
/// Intentionally not Hive-persisted — the session recorder flattens these
/// into [PolarMetrics.rrIntervalsMs] when the session finalizes. Keeping
/// the in-flight record lightweight avoids a schema bump and keeps the
/// Hive type-adapter table stable.
class RrIntervalSample extends NormalizedRecord {
  final List<int> rrIntervalsMs;

  RrIntervalSample({
    required this.rrIntervalsMs,
    required super.connectorId,
    required super.timestamp,
    required super.quality,
  });

  @override
  Map<String, dynamic> toJson() => {
        'rrIntervalsMs': rrIntervalsMs,
        'connectorId': connectorId,
        'timestamp': timestamp.toIso8601String(),
        'quality': quality.name,
      };
}

// ---------------------------------------------------------------------------
// ECGRecord
// ---------------------------------------------------------------------------

@HiveType(typeId: 10)
class ECGRecord extends NormalizedRecord {
  @HiveField(0)
  final double qualityScore;

  @HiveField(1)
  final String? waveformPath;

  @HiveField(2)
  final List<int> rrIntervalsMs;

  @HiveField(3)
  @override
  final String connectorId;

  @HiveField(4)
  @override
  final DateTime timestamp;

  @HiveField(5)
  @override
  final DataQuality quality;

  ECGRecord({
    required this.qualityScore,
    this.waveformPath,
    required this.rrIntervalsMs,
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
        'qualityScore': qualityScore,
        'waveformPath': waveformPath,
        'rrIntervalsMs': rrIntervalsMs,
        'connectorId': connectorId,
        'timestamp': timestamp.toIso8601String(),
        'quality': quality.name,
      };

  factory ECGRecord.fromJson(Map<String, dynamic> json) => ECGRecord(
        qualityScore: (json['qualityScore'] as num).toDouble(),
        waveformPath: json['waveformPath'] as String?,
        rrIntervalsMs: (json['rrIntervalsMs'] as List<dynamic>)
            .map((e) => (e as num).toInt())
            .toList(),
        connectorId: json['connectorId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        quality: DataQuality.values.byName(json['quality'] as String),
      );
}
