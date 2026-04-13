import 'package:equatable/equatable.dart';
import 'sensors_event.dart';

class SensorsState extends Equatable {
  final bool isConnected;
  final double heartRate;
  final double hrv;
  final double gsr;
  final double temperature;
  final double spo2;
  final double lfHfRatio;
  final double coherence;
  final int batteryPercent;

  /// Whether HRV is currently derived from ECG R-R intervals (gold standard)
  /// or PPG pulse rate variability (fallback).
  final HrvSource? _hrvSource;

  HrvSource get hrvSource => _hrvSource ?? HrvSource.ecg;

  const SensorsState({
    this.isConnected = false,
    this.heartRate = 0,
    this.hrv = 0,
    this.gsr = 0,
    this.temperature = 0,
    this.spo2 = 0,
    this.lfHfRatio = 0,
    this.coherence = 0,
    this.batteryPercent = 87,
    HrvSource hrvSource = HrvSource.ecg,
  }) : _hrvSource = hrvSource;

  SensorsState copyWith({
    bool? isConnected,
    double? heartRate,
    double? hrv,
    double? gsr,
    double? temperature,
    double? spo2,
    double? lfHfRatio,
    double? coherence,
    int? batteryPercent,
    HrvSource? hrvSource,
  }) {
    return SensorsState(
      isConnected: isConnected ?? this.isConnected,
      heartRate: heartRate ?? this.heartRate,
      hrv: hrv ?? this.hrv,
      gsr: gsr ?? this.gsr,
      temperature: temperature ?? this.temperature,
      spo2: spo2 ?? this.spo2,
      lfHfRatio: lfHfRatio ?? this.lfHfRatio,
      coherence: coherence ?? this.coherence,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      hrvSource: hrvSource ?? this.hrvSource,
    );
  }

  @override
  List<Object?> get props => [
        isConnected,
        heartRate,
        hrv,
        gsr,
        temperature,
        spo2,
        lfHfRatio,
        coherence,
        batteryPercent,
        hrvSource,
      ];
}
