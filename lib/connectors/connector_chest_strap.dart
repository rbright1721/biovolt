import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/biometric_records.dart';
import '../models/device_capability.dart';
import '../models/normalized_record.dart';
import 'chest_strap_known_devices.dart';
import 'connector_base.dart';
import 'connector_registry.dart';

/// Generic BLE chest-strap connector.
///
/// Pairs with any device that advertises the standard BLE Heart Rate
/// Service (UUID 0x180D) and streams heart rate + R-R intervals from
/// the HR Measurement characteristic (0x2A37). RMSSD + SDNN are emitted
/// every 5 seconds over a rolling R-R buffer.
///
/// Polar H10 and Coospo H9Z are both supported out of the box; unknown
/// HR-Service devices also pair and are labelled by their advertised
/// BLE name. Proprietary ECG streaming is intentionally not wired up —
/// see [ChestStrapDeviceProfile.supportsEcg].
class ChestStrapConnector implements BioVoltConnector {
  static const _connectorId = 'chest_strap';
  static const _keyDeviceId = 'chest_strap_device_id';

  /// Standard BLE Heart Rate Service (0x180D) as a 128-bit UUID.
  static const String hrServiceUuid = '0000180d-0000-1000-8000-00805f9b34fb';

  /// Standard BLE Heart Rate Measurement characteristic (0x2A37).
  static const String hrMeasurementUuid =
      '00002a37-0000-1000-8000-00805f9b34fb';

  /// How long to keep trailing R-R intervals across windows so the HRV
  /// computation stays continuous when the next 5-second tick fires.
  static const int _rrBufferCarryOver = 10;

  final FlutterSecureStorage _secureStorage;

  ChestStrapConnector({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  String? _deviceId;
  String _displayName = 'Chest Strap';
  BluetoothDevice? _device;
  ConnectorStatus _status = ConnectorStatus.disconnected;
  DateTime? _lastSync;
  bool _connected = false;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;

  // ---------------------------------------------------------------------------
  // Identity
  // ---------------------------------------------------------------------------

  @override
  String get connectorId => _connectorId;

  @override
  String get displayName => _displayName;

  @override
  String get deviceDescription =>
      'BLE chest strap (Heart Rate Service 0x180D) — '
      'heart rate with R-R intervals for HRV';

  @override
  ConnectorType get type => ConnectorType.ble;

  @override
  List<DataType> get supportedDataTypes => const [
        DataType.heartRate,
        DataType.hrv,
      ];

  @override
  Set<DeviceCapability> get capabilities => const {
        DeviceCapability.liveHeartRate,
        DeviceCapability.liveHrvRr,
      };

  @override
  Future<void> prepareForSession() async {}

  // ---------------------------------------------------------------------------
  // Auth — BLE scan + connect
  // ---------------------------------------------------------------------------

  @override
  Future<void> authenticate() async {
    final storedId = await _secureStorage.read(key: _keyDeviceId);
    if (storedId != null && storedId.isNotEmpty) {
      _deviceId = storedId;
      await _connectToDevice(BluetoothDevice.fromId(storedId));
      return;
    }

    _status = ConnectorStatus.syncing;
    try {
      final found = await _scanForFirstHrDevice();
      if (found == null) {
        _status = ConnectorStatus.disconnected;
        return;
      }
      await _secureStorage.write(
        key: _keyDeviceId,
        value: found.remoteId.str,
      );
      _deviceId = found.remoteId.str;
      await _connectToDevice(found);
    } catch (e) {
      debugPrint('Chest strap scan error: $e');
      _status = ConnectorStatus.error;
    }
  }

  Future<BluetoothDevice?> _scanForFirstHrDevice() async {
    final completer = Completer<BluetoothDevice?>();
    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (_advertisesHrService(r)) {
          if (!completer.isCompleted) completer.complete(r.device);
          return;
        }
      }
    });

    await FlutterBluePlus.startScan(
      withServices: [Guid(hrServiceUuid)],
      timeout: const Duration(seconds: 15),
    );

    final device = await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => null,
    );

    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    return device;
  }

  static bool _advertisesHrService(ScanResult r) {
    final advertised = r.advertisementData.serviceUuids
        .map((g) => g.str.toLowerCase())
        .toList();
    return advertised.contains(hrServiceUuid) ||
        advertised.contains('180d');
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      _device = device;
      _displayName =
          resolveChestStrapProfile(device.platformName).label;

      await _connStateSub?.cancel();
      _connStateSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          _connected = true;
          _status = ConnectorStatus.connected;
          _lastSync = DateTime.now();
        } else if (state == BluetoothConnectionState.disconnected) {
          _connected = false;
          _status = ConnectorStatus.disconnected;
        }
        // Let the registry (and anything listening to its capability
        // stream — e.g. SensorsBloc) know this connector's liveStream
        // just flipped between null and non-null.
        ConnectorRegistry.instance.notifyStateChanged();
      });

      await device.connect(autoConnect: false);
    } catch (e) {
      debugPrint('Chest strap connect error: $e');
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
          DateTime from, DateTime to) async =>
      [];

  @override
  Stream<NormalizedRecord>? get liveStream {
    final device = _device;
    if (device == null || !_connected) return null;
    return _buildLiveStream(device);
  }

  Stream<NormalizedRecord> _buildLiveStream(BluetoothDevice device) {
    final controller = StreamController<NormalizedRecord>.broadcast();
    final subscriptions = <StreamSubscription>[];

    final rrBuffer = <int>[];
    Timer? hrvTimer;

    Future<void> subscribe() async {
      try {
        final services = await device.discoverServices();
        BluetoothCharacteristic? hrChar;
        for (final service in services) {
          if (service.uuid.str.toLowerCase() == hrServiceUuid ||
              service.uuid.str.toLowerCase() == '180d') {
            for (final char in service.characteristics) {
              final id = char.uuid.str.toLowerCase();
              if (id == hrMeasurementUuid || id == '2a37') {
                hrChar = char;
                break;
              }
            }
          }
          if (hrChar != null) break;
        }
        if (hrChar == null) {
          debugPrint(
              'Chest strap: HR Measurement characteristic not found');
          return;
        }
        await hrChar.setNotifyValue(true);
        subscriptions.add(hrChar.onValueReceived.listen((bytes) {
          final parsed = parseHrMeasurement(bytes);
          if (parsed == null) return;

          final now = DateTime.now();
          controller.add(HeartRateReading(
            bpm: parsed.bpm.toDouble(),
            source: DataSource.ppg50hz,
            quality: DataQuality.research,
            connectorId: connectorId,
            timestamp: now,
          ));
          if (parsed.rrIntervalsMs.isNotEmpty) {
            // Emit raw RR intervals as their own record so the session
            // recorder can persist the per-beat values — the chest
            // strap's differentiator over ring-based summary devices.
            controller.add(RrIntervalSample(
              rrIntervalsMs: List<int>.unmodifiable(parsed.rrIntervalsMs),
              connectorId: connectorId,
              timestamp: now,
              quality: DataQuality.research,
            ));
          }
          rrBuffer.addAll(parsed.rrIntervalsMs);
        }));
      } catch (e) {
        debugPrint('Chest strap subscribe error: $e');
      }
    }

    unawaited(subscribe());

    hrvTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (rrBuffer.length >= 3) {
        final rmssd = _computeRmssd(rrBuffer);
        final sdnn = _computeSdnn(rrBuffer);
        controller.add(HRVReading(
          rmssdMs: rmssd,
          sdnnMs: sdnn,
          source: DataSource.ppg50hz,
          quality: DataQuality.research,
          connectorId: connectorId,
          timestamp: DateTime.now(),
        ));
        if (rrBuffer.length > _rrBufferCarryOver) {
          rrBuffer.removeRange(
              0, rrBuffer.length - _rrBufferCarryOver);
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

  /// RMSSD = sqrt(mean of squared successive differences in R-R intervals).
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

  /// SDNN = standard deviation of all R-R intervals.
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
    await _scanSub?.cancel();
    _scanSub = null;
    await _connStateSub?.cancel();
    _connStateSub = null;

    final device = _device;
    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
    _device = null;
    _connected = false;
    _status = ConnectorStatus.disconnected;
  }

  // ---------------------------------------------------------------------------
  // Pure parser — exposed for unit testing.
  // ---------------------------------------------------------------------------

  /// Parse the BLE HR Measurement characteristic (0x2A37) payload.
  ///
  /// Layout per Bluetooth spec:
  ///   - Byte 0: flags
  ///     - bit 0: HR value format (0 = uint8, 1 = uint16)
  ///     - bits 1-2: sensor contact (ignored here)
  ///     - bit 3: energy expended present (skip 2 bytes if set)
  ///     - bit 4: RR intervals present
  ///   - Byte 1 (+2): HR value (uint8 or uint16 LE)
  ///   - Optional energy expended (uint16 LE) if bit 3 set
  ///   - Optional trailing R-R intervals (uint16 LE, units = 1/1024s)
  ///
  /// Returns `null` if the payload is too short to contain a flags byte
  /// and HR value. R-R intervals are converted to whole milliseconds.
  static HrMeasurement? parseHrMeasurement(List<int> bytes) {
    if (bytes.length < 2) return null;
    final flags = bytes[0];
    final hr16 = (flags & 0x01) != 0;
    final energyPresent = (flags & 0x08) != 0;
    final rrPresent = (flags & 0x10) != 0;

    int offset = 1;
    final int bpm;
    if (hr16) {
      if (bytes.length < offset + 2) return null;
      bpm = bytes[offset] | (bytes[offset + 1] << 8);
      offset += 2;
    } else {
      bpm = bytes[offset];
      offset += 1;
    }

    if (energyPresent) {
      offset += 2;
      if (bytes.length < offset) return null;
    }

    final rr = <int>[];
    if (rrPresent) {
      while (offset + 1 < bytes.length) {
        final raw = bytes[offset] | (bytes[offset + 1] << 8);
        // Units of 1/1024 s → ms.
        rr.add((raw * 1000 / 1024).round());
        offset += 2;
      }
    }

    return HrMeasurement(bpm: bpm, rrIntervalsMs: rr);
  }
}

/// Parsed payload from an HR Measurement notification.
class HrMeasurement {
  final int bpm;
  final List<int> rrIntervalsMs;

  const HrMeasurement({required this.bpm, required this.rrIntervalsMs});
}
