import '../../core/network/connectivity_status.dart';
import '../../core/sync/sync_state.dart';

enum ConnectivityBannerType {
  hidden,
  offline,
  syncing,
  syncError,
}

class ConnectivityBannerState {
  factory ConnectivityBannerState.fromStates({
    required ConnectivityStatus connectivity,
    required SyncState syncState,
  }) {
    if (connectivity == ConnectivityStatus.offline) {
      return const ConnectivityBannerState(
        type: ConnectivityBannerType.offline,
        message: "You're offline. Changes will sync when you reconnect.",
      );
    }

    return switch (syncState) {
      SyncIdle() => const ConnectivityBannerState(
          type: ConnectivityBannerType.hidden,
        ),
      SyncSyncing() => const ConnectivityBannerState(
          type: ConnectivityBannerType.syncing,
        ),
      SyncSyncingWithErrors(:final pendingCount) => ConnectivityBannerState(
          type: ConnectivityBannerType.syncError,
          message: '$pendingCount items pending',
        ),
      SyncError(:final message) => ConnectivityBannerState(
          type: ConnectivityBannerType.syncError,
          message: message,
        ),
      SyncStopped() => const ConnectivityBannerState(
          type: ConnectivityBannerType.hidden,
        ),
    };
  }

  const ConnectivityBannerState({
    required this.type,
    this.message,
  });

  final ConnectivityBannerType type;
  final String? message;
}
