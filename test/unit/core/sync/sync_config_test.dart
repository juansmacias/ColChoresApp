import 'package:family_chores_app/core/sync/sync_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncConfig', () {
    test('retryDelay follows exponential backoff', () {
      expect(SyncConfig.retryDelay(0), const Duration(seconds: 1));
      expect(SyncConfig.retryDelay(1), const Duration(seconds: 4));
      expect(SyncConfig.retryDelay(2), const Duration(seconds: 16));
    });

    test('queue warning threshold stays below max queue size', () {
      expect(
        SyncConfig.queueWarningThreshold,
        lessThan(SyncConfig.maxQueueSize),
      );
    });
  });
}
