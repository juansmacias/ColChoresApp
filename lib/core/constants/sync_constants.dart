abstract class SyncConstants {
  static const int maxRetryAttempts = 3;
  static const int retryBaseDelaySeconds = 1;
  // Exponential backoff: 1s, 4s, 16s
  static const int retryExponent = 4;
  static const int maxQueueSize = 1000;
  static const int queueWarningThreshold = 800;
  static const int syncBatchSize = 50;
  // Periodic sync interval in seconds (5 minutes)
  static const int periodicSyncIntervalSeconds = 300;
}
