abstract class SyncConstants {
  static const int maxRetryAttempts = 3;
  static const int retryBaseDelaySeconds = 1;
  // Exponential backoff: 1s, 4s, 16s
  static const int retryExponent = 4;
  static const int maxQueueSize = 500;
  static const int syncBatchSize = 50;
}
