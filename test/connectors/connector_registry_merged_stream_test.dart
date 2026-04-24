import 'dart:async';

import 'package:biovolt/connectors/connector_base.dart';
import 'package:biovolt/connectors/connector_registry.dart';
import 'package:biovolt/models/biometric_records.dart';
import 'package:biovolt/models/device_capability.dart';
import 'package:biovolt/models/normalized_record.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal connector whose [liveStream] emits a controllable stream
/// of records so we can drive the registry's merged view.
class _StreamingMockConnector implements BioVoltConnector {
  _StreamingMockConnector(this.connectorId);

  @override
  final String connectorId;

  final _controller = StreamController<NormalizedRecord>.broadcast();

  void push(NormalizedRecord record) => _controller.add(record);
  Future<void> closeController() => _controller.close();

  @override
  Stream<NormalizedRecord>? get liveStream => _controller.stream;

  @override
  ConnectorStatus get status => ConnectorStatus.connected;

  @override
  ConnectorType get type => ConnectorType.ble;

  @override
  Set<DeviceCapability> get capabilities =>
      const {DeviceCapability.liveHeartRate};

  @override
  String get displayName => connectorId;

  @override
  String get deviceDescription => 'mock';

  @override
  List<DataType> get supportedDataTypes => const [DataType.heartRate];

  @override
  bool get isAuthenticated => true;

  @override
  DateTime? get lastSync => null;

  @override
  Future<void> authenticate() async {}

  @override
  Future<void> revokeAuth() async {}

  @override
  Future<void> prepareForSession() async {}

  @override
  Future<List<NormalizedRecord>> pullHistorical(
          DateTime from, DateTime to) async =>
      const [];

  @override
  Future<void> disconnect() async {}
}

HeartRateReading _hr(double bpm) => HeartRateReading(
      bpm: bpm,
      source: DataSource.ppg50hz,
      quality: DataQuality.research,
      connectorId: 'mock',
      timestamp: DateTime(2026, 4, 23),
    );

void main() {
  group('ConnectorRegistry.mergedLiveStream — broadcast behaviour', () {
    tearDown(() {
      ConnectorRegistry.instance.resetForTest();
    });

    test('supports multiple concurrent listeners across getter calls',
        () async {
      final registry = ConnectorRegistry.instance;
      final mock = _StreamingMockConnector('mock');
      registry.register(mock);

      // Two consumers — SensorsBloc (live UI) and SessionRecorder
      // (active session) in the real app — each hit the getter and
      // listen concurrently. Pre-fix this silently worked because each
      // call produced a fresh single-sub merge; the broadcast change
      // keeps the contract explicit.
      final a = <double>[];
      final b = <double>[];
      final subA = registry.mergedLiveStream
          .where((r) => r is HeartRateReading)
          .cast<HeartRateReading>()
          .listen((r) => a.add(r.bpm));
      final subB = registry.mergedLiveStream
          .where((r) => r is HeartRateReading)
          .cast<HeartRateReading>()
          .listen((r) => b.add(r.bpm));

      mock.push(_hr(72));
      await Future<void>.delayed(Duration.zero);

      expect(a, [72]);
      expect(b, [72]);

      await subA.cancel();
      await subB.cancel();
      await mock.closeController();
    });

    test('same merged stream instance accepts a second listener', () async {
      // Regression guard for "Bad state: Stream has already been
      // listened to": if any code path happens to reuse the same
      // merged-stream reference and adds a second listener, the
      // broadcast semantics must not crash.
      final registry = ConnectorRegistry.instance;
      final mock = _StreamingMockConnector('mock');
      registry.register(mock);

      final merged = registry.mergedLiveStream;
      final a = <double>[];
      final b = <double>[];
      final subA = merged
          .where((r) => r is HeartRateReading)
          .cast<HeartRateReading>()
          .listen((r) => a.add(r.bpm));
      final subB = merged
          .where((r) => r is HeartRateReading)
          .cast<HeartRateReading>()
          .listen((r) => b.add(r.bpm));

      mock.push(_hr(60));
      await Future<void>.delayed(Duration.zero);

      expect(a, contains(60));
      expect(b, contains(60));

      await subA.cancel();
      await subB.cancel();
      await mock.closeController();
    });
  });
}
