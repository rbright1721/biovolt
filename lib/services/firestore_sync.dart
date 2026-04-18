import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

class FirestoreSync {
  static final FirestoreSync _instance = FirestoreSync._();
  factory FirestoreSync() => _instance;
  FirestoreSync._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Returns null if not authenticated
  String? get _uid => _auth.currentUser?.uid;

  // Root reference for current user
  DocumentReference? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  CollectionReference? _collection(String name) {
    return _userDoc?.collection(name);
  }

  // ── Sync guard ─────────────────────────────────────
  // All sync operations are no-ops if not authenticated
  bool get canSync => _uid != null;

  // ── Full sync on login ─────────────────────────────
  // Call this after user signs in
  Future<void> syncAll(StorageService storage) async {
    if (!canSync) return;
    try {
      await Future.wait([
        syncProfile(storage),
        syncProtocols(storage),
        syncSessions(storage),
        syncJournal(storage),
        syncBloodwork(storage),
      ]);
      debugPrint('FirestoreSync: full sync complete');
    } catch (e) {
      debugPrint('FirestoreSync: sync error: $e');
      // Never throw — sync failures are non-fatal
    }
  }

  // ── Individual sync methods (stubs for now) ────────
  Future<void> syncProfile(StorageService storage) async {}
  Future<void> syncProtocols(StorageService storage) async {}
  Future<void> syncSessions(StorageService storage) async {}
  Future<void> syncJournal(StorageService storage) async {}
  Future<void> syncBloodwork(StorageService storage) async {}

  // ── Write helpers ──────────────────────────────────
  Future<void> _set(String collection, String docId,
      Map<String, dynamic> data) async {
    if (!canSync) return;
    try {
      await _collection(collection)
          ?.doc(docId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreSync._set error: $e');
    }
  }

  Future<void> _delete(String collection, String docId) async {
    if (!canSync) return;
    try {
      await _collection(collection)?.doc(docId).delete();
    } catch (e) {
      debugPrint('FirestoreSync._delete error: $e');
    }
  }
}
