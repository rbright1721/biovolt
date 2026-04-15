import 'dart:async';

import '../models/biometric_records.dart';
import '../models/normalized_record.dart';
import '../services/ble_service.dart';
import 'connector_base.dart';

/// ESP32 BioVolt Pod connector.
///
/// Wraps the existing [BleService] — all signal processing math stays
/// untouched inside [BleService]. This connector simply maps its output
/// streams to [NormalizedRecord] types for the connector framework.
class Esp32Connector implements BioVoltConnector {
  final BleService _bleService;
  DateTime? _lastSync;
  bool _connected = false;
  StreamSubscription<bool>? _connSub;

  Esp32Connector({required BleService bleService}) : _bleService = bleService {
    _connSub = _bleService.connectionStream.listen((connected) {
      _connected = connected;
      if (connected) _lastSync = DateTime.now();
    });
  }

  // ---------------------------------------------------------------------------
  // Identity
  // ---------------------------------------------------------------------------

  @override
  String get connectorId => 'esp32_biovolt';

  @override
  String get displayName => 'BioVolt Pod';

  @override
  String get deviceDescription =>
      'DIY ESP32 biofeedback device with GSR, MAX30102 PPG, '
      'DS18B20 temperature, and AD8232 ECG sensors';

  @override
  ConnectorType get type => ConnectorType.ble;

  @override
  List<DataType> get supportedDataTypes => const [
        DataType.heartRate,
        DataType.hrv,
        DataType.ecg,
        DataType.ppg,
        DataType.eda,
        DataType.skinTemp,
        DataType.spO2,
      ];

  // ---------------------------------------------------------------------------
  // Auth — BLE connection IS authentication
  // ---------------------------------------------------------------------------

  @override
  Future<void> authenticate() async {
    _bleService.start();
  }

  @override
  Future<void> revokeAuth() async {
    await disconnect();
  }

  @override
  bool get isAuthenticated => _connected;

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  /// BLE connectors have no historical data.
  @override
  Future<List<NormalizedRecord>> pullHistorical(
      DateTime from, DateTime to) async => [];

  /// Merged live stream of all sensor readings as [NormalizedRecord] objects.
  @override
  Stream<NormalizedRecord>? get liveStream => _buildLiveStream();

  Stream<NormalizedRecord> _buildLiveStream() {
    final controller = StreamController<NormalizedRecord>.broadcast();
    final subscriptions = <StreamSubscription>[];

    subscriptions.addAll([
      _bleService.heartRateStream.listen((bpm) {
        controller.add(HeartRateReading(
          bpm: bpm,
          source: DataSource.ppg50hz,
          quality: DataQuality.consumer,
          connectorId: connectorId,
          timestamp: DateTime.now(),
        ));
      }),
      _bleService.hrvStream.listen((rmssd) {
        controller.add(HRVReading(
          rmssdMs: rmssd,
          source: DataSource.ppg50hz,
          quality: DataQuality.consumer,
          connectorId: connectorId,
          timestamp: DateTime.now(),
        ));
      }),
      _bleService.gsrStream.listen((us) {
        controller.add(EDAReading(
          microSiemens: us,
          connectorId: connectorId,
          timestamp: DateTime.now(),
          quality: DataQuality.consumer,
        ));
      }),
      _bleService.spo2Stream.listen((pct) {
        controller.add(SpO2Reading(
          percent: pct,
          connectorId: connectorId,
          timestamp: DateTime.now(),
          quality: DataQuality.consumer,
        ));
      }),
      _bleService.temperatureStream.listen((celsius) {
        controller.add(TemperatureReading(
          celsius: celsius,
          placement: TemperaturePlacement.skin,
          connectorId: connectorId,
          timestamp: DateTime.now(),
          quality: DataQuality.consumer,
        ));
      }),
    ]);

    controller.onCancel = () {
      for (final sub in subscriptions) {
        sub.cancel();
      }
    };

    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  @override
  ConnectorStatus get status =>
      _connected ? ConnectorStatus.connected : ConnectorStatus.disconnected;

  @override
  DateTime? get lastSync => _lastSync;

  @override
  Future<void> disconnect() async {
    _connSub?.cancel();
    _connSub = null;
    _bleService.dispose();
    _connected = false;
  }
}
