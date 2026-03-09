import 'models/conflict_result.dart';

/// Individual sync events emitted for UI consumption.
sealed class SyncEvent {
  const SyncEvent();

  const factory SyncEvent.operationCompleted({
    required String entityType,
    required String entityId,
  }) = SyncOperationCompleted;

  const factory SyncEvent.operationFailed({
    required String entityType,
    required String entityId,
    required String error,
  }) = SyncOperationFailed;

  const factory SyncEvent.conflictResolved({
    required String entityType,
    required String entityId,
    required ConflictWinner winner,
  }) = SyncConflictResolved;

  const factory SyncEvent.syncPausedOffline({
    required int remainingOperations,
  }) = SyncPausedOffline;

  const factory SyncEvent.queueNearCapacity({
    required int pendingCount,
  }) = SyncQueueNearCapacity;

  const factory SyncEvent.queueFull({
    required int pendingCount,
  }) = SyncQueueFull;

  const factory SyncEvent.pullError({
    required String entityType,
    required String error,
  }) = SyncPullError;

  const factory SyncEvent.authRequired() = SyncAuthRequired;
}

final class SyncOperationCompleted extends SyncEvent {
  const SyncOperationCompleted({
    required this.entityType,
    required this.entityId,
  });
  final String entityType;
  final String entityId;
}

final class SyncOperationFailed extends SyncEvent {
  const SyncOperationFailed({
    required this.entityType,
    required this.entityId,
    required this.error,
  });
  final String entityType;
  final String entityId;
  final String error;
}

final class SyncConflictResolved extends SyncEvent {
  const SyncConflictResolved({
    required this.entityType,
    required this.entityId,
    required this.winner,
  });
  final String entityType;
  final String entityId;
  final ConflictWinner winner;
}

final class SyncPausedOffline extends SyncEvent {
  const SyncPausedOffline({required this.remainingOperations});
  final int remainingOperations;
}

final class SyncQueueNearCapacity extends SyncEvent {
  const SyncQueueNearCapacity({required this.pendingCount});
  final int pendingCount;
}

final class SyncQueueFull extends SyncEvent {
  const SyncQueueFull({required this.pendingCount});
  final int pendingCount;
}

final class SyncPullError extends SyncEvent {
  const SyncPullError({required this.entityType, required this.error});
  final String entityType;
  final String error;
}

final class SyncAuthRequired extends SyncEvent {
  const SyncAuthRequired();
}
