import 'dart:async';
import 'dart:math';

/// Realistic mock biometric data generator for UI development.
class MockDataService {
  final _random = Random();
  Timer? _waveformTimer;
  Timer? _vitalsTimer;
  bool _running = false;

  // Waveform controllers (50Hz)
  final _ecgController = StreamController<double>.broadcast();
  final _ppgController = StreamController<double>.broadcast();
  final _gsrRawController = StreamController<double>.broadcast();

  // Vitals controllers (1Hz)
  final _heartRateController = StreamController<double>.broadcast();
  final _hrvController = StreamController<double>.broadcast();
  final _spo2Controller = StreamController<double>.broadcast();
  final _temperatureController = StreamController<double>.broadcast();
  final _gsrController = StreamController<double>.broadcast();
  final _lfHfController = StreamController<double>.broadcast();
  final _coherenceController = StreamController<double>.broadcast();

  Stream<double> get ecgStream => _ecgController.stream;
  Stream<double> get ppgStream => _ppgController.stream;
  Stream<double> get gsrRawStream => _gsrRawController.stream;
  Stream<double> get heartRateStream => _heartRateController.stream;
  Stream<double> get hrvStream => _hrvController.stream;
  Stream<double> get spo2Stream => _spo2Controller.stream;
  Stream<double> get temperatureStream => _temperatureController.stream;
  Stream<double> get gsrStream => _gsrController.stream;
  Stream<double> get lfHfStream => _lfHfController.stream;
  Stream<double> get coherenceStream => _coherenceController.stream;

  // Internal state for waveform generation
  double _ecgPhase = 0;
  double _ppgPhase = 0;
  double _gsrPhase = 0;
  double _tempDrift = 97.2;
  double _tempDirection = 0.01;
  double _currentHR = 72;
  double _currentHRV = 45;

  void start() {
    if (_running) return;
    _running = true;

    // Waveform generation at 50Hz (20ms)
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 20), (_) {
      _generateWaveforms();
    });

    // Vitals update at 1Hz
    _vitalsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _generateVitals();
    });
  }

  void _generateWaveforms() {
    // ECG: synthetic PQRST complex
    _ecgPhase += 0.04; // ~75 BPM at 50Hz
    final ecgValue = _generateECG(_ecgPhase);
    _ecgController.add(ecgValue);

    // PPG: synthetic photoplethysmogram
    _ppgPhase += 0.04;
    final ppgValue = _generatePPG(_ppgPhase);
    _ppgController.add(ppgValue);

    // GSR raw: slow sine with noise
    _gsrPhase += 0.002;
    final gsrRaw = 500 + 200 * sin(_gsrPhase) + _noise(30);
    // Occasional spike
    final gsrWithSpike = _random.nextDouble() < 0.002
        ? gsrRaw + 150 + _noise(50)
        : gsrRaw;
    _gsrRawController.add(gsrWithSpike.clamp(200, 800));
  }

  /// Synthetic ECG PQRST complex.
  double _generateECG(double phase) {
    final t = phase % 1.0; // Normalize to one beat cycle

    // P wave (small bump around t=0.1)
    final p = 0.15 * _gaussian(t, 0.10, 0.02);
    // Q dip
    final q = -0.10 * _gaussian(t, 0.22, 0.008);
    // R peak (tall sharp spike)
    final r = 1.0 * _gaussian(t, 0.25, 0.012);
    // S dip
    final s = -0.20 * _gaussian(t, 0.28, 0.010);
    // T wave (broad bump)
    final tw = 0.25 * _gaussian(t, 0.42, 0.035);

    return (p + q + r + s + tw) + _noise(0.02);
  }

  /// Synthetic PPG waveform.
  double _generatePPG(double phase) {
    final t = phase % 1.0;

    // Systolic peak
    final systolic = _gaussian(t, 0.25, 0.06);
    // Dicrotic notch and secondary peak
    final dicrotic = 0.35 * _gaussian(t, 0.50, 0.08);

    return (systolic + dicrotic) * 0.8 + _noise(0.03);
  }

  void _generateVitals() {
    // Heart rate: 60-80 BPM with natural variability
    _currentHR += (_random.nextDouble() - 0.5) * 2;
    _currentHR = _currentHR.clamp(58, 82);
    _heartRateController.add(_currentHR.roundToDouble());

    // HRV RMSSD: 30-65ms
    _currentHRV += (_random.nextDouble() - 0.5) * 3;
    _currentHRV = _currentHRV.clamp(28, 67);
    _hrvController.add(double.parse(_currentHRV.toStringAsFixed(1)));

    // SpO2: 96-99%
    final spo2 = 97.0 + _random.nextDouble() * 2 + _noise(0.3);
    _spo2Controller.add(spo2.clamp(95, 100).roundToDouble());

    // Temperature: slow drift 96.5-98.2
    _tempDrift += _tempDirection + _noise(0.005);
    if (_tempDrift > 98.2 || _tempDrift < 96.5) {
      _tempDirection = -_tempDirection;
    }
    _temperatureController.add(
      double.parse(_tempDrift.clamp(96.5, 98.2).toStringAsFixed(1)),
    );

    // GSR: smoothed conductance value (µS)
    final gsr = 3.5 + 1.5 * sin(_gsrPhase * 0.5) + _noise(0.2);
    _gsrController.add(double.parse(gsr.clamp(1.0, 8.0).toStringAsFixed(2)));

    // LF/HF ratio: 1.0-3.0
    final lfhf = 1.8 + sin(_gsrPhase * 0.3) * 0.6 + _noise(0.15);
    _lfHfController.add(double.parse(lfhf.clamp(0.8, 3.5).toStringAsFixed(2)));

    // Coherence score: 0-100
    final coherence = 65 + 15 * sin(_gsrPhase * 0.2) + _noise(5);
    _coherenceController.add(coherence.clamp(30, 95).roundToDouble());
  }

  double _gaussian(double x, double mean, double sigma) {
    final d = (x - mean) / sigma;
    return exp(-0.5 * d * d);
  }

  double _noise(double amplitude) {
    return (_random.nextDouble() - 0.5) * 2 * amplitude;
  }

  void dispose() {
    _running = false;
    _waveformTimer?.cancel();
    _vitalsTimer?.cancel();
    _ecgController.close();
    _ppgController.close();
    _gsrRawController.close();
    _heartRateController.close();
    _hrvController.close();
    _spo2Controller.close();
    _temperatureController.close();
    _gsrController.close();
    _lfHfController.close();
    _coherenceController.close();
  }
}
