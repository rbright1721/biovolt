import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/foundation.dart';

import '../models/device_capability.dart';
import '../models/normalized_record.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';
import 'connector_base.dart';

/// Singleton registry that manages all [BioVoltConnector] instances.
///
/// Provides unified access to connectors by ID, type, or connection state,
/// and exposes a single [mergedLiveStream] that combines output from every
/// active BLE connector.
class ConnectorRegistry {
  ConnectorRegistry._internal();
  static final ConnectorRegistry instance = ConnectorRegistry._internal();

  final Map<String, BioVoltConnector> _connectors = {};

  /// Broadcast stream of the currently-available capability set.
  /// Emits whenever a connector is registered or [notifyStateChanged]
  /// is called (e.g. after a BLE connect/disconnect). De-duplicates:
  /// if the set is unchanged from the last emission, nothing is sent.
  final _capabilityController =
      StreamController<Set<DeviceCapability>>.broadcast();
  Set<DeviceCapability> _lastEmittedCapabilities = const {};

  /// Capability changes, driven by connect/disconnect transitions.
  Stream<Set<DeviceCapability>> get capabilityStream =>
      _capabilityController.stream;

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  /// Register a connector. Overwrites any existing connector with the same ID.
  void register(BioVoltConnector connector) {
    _connectors[connector.connectorId] = connector;
    _persistState(connector);
    _emitCapabilities();
  }

  /// Signal that a connector's connection status changed so the registry
  /// re-evaluates the capability set. Concrete connectors / the app
  /// call this after BLE connect/disconnect or REST auth state changes.
  void notifyStateChanged() => _emitCapabilities();

  /// Test-only: clear registered connectors and the cached capability
  /// snapshot so each test starts from an empty registry.
  @visibleForTesting
  void resetForTest() {
    _connectors.clear();
    _lastEmittedCapabilities = const {};
  }

  // ---------------------------------------------------------------------------
  // Lookup
  // ---------------------------------------------------------------------------

  /// Get a connector by its unique ID.
  BioVoltConnector? get(String connectorId) => _connectors[connectorId];

  /// All registered connectors.
  List<BioVoltConnector> getAll() => _connectors.values.toList();

  /// Connectors filtered by transport type.
  List<BioVoltConnector> getByType(ConnectorType type) =>
      _connectors.values.where((c) => c.type == type).toList();

  /// Only connectors whose status is [ConnectorStatus.connected].
  List<BioVoltConnector> getConnected() => _connectors.values
      .where((c) => c.status == ConnectorStatus.connected)
      .toList();

  /// Connectors that expose a non-null [liveStream].
  List<BioVoltConnector> getLiveStreamConnectors() =>
      _connectors.values.where((c) => c.liveStream != null).toList();

  // ---------------------------------------------------------------------------
  // Capabilities
  // ---------------------------------------------------------------------------

  /// Union of [BioVoltConnector.capabilities] across every currently-
  /// connected connector. Disconnected connectors contribute nothing,
  /// even if their capability set is non-empty in principle.
  Set<DeviceCapability> availableCapabilities() {
    final set = <DeviceCapability>{};
    for (final c in _connectors.values) {
      if (c.status != ConnectorStatus.connected) continue;
      set.addAll(c.capabilities);
    }
    return set;
  }

  /// Whether any currently-connected connector provides [cap].
  bool has(DeviceCapability cap) => availableCapabilities().contains(cap);

  void _emitCapabilities() {
    final current = availableCapabilities();
    if (_setEquals(current, _lastEmittedCapabilities)) return;
    _lastEmittedCapabilities = current;
    _capabilityController.add(current);
  }

  static bool _setEquals<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    for (final x in a) {
      if (!b.contains(x)) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Merged live stream
  // ---------------------------------------------------------------------------

  /// A single stream that merges live output from ALL connectors whose
  /// [liveStream] is non-null, using [StreamGroup.merge].
  Stream<NormalizedRecord> get mergedLiveStream {
    final streams = _connectors.values
        .map((c) => c.liveStream)
        .whereType<Stream<NormalizedRecord>>()
        .toList();

    if (streams.isEmpty) return const Stream.empty();
    return StreamGroup.merge(streams);
  }

  // ---------------------------------------------------------------------------
  // Historical sync
  // ---------------------------------------------------------------------------

  /// Pull historical data from every REST connector and return a combined
  /// list sorted by timestamp ascending.
  Future<List<NormalizedRecord>> syncAllRest(
      DateTime from, DateTime to) async {
    final restConnectors =
        _connectors.values.where((c) => c.type == ConnectorType.restApi);

    final results = await Future.wait(
      restConnectors.map((c) async {
        try {
          final records = await c.pullHistorical(from, to);
          await _persistState(c);
          return records;
        } catch (_) {
          return <NormalizedRecord>[];
        }
      }),
    );

    final combined = results.expand((r) => r).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return combined;
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<void> _persistState(BioVoltConnector connector) async {
    // register() invokes this fire-and-forget, so surface nothing on
    // the call site but don't crash the app if storage isn't ready
    // (e.g. during test teardown where Hive boxes are already closed).
    try {
      final storage = StorageService();
      await storage.saveConnectorState(
        ConnectorState(
          connectorId: connector.connectorId,
          status: connector.status,
          lastSync: connector.lastSync,
          isAuthenticated: connector.isAuthenticated,
        ),
      );
    } catch (e) {
      debugPrint(
          'ConnectorRegistry._persistState suppressed error: $e');
    }
    _emitCapabilities();
  }
}
