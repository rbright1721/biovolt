import 'package:async/async.dart';

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

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  /// Register a connector. Overwrites any existing connector with the same ID.
  void register(BioVoltConnector connector) {
    _connectors[connector.connectorId] = connector;
    _persistState(connector);
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
    final storage = StorageService();
    await storage.saveConnectorState(
      ConnectorState(
        connectorId: connector.connectorId,
        status: connector.status,
        lastSync: connector.lastSync,
        isAuthenticated: connector.isAuthenticated,
      ),
    );
  }
}
