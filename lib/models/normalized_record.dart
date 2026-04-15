// =============================================================================
// Hive TypeAdapter IDs used in this file:
//   1  — DataSource
//   2  — DataQuality
//   3  — ConnectorType
//   4  — ConnectorStatus
// =============================================================================

import 'package:hive/hive.dart';

part 'normalized_record.g.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

@HiveType(typeId: 1)
enum DataSource {
  @HiveField(0)
  ecg130hz,

  @HiveField(1)
  ppg50hz,

  @HiveField(2)
  overnightRing,

  @HiveField(3)
  manual,
}

@HiveType(typeId: 2)
enum DataQuality {
  @HiveField(0)
  clinical,

  @HiveField(1)
  research,

  @HiveField(2)
  consumer,

  @HiveField(3)
  manual,
}

@HiveType(typeId: 3)
enum ConnectorType {
  @HiveField(0)
  ble,

  @HiveField(1)
  restApi,

  @HiveField(2)
  fileImport,

  @HiveField(3)
  manual,
}

@HiveType(typeId: 4)
enum ConnectorStatus {
  @HiveField(0)
  connected,

  @HiveField(1)
  disconnected,

  @HiveField(2)
  syncing,

  @HiveField(3)
  error,

  @HiveField(4)
  unauthorized,
}

// ---------------------------------------------------------------------------
// Abstract base
// ---------------------------------------------------------------------------

abstract class NormalizedRecord {
  final String connectorId;
  final DateTime timestamp;
  final DataQuality quality;

  NormalizedRecord({
    required this.connectorId,
    required this.timestamp,
    required this.quality,
  });

  Map<String, dynamic> toJson();
}
