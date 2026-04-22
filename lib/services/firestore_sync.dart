import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/active_protocol.dart';
import '../models/ai_analysis.dart';
import '../models/bloodwork.dart';
import '../models/health_journal_entry.dart';
import '../models/log_entry.dart';
import '../models/session.dart';
import '../models/vitals_bookmark.dart';
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
        syncBookmarks(storage),
        syncLogEntries(storage),
      ]);
      debugPrint('FirestoreSync: full sync complete');
    } catch (e) {
      debugPrint('FirestoreSync: sync error: $e');
      // Never throw — sync failures are non-fatal
    }
  }

  // ── Individual sync methods ────────────────────────
  Future<void> syncProfile(StorageService storage) async {
    if (!canSync) return;
    try {
      final profile = storage.getUserProfile();
      if (profile == null) return;

      await _set('meta', 'profile', {
        'userId': profile.userId,
        'biologicalSex': profile.biologicalSex,
        'dateOfBirth': profile.dateOfBirth?.toIso8601String(),
        'heightCm': profile.heightCm,
        'weightKg': profile.weightKg,
        'healthGoals': profile.healthGoals,
        'knownConditions': profile.knownConditions,
        'mthfr': profile.mthfr,
        'apoe': profile.apoe,
        'comt': profile.comt,
        'fastingType': profile.fastingType,
        'eatWindowStartHour': profile.eatWindowStartHour,
        'eatWindowEndHour': profile.eatWindowEndHour,
        'lastMealTime': profile.lastMealTime?.toIso8601String(),
        'aiCoachingStyle': profile.aiCoachingStyle,
        'syncedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('FirestoreSync: profile synced');
    } catch (e) {
      debugPrint('FirestoreSync.syncProfile error: $e');
    }
  }

  Future<void> syncProtocols(StorageService storage) async {
    if (!canSync) return;
    try {
      final protocols = storage.getAllActiveProtocols();

      for (final p in protocols) {
        await _set('protocols', p.id, {
          'id': p.id,
          'name': p.name,
          'type': p.type,
          'doseMcg': p.doseMcg,
          'route': p.route,
          'startDate': p.startDate.toIso8601String(),
          'cycleLengthDays': p.cycleLengthDays,
          'notes': p.notes,
          'currentCycleDay': p.currentCycleDay,
          'isOngoing':
              p.cycleLengthDays == 0 || p.cycleLengthDays == 365,
          'syncedAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint(
          'FirestoreSync: ${protocols.length} protocols synced');
    } catch (e) {
      debugPrint('FirestoreSync.syncProtocols error: $e');
    }
  }

  // Write-through for a single protocol save/update
  Future<void> writeProtocol(ActiveProtocol protocol) async {
    if (!canSync) return;
    await _set('protocols', protocol.id, {
      'id': protocol.id,
      'name': protocol.name,
      'type': protocol.type,
      'doseMcg': protocol.doseMcg,
      'route': protocol.route,
      'startDate': protocol.startDate.toIso8601String(),
      'cycleLengthDays': protocol.cycleLengthDays,
      'notes': protocol.notes,
      'currentCycleDay': protocol.currentCycleDay,
      'isOngoing': protocol.cycleLengthDays == 0 ||
          protocol.cycleLengthDays == 365,
      'syncedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProtocol(String protocolId) async {
    await _delete('protocols', protocolId);
  }

  Future<void> syncSessions(StorageService storage) async {
    if (!canSync) return;
    try {
      final sessions = storage.getAllSessions();
      // Only sync last 30 sessions to keep Firestore lean
      final toSync = sessions.take(30).toList();

      for (final s in toSync) {
        await _writeSession(s, storage);
      }

      debugPrint(
          'FirestoreSync: ${toSync.length} sessions synced');
    } catch (e) {
      debugPrint('FirestoreSync.syncSessions error: $e');
    }
  }

  Future<void> _writeSession(
      Session session, StorageService storage) async {
    if (!canSync) return;

    final map = <String, dynamic>{
      'sessionId': session.sessionId,
      'createdAt': session.createdAt.toIso8601String(),
      'userId': session.userId,
      'durationSeconds': session.durationSeconds,
      'dataSources': session.dataSources,
      'syncedAt': FieldValue.serverTimestamp(),
    };

    final ctx = session.context;
    if (ctx != null) {
      map['context'] = {
        'activities': ctx.activities
            .map((a) => {
                  'type': a.type,
                  'subtype': a.subtype,
                  'startOffsetSeconds': a.startOffsetSeconds,
                  'durationSeconds': a.durationSeconds,
                })
            .toList(),
        'fastingHours': ctx.fastingHours,
        'timeSinceWakeHours': ctx.timeSinceWakeHours,
        'sleepLastNightHours': ctx.sleepLastNightHours,
        'stressContext': ctx.stressContext,
        'notes': ctx.notes,
      };
    }

    final computed = session.biometrics?.computed;
    if (computed != null) {
      map['biometrics'] = {
        'heartRateMeanBpm': computed.heartRateMeanBpm,
        'heartRateMinBpm': computed.heartRateMinBpm,
        'heartRateMaxBpm': computed.heartRateMaxBpm,
        'hrvRmssdMs': computed.hrvRmssdMs,
        'coherenceScore': computed.coherenceScore,
        'lfHfProxy': computed.lfHfProxy,
        'hrSource': computed.hrSource,
        'hrvSource': computed.hrvSource,
      };
    }

    final esp32 = session.biometrics?.esp32;
    if (esp32 != null) {
      map['esp32'] = {
        'heartRateBpm': esp32.heartRateBpm,
        'hrvRmssdMs': esp32.hrvRmssdMs,
        'gsrMeanUs': esp32.gsrMeanUs,
        'gsrBaselineShiftUs': esp32.gsrBaselineShiftUs,
        'skinTempC': esp32.skinTempC,
        'spo2Percent': esp32.spo2Percent,
      };
    }

    final subj = session.subjective;
    if (subj != null) {
      final pre = subj.preSession;
      final post = subj.postSession;
      map['subjective'] = {
        'preMood': pre?.mood,
        'preEnergy': pre?.energy,
        'preAnxiety': pre?.anxiety,
        'preCalm': pre?.calm,
        'preFocus': pre?.focus,
        'postMood': post?.mood,
        'postEnergy': post?.energy,
        'postAnxiety': post?.anxiety,
        'postCalm': post?.calm,
        'postFocus': post?.focus,
        'sessionQuality': post?.sessionQuality,
        'postNotes': post?.notes,
      };
    }

    await _set('sessions', session.sessionId, map);

    // Also sync AI analysis if it exists
    final analysis = storage.getAiAnalysis(session.sessionId);
    if (analysis != null) {
      await _writeAiAnalysis(analysis);
    }
  }

  Future<void> _writeAiAnalysis(AiAnalysis analysis) async {
    if (!canSync) return;
    try {
      await _set('ai_analysis', analysis.sessionId, {
        'sessionId': analysis.sessionId,
        'generatedAt': analysis.generatedAt.toIso8601String(),
        'provider': analysis.provider,
        'model': analysis.model,
        'promptVersion': analysis.promptVersion,
        'insights': analysis.insights,
        'anomalies': analysis.anomalies,
        'correlationsDetected': analysis.correlationsDetected,
        'protocolRecommendations': analysis.protocolRecommendations,
        'flags': analysis.flags,
        'trendSummary': analysis.trendSummary,
        'confidence': analysis.confidence,
        'ouraContextUsed': analysis.ouraContextUsed,
        'syncedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FirestoreSync._writeAiAnalysis error: $e');
    }
  }

  // Public write-through entry points
  Future<void> writeSession(
      Session session, StorageService storage) async {
    await _writeSession(session, storage);
  }

  Future<void> writeAiAnalysis(AiAnalysis analysis) async {
    await _writeAiAnalysis(analysis);
  }

  Future<void> deleteSession(String sessionId) async {
    await _delete('sessions', sessionId);
    await _delete('ai_analysis', sessionId);
  }

  Future<void> syncJournal(StorageService storage) async {
    if (!canSync) return;
    try {
      final entries = storage.getAllJournalEntries();
      final toSync = entries.take(100).toList();

      for (final e in toSync) {
        await _writeJournalEntry(e);
      }

      debugPrint(
          'FirestoreSync: ${toSync.length} journal entries synced');
    } catch (e) {
      debugPrint('FirestoreSync.syncJournal error: $e');
    }
  }

  Future<void> _writeJournalEntry(HealthJournalEntry entry) async {
    if (!canSync) return;
    try {
      await _set('journal', entry.id, {
        'id': entry.id,
        'timestamp': entry.timestamp.toIso8601String(),
        'conversationId': entry.conversationId,
        'userMessage': entry.userMessage,
        'aiResponse': entry.aiResponse,
        'bookmarked': entry.bookmarked,
        'autoTags': entry.autoTags,
        'researchGrounded': entry.researchGrounded,
        'sessionId': entry.sessionId,
        'hrBpm': entry.hrBpm,
        'hrvMs': entry.hrvMs,
        'gsrUs': entry.gsrUs,
        'skinTempF': entry.skinTempF,
        'spo2Percent': entry.spo2Percent,
        'syncedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FirestoreSync._writeJournalEntry error: $e');
    }
  }

  Future<void> writeJournalEntry(HealthJournalEntry entry) async {
    await _writeJournalEntry(entry);
  }

  Future<void> syncBloodwork(StorageService storage) async {
    if (!canSync) return;
    try {
      final panels = storage.getAllBloodwork();
      for (final b in panels) {
        await _writeBloodwork(b);
      }
      debugPrint(
          'FirestoreSync: ${panels.length} bloodwork panels synced');
    } catch (e) {
      debugPrint('FirestoreSync.syncBloodwork error: $e');
    }
  }

  Future<void> _writeBloodwork(Bloodwork bloodwork) async {
    if (!canSync) return;
    try {
      final map = bloodwork.toJson();
      map['syncedAt'] = FieldValue.serverTimestamp();
      await _set('bloodwork', bloodwork.id, map);
    } catch (e) {
      debugPrint('FirestoreSync._writeBloodwork error: $e');
    }
  }

  Future<void> writeBloodwork(Bloodwork bloodwork) async {
    await _writeBloodwork(bloodwork);
  }

  Future<void> deleteBloodwork(String id) async {
    await _delete('bloodwork', id);
  }

  Future<void> syncBookmarks(StorageService storage) async {
    if (!canSync) return;
    try {
      final bookmarks = storage.getAllBookmarks();
      for (final b in bookmarks) {
        await _set('bookmarks', b.id, {
          'id': b.id,
          'timestamp': b.timestamp.toIso8601String(),
          'note': b.note,
          'hrBpm': b.hrBpm,
          'hrvMs': b.hrvMs,
          'gsrUs': b.gsrUs,
          'skinTempF': b.skinTempF,
          'spo2Percent': b.spo2Percent,
          'ecgHrBpm': b.ecgHrBpm,
          'syncedAt': FieldValue.serverTimestamp(),
        });
      }
      debugPrint(
          'FirestoreSync: ${bookmarks.length} bookmarks synced');
    } catch (e) {
      debugPrint('FirestoreSync.syncBookmarks error: $e');
    }
  }

  Future<void> writeBookmark(VitalsBookmark bookmark) async {
    if (!canSync) return;
    await _set('bookmarks', bookmark.id, {
      'id': bookmark.id,
      'timestamp': bookmark.timestamp.toIso8601String(),
      'note': bookmark.note,
      'hrBpm': bookmark.hrBpm,
      'hrvMs': bookmark.hrvMs,
      'gsrUs': bookmark.gsrUs,
      'skinTempF': bookmark.skinTempF,
      'spo2Percent': bookmark.spo2Percent,
      'ecgHrBpm': bookmark.ecgHrBpm,
      'syncedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Log entries ───────────────────────────────────
  // Raw user observations captured via the Quick Log pill on the
  // dashboard. Written to `users/{uid}/log_entries/{id}`. The
  // classifier Cloud Function (Part 2) reads from this same path.

  Future<void> syncLogEntries(StorageService storage) async {
    if (!canSync) return;
    try {
      final entries = storage.getAllLogEntries();
      for (final e in entries) {
        await _set('log_entries', e.id, _logEntryPayload(e));
      }
      debugPrint(
          'FirestoreSync: ${entries.length} log entries synced');
    } catch (e) {
      debugPrint('FirestoreSync.syncLogEntries error: $e');
    }
  }

  Future<void> writeLogEntry(LogEntry entry) async {
    if (!canSync) return;
    await _set('log_entries', entry.id, _logEntryPayload(entry));
  }

  Future<void> deleteLogEntry(String id) async {
    await _delete('log_entries', id);
  }

  Map<String, dynamic> _logEntryPayload(LogEntry e) =>
      buildLogEntryFirestorePayload(e);

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

/// Builds the Firestore document body for a [LogEntry].
///
/// Pulled out of the [FirestoreSync] class so tests can assert the
/// field shape without constructing the [FirestoreSync] singleton,
/// whose `_auth` field would access [FirebaseAuth.instance] during
/// initialization and crash without a Firebase test harness.
Map<String, dynamic> buildLogEntryFirestorePayload(LogEntry e) => {
      'id': e.id,
      'occurredAt': e.occurredAt.toIso8601String(),
      'loggedAt': e.loggedAt.toIso8601String(),
      'rawText': e.rawText,
      'rawAudioPath': e.rawAudioPath,
      'type': e.type,
      'structured': e.structured,
      'classificationConfidence': e.classificationConfidence,
      'classificationStatus': e.classificationStatus,
      'classificationError': e.classificationError,
      'classificationAttempts': e.classificationAttempts,
      'hrBpm': e.hrBpm,
      'hrvMs': e.hrvMs,
      'gsrUs': e.gsrUs,
      'skinTempF': e.skinTempF,
      'spo2Percent': e.spo2Percent,
      'ecgHrBpm': e.ecgHrBpm,
      'protocolIdAtTime': e.protocolIdAtTime,
      'tags': e.tags,
      'userNotes': e.userNotes,
      'syncedAt': FieldValue.serverTimestamp(),
    };
