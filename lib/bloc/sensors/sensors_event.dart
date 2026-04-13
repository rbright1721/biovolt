import 'package:equatable/equatable.dart';

abstract class SensorsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SensorsStarted extends SensorsEvent {}

class SensorsStopped extends SensorsEvent {}

class HeartRateUpdated extends SensorsEvent {
  final double value;
  HeartRateUpdated(this.value);
  @override
  List<Object?> get props => [value];
}

class HrvUpdated extends SensorsEvent {
  final double value;
  HrvUpdated(this.value);
  @override
  List<Object?> get props => [value];
}

class GsrUpdated extends SensorsEvent {
  final double value;
  GsrUpdated(this.value);
  @override
  List<Object?> get props => [value];
}

class TemperatureUpdated extends SensorsEvent {
  final double value;
  TemperatureUpdated(this.value);
  @override
  List<Object?> get props => [value];
}

class Spo2Updated extends SensorsEvent {
  final double value;
  Spo2Updated(this.value);
  @override
  List<Object?> get props => [value];
}

class LfHfUpdated extends SensorsEvent {
  final double value;
  LfHfUpdated(this.value);
  @override
  List<Object?> get props => [value];
}

class CoherenceUpdated extends SensorsEvent {
  final double value;
  CoherenceUpdated(this.value);
  @override
  List<Object?> get props => [value];
}

class ConnectionUpdated extends SensorsEvent {
  final bool connected;
  ConnectionUpdated(this.connected);
  @override
  List<Object?> get props => [connected];
}

class HrvSourceUpdated extends SensorsEvent {
  final HrvSource source;
  HrvSourceUpdated(this.source);
  @override
  List<Object?> get props => [source];
}

/// Whether HRV is derived from ECG R-R intervals (gold standard) or
/// PPG-based pulse rate variability (fallback when AD8232 is unavailable).
enum HrvSource { ecg, ppg }
