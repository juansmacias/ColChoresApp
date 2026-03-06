import 'package:injectable/injectable.dart';

import 'sync_config.dart';
import 'sync_status.dart';

// TODO(phase-1): Full implementation per specs/03_sync_engine.md
@singleton
class SyncEngine {
  SyncEngine(this._config);

  // ignore: unused_field — will be used in phase-1 implementation
  final SyncConfig _config;

  Future<void> trigger(SyncTrigger trigger) async {
    // TODO(phase-1): Push pending operations, then pull remote changes
  }

  Future<void> processPendingOperations() async {
    // TODO(phase-1): Dequeue and execute pending sync operations
  }
}
