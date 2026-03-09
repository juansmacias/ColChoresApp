/// High-level sync engine state, emitted on the state stream.
sealed class SyncState {
  const SyncState();

  const factory SyncState.idle() = SyncIdle;
  const factory SyncState.syncing() = SyncSyncing;
  const factory SyncState.syncingWithErrors({required int pendingCount}) =
      SyncSyncingWithErrors;
  const factory SyncState.error({required String message}) = SyncError;
  const factory SyncState.stopped() = SyncStopped;
}

final class SyncIdle extends SyncState {
  const SyncIdle();
}

final class SyncSyncing extends SyncState {
  const SyncSyncing();
}

final class SyncSyncingWithErrors extends SyncState {
  const SyncSyncingWithErrors({required this.pendingCount});
  final int pendingCount;
}

final class SyncError extends SyncState {
  const SyncError({required this.message});
  final String message;
}

final class SyncStopped extends SyncState {
  const SyncStopped();
}
