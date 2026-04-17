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
  Stream<double> get heartRateStream       => _heartRateCtrl.stream;
  Stream<double> get hrvStream             => _hrvCtrl.stream;
  Stream<double> get gsrStream             => _gsrCtrl.stream;
  Stream<double> get gsrBaselineShiftStream => _gsrBaselineShiftCtrl.stream;
  Stream<double> get temperatureStream     => _tempCtrl.stream;
  Stream<double> get spo2Stream            => _spo2Ctrl.stream;
  Stream<double> get lfHfStream            => _lfHfCtrl.stream;
  Stream<double> get coherenceStream       => _coherenceCtrl.stream;
  Stream<double> get ecgStream             => _ecgCtrl.stream;
  Stream<double> get ppgStream             => _ppgCtrl.stream;
  Stream<double> get gsrRawStream          => _gsrRawCtrl.stream;
  Stream<bool>   get connectionStream      => _connectedCtrl.stream;

  /// Emits the current HRV source whenever it changes.
  /// UI can listen to show the ECG/PPG badge on the HRV card.
  Stream<String> get hrvSourceStream   => _hrvSourceCtrl.stream;

  final _heartRateCtrl         = StreamController<double>.broadcast();
  final _hrvCtrl               = StreamController<double>.broadcast();
  final _gsrCtrl               = StreamController<double>.broadcast();
  final _gsrBaselineShiftCtrl  = StreamController<double>.broadcast();
  final _tempCtrl              = StreamController<double>.broadcast();
  final _spo2Ctrl              = StreamController<double>.broadcast();
  final _lfHfCtrl              = StreamController<double>.broadcast();
  final _coherenceCtrl         = StreamController<double>.broadcast();
  final _ecgCtrl               = StreamController<double>.broadcast();
  final _ppgCtrl               = StreamController<double>.broadcast();
  final _gsrRawCtrl            = StreamController<double>.broadcast();
  final _connectedCtrl         = StreamController<bool>.broadcast();
  final _hrvSourceCtrl         = StreamController<String>.broadcast();

  // ── GSR session baseline tracker ──────────────────────────────────────
  // First ~3s of session = baseline window. After that, emit relative shift.
  double _gsrSessionBaseline = 0.0;
  int    _gsrBaselineSamples = 0;
  static const int _gsrBaselineWindow = 150; // 150 samples @ 50Hz = 3s

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

  // ── PPG Peak detection state ──────────────────────────────────────────
  // α = 0.98 per sample → τ ≈ 1 second at 50 Hz
  // Research: 0.999 has τ = 20s — 20× too slow, causes missed beats
  static const double _thresholdDecay    = 0.98;
  static const int    _refractorySamples = 35;  // 700ms
  static const int    _maxPeakGap        = 100; // 2000ms = 30 BPM minimum

  double _filteredPrev    = 0;
  double _peakThreshold   = 0;
  int    _refractoryCount = 0;
  int    _sampleIndex     = 0;
  bool   _thresholdInit   = false;

  // ── PPG Parabolic interpolation state ─────────────────────────────────
  final List<double> _peakHistory   = [];
  double? _lastPeakTimeMs;

  // ── PPG RR intervals for HRV ──────────────────────────────────────────
  final List<int> _ppgRrIntervals = [];

  // ── SpO2 rolling window (2 seconds = 100 samples) ────────────────────
  static const int    _spo2Window = 100;
  static const double _minPI      = 0.5; // perfusion index threshold
  final List<double>  _redWindow  = [];
  final List<double>  _irWindow   = [];

  // ── Vitals emit counter ───────────────────────────────────────────────
  int _vitalsCounter = 0;

  // ════════════════════════════════════════════════════════════════════════
  // ── ECG R-peak detection state (simplified Hamilton variant) ──────────
  // ════════════════════════════════════════════════════════════════════════
  //
  // Pipeline: IIR HPF (1 Hz) → rectify → 3-point moving average →
  //           4-sample MWI → adaptive threshold → refractory → parabolic
  //
  // Research basis:
  //   - Hamilton 2002: simplified Pan-Tompkins on PIC16F877, 99.80% Se/PPV
  //   - AD8232 analog bandpass 0.5–40 Hz handles most preprocessing
  //   - Parabolic interpolation mandatory: without it RMSSD CCC = 0.432
  //     vs gold standard; with it RAE drops to ~5% (Béres & Hejjel 2021)

  // -- ECG IIR high-pass filter (α=0.94, fc ≈ 1 Hz at 50 Hz) -----------
  // Strips residual baseline wander the AD8232's 0.5 Hz analog HPF misses
  double _ecgHpPrevIn  = 0;
  double _ecgHpPrevOut = 0;
  bool   _ecgHpInit    = false;

  // -- ECG 3-point moving average buffer --------------------------------
  final List<double> _ecgMaBuffer = [0, 0, 0];

  // -- ECG slope tracking for T-wave rejection ----------------------------
  double _ecgHpPrevForSlope    = 0;
  double _ecgMaxSlopeInWindow  = 0;
  double _ecgLastRPeakSlope    = 0;

  // -- ECG adaptive threshold (Pan-Tompkins formulation) ----------------
  // threshold = noiseLevel + 0.25 × (signalLevel - noiseLevel)
  // Signal update: signalLevel = 0.125 × peakAmp + 0.875 × signalLevel
  // Noise update:  noiseLevel  = 0.125 × peakAmp + 0.875 × noiseLevel
  double _ecgSignalLevel     = 0;
  double _ecgNoiseLevel      = 0;
  int    _ecgLearningSamples = 0;
  double _ecgLearningMax     = 0;
  static const int _ecgLearningPhase = 100; // 2 seconds at 50 Hz

  // -- ECG refractory & timing ------------------------------------------
  // 200ms refractory = 10 samples (ventricular absolute refractory period)
  // Max gap 2000ms = 100 samples (30 BPM floor, triggers searchback)
  static const int _ecgRefractorySamples = 15;   // 300ms — blanks through T-wave
  static const int _ecgMaxGapSamples     = 100;  // 2000ms = 30 BPM
  int    _ecgRefractoryCount = 0;
  int    _ecgSampleIndex     = 0;
  double? _ecgLastPeakTimeMs;

  // -- ECG T-wave rejection ---------------------------------------------
  // Any peak within 360ms (18 samples) of confirmed R-peak AND < 50% of
  // previous R-peak amplitude = T-wave → discard
  double _ecgLastRPeakAmp = 0;
  int    _ecgSamplesSinceRPeak = 999;

  // -- ECG parabolic interpolation history (3 samples around peak) ------
  final List<double> _ecgPeakHistory = [];

  // -- ECG R-R intervals (separate from PPG) ----------------------------
  final List<int> _ecgRrIntervals = [];

  // -- ECG searchback state ---------------------------------------------
  // Track last 8 integrated values for searchback when R-R gap exceeds
  // 150% of average R-R interval
  final List<double> _ecgSearchbackBuffer    = [];
  final List<int>    _ecgSearchbackIndices   = [];
  static const int   _ecgSearchbackLen       = 50; // ~1 second of history

  // -- ECG average R-R for searchback trigger ---------------------------
  double _ecgAvgRr = 800; // initial guess: 75 BPM

  // -- ECG waveform display normalization ──────────────────────────────
  double _ecgDispMin =  double.maxFinite;
  double _ecgDispMax = -double.maxFinite;
  int    _ecgDispSamples = 0;

  // -- ECG active tracking ──────────────────────────────────────────────
  int _ecgConfirmedPeaks  = 0;
  int _ecgZeroCount       = 0;
  static const int _ecgZeroTimeout = 25; // 500ms of zeros = ECG offline

  /// Returns true when the AD8232 is producing valid ECG and at least 4
  /// R-peaks have been confirmed — meaning ECG-derived HRV is available.
  bool get ecgActive => _ecgConfirmedPeaks >= 4 && _ecgZeroCount < _ecgZeroTimeout;

  /// Last HRV source that was emitted. UI can read this synchronously.
  String _lastHrvSource = 'ppg';
  String get hrvSource => _lastHrvSource;

  void start() {
    if (_running) return;
    _running = true;
    _startScan();
  }

  /// Reset GSR session baseline — call when a new session starts so the
  /// next ~3 seconds re-establish the baseline window.
  void resetGsrBaseline() {
    _gsrSessionBaseline = 0.0;
    _gsrBaselineSamples = 0;
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
    _gsrBaselineShiftCtrl.close();
    _tempCtrl.close();
    _spo2Ctrl.close();
    _lfHfCtrl.close();
    _coherenceCtrl.close();
    _ecgCtrl.close();
    _ppgCtrl.close();
    _gsrRawCtrl.close();
    _connectedCtrl.close();
    _hrvSourceCtrl.close();
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

    // ── GSR baseline normalization ────────────────────────────────────
    // First 3 seconds of session = baseline window
    // After that, emit relative change from baseline
    if (_gsrBaselineSamples < _gsrBaselineWindow) {
      _gsrBaselineSamples++;
      // Running average of baseline
      _gsrSessionBaseline = (_gsrSessionBaseline * (_gsrBaselineSamples - 1) +
          gsrUs) / _gsrBaselineSamples;
    } else if (_gsrSessionBaseline > 0) {
      // Relative shift: positive = more aroused than baseline
      //                negative = calmer than baseline
      final shift = gsrUs - _gsrSessionBaseline;
      _gsrBaselineShiftCtrl.add(shift);
    }

    // ── Temperature °C → °F
    _tempCtrl.add(packet.temperature * 9.0 / 5.0 + 32.0);

    // ── ECG processing (runs independently of PPG) ──────────────────────
    _processEcg(packet.ecgRaw.toDouble());

    // ── Raw PPG values (14-bit after firmware >>4 shift)
    final rawRed = packet.ppgRed.toDouble();
    final rawIR  = packet.ppgIR.toDouble();

    // ── Finger detection: both channels above noise floor
    final fingerOn = rawRed > 1000 && rawIR > 1000;

    if (fingerOn) {
      // ── Stage 1: DC removal via single-pole IIR HPF (α = 0.9409, fc = 0.5 Hz)
      // Converts ~13,000 DC + ~300 AC → zero-centered ±150-250 counts
      final acRed = _hpfRed.filter(rawRed);
      final acIR  = _hpfIR.filter(rawIR);

      // ── Stage 2: Noise rejection via 2nd-order Butterworth LPF (5 Hz)
      // Preserves cardiac band 0.5-5 Hz, rejects high-frequency artifacts
      final filteredRed = _lpfRed.filter(acRed);
      final filteredIR  = _lpfIR.filter(acIR);

      // ── Stage 3A: PPG waveform display — rolling min/max normalization
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
      final ppgNorm = dispRange > 10
          ? ((filteredRed - _dispMin) / dispRange).clamp(0.0, 1.0)
          : 0.5;
      _ppgCtrl.add(ppgNorm);

      // Show PPG waveform on _ecgCtrl only when ECG is NOT active
      if (!ecgActive) {
        _ecgCtrl.add(ppgNorm);
      }

      // ── Stage 3B: SpO2 — use raw (unfiltered) values for AC/DC ratio
      _redWindow.add(rawRed);
      _irWindow.add(rawIR);
      if (_redWindow.length > _spo2Window) _redWindow.removeAt(0);
      if (_irWindow.length > _spo2Window)  _irWindow.removeAt(0);

      // ── Stage 3C: PPG Peak detection on filtered AC signal
      _detectPpgPeak(filteredRed);
    } else {
      // Finger off PPG sensor — clear PPG state only
      _clearPpgBiometrics();

      // Waveform display: show ECG if active, else flat line
      if (!ecgActive) {
        _ecgCtrl.add(0.5);
      }
    }

    // ── Emit vitals at 1Hz — ALWAYS runs regardless of finger state ─────
    // When finger is off but ECG is active, we still emit ECG-derived
    // HR/HRV. When both are off, _emitVitals() skips gracefully.
    _vitalsCounter++;
    if (_vitalsCounter >= _sampleRateHz) {
      _vitalsCounter = 0;
      _emitVitals();
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // ── ECG R-PEAK DETECTION (simplified Hamilton variant) ────────────────
  // ════════════════════════════════════════════════════════════════════════
  //
  // Pipeline:
  //   1. IIR high-pass (α=0.94, ~1 Hz) — strips residual baseline wander
  //   2. Rectify (absolute value) — Hamilton uses abs instead of squaring
  //   3. 3-point moving average — gentle smoothing (no MWI — preserves R/T ratio)
  //   4. Slope tracking for T-wave rejection
  //   5. Adaptive threshold (Pan-Tompkins formulation)
  //   6. Refractory period (300ms = 15 samples)
  //   7. Slope-based T-wave rejection (slope < 40% of R-peak slope)
  //   8. Searchback (150% avg R-R gap)
  //   9. Parabolic interpolation for sub-sample R-peak timing
  //
  // Why not full Pan-Tompkins:
  //   At 50 Hz the QRS is only 4-6 samples wide. The 5-point derivative
  //   spans 100ms (the entire QRS), squaring amplifies single-sample
  //   spikes, and the 150ms MWI window is only 7 samples. Hamilton's
  //   simplification (rectify instead of square, shorter MWI) works
  //   better at low sample rates. Tested at 99.80% Se/PPV on MIT-BIH.

  void _processEcg(double rawEcg) {
    _ecgSampleIndex++;
    _ecgSamplesSinceRPeak++;

    // ── ECG liveness detection ──────────────────────────────────────────
    // Firmware sends ecgRaw=0 when leads are off
    if (rawEcg == 0) {
      _ecgZeroCount++;
      if (_ecgZeroCount >= _ecgZeroTimeout) {
        // ECG went offline — don't clear state immediately, just mark inactive.
        // State persists so if leads reconnect, detection resumes quickly.
      }
      return;
    }
    _ecgZeroCount = 0; // reset on any non-zero sample

    // ── Step 1: IIR high-pass filter (α=0.94, cutoff ~1 Hz) ────────────
    // AD8232 has 0.5 Hz analog HPF but only -12 dB at 0.3 Hz respiratory
    // frequency. This software HPF adds robustness against baseline wander.
    double ecgHp;
    if (!_ecgHpInit) {
      _ecgHpPrevIn = rawEcg;
      _ecgHpInit = true;
      ecgHp = 0;
    } else {
      ecgHp = 0.97 * (_ecgHpPrevOut + rawEcg - _ecgHpPrevIn);
      _ecgHpPrevIn  = rawEcg;
      _ecgHpPrevOut = ecgHp;
    }

    // ── ECG waveform display (normalized 0-1) when ECG is active ────────
    // Uses the high-pass filtered signal for clean waveform display
    if (ecgActive || _ecgConfirmedPeaks > 0) {
      _ecgDispSamples++;
      if (ecgHp > _ecgDispMax) _ecgDispMax = ecgHp;
      if (ecgHp < _ecgDispMin) _ecgDispMin = ecgHp;

      // Decay envelope every 50 samples (1Hz)
      if (_ecgDispSamples % 50 == 0) {
        final range = _ecgDispMax - _ecgDispMin;
        if (range > 0) {
          _ecgDispMax -= range * 0.002;
          _ecgDispMin += range * 0.002;
        }
      }

      final ecgDispRange = _ecgDispMax - _ecgDispMin;
      if (ecgActive && ecgDispRange > 10) {
        final ecgNorm = ((ecgHp - _ecgDispMin) / ecgDispRange).clamp(0.0, 1.0);
        _ecgCtrl.add(ecgNorm);
      }
    }

    // ── Step 2: Rectify (absolute value) ────────────────────────────────
    // Hamilton uses abs instead of squaring — less gain-sensitive, better
    // for low-resolution signals where squaring a 1-2 sample spike
    // produces unusable single-sample impulses
    final rectified = ecgHp.abs();

    // ── Step 3: 3-point moving average ──────────────────────────────────
    // Gentle smoothing: rejects single-sample ADC noise spikes (~±20-50 LSB)
    // without smearing the already-narrow 4-6 sample QRS
    _ecgMaBuffer.removeAt(0);
    _ecgMaBuffer.add(rectified);
    final smoothed = (_ecgMaBuffer[0] + _ecgMaBuffer[1] + _ecgMaBuffer[2]) / 3.0;

    // ── Step 4: Slope tracking for T-wave rejection ───────────────────────
    // Track max absolute slope of raw HPF signal since last confirmed peak
    final currentSlope = (ecgHp - _ecgHpPrevForSlope).abs();
    _ecgHpPrevForSlope = ecgHp;
    if (currentSlope > _ecgMaxSlopeInWindow) {
      _ecgMaxSlopeInWindow = currentSlope;
    }

    // ── Searchback buffer — keep last ~1s of smoothed values ────────────
    _ecgSearchbackBuffer.add(smoothed);
    _ecgSearchbackIndices.add(_ecgSampleIndex);
    if (_ecgSearchbackBuffer.length > _ecgSearchbackLen) {
      _ecgSearchbackBuffer.removeAt(0);
      _ecgSearchbackIndices.removeAt(0);
    }

    // ── Step 5: Learning phase (first 2 seconds = 100 samples) ──────────
    // Initialize adaptive threshold from the max signal seen during startup
    if (_ecgLearningSamples < _ecgLearningPhase) {
      _ecgLearningSamples++;
      if (smoothed > _ecgLearningMax) _ecgLearningMax = smoothed;
      if (_ecgLearningSamples == _ecgLearningPhase) {
        _ecgSignalLevel = _ecgLearningMax * 0.5;
        _ecgNoiseLevel  = _ecgLearningMax * 0.1;
      }
      _ecgPeakHistory.add(smoothed);
      if (_ecgPeakHistory.length > 3) _ecgPeakHistory.removeAt(0);
      return;
    }

    // ── Step 6: Adaptive threshold ──────────────────────────────────────
    final threshold = _ecgNoiseLevel + 0.25 * (_ecgSignalLevel - _ecgNoiseLevel);

    // ── Step 7: Refractory period countdown ─────────────────────────────
    if (_ecgRefractoryCount > 0) {
      _ecgRefractoryCount--;
      if (_ecgRefractoryCount == 0) {
        _ecgMaxSlopeInWindow = 0;
      }
      _ecgPeakHistory.add(smoothed);
      if (_ecgPeakHistory.length > 3) _ecgPeakHistory.removeAt(0);
      return;
    }

    // ── Step 8: Peak detection on smoothed rectified signal ─────────────
    final isPeak = _ecgPeakHistory.isNotEmpty &&
        _ecgPeakHistory.last > threshold &&
        smoothed < _ecgPeakHistory.last;

    if (isPeak) {
      final peakAmp = _ecgPeakHistory.last;

      // ── Slope-based T-wave rejection ──────────────────────────────────
      // Universal slope gate: every peak must have slope >= 40% of last
      // confirmed R-peak. Real R-peaks have slopes >900, false positives 200-450.
      final isTWave = _ecgLastRPeakSlope > 0 &&
          _ecgMaxSlopeInWindow < _ecgLastRPeakSlope * 0.4;

      if (isTWave) {
        _ecgNoiseLevel = 0.125 * peakAmp + 0.875 * _ecgNoiseLevel;
      } else {
        // ── Confirmed R-peak ──────────────────────────────────────────
        _ecgSignalLevel = 0.125 * peakAmp + 0.875 * _ecgSignalLevel;
        _ecgLastRPeakAmp = peakAmp;
        _ecgLastRPeakSlope = _ecgMaxSlopeInWindow;
        _ecgSamplesSinceRPeak = 0;
        _ecgMaxSlopeInWindow = 0; // reset for next window
        _ecgConfirmedPeaks++;

        // TODO: remove debug print after verifying ECG detection works
        print('[ECG] R-peak #$_ecgConfirmedPeaks  amp=${peakAmp.toStringAsFixed(1)}'
            '  thresh=${threshold.toStringAsFixed(1)}'
            '  slope=${_ecgLastRPeakSlope.toStringAsFixed(1)}'
            '  RRs=${_ecgRrIntervals.length}'
            '  active=$ecgActive');

        // ── Parabolic interpolation for sub-sample timing ─────────────
        double refinedOffset = 0.0;
        if (_ecgPeakHistory.length >= 2) {
          final yPrev = _ecgPeakHistory[_ecgPeakHistory.length - 2];
          final yPeak = _ecgPeakHistory[_ecgPeakHistory.length - 1];
          final yCurr = smoothed;
          final denom = yPrev - 2 * yPeak + yCurr;
          if (denom.abs() > 0.001) {
            refinedOffset = 0.5 * (yPrev - yCurr) / denom;
            refinedOffset = refinedOffset.clamp(-1.0, 1.0);
          }
        }

        final refinedTimeMs =
            (_ecgSampleIndex - 1 + refinedOffset) * _msPerSample;

        if (_ecgLastPeakTimeMs != null) {
          final rrMs = (refinedTimeMs - _ecgLastPeakTimeMs!).round();
          final withinBounds = rrMs >= _ecgRefractorySamples * _msPerSample &&
              rrMs <= _ecgMaxGapSamples * _msPerSample;
          // Reject RR intervals that are >30% shorter than running average.
          // The heart cannot accelerate by more than 30% in a single beat.
          // Only apply this check once we have enough data to trust the average.
          final consistentWithAvg = _ecgRrIntervals.length < 4 ||
              rrMs > _ecgAvgRr * 0.7;

          if (withinBounds) {
            // Always update timing anchor for peaks within physiological
            // bounds. This peak IS a real heartbeat — we just may not
            // trust this particular interval measurement.
            _ecgLastPeakTimeMs = refinedTimeMs;

            if (consistentWithAvg) {
              _ecgRrIntervals.add(rrMs);
              if (_ecgRrIntervals.length > 15) _ecgRrIntervals.removeAt(0);
              _ecgAvgRr = _ecgRrIntervals.reduce((a, b) => a + b) /
                  _ecgRrIntervals.length;
            }
          }
        } else {
          _ecgLastPeakTimeMs = refinedTimeMs;
        }
        _ecgRefractoryCount = _ecgRefractorySamples;
      }
    } else {
      // No peak — check searchback
      if (_ecgLastPeakTimeMs != null) {
        final msSinceLastPeak =
            (_ecgSampleIndex * _msPerSample) - _ecgLastPeakTimeMs!;
        final searchbackTriggerMs = _ecgAvgRr * 1.5;

        if (msSinceLastPeak > searchbackTriggerMs &&
            msSinceLastPeak < _ecgMaxGapSamples * _msPerSample) {
          _performSearchback(threshold * 0.5);
        }
      }
    }

    // Keep rolling 3-sample history for parabolic interpolation
    _ecgPeakHistory.add(smoothed);
    if (_ecgPeakHistory.length > 3) _ecgPeakHistory.removeAt(0);
  }

  /// Helper for readability — true when the smoothed value is below
  /// the current detection threshold (i.e. no peak candidate).
  bool peakBelowThreshold(double smoothed, double threshold) {
    return smoothed < threshold;
  }

  /// Search backward through the integration buffer for the largest peak
  /// that exceeds [halfThreshold]. Used when the R-R gap exceeds 150% of
  /// the running average, suggesting a beat was missed.
  void _performSearchback(double halfThreshold) {
    if (_ecgSearchbackBuffer.length < 5) return;

    double maxVal = 0;
    int    maxIdx = -1;
    int    maxSampleIdx = 0;

    for (int i = 1; i < _ecgSearchbackBuffer.length - 1; i++) {
      final val = _ecgSearchbackBuffer[i];
      if (val > halfThreshold &&
          val > _ecgSearchbackBuffer[i - 1] &&
          val > _ecgSearchbackBuffer[i + 1] &&
          val > maxVal) {
        maxVal = val;
        maxIdx = i;
        maxSampleIdx = _ecgSearchbackIndices[i];
      }
    }

    if (maxIdx > 0) {
      // Found a missed peak — register it
      _ecgSignalLevel = 0.125 * maxVal + 0.875 * _ecgSignalLevel;
      _ecgLastRPeakAmp = maxVal;
      _ecgConfirmedPeaks++;

      // Parabolic interpolation on the searchback peak
      double refinedOffset = 0.0;
      if (maxIdx >= 1 && maxIdx < _ecgSearchbackBuffer.length - 1) {
        final yPrev = _ecgSearchbackBuffer[maxIdx - 1];
        final yPeak = _ecgSearchbackBuffer[maxIdx];
        final yCurr = _ecgSearchbackBuffer[maxIdx + 1];
        final denom = yPrev - 2 * yPeak + yCurr;
        if (denom.abs() > 0.001) {
          refinedOffset = 0.5 * (yPrev - yCurr) / denom;
          refinedOffset = refinedOffset.clamp(-1.0, 1.0);
        }
      }

      final refinedTimeMs = (maxSampleIdx + refinedOffset) * _msPerSample;

      if (_ecgLastPeakTimeMs != null) {
        final rrMs = (refinedTimeMs - _ecgLastPeakTimeMs!).round();
        if (rrMs >= _ecgRefractorySamples * _msPerSample &&
            rrMs <= _ecgMaxGapSamples * _msPerSample) {
          _ecgRrIntervals.add(rrMs);
          if (_ecgRrIntervals.length > 15) _ecgRrIntervals.removeAt(0);
          _ecgAvgRr = _ecgRrIntervals.reduce((a, b) => a + b) /
              _ecgRrIntervals.length;
        }
      }

      _ecgLastPeakTimeMs = refinedTimeMs;
      _ecgSamplesSinceRPeak = _ecgSampleIndex - maxSampleIdx;
      // Don't set refractory here — we're already past the peak in time
    }
  }

  // ── Clear PPG biometrics (finger removed) ─────────────────────────────
  // Resets PPG state only. ECG state is NOT cleared here — the AD8232
  // operates independently of the MAX30102 finger sensor.
  void _clearPpgBiometrics() {
    _ppgRrIntervals.clear();
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

    // Only zero out vitals if ECG isn't providing them
    if (!ecgActive) {
      _heartRateCtrl.add(0);
      _hrvCtrl.add(0);
      _lfHfCtrl.add(0);
      _coherenceCtrl.add(0);
    }
    _spo2Ctrl.add(0);
  }

  // ── Clear ECG state (called on full disconnect, not on leads-off) ─────
  void _clearEcgState() {
    _ecgHpPrevIn  = 0;
    _ecgHpPrevOut = 0;
    _ecgHpInit    = false;
    _ecgMaBuffer.fillRange(0, 3, 0);
    _ecgHpPrevForSlope   = 0;
    _ecgMaxSlopeInWindow = 0;
    _ecgLastRPeakSlope   = 0;
    _ecgSignalLevel     = 0;
    _ecgNoiseLevel      = 0;
    _ecgLearningSamples = 0;
    _ecgLearningMax     = 0;
    _ecgRefractoryCount = 0;
    _ecgSampleIndex     = 0;
    _ecgLastPeakTimeMs  = null;
    _ecgLastRPeakAmp    = 0;
    _ecgSamplesSinceRPeak = 999;
    _ecgPeakHistory.clear();
    _ecgRrIntervals.clear();
    _ecgSearchbackBuffer.clear();
    _ecgSearchbackIndices.clear();
    _ecgAvgRr           = 800;
    _ecgDispMin         =  double.maxFinite;
    _ecgDispMax         = -double.maxFinite;
    _ecgDispSamples     = 0;
    _ecgConfirmedPeaks  = 0;
    _ecgZeroCount       = 0;
  }

  // ── Legacy _clearBiometrics — clears everything (full disconnect) ─────
  void _clearBiometrics() {
    _clearPpgBiometrics();
    _clearEcgState();
    _heartRateCtrl.add(0);
    _hrvCtrl.add(0);
    _spo2Ctrl.add(0);
    _lfHfCtrl.add(0);
    _coherenceCtrl.add(0);
  }

  // ── PPG Derivative zero-crossing peak detection ───────────────────────
  // Research: "derivative zero-crossing with 300ms refractory period"
  // α = 0.98 per sample (τ ≈ 1s) — fixes the 20s settling time of 0.999
  // Min slope: 15 counts/sample to reject noise (research: 15-25 counts)

  void _detectPpgPeak(double filtered) {
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
          _ppgRrIntervals.add(rrMs);
          if (_ppgRrIntervals.length > 15) _ppgRrIntervals.removeAt(0);
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
    // ── Decide HRV source: prefer ECG when active with enough data ──────
    // ECG R-R intervals are near-clinical grade (AD8232 + parabolic interp)
    // PPG R-R intervals are consumer wellness grade (±5-10 BPM)
    final useEcg = ecgActive && _ecgRrIntervals.length >= 4;
    final rrIntervals = useEcg ? _ecgRrIntervals : _ppgRrIntervals;

    // TODO: remove debug print after verifying ECG/PPG source selection
    print('[VITALS] source=${useEcg ? "ECG" : "PPG"}'
        '  ecgActive=$ecgActive'
        '  ecgPeaks=$_ecgConfirmedPeaks'
        '  ecgRRs=${_ecgRrIntervals.length}'
        '  ppgRRs=${_ppgRrIntervals.length}');

    // Emit HRV source change
    final newSource = useEcg ? 'ecg' : 'ppg';
    if (newSource != _lastHrvSource) {
      _lastHrvSource = newSource;
      _hrvSourceCtrl.add(newSource);
    }

    if (rrIntervals.length >= 4) {
      // Heart rate: median RR is more robust than mean
      final sorted = List<int>.from(rrIntervals)..sort();
      final medianRr = sorted[sorted.length ~/ 2].toDouble();
      final hr = (60000.0 / medianRr).clamp(40.0, 180.0);
      _heartRateCtrl.add(hr);

      // RMSSD — gold standard when from ECG, validated PPG metric at rest
      double sumSq = 0;
      for (int i = 1; i < rrIntervals.length; i++) {
        final diff = (rrIntervals[i] - rrIntervals[i - 1]).toDouble();
        sumSq += diff * diff;
      }
      final rmssd = math.sqrt(sumSq / (rrIntervals.length - 1));
      _hrvCtrl.add(rmssd.clamp(0, 250));

      final cv = _rrCoefficientOfVariation(rrIntervals);

      // ── Coherence: measures REGULARITY of oscillation pattern ─────────
      // True coherence = smooth rhythmic HRV (sine-like) vs chaotic random
      // Method: calculate CV of successive RR DIFFERENCES
      // Regular oscillation → similar-sized swings → low diff CV → high coherence
      // Chaotic pattern → erratic swings → high diff CV → low coherence
      double coherence = 50.0; // default mid-range
      if (rrIntervals.length >= 4) {
        final diffs = <double>[];
        for (int i = 1; i < rrIntervals.length; i++) {
          diffs.add((rrIntervals[i] - rrIntervals[i - 1]).abs().toDouble());
        }
        final diffMean = diffs.reduce((a, b) => a + b) / diffs.length;
        if (diffMean > 0) {
          double diffVariance = 0;
          for (final d in diffs) {
            diffVariance += (d - diffMean) * (d - diffMean);
          }
          final diffCv = math.sqrt(diffVariance / diffs.length) / diffMean;
          // Low diffCv (regular oscillation) = high coherence
          // diffCv of 0 = perfect rhythm = 100
          // diffCv of 1+ = chaotic = ~10
          coherence = (100.0 - (diffCv * 90.0)).clamp(10.0, 100.0);
        }
      }
      _coherenceCtrl.add(coherence);

      // ── LF/HF proxy: two-timescale autonomic balance ──────────────────
      // Short-term (RMSSD-like) = HF = parasympathetic
      // Longer-term drift = LF = sympathetic
      // Proxy: compare recent CV to longer-window CV
      // High short-term relative to long → parasympathetic → low LF/HF
      // Low short-term relative to long → sympathetic → high LF/HF
      //
      // Practical: use CV with wider scaling so it doesn't peg at max
      // cv range 0-0.25 maps to LF/HF 0.3-3.0
      final lfHfProxy = (cv * 12.0).clamp(0.3, 3.0);
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

  double _rrCoefficientOfVariation(List<int> intervals) {
    if (intervals.length < 2) return 0;
    final mean = intervals.reduce((a, b) => a + b) / intervals.length;
    if (mean <= 0) return 0;
    double variance = 0;
    for (final rr in intervals) {
      final d = rr - mean;
      variance += d * d;
    }
    return math.sqrt(variance / intervals.length) / mean;
  }
}