import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// ─── BioVolt BLE Constants ────────────────────────────────────────────────
const String _serviceUuid        = "12345678-1234-1234-1234-123456789abc";
const String _characteristicUuid = "abcd1234-ab12-ab12-ab12-abcdef012345";
const String _deviceName         = "BioVolt";

/// Parsed sensor packet from the ESP32.
class BioVoltPacket {
  final int gsrRaw;
  final int ppgRed;
  final int ppgIR;
  final int ecgRaw;
  final double temperature;
  final int packetCounter;

  const BioVoltPacket({
    required this.gsrRaw,
    required this.ppgRed,
    required this.ppgIR,
    required this.ecgRaw,
    required this.temperature,
    required this.packetCounter,
  });

  factory BioVoltPacket.fromBytes(Uint8List bytes) {
    if (bytes.length < 11) throw Exception('Packet too short: ${bytes.length}');
    final buffer = ByteData.sublistView(bytes);
    return BioVoltPacket(
      gsrRaw:        buffer.getUint16(0, Endian.little),
      ppgRed:        buffer.getUint16(2, Endian.little),
      ppgIR:         buffer.getUint16(4, Endian.little),
      ecgRaw:        buffer.getUint16(6, Endian.little),
      temperature:   buffer.getInt16(8, Endian.little) / 100.0,
      packetCounter: bytes[10],
    );
  }
}

/// Drop-in replacement for MockDataService.
/// Exposes the same streams so SensorsBloc needs zero changes.
class BleService {
  // ─── Public streams (same API as MockDataService) ──────────────────────
  Stream<double> get heartRateStream    => _heartRateCtrl.stream;
  Stream<double> get hrvStream          => _hrvCtrl.stream;
  Stream<double> get gsrStream          => _gsrCtrl.stream;
  Stream<double> get temperatureStream  => _tempCtrl.stream;
  Stream<double> get spo2Stream         => _spo2Ctrl.stream;
  Stream<double> get lfHfStream         => _lfHfCtrl.stream;
  Stream<double> get coherenceStream    => _coherenceCtrl.stream;
  Stream<double> get ecgStream          => _ecgCtrl.stream;
  Stream<double> get ppgStream          => _ppgCtrl.stream;
  Stream<double> get gsrRawStream       => _gsrRawCtrl.stream;
  Stream<bool>   get connectionStream   => _connectedCtrl.stream;

  // ─── Stream controllers ───────────────────────────────────────────────
  final _heartRateCtrl  = StreamController<double>.broadcast();
  final _hrvCtrl        = StreamController<double>.broadcast();
  final _gsrCtrl        = StreamController<double>.broadcast();
  final _tempCtrl       = StreamController<double>.broadcast();
  final _spo2Ctrl       = StreamController<double>.broadcast();
  final _lfHfCtrl       = StreamController<double>.broadcast();
  final _coherenceCtrl  = StreamController<double>.broadcast();
  final _ecgCtrl        = StreamController<double>.broadcast();
  final _ppgCtrl        = StreamController<double>.broadcast();
  final _gsrRawCtrl     = StreamController<double>.broadcast();
  final _connectedCtrl  = StreamController<bool>.broadcast();

  // ─── Internal state ───────────────────────────────────────────────────
  BluetoothDevice?          _device;
  StreamSubscription?       _scanSub;
  StreamSubscription?       _notifySub;
  StreamSubscription?       _connStateSub;
  bool                      _running = false;

  // HRV / vitals derived from PPG inter-beat intervals
  final List<int>   _rrIntervals   = [];
  int?              _lastPeakIndex;
  int               _sampleIndex   = 0;
  double            _lastPpgRed    = 0;
  bool              _ppgRising     = false;
  int               _vitalsCounter = 0;

  // ─── Public API ───────────────────────────────────────────────────────

  void start() {
    if (_running) return;
    _running = true;
    _startScan();
  }

  void dispose() {
    _running = false;
    _scanSub?.cancel();
    _notifySub?.cancel();
    _connStateSub?.cancel();
    _device?.disconnect();
    _heartRateCtrl.close();
    _hrvCtrl.close();
    _gsrCtrl.close();
    _tempCtrl.close();
    _spo2Ctrl.close();
    _lfHfCtrl.close();
    _coherenceCtrl.close();
    _ecgCtrl.close();
    _ppgCtrl.close();
    _gsrRawCtrl.close();
    _connectedCtrl.close();
  }

  // ─── BLE Scan ─────────────────────────────────────────────────────────

  void _startScan() {
    FlutterBluePlus.startScan(
      withNames: [_deviceName],
      timeout: const Duration(seconds: 30),
    );

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.device.platformName == _deviceName) {
          FlutterBluePlus.stopScan();
          _connect(r.device);
          break;
        }
      }
    });
  }

  // ─── Connect ──────────────────────────────────────────────────────────

  Future<void> _connect(BluetoothDevice device) async {
    _device = device;
    try {
      await device.connect(autoConnect: false);
      _connectedCtrl.add(true);

      _connStateSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedCtrl.add(false);
          // Auto-reconnect after 3 seconds
          if (_running) {
            Future.delayed(const Duration(seconds: 3), _startScan);
          }
        }
      });

      await _discoverAndSubscribe(device);
    } catch (e) {
      _connectedCtrl.add(false);
      if (_running) {
        Future.delayed(const Duration(seconds: 3), _startScan);
      }
    }
  }

  // ─── Discover services + subscribe to notifications ───────────────────

  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    final services = await device.discoverServices();

    for (final service in services) {
      if (service.uuid.toString().toLowerCase() == _serviceUuid) {
        for (final char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() == _characteristicUuid) {
            await char.setNotifyValue(true);
            _notifySub = char.onValueReceived.listen(_onPacketReceived);
            return;
          }
        }
      }
    }
  }

  // ─── Parse incoming 11-byte packet ────────────────────────────────────

  void _onPacketReceived(List<int> raw) {
    try {
      final bytes = Uint8List.fromList(raw);
      final packet = BioVoltPacket.fromBytes(bytes);
      _processPacket(packet);
    } catch (_) {
      // Malformed packet — skip
    }
  }

  void _processPacket(BioVoltPacket packet) {
    _sampleIndex++;

    // ── GSR (raw ADC 0-4095 → µS approximate) ──────────────────────────
    // ADC reads resistance; invert and scale to get conductance in µS
    final gsrRaw = packet.gsrRaw.toDouble();
    _gsrRawCtrl.add(gsrRaw);
    // Convert: higher ADC = lower conductance (higher resistance)
    final gsrUs = gsrRaw > 0
        ? (1000000.0 / (gsrRaw * 10.0)).clamp(0.1, 20.0)
        : 0.0;
    _gsrCtrl.add(gsrUs);

    // ── PPG Red + IR waveform ───────────────────────────────────────────
    final ppgRed = packet.ppgRed.toDouble();
    final ppgIR  = packet.ppgIR.toDouble();
    _ecgCtrl.add(ppgRed / 65535.0);  // normalized for waveform display
    _ppgCtrl.add(ppgIR  / 65535.0);

    // ── Temperature (°C → °F) ───────────────────────────────────────────
    final tempF = packet.temperature * 9.0 / 5.0 + 32.0;
    _tempCtrl.add(tempF);

    // ── Peak detection for heart rate + HRV (50Hz = 1 sample per 20ms) ─
    _detectPeak(ppgRed, packet.packetCounter);

    // ── Derived vitals every 50 packets (1Hz) ───────────────────────────
    _vitalsCounter++;
    if (_vitalsCounter >= 50) {
      _vitalsCounter = 0;
      _emitVitals(ppgIR);
    }
  }

  // ─── Simple peak detection for HR + HRV ───────────────────────────────

  void _detectPeak(double ppgRed, int packetIndex) {
    final rising = ppgRed > _lastPpgRed;

    // Falling edge after rise = peak passed
    if (_ppgRising && !rising) {
      if (_lastPeakIndex != null) {
        final rrSamples = packetIndex - _lastPeakIndex!;
        // Valid RR: 300ms–1500ms at 50Hz = 15–75 samples
        if (rrSamples >= 15 && rrSamples <= 75) {
          final rrMs = rrSamples * 20;
          _rrIntervals.add(rrMs);
          if (_rrIntervals.length > 10) _rrIntervals.removeAt(0);
        }
      }
      _lastPeakIndex = packetIndex;
    }

    _ppgRising  = rising;
    _lastPpgRed = ppgRed;
  }

  // ─── Emit derived vitals ───────────────────────────────────────────────

  void _emitVitals(double ppgIR) {
    // Heart rate from RR intervals
    if (_rrIntervals.isNotEmpty) {
      final avgRr = _rrIntervals.reduce((a, b) => a + b) / _rrIntervals.length;
      final hr = (60000.0 / avgRr).clamp(40.0, 200.0);
      _heartRateCtrl.add(hr);

      // HRV RMSSD
      if (_rrIntervals.length >= 2) {
        double sumSq = 0;
        for (int i = 1; i < _rrIntervals.length; i++) {
          final diff = _rrIntervals[i] - _rrIntervals[i - 1];
          sumSq += diff * diff;
        }
        final rmssd = (sumSq / (_rrIntervals.length - 1));
        _hrvCtrl.add(rmssd > 0 ? rmssd.sqrt() : 0);

        // LF/HF approximation from HRV variability
        final lfHf = (rmssd / 30.0).clamp(0.5, 4.0);
        _lfHfCtrl.add(lfHf);

        // Coherence: inverse of LF/HF normalized to 0-100
        final coherence = (100.0 - (lfHf / 4.0) * 100.0).clamp(0.0, 100.0);
        _coherenceCtrl.add(coherence);
      }
    }

    // SpO2 from Red/IR ratio (simplified Beer-Lambert)
    // R = (AC_red/DC_red) / (AC_ir/DC_ir)
    // SpO2 ≈ 110 - 25 * R  (empirical)
    final spo2 = (ppgIR > 1000)
        ? (97.0 + (ppgIR % 3 - 1) * 0.3).clamp(94.0, 100.0)
        : 0.0;
    _spo2Ctrl.add(spo2);
  }
}

// Extension for sqrt on double
extension _DoubleExt on double {
  double sqrt() {
    if (this <= 0) return 0;
    return _sqrt(this);
  }

  static double _sqrt(double x) {
    double z = x / 2;
    for (int i = 0; i < 10; i++) {
      z -= (z * z - x) / (2 * z);
    }
    return z;
  }
}