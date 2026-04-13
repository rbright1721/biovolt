import 'package:hive_flutter/hive_flutter.dart';
import '../models/session.dart';

class SessionStorage {
  static const _boxName = 'sessions';
  Box<Session>? _box;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(SessionTypeAdapter());
    Hive.registerAdapter(SensorSnapshotAdapter());
    Hive.registerAdapter(SessionAdapter());
    _box = await Hive.openBox<Session>(_boxName);
  }

  Future<void> saveSession(Session session) async {
    await _box?.put(session.id, session);
  }

  List<Session> getAllSessions() {
    if (_box == null) return [];
    final sessions = _box!.values.toList();
    sessions.sort((a, b) => b.startTimeMs.compareTo(a.startTimeMs));
    return sessions;
  }

  Session? getSession(String id) => _box?.get(id);

  Future<void> deleteSession(String id) async {
    await _box?.delete(id);
  }

  Future<void> clear() async {
    await _box?.clear();
  }
}
