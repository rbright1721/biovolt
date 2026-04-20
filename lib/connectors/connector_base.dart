import '../models/device_capability.dart';
import '../models/normalized_record.dart';

/// Every signal type that BioVolt can ingest from any connector.
enum DataType {
  heartRate,
  hrv,
  ecg,
  ppg,
  eda,
  skinTemp,
  spO2,
  sleep,
  readiness,
  glucose,
  activity,
  stress,
  eeg,
}

/// Abstract interface that every device connector must implement.
///
/// BLE connectors provide [liveStream] and return immediately from [authenticate].
/// REST/API connectors implement [pullHistorical] and use OAuth for [authenticate].
abstract class BioVoltConnector {
  /// Unique identifier for this connector instance (e.g. 'esp32_biovolt', 'oura_ring').
  String get connectorId;

  /// Human-readable name shown in the UI (e.g. 'BioVolt Pod').
  String get displayName;

  /// Short description of the hardware or service.
  String get deviceDescription;

  /// Transport type — BLE, REST API, file import, or manual entry.
  ConnectorType get type;

  /// Which data types this connector can provide.
  List<DataType> get supportedDataTypes;

  /// What the connector can actually deliver — live streams,
  /// post-hoc summaries, or both. SessionRecorder uses the union of
  /// capabilities from connected connectors to pick streaming vs.
  /// enrich-later vs. manual mode.
  Set<DeviceCapability> get capabilities;

  /// Called just before a session starts so connectors can reset any
  /// per-session baselines (e.g. GSR tonic baseline on the ESP32 pod).
  /// Most connectors implement this as a no-op.
  Future<void> prepareForSession();

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  /// Initiate authentication.
  ///
  /// BLE connectors: resolves immediately (connection *is* auth).
  /// REST connectors: launches OAuth flow, resolves when token is acquired.
  Future<void> authenticate();

  /// Revoke any stored credentials / disconnect.
  Future<void> revokeAuth();

  /// Whether the connector is currently authenticated and ready to pull data.
  bool get isAuthenticated;

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  /// Pull historical records from a REST/cloud connector.
  ///
  /// BLE connectors return an empty list — they only provide live data.
  Future<List<NormalizedRecord>> pullHistorical(DateTime from, DateTime to);

  /// A continuous stream of [NormalizedRecord] objects from a BLE connector.
  ///
  /// REST connectors return `null` — they only provide historical pulls.
  Stream<NormalizedRecord>? get liveStream;

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  /// Current connection/sync status.
  ConnectorStatus get status;

  /// When data was last successfully synced, or `null` if never.
  DateTime? get lastSync;

  /// Disconnect and clean up resources.
  Future<void> disconnect();
}
