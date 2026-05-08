import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import 'local_db_service.dart';

/// Listens for network connectivity changes and flushes any locally
/// stored journal entries, mood entries, and chat messages that have
/// not yet been synced to Firestore.
///
/// Call [SyncService.instance.init()] once at app startup (after Firebase
/// is ready) and the service handles everything automatically.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isSyncing = false;

  // Broadcast stream so UI can observe sync state
  final _syncStateController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get syncStateStream => _syncStateController.stream;
  SyncState _lastState = SyncState.idle;

  // ── Init ──────────────────────────────────
  Future<void> init() async {
    // Run an immediate sync attempt in case we are already online
    final results = await _connectivity.checkConnectivity();
    if (_isOnline(results)) {
      await _syncAll();
    }

    // Listen for subsequent connectivity changes
    _subscription =
        _connectivity.onConnectivityChanged.listen((results) {
      if (_isOnline(results)) {
        _syncAll();
      }
    });
  }

  // ── Dispose ───────────────────────────────
  void dispose() {
    _subscription?.cancel();
    _syncStateController.close();
  }

  // ── Manual trigger ────────────────────────
  Future<void> syncNow() => _syncAll();

  // ── Core sync logic ───────────────────────
  Future<void> _syncAll() async {
    if (_isSyncing) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _isSyncing = true;
    _emit(SyncState.syncing);

    int synced = 0;
    int failed = 0;

    try {
      // Sync journal entries
      final journals =
          await LocalDbService.instance.getUnsyncedJournals(uid);
      for (final entry in journals) {
        try {
          final docId = 'j_${uid}_${entry.id}';
          await _firestore
              .collection(AppConstants.colJournalEntries)
              .doc(docId)
              .set({
            ...entry.toFirestore(),
            'localId': entry.id,
            'syncedAt': FieldValue.serverTimestamp(),
          });
          await LocalDbService.instance.markJournalSynced(entry.id!);
          synced++;
        } catch (e) {
          failed++;
          debugPrint(
              '[SyncService] Failed to sync journal ${entry.id}: $e');
        }
      }

      // Sync mood entries
      final moods =
          await LocalDbService.instance.getUnsyncedMoods(uid);
      for (final entry in moods) {
        try {
          final docId = 'm_${uid}_${entry.id}';
          await _firestore
              .collection(AppConstants.colMoodEntries)
              .doc(docId)
              .set({
            ...entry.toFirestore(),
            'localId': entry.id,
            'syncedAt': FieldValue.serverTimestamp(),
          });
          await LocalDbService.instance.markMoodSynced(entry.id!);
          synced++;
        } catch (e) {
          failed++;
          debugPrint(
              '[SyncService] Failed to sync mood ${entry.id}: $e');
        }
      }

      // Sync meditation sessions
      final sessions =
          await LocalDbService.instance.getMeditationSessions(uid);
      final unsynced = sessions.where(
          (s) => s.completed && s.id != null);
      for (final session in unsynced) {
        try {
          final docId = 'med_${uid}_${session.id}';
          // Use set with merge so we don't overwrite if already synced
          final docRef = _firestore
              .collection(AppConstants.colMeditationSessions)
              .doc(docId);
          final existing = await docRef.get();
          if (!existing.exists) {
            await docRef.set({
              'userId': uid,
              'durationSeconds': session.durationSeconds,
              'type': session.type,
              'completed': session.completed,
              'completedAt': session.completedAt.toIso8601String(),
              'syncedAt': FieldValue.serverTimestamp(),
            });
            synced++;
          }
        } catch (e) {
          failed++;
          debugPrint(
              '[SyncService] Failed to sync meditation ${session.id}: $e');
        }
      }

      if (failed == 0) {
        _emit(SyncState.success(synced: synced));
      } else {
        _emit(SyncState.partialSuccess(synced: synced, failed: failed));
      }
    } catch (e) {
      debugPrint('[SyncService] Sync error: $e');
      _emit(SyncState.error(e.toString()));
    } finally {
      _isSyncing = false;
    }
  }

  void _emit(SyncState state) {
    _lastState = state;
    if (!_syncStateController.isClosed) {
      _syncStateController.add(state);
    }
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }

  SyncState get lastState => _lastState;
}

// ── Sync state ────────────────────────────────
abstract class SyncState {
  const SyncState();

  static const SyncState idle = SyncIdle();
  static const SyncState syncing = SyncInProgress();

  static SyncState success({required int synced}) =>
      SyncSuccess(synced: synced);

  static SyncState partialSuccess(
          {required int synced, required int failed}) =>
      SyncPartialSuccess(synced: synced, failed: failed);

  static SyncState error(String message) => SyncError(message);

  bool get isSyncing => this is SyncInProgress;
  bool get isError => this is SyncError;
  bool get isSuccess => this is SyncSuccess || this is SyncPartialSuccess;
}

class SyncIdle extends SyncState {
  const SyncIdle();
}

class SyncInProgress extends SyncState {
  const SyncInProgress();
}

class SyncSuccess extends SyncState {
  final int synced;
  const SyncSuccess({required this.synced});
}

class SyncPartialSuccess extends SyncState {
  final int synced;
  final int failed;
  const SyncPartialSuccess(
      {required this.synced, required this.failed});
}

class SyncError extends SyncState {
  final String message;
  const SyncError(this.message);
}
