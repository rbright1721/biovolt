import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../connectors/connector_registry.dart';
import '../../models/biometric_records.dart';
import '../../services/ble_service.dart';
import 'sensors_event.dart';
import 'sensors_state.dart';

class SensorsBloc extends Bloc<SensorsEvent, SensorsState> {
  final BleService _bleService;
  final ConnectorRegistry? _connectorRegistry;
  final List<StreamSubscription> _subscriptions = [];

  /// Recycled on every capability change so newly-connected connectors
  /// (e.g. chest strap paired after app launch) start feeding HR/HRV.
  StreamSubscription? _mergedSubscription;
  StreamSubscription? _capabilitySubscription;

  SensorsBloc({
    required BleService bleService,
    ConnectorRegistry? connectorRegistry,
  })  : _bleService = bleService,
        _connectorRegistry = connectorRegistry,
        super(const SensorsState()) {
    on<SensorsStarted>(_onStarted);
    on<SensorsStopped>(_onStopped);
    on<HeartRateUpdated>((e, emit) =>
        emit(state.copyWith(heartRate: e.value)));
    on<HrvUpdated>((e, emit) =>
        emit(state.copyWith(hrv: e.value)));
    on<GsrUpdated>((e, emit) =>
        emit(state.copyWith(gsr: e.value)));
    on<GsrBaselineShiftUpdated>((e, emit) =>
        emit(state.copyWith(gsrBaselineShift: e.value)));
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

    // HR/HRV come from the connector registry so that non-ESP32 HR
    // sources (chest strap, future devices) feed the live UI the same
    // way they already feed the session recorder. ESP32 HR still
    // arrives here too — it's relayed through Esp32Connector.liveStream
    // into the merged stream.
    final registry = _connectorRegistry;
    if (registry != null) {
      _resubscribeToRegistry(registry);
      _capabilitySubscription = registry.capabilityStream.listen((_) {
        _resubscribeToRegistry(registry);
      });
    } else {
      // No registry wired (unit tests): fall back to BleService streams
      // so behaviour matches the pre-refactor bloc.
      _subscriptions.addAll([
        _bleService.heartRateStream.listen((v) => add(HeartRateUpdated(v))),
        _bleService.hrvStream.listen((v) => add(HrvUpdated(v))),
      ]);
    }

    _subscriptions.addAll([
      _bleService.gsrStream.listen((v) => add(GsrUpdated(v))),
      _bleService.gsrBaselineShiftStream
          .listen((v) => add(GsrBaselineShiftUpdated(v))),
      _bleService.temperatureStream.listen((v) => add(TemperatureUpdated(v))),
      _bleService.spo2Stream.listen((v) => add(Spo2Updated(v))),
      _bleService.lfHfStream.listen((v) => add(LfHfUpdated(v))),
      _bleService.coherenceStream.listen((v) => add(CoherenceUpdated(v))),
      _bleService.connectionStream.listen((v) => add(ConnectionUpdated(v))),
      _bleService.hrvSourceStream.listen((source) =>
          add(HrvSourceUpdated(source == 'ecg' ? HrvSource.ecg : HrvSource.ppg))),
    ]);
  }

  void _resubscribeToRegistry(ConnectorRegistry registry) {
    _mergedSubscription?.cancel();
    _mergedSubscription = registry.mergedLiveStream.listen((record) {
      if (record is HeartRateReading) {
        add(HeartRateUpdated(record.bpm));
      } else if (record is HRVReading) {
        add(HrvUpdated(record.rmssdMs));
      }
    });
  }

  void _onStopped(SensorsStopped event, Emitter<SensorsState> emit) {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _mergedSubscription?.cancel();
    _mergedSubscription = null;
    _capabilitySubscription?.cancel();
    _capabilitySubscription = null;
    emit(state.copyWith(isConnected: false));
  }

  @override
  Future<void> close() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _mergedSubscription?.cancel();
    _capabilitySubscription?.cancel();
    _bleService.dispose();
    return super.close();
  }
}