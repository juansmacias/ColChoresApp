enum SyncStatus {
  synced,
  pending,
  conflict,
  failed,
}

enum SyncTrigger {
  appForeground,
  connectivityRestored,
  onlineWrite,
  firestoreListener,
  pullToRefresh,
}
