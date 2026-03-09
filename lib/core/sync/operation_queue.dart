import '../database/app_database.dart';

/// Manages the FIFO queue of pending sync operations.
/// Backed by the [SyncOperationsTable] Drift table.
abstract class OperationQueue {
  /// Adds a new operation to the queue.
  Future<void> enqueue(SyncOperationsTableData operation);

  /// Returns the next pending operation (oldest createdAt first).
  /// Returns null if queue is empty.
  Future<SyncOperationsTableData?> dequeueNext();

  /// Marks an operation as successfully completed.
  Future<void> markCompleted(int operationId);

  /// Marks an operation as in-progress (currently being synced).
  Future<void> markInProgress(int operationId);

  /// Increments retry count. If max retries exceeded, marks as failed.
  ///
  /// SE-FT-004: retryCount=0 → markRetry → count=1, status=pending
  /// SE-FT-005: retryCount=2 → markRetry → count=3, status=failed
  Future<void> markRetry(int operationId, String errorMessage);

  /// Marks an operation as permanently failed (no more retries).
  Future<void> markFailed(int operationId, String errorMessage);

  /// Count of operations with status="pending".
  Future<int> get pendingCount;

  /// Count of operations with status="failed".
  Future<int> get failedCount;

  /// All operations with status="failed" for user review.
  Future<List<SyncOperationsTableData>> getFailedOperations();

  /// Removes all operations with status="completed".
  Future<void> purgeCompleted();

  /// Resets any "inProgress" operations back to "pending".
  /// Called on engine start to recover from interrupted syncs (SE-FT-020).
  Future<void> recoverInterruptedOperations();

  /// True when pending count >= [SyncConfig.maxQueueSize].
  Future<bool> get isAtCapacity;
}
