import '../enums/operation_type.dart';
import 'sync_event.dart';
import 'sync_state.dart';

/// The main sync engine interface.
/// Orchestrates operation queue processing, conflict resolution,
/// and connectivity-aware sync triggers.
abstract class SyncEngine {
  /// Starts the sync engine. Begins listening for triggers.
  /// Must be called after DI initialization and authentication.
  Future<void> start();

  /// Stops the sync engine. Detaches all listeners.
  /// Called on logout or app termination.
  Future<void> stop();

  /// Triggers an immediate full sync (push pending + pull remote).
  Future<void> syncNow();

  /// Enqueues a sync operation for a local write.
  /// Called by repository implementations after every local write.
  /// When online, also triggers an immediate push of this operation.
  Future<void> enqueueOperation({
    required String entityType,
    required String entityId,
    required OperationType operationType,
    required String payload,
  });

  /// Stream of high-level sync state changes.
  Stream<SyncState> get stateStream;

  /// Stream of individual sync events (for UI notifications).
  Stream<SyncEvent> get eventStream;

  /// Current sync state snapshot.
  SyncState get currentState;

  /// Number of pending operations in the queue.
  Future<int> get pendingOperationCount;
}
