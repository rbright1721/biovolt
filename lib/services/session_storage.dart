import '../models/session.dart';
import 'storage_service.dart';

/// Thin wrapper around [StorageService] for session operations.
///
/// Preserves the existing interface used by [SessionBloc] and [BioVoltApp]
/// while delegating all persistence to the unified [StorageService].
class SessionStorage {
  final StorageService _storage;

  SessionStorage(this._storage);

  Future<void> saveSession(Session session) => _storage.saveSession(session);

  List<Session> getAllSessions() => _storage.getAllSessions();

  Session? getSession(String id) => _storage.getSession(id);

  Future<void> deleteSession(String id) => _storage.deleteSession(id);

  Future<void> clear() => _storage.clearAll();
}
