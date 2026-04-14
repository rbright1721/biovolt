import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/ble_service.dart';
import 'sensors_event.dart';
import 'sensors_state.dart';

class SensorsBloc extends Bloc<SensorsEvent, SensorsState> {
  final BleService _bleService;
  final List<StreamSubscription> _subscriptions = [];

  SensorsBloc({required BleService bleService})
      : _bleService = bleService,
        super(const SensorsState()) {
    on<SensorsStarted>(_onStarted);
    on<SensorsStopped>(_onStopped);
    on<HeartRateUpdated>((e, emit) =>
        emit(state.copyWith(heartRate: e.value)));
    on<HrvUpdated>((e, emit) =>
        emit(state.copyWith(hrv: e.value)));
    on<GsrUpdated>((e, emit) =>
        emit(state.copyWith(gsr: e.value)));
    on<TemperatureUpdated>((e, emit) =>
        emit(state.copyWith(temperature: e.value)));
    on<Spo2Updated>((e, emit) =>
        emit(state.copyWith(spo2: e.value)));
    on<LfHfUpdated>((e, emit) =>
        emit(state.copyWith(lfHfRatio: e.value)));
    on<CoherenceUpdated>((e, emit) =>
        emit(state.copyWith(coherence: e.value)));
    on<ConnectionUpdated>((e, emit) =>
        emit(state.copyWith(isConnected: e.connected)));
    on<HrvSourceUpdated>((e, emit) =>
        emit(state.copyWith(hrvSource: e.source)));
  }

  void _onStarted(SensorsStarted event, Emitter<SensorsState> emit) {
    _bleService.start();

    _subscriptions.addAll([
      _bleService.heartRateStream.listen((v) => add(HeartRateUpdated(v))),
      _bleService.hrvStream.listen((v) => add(HrvUpdated(v))),
      _bleService.gsrStream.listen((v) => add(GsrUpdated(v))),
      _bleService.temperatureStream.listen((v) => add(TemperatureUpdated(v))),
      _bleService.spo2Stream.listen((v) => add(Spo2Updated(v))),
      _bleService.lfHfStream.listen((v) => add(LfHfUpdated(v))),
      _bleService.coherenceStream.listen((v) => add(CoherenceUpdated(v))),
      _bleService.connectionStream.listen((v) => add(ConnectionUpdated(v))),
      _bleService.hrvSourceStream.listen((source) =>
          add(HrvSourceUpdated(source == 'ecg' ? HrvSource.ecg : HrvSource.ppg))),
    ]);
  }

  void _onStopped(SensorsStopped event, Emitter<SensorsState> emit) {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    emit(state.copyWith(isConnected: false));
  }

  @override
  Future<void> close() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _bleService.dispose();
    return super.close();
  }
}