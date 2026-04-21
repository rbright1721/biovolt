import 'dart:async';
import 'dart:math';

import 'package:hive/hive.dart';
import 'package:ulid/ulid.dart';

import '../models/biovolt_event.dart';

/// Append-only log of every mutation in the app.
///
/// Owns the `events` Hive box. Each [append] generates a ULID (time-
/// ordered), stamps it with the stable `deviceId`, and writes the event.
/// The log is exempt from the schema-version-clear behavior in
/// StorageService — if state boxes are wiped, events persist.
///
/// Mutations that can't log their event should fail loudly. Do not
/// catch-and-swallow errors from [append] — a diverged state/event log
/// is worse than a noisy exception.
class EventLog {
  final Box<BiovoltEvent> _eventsBox;
  final String _deviceId;

  /// Tracks the most recent ULID issued by this instance so that rapid
  /// sequential calls within a single millisecond still produce
  /// lexicographically-increasing IDs (the ulid package's randomness
  /// is otherwise not guaranteed to be monotonic within the same ms).
  String _lastId = '';

  EventLog({
    required Box<BiovoltEvent> eventsBox,
    required String deviceId,
  })  : _eventsBox = eventsBox,
        _deviceId = deviceId;

  /// Box name used by this service. Must NOT appear in the list of
  /// boxes that StorageService wipes on a schema bump.
  static const String boxName = 'events';

  /// Box name for the per-install device identity UUID.
  static const String deviceIdentityBoxName = 'device_identity';

  /// Key under which the UUID is stored inside the device_identity box.
  static const String deviceIdentityKey = 'id';

  String get deviceId => _deviceId;

  /// Append a new event. Returns the persisted record with its ULID.
  Future<BiovoltEvent> append({
    required String type,
    required Map<String, dynamic> payload,
    int schemaVersion = 1,
  }) async {
    final id = await _nextMonotonicUlid();
    final event = BiovoltEvent(
      id: id,
      timestamp: DateTime.now(),
      deviceId: _deviceId,
      type: type,
      payload: payload,
      schemaVersion: schemaVersion,
    );
    await _eventsBox.put(id, event);
    return event;
  }

  /// Events strictly after [cursorEventId], sorted by ULID (which is
  /// the same as chronological order). If [cursorEventId] is null,
  /// returns all events.
  Future<List<BiovoltEvent>> since(String? cursorEventId) async {
    final all = _eventsBox.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (cursorEventId == null) return all;
    return all.where((e) => e.id.compareTo(cursorEventId) > 0).toList();
  }

  /// Filtered read. [from] and [to] compare against [BiovoltEvent.timestamp]
  /// inclusively. [limit] caps the returned list length (oldest-first).
  ///
  /// [type] is kept for backward compatibility and is merged with [types]
  /// (union). Passing an empty [types] set is treated the same as passing
  /// null — it does not filter to "no events".
  ///
  /// [sources] filters by [BiovoltEvent.deviceId] — useful once the log
  /// contains events from more than one device/install.
  // PERF: in-memory filter over the full events box. Fine up to ~50k
  // events (~2.7 years at 50 events/day). Past that, add Hive indices or
  // a secondary chronological index keyed by timestamp buckets.
  Future<List<BiovoltEvent>> query({
    String? type,
    Set<String>? types,
    Set<String>? sources,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final typeFilter = <String>{
      ?type,
      if (types != null) ...types,
    };
    Iterable<BiovoltEvent> events = _eventsBox.values;
    if (typeFilter.isNotEmpty) {
      events = events.where((e) => typeFilter.contains(e.type));
    }
    if (sources != null && sources.isNotEmpty) {
      events = events.where((e) => sources.contains(e.deviceId));
    }
    if (from != null) {
      events = events.where((e) => !e.timestamp.isBefore(from));
    }
    if (to != null) {
      events = events.where((e) => !e.timestamp.isAfter(to));
    }
    final list = events.toList()..sort((a, b) => a.id.compareTo(b.id));
    if (limit != null && list.length > limit) {
      return list.sublist(0, limit);
    }
    return list;
  }

  /// Most recent event of [type] by ULID ordering, or null if none.
  Future<BiovoltEvent?> latest(String type) async {
    BiovoltEvent? best;
    for (final e in _eventsBox.values) {
      if (e.type != type) continue;
      if (best == null || e.id.compareTo(best.id) > 0) best = e;
    }
    return best;
  }

  Future<String> _nextMonotonicUlid() async {
    var id = Ulid().toString();
    // ULIDs share a timestamp prefix within the same millisecond; the
    // random suffix is not ordered. If a rapid-fire call lands in the
    // same ms as the previous append, yield to the event loop and try
    // again until the timestamp advances.
    var guard = 0;
    while (id.compareTo(_lastId) <= 0) {
      guard++;
      if (guard > 16) {
        // Give up trying to outpace the clock — pad the random tail to
        // force lex-gt. This should effectively never trigger outside
        // tight test loops.
        id = _bumpUlid(_lastId);
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
      id = Ulid().toString();
    }
    _lastId = id;
    return id;
  }

  /// Produce a ULID strictly greater than [prev] by copying its
  /// timestamp prefix and appending a lex-greater random tail.
  static String _bumpUlid(String prev) {
    // Keep first 10 chars (timestamp), regenerate last 16 with a
    // guaranteed-larger random tail by taking the max random suffix.
    final prefix = prev.substring(0, 10);
    final rand = Random.secure();
    // Crockford base32 lowercase alphabet used by the ulid package.
    const alphabet = '0123456789abcdefghjkmnpqrstvwxyz';
    final buf = StringBuffer();
    for (var i = 0; i < 16; i++) {
      buf.write(alphabet[rand.nextInt(alphabet.length)]);
    }
    final bumped = '$prefix${buf.toString()}';
    // If we were unlucky and still got lex-le, just append 'z' wrap.
    return bumped.compareTo(prev) > 0
        ? bumped
        : '$prefix${'z' * 16}';
  }
}
