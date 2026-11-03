import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/account_providers.dart';
import '../repositories/account_guard.dart';

enum SyncPhase { idle, syncing, synced, offline, failed }

class SyncState {
  const SyncState(this.phase, {this.message, this.lastSyncedAt});

  final SyncPhase phase;
  final String? message;
  final DateTime? lastSyncedAt;
}

/// Retries Firestore sync on startup/sign-in, app resume, network
/// restoration and every [interval] while the app is in the foreground.
/// Nothing syncs while the app is closed.
class SyncController extends StateNotifier<SyncState>
    with WidgetsBindingObserver {
  SyncController(this._ref) : super(const SyncState(SyncPhase.idle)) {
    WidgetsBinding.instance.addObserver(this);
    _connectivity = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) syncNow();
    });
    _timer = Timer.periodic(interval, (_) {
      if (_foreground) syncNow();
    });
    _ref.listen<String?>(currentUidProvider, (previous, next) {
      if (previous != next) {
        state = const SyncState(SyncPhase.idle);
        if (next != null) syncNow();
      }
    }, fireImmediately: true);
  }

  static const interval = Duration(seconds: 60);

  final Ref _ref;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Timer? _timer;
  bool _foreground = true;

  Future<void> syncNow() async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null || state.phase == SyncPhase.syncing) return;
    state = SyncState(SyncPhase.syncing, lastSyncedAt: state.lastSyncedAt);
    try {
      await _ref.read(progressRepositoryProvider).sync(uid);
      if (!mounted || _ref.read(currentUidProvider) != uid) return;
      state = SyncState(SyncPhase.synced, lastSyncedAt: DateTime.now());
    } on AccountChangedException {
      if (mounted) state = const SyncState(SyncPhase.idle);
    } on FirebaseException catch (error) {
      if (!mounted || _ref.read(currentUidProvider) != uid) return;
      state = switch (error.code) {
        'unavailable' || 'deadline-exceeded' => SyncState(
          SyncPhase.offline,
          message: 'Cloud unreachable. Will retry automatically.',
          lastSyncedAt: state.lastSyncedAt,
        ),
        'permission-denied' || 'unauthenticated' => SyncState(
          SyncPhase.failed,
          message: 'Cloud access denied. Sign out and sign in again.',
          lastSyncedAt: state.lastSyncedAt,
        ),
        _ => SyncState(
          SyncPhase.failed,
          message: 'Sync failed (${error.code}). Tap to retry.',
          lastSyncedAt: state.lastSyncedAt,
        ),
      };
    } on Object catch (error) {
      if (!mounted || _ref.read(currentUidProvider) != uid) return;
      state = SyncState(
        SyncPhase.failed,
        message: 'Sync failed: $error',
        lastSyncedAt: state.lastSyncedAt,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) syncNow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivity?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}

final syncControllerProvider = StateNotifierProvider<SyncController, SyncState>(
  (ref) => SyncController(ref),
);

/// User-facing sync label that never claims "Synced" with pending changes.
class SyncLabel {
  const SyncLabel(this.text, {this.isError = false, this.canRetry = false});

  final String text;
  final bool isError;
  final bool canRetry;
}

final syncLabelProvider = Provider<SyncLabel>((ref) {
  final sync = ref.watch(syncControllerProvider);
  final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
  switch (sync.phase) {
    case SyncPhase.syncing:
      return const SyncLabel('Syncing…');
    case SyncPhase.failed:
      return SyncLabel(
        sync.message ?? 'Sync failed. Tap to retry.',
        isError: true,
        canRetry: true,
      );
    case SyncPhase.offline:
      return SyncLabel(
        pending > 0
            ? 'Waiting to sync ($pending saved on this device)'
            : 'Saved on this device · offline',
        canRetry: true,
      );
    case SyncPhase.synced:
      return pending > 0
          ? SyncLabel('Waiting to sync ($pending)', canRetry: true)
          : const SyncLabel('Synced');
    case SyncPhase.idle:
      return pending > 0
          ? SyncLabel('Waiting to sync ($pending)', canRetry: true)
          : const SyncLabel('Saved on this device', canRetry: true);
  }
});
