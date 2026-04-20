// =============================================================================
// Hive TypeAdapter IDs used in this file:
//  42  — BiovoltEvent
// =============================================================================

import 'dart:convert';

import 'package:hive/hive.dart';

/// An append-only record of a single mutation in the app. Every state
/// write emits one of these alongside itself so the history of *what
/// happened* is preserved independently of the current state snapshot.
///
/// Stored in the `events` Hive box, keyed by [id]. That box is exempt
/// from the schema-version clear behavior — if state boxes are wiped on
/// a model-shape change, the event log survives.
class BiovoltEvent {
  /// ULID — lexicographically sortable by creation time.
  final String id;

  final DateTime timestamp;

  /// Stable per-install UUID from the `device_identity` box.
  final String deviceId;

  /// Dotted event type, e.g. `supplement.added`, `session.started`.
  /// See [EventTypes] for the canonical list.
  final String type;

  /// Arbitrary payload. Serialized to JSON on the wire.
  final Map<String, dynamic> payload;

  /// Per-event payload schema version. Older events keep their own
  /// version so payloads can be migrated later without rewriting the log.
  final int schemaVersion;

  BiovoltEvent({
    required this.id,
    required this.timestamp,
    required this.deviceId,
    required this.type,
    required this.payload,
    required this.schemaVersion,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'deviceId': deviceId,
        'type': type,
        'payload': payload,
        'schemaVersion': schemaVersion,
      };

  factory BiovoltEvent.fromJson(Map<String, dynamic> json) => BiovoltEvent(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        deviceId: json['deviceId'] as String,
        type: json['type'] as String,
        payload: (json['payload'] as Map).cast<String, dynamic>(),
        schemaVersion: json['schemaVersion'] as int,
      );
}

/// Hand-written adapter. The payload is serialized as a JSON string so
/// arbitrary Map shapes round-trip safely without needing generated
/// adapters for every payload field.
class BiovoltEventAdapter extends TypeAdapter<BiovoltEvent> {
  @override
  final int typeId = 42;

  @override
  BiovoltEvent read(BinaryReader reader) {
    final id = reader.readString();
    final tsMs = reader.readInt();
    final deviceId = reader.readString();
    final type = reader.readString();
    final payloadJson = reader.readString();
    final schemaVersion = reader.readInt();
    return BiovoltEvent(
      id: id,
      timestamp: DateTime.fromMillisecondsSinceEpoch(tsMs, isUtc: true)
          .toLocal(),
      deviceId: deviceId,
      type: type,
      payload: (jsonDecode(payloadJson) as Map).cast<String, dynamic>(),
      schemaVersion: schemaVersion,
    );
  }

  @override
  void write(BinaryWriter writer, BiovoltEvent obj) {
    writer.writeString(obj.id);
    writer.writeInt(obj.timestamp.toUtc().millisecondsSinceEpoch);
    writer.writeString(obj.deviceId);
    writer.writeString(obj.type);
    writer.writeString(jsonEncode(obj.payload));
    writer.writeInt(obj.schemaVersion);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BiovoltEventAdapter && other.typeId == typeId;
}
