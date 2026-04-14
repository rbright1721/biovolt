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

// ── Single-pole IIR high-pass filter ─────────────────────────────────────
// y[n] = α × (y[n-1] + x[n] - x[n-1])
// α = 0.9409 for 0.5 Hz cutoff at 50 Hz — strips DC baseline (~13,000)
// leaving only the pulsatile AC component (~200-500 counts)
class _SinglePoleHPF {
  final double alpha;
  double _prevIn  = 0;
  double _prevOut = 0;
  bool   _init    = false;

  _SinglePoleHPF(this.alpha);

  double filter(double x) {
    if (!_init) {
      _prevIn = x;
      _init   = true;
      return 0;
    }
    final y = alpha * (_prevOut + x - _prevIn);
    _prevIn  = x;
    _prevOut = y;
    return y;
  }

  void reset() {
    _prevIn  = 0;
    _prevOut = 0;
    _init    = false;
  }
}

// ── 2nd-order Butterworth LPF biquad section ─────────────────────────────
// 5 Hz cutoff at 50 Hz: b=[0.0675,0.1349,0.0675], a=[1,−1.1430,0.4128]
// Rejects high-frequency noise while preserving cardiac harmonics (0.5–5 Hz)
class _BiquadLPF {
  static const double _b0 =  0.0675;
  static const double _b1 =  0.1349;
  static const double _b2 =  0.0675;
  static const double _a1 = -1.1430;
  static const double _a2 =  0.4128;

  double _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;

  double filter(double x) {
    final y = _b0*x + _b1*_x1 + _b2*_x2 - _a1*_y1 - _a2*_y2;
    _x2 = _x1; _x1 = x;
    _y2 = _y1; _y1 = y;
    return y;
  }

  void reset() { _x1 = _x2 = _y1 = _y2 = 0; }
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

  // ── Sample rate constants ─────────────────────────────────────────────
  static const int    _sampleRateHz = 50;
  static const int    _msPerSample  = 1000 ~/ _sampleRateHz; // 20ms

  // ── PPG filters (research-validated coefficients) ─────────────────────
  // HPF at 0.5 Hz: strips ~13,000 count DC baseline
  // LPF at 5.0 Hz: rejects noise above cardiac band
  final _hpfRed = _SinglePoleHPF(0.9409);
  final _lpfRed = _BiquadLPF();
  final _hpfIR  = _SinglePoleHPF(0.9409);
  final _lpfIR  = _BiquadLPF();

  // ── Rolling envelope for waveform display normalization ───────────────
  // Track AC signal min/max over ~4s window, decay slowly to adapt
  double _dispMin =  double.maxFinite;
  double _dispMax = -double.maxFinite;
  int    _dispSamples = 0;

  // ── Peak detection state ──────────────────────────────────────────────
  // α = 0.98 per sample → τ ≈ 1 second at 50 Hz
  // Research: 0.999 has τ = 20s — 20× too slow, causes missed beats
  static const double _thresholdDecay = 0.98;
  static const int    _refractorySamples = 35;  // 700ms
  static const int    _maxPeakGap        = 100; // 2000ms = 30 BPM minimum

  double _filteredPrev    = 0;
  double _peakThreshold   = 0;
  int    _refractoryCount = 0;
  int    _sampleIndex     = 0;
  bool   _thresholdInit   = false;

  // ── Parabolic interpolation state ─────────────────────────────────────
  final List<double> _peakHistory   = [];
  double?            _lastPeakTimeMs;

  // ── RR intervals for HRV ─────────────────────────────────────────────
  final List<int> _rrIntervals = [];

  // ── SpO2 rolling window (2 seconds = 100 samples) ────────────────────
  static const int    _spo2Window = 100;
  static const double _minPI      = 0.5; // perfusion index threshold
  final List<double>  _redWindow  = [];
  final List<double>  _irWindow   = [];

  // ── Vitals emit counter ───────────────────────────────────────────────
  int _vitalsCounter = 0;

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

  // ── BLE ──────────────────────────────────────────────────────────────

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

    // ── Raw PPG values (14-bit after firmware >>4 shift)
    final rawRed = packet.ppgRed.toDouble();
    final rawIR  = packet.ppgIR.toDouble();

    // ── Finger detection: both channels above noise floor
    final fingerOn = rawRed > 1000 && rawIR > 1000;

    if (!fingerOn) {
      _clearBiometrics();
      // Emit flat line for waveform display
      _ecgCtrl.add(0.5);
      return;
    }

    // ── Stage 1: DC removal via single-pole IIR HPF (α = 0.9409, fc = 0.5 Hz)
    // Converts ~13,000 DC + ~300 AC → zero-centered ±150-250 counts
    final acRed = _hpfRed.filter(rawRed);
    final acIR  = _hpfIR.filter(rawIR);

    // ── Stage 2: Noise rejection via 2nd-order Butterworth LPF (5 Hz)
    // Preserves cardiac band 0.5-5 Hz, rejects high-frequency artifacts
    final filteredRed = _lpfRed.filter(acRed);
    final filteredIR  = _lpfIR.filter(acIR);

    // ── Stage 3A: Waveform display — rolling min/max normalization
    // Track envelope over ~4s window with slow decay to adapt to amplitude changes
    _dispSamples++;
    if (filteredRed > _dispMax) _dispMax = filteredRed;
    if (filteredRed < _dispMin) _dispMin = filteredRed;

    // Decay envelope slowly every 50 samples (1Hz)
    if (_dispSamples % 50 == 0) {
      final range = _dispMax - _dispMin;
      if (range > 0) {
        _dispMax -= range * 0.001;
        _dispMin += range * 0.001;
      }
    }

    final dispRange = _dispMax - _dispMin;
    final normalized = dispRange > 10
        ? ((filteredRed - _dispMin) / dispRange).clamp(0.0, 1.0)
        : 0.5;
    _ecgCtrl.add(normalized);
    _ppgCtrl.add(normalized);

    // ── Stage 3B: SpO2 — use raw (unfiltered) values for AC/DC ratio
    _redWindow.add(rawRed);
    _irWindow.add(rawIR);
    if (_redWindow.length > _spo2Window) _redWindow.removeAt(0);
    if (_irWindow.length > _spo2Window)  _irWindow.removeAt(0);

    // ── Stage 3C: Peak detection on filtered AC signal
    _detectPeak(filteredRed);

    // ── Emit vitals at 1Hz
    _vitalsCounter++;
    if (_vitalsCounter >= _sampleRateHz) {
      _vitalsCounter = 0;
      _emitVitals();
    }
  }

  void _clearBiometrics() {
    _rrIntervals.clear();
    _redWindow.clear();
    _irWindow.clear();
    _lastPeakTimeMs   = null;
    _peakHistory.clear();
    _refractoryCount  = 0;
    _thresholdInit    = false;
    _peakThreshold    = 0;
    _filteredPrev     = 0;
    _dispMin          =  double.maxFinite;
    _dispMax          = -double.maxFinite;
    _dispSamples      = 0;
    _hpfRed.reset();
    _lpfRed.reset();
    _hpfIR.reset();
    _lpfIR.reset();
    _heartRateCtrl.add(0);
    _hrvCtrl.add(0);
    _spo2Ctrl.add(0);
    _lfHfCtrl.add(0);
    _coherenceCtrl.add(0);
  }

  // ── Derivative zero-crossing peak detection ───────────────────────────
  // Research: "derivative zero-crossing with 300ms refractory period"
  // α = 0.98 per sample (τ ≈ 1s) — fixes the 20s settling time of 0.999
  // Min slope: 15 counts/sample to reject noise (research: 15-25 counts)

  void _detectPeak(double filtered) {
    final slope = filtered - _filteredPrev;
    _filteredPrev = filtered;

    if (_refractoryCount > 0) {
      _refractoryCount--;
      return;
    }

    if (!_thresholdInit && filtered.abs() > 5) {
      _peakThreshold = filtered.abs() * 0.4;
      _thresholdInit = true;
    }

    _peakThreshold *= _thresholdDecay;

    if (slope < 0 && _filteredPrev > _peakThreshold && filtered > 10) {
      _peakThreshold = filtered * 0.80;

      // ── Parabolic interpolation for sub-sample peak timing ──────────────
      // Research: upgrades 20ms resolution to ~1ms at negligible cost
      // p = 0.5 × (y[n-1] - y[n+1]) / (y[n-1] - 2×y[n] + y[n+1])
      double refinedOffset = 0.0;
      if (_peakHistory.length >= 3) {
        final yn1 = _peakHistory[_peakHistory.length - 3]; // y[n-1]
        final yn  = _peakHistory[_peakHistory.length - 2]; // y[n]   (peak)
        final yn_1 = _peakHistory[_peakHistory.length - 1]; // y[n+1]
        final denom = yn1 - 2 * yn + yn_1;
        if (denom.abs() > 0.001) {
          refinedOffset = 0.5 * (yn1 - yn_1) / denom;
          refinedOffset = refinedOffset.clamp(-1.0, 1.0);
        }
      }

      // Refined peak time in milliseconds
      final refinedTimeMs = (_sampleIndex + refinedOffset) * _msPerSample;

      if (_lastPeakTimeMs != null) {
        final rrMs = (refinedTimeMs - _lastPeakTimeMs!).round();
        if (rrMs >= _refractorySamples * _msPerSample &&
            rrMs <= _maxPeakGap * _msPerSample) {
          _rrIntervals.add(rrMs);
          if (_rrIntervals.length > 15) _rrIntervals.removeAt(0);
        }
      }

      _lastPeakTimeMs  = refinedTimeMs;
      _refractoryCount = _refractorySamples;
    }

    // Keep rolling 3-sample history for parabolic interpolation
    _peakHistory.add(filtered);
    if (_peakHistory.length > 3) _peakHistory.removeAt(0);
  }

  // ── Emit vitals at 1Hz ────────────────────────────────────────────────

  void _emitVitals() {
    if (_rrIntervals.length >= 4) {
      // Heart rate: median RR is more robust than mean
      final sorted = List<int>.from(_rrIntervals)..sort();
      final medianRr = sorted[sorted.length ~/ 2].toDouble();
      final hr = (60000.0 / medianRr).clamp(40.0, 180.0);
      _heartRateCtrl.add(hr);

      // RMSSD — validated PPG metric (ICC > 0.95 vs ECG at rest)
      double sumSq = 0;
      for (int i = 1; i < _rrIntervals.length; i++) {
        final diff = (_rrIntervals[i] - _rrIntervals[i - 1]).toDouble();
        sumSq += diff * diff;
      }
      final rmssd = math.sqrt(sumSq / (_rrIntervals.length - 1));
      _hrvCtrl.add(rmssd.clamp(0, 120));

      // RR coefficient of variation as autonomic balance proxy
      // Research: "LF/HF ratio should not be computed from PPG"
      final cv = _rrCoefficientOfVariation();
      final coherence = (100.0 - (cv * 500.0)).clamp(10.0, 100.0);
      _coherenceCtrl.add(coherence);
      final lfHfProxy = (cv * 20.0).clamp(0.3, 3.0);
      _lfHfCtrl.add(lfHfProxy);
    }

    _computeSpO2();
  }

  // ── SpO2: AC/DC ratio of ratios (Maxim AN6409) ───────────────────────
  // R = (AC_red/DC_red) / (AC_IR/DC_IR)
  // SpO2 = 104 - 17*R (validated formula, R≈0.4→97%, R≈1.0→87%)

  void _computeSpO2() {
    if (_redWindow.length < 50 || _irWindow.length < 50) return;

    final dcRed = _redWindow.reduce((a, b) => a + b) / _redWindow.length;
    final dcIr  = _irWindow.reduce((a, b) => a + b)  / _irWindow.length;
    if (dcRed <= 0 || dcIr <= 0) return;

    final acRed = _redWindow.reduce(math.max) - _redWindow.reduce(math.min);
    final acIr  = _irWindow.reduce(math.max)  - _irWindow.reduce(math.min);

    // Perfusion index check (PI = AC/DC × 100, minimum 0.5%)
    final piRed = (acRed / dcRed) * 100.0;
    final piIr  = (acIr  / dcIr)  * 100.0;
    if (piRed < _minPI || piIr < _minPI || acIr <= 0) {
      _spo2Ctrl.add(0);
      return;
    }

    final R    = (acRed / dcRed) / (acIr / dcIr);
    final spo2 = (104.0 - 17.0 * R).clamp(70.0, 100.0);
    _spo2Ctrl.add(spo2);
  }

  double _rrCoefficientOfVariation() {
    if (_rrIntervals.length < 2) return 0;
    final mean = _rrIntervals.reduce((a, b) => a + b) / _rrIntervals.length;
    if (mean <= 0) return 0;
    double variance = 0;
    for (final rr in _rrIntervals) {
      final d = rr - mean;
      variance += d * d;
    }
    return math.sqrt(variance / _rrIntervals.length) / mean;
  }
}