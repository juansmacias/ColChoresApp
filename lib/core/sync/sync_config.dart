import '../constants/sync_constants.dart';

/// Sync engine configuration. All values sourced from [SyncConstants].
/// Static-only class — no instantiation needed.
abstract class SyncConfig {
  static const int maxRetryCount = SyncConstants.maxRetryAttempts;
  static const int retryBaseDelaySeconds = SyncConstants.retryBaseDelaySeconds;
  static const int retryBackoffFactor = SyncConstants.retryExponent;
  static const int maxQueueSize = SyncConstants.maxQueueSize;
  static const int queueWarningThreshold = SyncConstants.queueWarningThreshold;
  static const int periodicSyncIntervalSeconds =
      SyncConstants.periodicSyncIntervalSeconds;
  static const int batchSize = SyncConstants.syncBatchSize;

  /// Calculates retry delay for a given attempt number (0-indexed).
  /// attempt 0 → 1s, attempt 1 → 4s, attempt 2 → 16s
  static Duration retryDelay(int attemptNumber) {
    final seconds =
        retryBaseDelaySeconds * _pow(retryBackoffFactor, attemptNumber);
    return Duration(seconds: seconds);
  }

  static int _pow(int base, int exponent) {
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}
