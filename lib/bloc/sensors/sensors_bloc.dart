import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/mock_data_service.dart';
import 'sensors_event.dart';
import 'sensors_state.dart';

class SensorsBloc extends Bloc<SensorsEvent, SensorsState> {
  final MockDataService _mockService;
  final List<StreamSubscription> _subscriptions = [];

  SensorsBloc({required MockDataService mockService})
      : _mockService = mockService,
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
    on<HrvSourceUpdated>((e, emit) =>
        emit(state.copyWith(hrvSource: e.source)));
  }

  void _onStarted(SensorsStarted event, Emitter<SensorsState> emit) {
    _mockService.start();
    emit(state.copyWith(isConnected: true));

    _subscriptions.addAll([
      _mockService.heartRateStream.listen((v) => add(HeartRateUpdated(v))),
      _mockService.hrvStream.listen((v) => add(HrvUpdated(v))),
      _mockService.gsrStream.listen((v) => add(GsrUpdated(v))),
      _mockService.temperatureStream.listen((v) => add(TemperatureUpdated(v))),
      _mockService.spo2Stream.listen((v) => add(Spo2Updated(v))),
      _mockService.lfHfStream.listen((v) => add(LfHfUpdated(v))),
      _mockService.coherenceStream.listen((v) => add(CoherenceUpdated(v))),
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
    _mockService.dispose();
    return super.close();
  }
}
