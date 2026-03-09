import 'dart:isolate';

/// Manages a dedicated isolate for sync processing.
///
/// Phase 1: Uses [Isolate.run] for individual sync batches.
/// Phase 3: Upgrades to a long-lived isolate with SendPort/ReceivePort
///          for real-time Firestore listener integration.
///
/// See specs/03_sync_engine.md Section 4.5.
class SyncIsolateManager {
  Isolate? _isolate;
  final _receivePort = ReceivePort();

  bool get isRunning => _isolate != null;

  /// Spawns the sync isolate. Not yet used in Phase 1.
  Future<void> spawn() async {
    // Phase 3 implementation: spawn long-lived isolate with DB + Firestore.
    throw UnimplementedError(
      'Long-lived sync isolate is a Phase 3 feature. '
      'Use SyncEngineImpl directly in Phase 1.',
    );
  }

  /// Kills the sync isolate and closes the receive port.
  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort.close();
  }
}
