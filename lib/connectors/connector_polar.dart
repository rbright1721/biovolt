import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:polar/polar.dart';

import '../models/biometric_records.dart';
import '../models/normalized_record.dart';
import 'connector_base.dart';

/// Polar H10 BLE connector using the polar_ble_sdk Flutter plugin.
///
/// Provides clinical-grade ECG at 130Hz and HR with R-R intervals.
/// HRV (RMSSD) is computed every 5 seconds from R-R interval stream.
class PolarConnector implements BioVoltConnector {
  static const _connectorId = 'polar_h10';
  static const _keyDeviceId = 'polar_device_id';

  final Polar _polar = Polar();
  final _secureStorage = const FlutterSecureStorage();

  String? _deviceId;
  ConnectorStatus _status = ConnectorStatus.disconnected;
  DateTime? _lastSync;
  bool _connected = false;

  StreamSubscription? _connectionSub;
  StreamSubscription? _disconnectionSub;

  // ---------------------------------------------------------------------------
  // Identity
  // ---------------------------------------------------------------------------

  @override
  String get connectorId => _connectorId;

  @override
  String get displayName => 'Polar H10';

  @override
  String get deviceDescription =>
      'Polar H10 chest strap — clinical-grade ECG at 130Hz, '
      'heart rate with R-R intervals for gold-standard HRV';

  @override
  ConnectorType get type => ConnectorType.ble;

  @override
  List<DataType> get supportedDataTypes => const [
        DataType.heartRate,
        DataType.hrv,
        DataType.ecg,
      ];

  // ---------------------------------------------------------------------------
  // Auth — BLE scan + connect
  // ---------------------------------------------------------------------------

  @override
  Future<void> authenticate() async {
    // Check for previously paired device
    final storedId = await _secureStorage.read(key: _keyDeviceId);
    if (storedId != null && storedId.isNotEmpty) {
      _deviceId = storedId;
      await _connectToDevice(storedId);
      return;
    }

    // Scan for nearby Polar H10 devices
    _status = ConnectorStatus.syncing; // scanning
    try {
      final completer = Completer<String>();
      final searchSub = _polar.searchForDevice().listen((device) {
        // Accept any H10 device
        if (device.deviceId.toUpperCase().contains('H10') ||
            device.name.toUpperCase().contains('H10')) {
          if (!completer.isCompleted) {
            completer.complete(device.deviceId);
          }
        }
      });

      // Wait up to 15 seconds for a device
      final deviceId = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => '',
      );

      await searchSub.cancel();

      if (deviceId.isEmpty) {
        _status = ConnectorStatus.disconnected;
        return;
      }

      _deviceId = deviceId;
      await _secureStorage.write(key: _keyDeviceId, value: deviceId);
      await _connectToDevice(deviceId);
    } catch (e) {
      debugPrint('Polar scan error: $e');
      _status = ConnectorStatus.error;
    }
  }

  Future<void> _connectToDevice(String deviceId) async {
    try {
      _connectionSub?.cancel();
      _disconnectionSub?.cancel();

      _connectionSub = _polar.deviceConnected.listen((info) {
        _connected = true;
        _status = ConnectorStatus.connected;
        _lastSync = DateTime.now();
      });

      _disconnectionSub = _polar.deviceDisconnected.listen((event) {
        _connected = false;
        _status = ConnectorStatus.disconnected;
      });

      await _polar.connectToDevice(deviceId);
    } catch (e) {
      debugPrint('Polar connect error: $e');
      _status = ConnectorStatus.error;
    }
  }

  @override
  Future<void> revokeAuth() async {
    await disconnect();
    await _secureStorage.delete(key: _keyDeviceId);
    _deviceId = null;
  }

  @override
  bool get isAuthenticated => _deviceId != null;

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  @override
  Future<List<NormalizedRecord>> pullHistorical(
      DateTime from, DateTime to) async => [];

  @override
  Stream<NormalizedRecord>? get liveStream {
    if (_deviceId == null || !_connected) return null;
    return _buildLiveStream(_deviceId!);
  }

  Stream<NormalizedRecord> _buildLiveStream(String deviceId) {
    final controller = StreamController<NormalizedRecord>.broadcast();
    final subscriptions = <StreamSubscription>[];

    // Accumulate R-R intervals for HRV computation every 5 seconds
    final rrBuffer = <int>[];
    Timer? hrvTimer;

    // HR + RR stream
    subscriptions.add(
      _polar.startHrStreaming(deviceId).listen(
        (hrData) {
          for (final sample in hrData.samples) {
            // Emit HeartRateReading
            controller.add(HeartRateReading(
              bpm: sample.hr.toDouble(),
              source: DataSource.ecg130hz,
              quality: DataQuality.clinical,
              connectorId: connectorId,
              timestamp: DateTime.now(),
            ));

            // Buffer R-R intervals
            rrBuffer.addAll(sample.rrsMs);
          }
        },
        onError: (e) => debugPrint('Polar HR stream error: $e'),
      ),
    );

    // ECG stream
    subscriptions.add(
      _polar.startEcgStreaming(deviceId).listen(
        (ecgData) {
          if (ecgData.samples.isNotEmpty) {
            controller.add(ECGRecord(
              qualityScore: 0.9,
              rrIntervalsMs: const [],
              connectorId: connectorId,
              timestamp: DateTime.now(),
              quality: DataQuality.clinical,
            ));
          }
        },
        onError: (e) => debugPrint('Polar ECG stream error: $e'),
      ),
    );

    // Emit HRV every 5 seconds from accumulated R-R intervals
    hrvTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (rrBuffer.length >= 3) {
        final rmssd = _computeRmssd(rrBuffer);
        final sdnn = _computeSdnn(rrBuffer);
        controller.add(HRVReading(
          rmssdMs: rmssd,
          sdnnMs: sdnn,
          source: DataSource.ecg130hz,
          quality: DataQuality.clinical,
          connectorId: connectorId,
          timestamp: DateTime.now(),
        ));
        // Keep last 10 intervals for continuity
        if (rrBuffer.length > 10) {
          rrBuffer.removeRange(0, rrBuffer.length - 10);
        }
      }
    });

    controller.onCancel = () {
      hrvTimer?.cancel();
      for (final sub in subscriptions) {
        sub.cancel();
      }
    };

    return controller.stream;
  }

  /// RMSSD = sqrt(mean of squared successive differences in R-R intervals)
  double _computeRmssd(List<int> rrMs) {
    if (rrMs.length < 2) return 0;
    double sumSqDiff = 0;
    int count = 0;
    for (int i = 1; i < rrMs.length; i++) {
      final diff = (rrMs[i] - rrMs[i - 1]).toDouble();
      sumSqDiff += diff * diff;
      count++;
    }
    return math.sqrt(sumSqDiff / count);
  }

  /// SDNN = standard deviation of all R-R intervals
  double _computeSdnn(List<int> rrMs) {
    if (rrMs.length < 2) return 0;
    final mean = rrMs.reduce((a, b) => a + b) / rrMs.length;
    double sumSqDev = 0;
    for (final rr in rrMs) {
      final dev = rr - mean;
      sumSqDev += dev * dev;
    }
    return math.sqrt(sumSqDev / rrMs.length);
  }

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  @override
  ConnectorStatus get status => _status;

  @override
  DateTime? get lastSync => _lastSync;

  @override
  Future<void> disconnect() async {
    _connectionSub?.cancel();
    _connectionSub = null;
    _disconnectionSub?.cancel();
    _disconnectionSub = null;

    if (_deviceId != null) {
      try {
        await _polar.disconnectFromDevice(_deviceId!);
      } catch (_) {}
    }
    _connected = false;
    _status = ConnectorStatus.disconnected;
  }
}
