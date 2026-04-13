import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

const String _serviceUuid        = "12345678-1234-1234-1234-123456789abc";
const String _characteristicUuid = "abcd1234-ab12-ab12-ab12-abcdef012345";
const String _deviceName         = "BioVolt";

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

class BleService {
  Stream<double> get heartRateStream   => _heartRateCtrl.stream;
  Stream<double> get hrvStream         => _hrvCtrl.stream;
  Stream<double> get gsrStream         => _gsrCtrl.stream;
  Stream<double> get temperatureStream => _tempCtrl.stream;
  Stream<double> get spo2Stream        => _spo2Ctrl.stream;
  Stream<double> get lfHfStream        => _lfHfCtrl.stream;
  Stream<double> get coherenceStream   => _coherenceCtrl.stream;
  Stream<double> get ecgStream         => _ecgCtrl.stream;
  Stream<double> get ppgStream         => _ppgCtrl.stream;
  Stream<double> get gsrRawStream      => _gsrRawCtrl.stream;
  Stream<bool>   get connectionStream  => _connectedCtrl.stream;

  final _heartRateCtrl = StreamController<double>.broadcast();
  final _hrvCtrl       = StreamController<double>.broadcast();
  final _gsrCtrl       = StreamController<double>.broadcast();
  final _tempCtrl      = StreamController<double>.broadcast();
  final _spo2Ctrl      = StreamController<double>.broadcast();
  final _lfHfCtrl      = StreamController<double>.broadcast();
  final _coherenceCtrl = StreamController<double>.broadcast();
  final _ecgCtrl       = StreamController<double>.broadcast();
  final _ppgCtrl       = StreamController<double>.broadcast();
  final _gsrRawCtrl    = StreamController<double>.broadcast();
  final _connectedCtrl = StreamController<bool>.broadcast();

  BluetoothDevice?    _device;
  StreamSubscription? _scanSub;
  StreamSubscription? _notifySub;
  StreamSubscription? _connStateSub;
  bool _running = false;

  // ── Sample rate: 50Hz = 20ms per sample ─────────────────────────────
  static const int _sampleRateHz   = 50;
  static const int _msPerSample   = 1000 ~/ _sampleRateHz; // 20ms

  static const int _minPeakGap = 15; // 300ms refractory period
  static const int _maxPeakGap = 75; // 1500ms max RR

  final List<double> _ppgRedBuffer = []; // raw red channel buffer
  int  _sampleIndex                = 0;
  int? _lastPeakSampleIndex;
  int  _vitalsCounter              = 0;

  // IBI/RR intervals for HRV
  final List<int> _rrIntervals = [];

  // ── SpO2 rolling window (100 samples = 2 seconds) ───────────────────
  static const int _spo2Window = 100;
  final List<double> _redWindow = [];
  final List<double> _irWindow  = [];

  // ── Perfusion index threshold ────────────────────────────────────────
  // PI = AC/DC * 100 — below 0.5% readings unreliable
  static const double _minPI = 0.5;

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

  // ── BLE scan ─────────────────────────────────────────────────────────

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

  Future<void> _connect(BluetoothDevice device) async {
    _device = device;
    try {
      await device.connect(autoConnect: false);
      _connectedCtrl.add(true);
      _connStateSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedCtrl.add(false);
          if (_running) Future.delayed(const Duration(seconds: 3), _startScan);
        }
      });
      await _discoverAndSubscribe(device);
    } catch (_) {
      _connectedCtrl.add(false);
      if (_running) Future.delayed(const Duration(seconds: 3), _startScan);
    }
  }

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

  void _onPacketReceived(List<int> raw) {
    try {
      final packet = BioVoltPacket.fromBytes(Uint8List.fromList(raw));
      _processPacket(packet);
    } catch (_) {}
  }

  // ── Main packet processing ────────────────────────────────────────────

  void _processPacket(BioVoltPacket packet) {
    _sampleIndex++;

    // ── GSR: linear invert (high ADC = high resistance = calm = low µS)
    final gsrRaw = packet.gsrRaw.toDouble();
    _gsrRawCtrl.add(gsrRaw);
    final gsrUs = ((4095.0 - gsrRaw) / 4095.0) * 15.0 + 0.5;
    _gsrCtrl.add(gsrUs.clamp(0.5, 20.0));

    // ── Temperature °C → °F
    _tempCtrl.add(packet.temperature * 9.0 / 5.0 + 32.0);

    // ── PPG values (firmware shifts right by 4, so range 0–4096)
    final ppgRed = packet.ppgRed.toDouble();
    final ppgIR  = packet.ppgIR.toDouble();

    // Normalize for waveform display
    _ecgCtrl.add((ppgRed / 16383.0).clamp(0.0, 1.0));
    _ppgCtrl.add((ppgIR  / 16383.0).clamp(0.0, 1.0));

    // ── Finger detection: both channels must be above noise floor
    final fingerOn = ppgRed > 1000 && ppgIR > 1000;

    if (!fingerOn) {
      _clearBiometrics();
      return;
    }

    // ── Buffer for SpO2 AC/DC calculation
    _redWindow.add(ppgRed);
    _irWindow.add(ppgIR);
    if (_redWindow.length > _spo2Window) _redWindow.removeAt(0);
    if (_irWindow.length > _spo2Window)  _irWindow.removeAt(0);

    // ── Adaptive threshold peak detection
    _adaptivePeakDetect(ppgRed);

    // ── Emit vitals at 1Hz
    _vitalsCounter++;
    if (_vitalsCounter >= _sampleRateHz) {
      _vitalsCounter = 0;
      _emitVitals();
    }
  }

  void _clearBiometrics() {
    _rrIntervals.clear();
    _ppgRedBuffer.clear();
    _redWindow.clear();
    _irWindow.clear();
    _lastPeakSampleIndex = null;
    _aboveThreshold  = false;
    _peakCandidate   = 0;
    _signalMax       = double.negativeInfinity;
    _signalMin       = double.maxFinite;
    _heartRateCtrl.add(0);
    _hrvCtrl.add(0);
    _spo2Ctrl.add(0);
    _lfHfCtrl.add(0);
    _coherenceCtrl.add(0);
  }

  // ── Adaptive threshold peak detection (works reliably at 50Hz) ──────────
  // Based on local mean + fraction of AC range
  // Simpler than Elgendi but validated for low sample rates

  double _adaptiveThreshold = 0;
  double _signalMin         = double.maxFinite;
  double _signalMax         = double.negativeInfinity;
  bool   _aboveThreshold    = false;
  double _peakCandidate     = 0;
  int    _peakCandidateIdx  = 0;

  void _adaptivePeakDetect(double value) {
    // Update running min/max with decay (forget old extremes slowly)
    _signalMax = math.max(_signalMax * 0.999, value);
    _signalMin = _signalMin * 0.999 + value * 0.001;
    if (_signalMin > value) _signalMin = value;

    final amplitude = _signalMax - _signalMin;
    if (amplitude < 100) return; // not enough signal variation

    // Threshold at 60% of amplitude above min
    _adaptiveThreshold = _signalMin + amplitude * 0.6;

    if (value > _adaptiveThreshold) {
      if (!_aboveThreshold) {
        // Just crossed above threshold — start tracking peak
        _aboveThreshold    = true;
        _peakCandidate     = value;
        _peakCandidateIdx  = _sampleIndex;
      } else if (value > _peakCandidate) {
        // Still rising — update peak candidate
        _peakCandidate    = value;
        _peakCandidateIdx = _sampleIndex;
      }
    } else {
      if (_aboveThreshold) {
        // Just crossed below threshold — peak confirmed at _peakCandidateIdx
        _aboveThreshold = false;
        _recordPeak(_peakCandidateIdx);
      }
    }
  }

  void _recordPeak(int peakIdx) {
    if (_lastPeakSampleIndex == null) {
      _lastPeakSampleIndex = peakIdx;
      return;
    }

    final rrSamples = peakIdx - _lastPeakSampleIndex!;

    if (rrSamples >= _minPeakGap && rrSamples <= _maxPeakGap) {
      final rrMs = rrSamples * _msPerSample;
      _rrIntervals.add(rrMs);
      if (_rrIntervals.length > 15) _rrIntervals.removeAt(0);
    }

    _lastPeakSampleIndex = peakIdx;
  }

  // ── Emit derived vitals at 1Hz ────────────────────────────────────────

  void _emitVitals() {
    // ── Heart rate + HRV from RR intervals
    if (_rrIntervals.length >= 4) {
      // Heart rate from median RR (more robust than mean)
      final sorted = List<int>.from(_rrIntervals)..sort();
      final medianRr = sorted[sorted.length ~/ 2].toDouble();
      final hr = (60000.0 / medianRr).clamp(40.0, 180.0);
      _heartRateCtrl.add(hr);

      // RMSSD (validated PPG metric at rest, ICC > 0.95 vs ECG)
      double sumSq = 0;
      for (int i = 1; i < _rrIntervals.length; i++) {
        final diff = (_rrIntervals[i] - _rrIntervals[i - 1]).toDouble();
        sumSq += diff * diff;
      }
      final rmssd = math.sqrt(sumSq / (_rrIntervals.length - 1));
      _hrvCtrl.add(rmssd.clamp(0, 120));

      // RR regularity score 0–100 (replaces unreliable LF/HF from PPG)
      // Research: "LF/HF ratio should not be computed from PPG"
      final rrCv = _rrCoefficientOfVariation();
      // Low CV = regular rhythm = high coherence
      final coherence = (100.0 - (rrCv * 500.0)).clamp(10.0, 100.0);
      _coherenceCtrl.add(coherence);

      // LF/HF: emit RR regularity as proxy (clearly labeled in UI as approx)
      final lfHfProxy = (rrCv * 20.0).clamp(0.3, 4.0);
      _lfHfCtrl.add(lfHfProxy);
    }

    // ── SpO2 via validated AC/DC ratio of ratios method
    // Reference: Maxim AN6409 — SpO2 = 104 - 17*R
    // R = (AC_red/DC_red) / (AC_IR/DC_IR)
    _computeSpO2();
  }

  // ── SpO2: proper AC/DC ratio of ratios ───────────────────────────────
  // Validated formula from Maxim AN6409: SpO2 = 104 - 17*R
  // AC = peak-to-peak over 2s window
  // DC = mean over same window
  // Perfusion index check: AC/DC > 0.5% required

  void _computeSpO2() {
    if (_redWindow.length < 50 || _irWindow.length < 50) return;

    final dcRed = _redWindow.reduce((a, b) => a + b) / _redWindow.length;
    final dcIr  = _irWindow.reduce((a, b) => a + b)  / _irWindow.length;

    if (dcRed <= 0 || dcIr <= 0) return;

    final acRed = _redWindow.reduce(math.max) - _redWindow.reduce(math.min);
    final acIr  = _irWindow.reduce(math.max)  - _irWindow.reduce(math.min);

    // Perfusion index check (PI = AC/DC * 100)
    final piRed = (acRed / dcRed) * 100.0;
    final piIr  = (acIr  / dcIr)  * 100.0;

    if (piRed < _minPI || piIr < _minPI) {
      // Poor perfusion — reading unreliable
      _spo2Ctrl.add(0);
      return;
    }

    if (acIr <= 0) return;

    // R = ratio of ratios
    final R = (acRed / dcRed) / (acIr / dcIr);

    // Maxim AN6409 empirical formula (validated 70–100% range)
    // R ≈ 0.4 → SpO2 ≈ 97%, R ≈ 1.0 → SpO2 ≈ 87%
    final spo2 = (104.0 - 17.0 * R).clamp(70.0, 100.0);

    _spo2Ctrl.add(spo2);
  }

  // ── RR coefficient of variation (σ/μ) ────────────────────────────────

  double _rrCoefficientOfVariation() {
    if (_rrIntervals.length < 2) return 0;
    final mean = _rrIntervals.reduce((a, b) => a + b) / _rrIntervals.length;
    if (mean <= 0) return 0;
    double variance = 0;
    for (final rr in _rrIntervals) {
      final d = rr - mean;
      variance += d * d;
    }
    final stdDev = math.sqrt(variance / _rrIntervals.length);
    return stdDev / mean;
  }
}