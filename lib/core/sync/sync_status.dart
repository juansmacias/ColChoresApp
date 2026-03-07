/// Sync status of a local entity (used in Drift table columns).
enum SyncStatus {
  synced,
  pending,
  conflict,
  failed,
}

/// Events that trigger a sync cycle.
enum SyncTrigger {
  appForeground,
  connectivityRestored,
  onlineWrite,
  firestoreListener,
  pullToRefresh,
  periodic,
}
