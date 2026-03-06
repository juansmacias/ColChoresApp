import 'package:injectable/injectable.dart';

import '../constants/sync_constants.dart';

@singleton
class SyncConfig {
  const SyncConfig({
    this.maxRetryAttempts = SyncConstants.maxRetryAttempts,
    this.retryBaseDelaySeconds = SyncConstants.retryBaseDelaySeconds,
    this.maxQueueSize = SyncConstants.maxQueueSize,
    this.batchSize = SyncConstants.syncBatchSize,
  });

  final int maxRetryAttempts;
  final int retryBaseDelaySeconds;
  final int maxQueueSize;
  final int batchSize;

  Duration retryDelay(int attempt) => Duration(
        seconds: retryBaseDelaySeconds *
            (SyncConstants.retryExponent * attempt).clamp(1, 60),
      );
}
