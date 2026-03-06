# Sync Engine

## 1. Overview

### 1.1 Summary

This specification defines the sync engine -- the most architecturally significant component of the Family Chores App. The sync engine mediates all data flow between the local Isar database and Firebase Firestore, enabling the offline-first experience. It comprises three sub-components: the OperationQueue (FIFO processing of local writes), the ConflictResolver (Last-Write-Wins with audit trail), and the SyncOrchestrator (trigger management, push/pull coordination, isolate execution).

### 1.2 Business Context

The offline-first constraint is non-negotiable (see `specs/00_project_foundation.md` Section 1.2). Families use the app in locations with unreliable connectivity. Every user action must succeed instantly from local state, with background synchronization that is invisible when working correctly and informative when encountering issues. The sync engine is what makes "works without internet" possible while ensuring multi-device consistency.

### 1.3 Scope

**In scope:**
- SyncOperation entity processing (FIFO queue)
- Retry logic with exponential backoff (1s, 4s, 16s)
- Queue capacity management (1000 operation cap)
- Conflict detection and LWW resolution using Firestore server timestamps
- Delete-wins-over-edit conflict rule
- Audit log creation for losing writes
- Sync trigger management (foreground, connectivity, online write, listener, refresh, periodic)
- Partial failure handling
- Isolate-based execution (sync never blocks UI)
- Public API for starting, stopping, and monitoring sync

**Out of scope:**
- Firestore security rules (defined in `specs/00_project_foundation.md` Section 4.7)
- Cloud Functions for server-side processing (Phase 2+)
- Photo upload sync (Phase 4)
- Specific entity serialization (repository responsibility)

### 1.4 References

- `specs/00_project_foundation.md` -- Section 4.4 (Sync Engine Detailed Design)
- `specs/02_isar_schemas.md` -- SyncOperationEntity, sync metadata fields
- `specs/04_connectivity_monitor.md` -- ConnectivityService interface
- `specs/06_error_handling.md` -- SyncFailure, ConflictFailure types

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| SE-001 | Every local write creates a SyncOperation | High | After any entity create/update/delete via repository, a SyncOperationEntity exists in the queue with status="pending" |
| SE-002 | Operations are processed FIFO | High | The oldest pending operation is always processed before newer ones |
| SE-003 | Failed operations retry with exponential backoff | High | Retry intervals are 1s, 4s, 16s. After 3 failures, status="failed" |
| SE-004 | Queue cap at 1000 operations | Medium | When queue reaches 1000, user is alerted. Oldest completed ops are purged first. |
| SE-005 | LWW conflict resolution uses server timestamps | High | When local updatedAt < remote updatedAt, remote wins. Losing write goes to audit log. |
| SE-006 | Delete wins over edit in conflicts | High | If one device deletes and another edits the same entity offline, the delete prevails |
| SE-007 | Audit log preserves losing writes | High | Every conflict resolution creates an audit_log entry with before/after state, performer, device, timestamp |
| SE-008 | Sync triggers fire on correct events | High | Sync activates on: app foreground, connectivity restored, online write, Firestore listener, pull-to-refresh, 5-min periodic |
| SE-009 | Partial failures don't block successful operations | High | If 8/10 operations succeed, those 8 are marked completed. The 2 failures remain pending. |
| SE-010 | Sync runs in a separate isolate | High | UI frame rate is unaffected during sync. Sync operations never execute on the main isolate. |
| SE-011 | Sync status is observable via stream | High | A stream of SyncStatus emits: idle, syncing, error, syncingWithErrors |
| SE-012 | Sync events are observable via stream | Medium | Individual events (operationCompleted, conflictResolved, operationFailed) are emitted for UI consumption |
| SE-013 | Sync engine can be started and stopped | Medium | Engine does not sync when stopped (e.g., during logout) |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| SE-NFR-001 | Sync latency | Time from connectivity restored to queue cleared | < 5 seconds for 50 operations (per NFR-002 of foundation spec) |
| SE-NFR-002 | UI impact during sync | Frame drops on main isolate | Zero dropped frames caused by sync |
| SE-NFR-003 | Battery impact | Sync frequency when backgrounded | Zero background syncs (per NFR-005 of foundation spec) |
| SE-NFR-004 | Data integrity | Writes lost during sync | Zero. Every write is either synced or preserved in the failed queue. |

### 2.3 Assumptions

- Firestore is the remote source of truth. Server timestamps are authoritative for conflict resolution.
- The sync engine does not handle authentication. It assumes a valid Firebase Auth session exists. If auth expires, the engine pauses and emits an event (handled by the auth layer).
- Entity serialization to/from Firestore documents is handled by repository-level mappers, not the sync engine itself.
- The sync engine processes operations for all entity types through a unified pipeline. Type-specific logic (e.g., task vs. reward) is encapsulated in the serializers passed to the engine.

### 2.4 Constraints

- No background execution. Sync only runs while the app is in the foreground (per NFR-005).
- No polling. The engine uses Firestore real-time listeners when online, not periodic HTTP requests.
- Operations are atomic per-entity. There are no multi-entity transactions in the sync queue (Firestore batch writes are used at the transport level, not the queue level).

---

## 3. Architecture

### 3.1 Component Diagram

```
+-----------------------------------------------------------------------+
|                           SyncEngine                                   |
|  (Orchestrator -- coordinates all sync sub-components)                 |
|                                                                        |
|  +-------------------+  +--------------------+  +-------------------+  |
|  |  OperationQueue   |  |  ConflictResolver  |  |  SyncStatus       |  |
|  |                   |  |                    |  |  Manager          |  |
|  |  - enqueue()      |  |  - resolve()       |  |  - statusStream   |  |
|  |  - dequeueNext()  |  |  - createAuditLog()|  |  - eventStream    |  |
|  |  - markCompleted()|  |                    |  |  - currentStatus  |  |
|  |  - markFailed()   |  +--------------------+  +-------------------+  |
|  |  - retryCount()   |                                                 |
|  |  - pendingCount() |                                                 |
|  +-------------------+                                                 |
|                                                                        |
|  Dependencies:                                                         |
|  - ConnectivityService (from specs/04_connectivity_monitor.md)         |
|  - Isar instance (for SyncOperationEntity and entity collections)      |
|  - Firestore instance (for remote reads/writes)                        |
|  - EntitySyncAdapters (type-specific serializers, per entity type)     |
+-----------------------------------------------------------------------+
         |                    |                     |
         v                    v                     v
  +-------------+    +----------------+    +------------------+
  | Isar (Local)|    | Firestore      |    | ConnectivitySvc  |
  | Database    |    | (Remote)       |    | (Network state)  |
  +-------------+    +----------------+    +------------------+
```

### 3.2 Class Interfaces

```dart
// lib/core/sync/sync_engine.dart

/// The main sync engine orchestrator.
/// Coordinates operation queue processing, conflict resolution,
/// and connectivity-aware sync triggers.
abstract class SyncEngine {
  /// Starts the sync engine. Begins listening for triggers.
  /// Must be called after DI initialization and authentication.
  Future<void> start();

  /// Stops the sync engine. Detaches all listeners.
  /// Called on logout or app termination.
  Future<void> stop();

  /// Triggers an immediate full sync (push pending + pull remote).
  /// Used for pull-to-refresh and manual sync.
  Future<void> syncNow();

  /// Enqueues a sync operation for a local write.
  /// Called by repository implementations after every local write.
  Future<void> enqueueOperation({
    required String entityType,
    required String entityId,
    required OperationType operationType,
    required String payload,
  });

  /// Stream of high-level sync status changes.
  Stream<SyncState> get stateStream;

  /// Stream of individual sync events (for UI notifications).
  Stream<SyncEvent> get eventStream;

  /// Current sync state snapshot.
  SyncState get currentState;

  /// Number of pending operations in the queue.
  Future<int> get pendingOperationCount;
}
```

```dart
// lib/core/sync/operation_queue.dart

/// Manages the FIFO queue of pending sync operations.
/// Backed by the SyncOperationEntity Isar collection.
abstract class OperationQueue {
  /// Adds a new operation to the queue.
  Future<void> enqueue(SyncOperationEntity operation);

  /// Returns the next pending operation (oldest first).
  /// Returns null if queue is empty.
  Future<SyncOperationEntity?> dequeueNext();

  /// Marks an operation as successfully completed and removes it.
  Future<void> markCompleted(int operationId);

  /// Marks an operation as in-progress (being synced).
  Future<void> markInProgress(int operationId);

  /// Increments retry count. If max retries exceeded, marks as failed.
  Future<void> markRetry(int operationId, String errorMessage);

  /// Marks an operation as permanently failed.
  Future<void> markFailed(int operationId, String errorMessage);

  /// Returns the count of pending operations.
  Future<int> get pendingCount;

  /// Returns the count of failed operations.
  Future<int> get failedCount;

  /// Returns all failed operations for user review.
  Future<List<SyncOperationEntity>> getFailedOperations();

  /// Removes all completed operations (cleanup).
  Future<void> purgeCompleted();

  /// Returns true if the queue has reached capacity.
  Future<bool> get isAtCapacity;
}
```

```dart
// lib/core/sync/conflict_resolver.dart

/// Resolves conflicts between local and remote entity states
/// using Last-Write-Wins (LWW) with audit trail.
abstract class ConflictResolver {
  /// Compares local and remote states and determines the winner.
  ///
  /// Returns a [ConflictResult] indicating:
  /// - Which version won (local or remote)
  /// - The audit log entry for the losing write
  ///
  /// Conflict rules (from specs/00_project_foundation.md Section 4.4.2):
  /// 1. Compare updatedAt timestamps: later timestamp wins.
  /// 2. Tie: remote wins (server is authoritative).
  /// 3. Delete vs. edit: delete always wins.
  ConflictResult resolve({
    required Map<String, dynamic> localState,
    required Map<String, dynamic> remoteState,
    required DateTime localUpdatedAt,
    required DateTime remoteUpdatedAt,
    required bool localIsDelete,
    required bool remoteIsDelete,
  });

  /// Creates an audit log entry in the Firestore audit_log subcollection.
  Future<void> createAuditLogEntry({
    required String familyId,
    required String entityType,
    required String entityId,
    required Map<String, dynamic>? beforeState,
    required Map<String, dynamic>? afterState,
    required String performedBy,
    required String deviceId,
  });
}
```

---

## 4. Detailed Design

### 4.1 Operation Queue Processing

#### 4.1.1 Enqueue Flow

Every local write (create, update, delete) performed through a repository must enqueue a sync operation:

```dart
// Called inside repository implementations:
Future<void> _enqueueForSync({
  required String entityType,
  required String entityId,
  required OperationType operationType,
  required Map<String, dynamic> payload,
}) async {
  final operation = SyncOperationEntity()
    ..entityType = entityType
    ..entityId = entityId
    ..operationType = operationType
    ..payload = jsonEncode(payload)
    ..timestamp = DateTime.now()  // Local time for queue ordering
    ..status = 'pending'
    ..retryCount = 0
    ..errorMessage = null
    ..createdAt = DateTime.now();

  await _operationQueue.enqueue(operation);
}
```

#### 4.1.2 Dequeue and Process Flow

```
[dequeueNext()] -> [markInProgress()] -> [send to Firestore]
                                              |
                              +---------------+---------------+
                              |                               |
                         [Success]                       [Failure]
                              |                               |
                    [markCompleted()]              [retryCount < 3?]
                                                    |           |
                                                  [Yes]        [No]
                                                    |           |
                                              [markRetry()] [markFailed()]
                                              [backoff wait]  [emit event]
```

#### 4.1.3 Retry Logic

```dart
// lib/core/sync/sync_config.dart

/// Sync engine configuration constants.
/// All values from specs/00_project_foundation.md Section 4.4.1.
class SyncConfig {
  SyncConfig._();

  /// Maximum number of retry attempts before marking as failed.
  static const int maxRetryCount = 3;

  /// Base delay for exponential backoff (in seconds).
  static const int retryBaseDelaySeconds = 1;

  /// Multiplier for exponential backoff.
  /// Delays: 1s (1*1), 4s (1*4), 16s (1*4*4)
  static const int retryBackoffFactor = 4;

  /// Maximum operations in the sync queue.
  static const int maxQueueSize = 1000;

  /// Warning threshold (alert user before queue is full).
  static const int queueWarningThreshold = 800;

  /// Periodic sync interval when online and foregrounded (in seconds).
  static const int periodicSyncIntervalSeconds = 300; // 5 minutes

  /// Calculates the retry delay for a given attempt number (0-indexed).
  static Duration retryDelay(int attemptNumber) {
    // attempt 0: 1s, attempt 1: 4s, attempt 2: 16s
    final seconds = retryBaseDelaySeconds *
        _pow(retryBackoffFactor, attemptNumber);
    return Duration(seconds: seconds);
  }

  static int _pow(int base, int exponent) {
    int result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}
```

#### 4.1.4 Queue Capacity Management

When the queue approaches capacity:

```dart
Future<void> _checkQueueCapacity() async {
  final count = await _operationQueue.pendingCount;

  if (count >= SyncConfig.maxQueueSize) {
    // Purge completed operations first
    await _operationQueue.purgeCompleted();

    // Re-check
    final newCount = await _operationQueue.pendingCount;
    if (newCount >= SyncConfig.maxQueueSize) {
      _statusManager.emitEvent(
        SyncEvent.queueFull(pendingCount: newCount),
      );
    }
  } else if (count >= SyncConfig.queueWarningThreshold) {
    _statusManager.emitEvent(
      SyncEvent.queueNearCapacity(pendingCount: count),
    );
  }
}
```

### 4.2 Conflict Resolution

#### 4.2.1 LWW Algorithm

```dart
// lib/core/sync/conflict_resolver_impl.dart

class ConflictResolverImpl implements ConflictResolver {
  @override
  ConflictResult resolve({
    required Map<String, dynamic> localState,
    required Map<String, dynamic> remoteState,
    required DateTime localUpdatedAt,
    required DateTime remoteUpdatedAt,
    required bool localIsDelete,
    required bool remoteIsDelete,
  }) {
    // Rule 3: Delete always wins over edit
    if (localIsDelete && !remoteIsDelete) {
      return ConflictResult(
        winner: ConflictWinner.local,
        winnerState: null, // Delete = no state
        loserState: remoteState,
        reason: 'Local delete wins over remote edit',
      );
    }

    if (remoteIsDelete && !localIsDelete) {
      return ConflictResult(
        winner: ConflictWinner.remote,
        winnerState: null,
        loserState: localState,
        reason: 'Remote delete wins over local edit',
      );
    }

    // Both deletes: no conflict, both agree
    if (localIsDelete && remoteIsDelete) {
      return ConflictResult(
        winner: ConflictWinner.remote,
        winnerState: null,
        loserState: null,
        reason: 'Both sides deleted, no conflict',
      );
    }

    // Rule 1: Compare timestamps -- later wins
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      return ConflictResult(
        winner: ConflictWinner.remote,
        winnerState: remoteState,
        loserState: localState,
        reason: 'Remote timestamp is newer',
      );
    }

    if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
      return ConflictResult(
        winner: ConflictWinner.local,
        winnerState: localState,
        loserState: remoteState,
        reason: 'Local timestamp is newer',
      );
    }

    // Rule 2: Tie -- remote (server) wins
    return ConflictResult(
      winner: ConflictWinner.remote,
      winnerState: remoteState,
      loserState: localState,
      reason: 'Timestamps equal, server is authoritative',
    );
  }
}
```

#### 4.2.2 ConflictResult Model

```dart
// lib/core/sync/models/conflict_result.dart

enum ConflictWinner { local, remote }

class ConflictResult {
  final ConflictWinner winner;
  final Map<String, dynamic>? winnerState;
  final Map<String, dynamic>? loserState;
  final String reason;

  const ConflictResult({
    required this.winner,
    required this.winnerState,
    required this.loserState,
    required this.reason,
  });
}
```

#### 4.2.3 Audit Log Entry

```dart
// Firestore audit_log subcollection document structure:
// families/{familyId}/tasks/{taskId}/audit_log/{logId}
//
// Fields (from specs/00_project_foundation.md Section 4.5.1):
// - action: String         (e.g., "conflict_resolved_lww")
// - before: Map?           (state before resolution)
// - after: Map?            (state after resolution)
// - performedBy: String    (member ID who caused the conflict)
// - timestamp: Timestamp   (server timestamp)
// - deviceId: String       (device that triggered the sync)
// - syncConflict: bool     (true for conflict-generated entries)
```

### 4.3 Sync Orchestrator

#### 4.3.1 Trigger Table

From `specs/00_project_foundation.md` Section 4.4.3:

| Trigger | Behavior | Implementation |
|---------|----------|----------------|
| App comes to foreground | Full sync: push then pull | `AppLifecycleListener` |
| Connectivity restored | Push pending, then pull | `ConnectivityService.statusStream` |
| User performs write while online | Immediate push of that operation | Called inline from `enqueueOperation()` |
| Firestore real-time listener fires | Pull changed document into local DB | `Firestore.snapshots()` listener |
| Manual pull-to-refresh | Full sync | Called from BLoC/Cubit on refresh gesture |
| Every 5 minutes while foregrounded and online | Background pull | `Timer.periodic` in orchestrator |

#### 4.3.2 Push Flow

```dart
/// Processes all pending operations in the queue.
Future<PushResult> _pushPendingOperations() async {
  int successCount = 0;
  int failureCount = 0;

  while (true) {
    final operation = await _operationQueue.dequeueNext();
    if (operation == null) break; // Queue empty

    await _operationQueue.markInProgress(operation.id);

    try {
      // Delegate to type-specific sync adapter
      final adapter = _adapters[operation.entityType];
      if (adapter == null) {
        await _operationQueue.markFailed(
          operation.id,
          'No sync adapter for type: ${operation.entityType}',
        );
        failureCount++;
        continue;
      }

      await adapter.pushToRemote(
        entityId: operation.entityId,
        operationType: operation.operationType,
        payload: operation.payload,
      );

      await _operationQueue.markCompleted(operation.id);
      successCount++;

      _statusManager.emitEvent(
        SyncEvent.operationCompleted(
          entityType: operation.entityType,
          entityId: operation.entityId,
        ),
      );
    } on SyncConflictException catch (e) {
      // Conflict detected -- resolve using LWW
      final result = _conflictResolver.resolve(
        localState: jsonDecode(operation.payload) as Map<String, dynamic>,
        remoteState: e.remoteState,
        localUpdatedAt: operation.timestamp,
        remoteUpdatedAt: e.remoteUpdatedAt,
        localIsDelete: operation.operationType == OperationType.delete,
        remoteIsDelete: e.remoteIsDeleted,
      );

      await _applyConflictResolution(operation, result);
      await _operationQueue.markCompleted(operation.id);

      _statusManager.emitEvent(
        SyncEvent.conflictResolved(
          entityType: operation.entityType,
          entityId: operation.entityId,
          winner: result.winner,
        ),
      );
    } on Exception catch (e) {
      // Transient failure -- retry
      if (operation.retryCount < SyncConfig.maxRetryCount - 1) {
        await _operationQueue.markRetry(operation.id, e.toString());
        failureCount++;

        // Wait for backoff delay before continuing
        final delay = SyncConfig.retryDelay(operation.retryCount);
        await Future<void>.delayed(delay);
      } else {
        await _operationQueue.markFailed(operation.id, e.toString());
        failureCount++;

        _statusManager.emitEvent(
          SyncEvent.operationFailed(
            entityType: operation.entityType,
            entityId: operation.entityId,
            error: e.toString(),
          ),
        );
      }
    }

    // Check if connectivity was lost mid-sync
    if (!_connectivityService.isOnline) {
      _statusManager.emitEvent(
        SyncEvent.syncPausedOffline(
          remainingOperations: await _operationQueue.pendingCount,
        ),
      );
      break;
    }
  }

  return PushResult(
    successCount: successCount,
    failureCount: failureCount,
  );
}
```

#### 4.3.3 Pull Flow

```dart
/// Pulls latest state from Firestore into local Isar.
/// Uses Firestore snapshot listeners for real-time updates when online.
Future<void> _pullRemoteChanges(String familyId) async {
  for (final adapter in _adapters.values) {
    try {
      final remoteChanges = await adapter.fetchChangesSince(
        familyId: familyId,
        since: adapter.lastSyncTimestamp,
      );

      for (final change in remoteChanges) {
        final localEntity = await adapter.findLocalByRemoteId(change.id);

        if (localEntity == null) {
          // New remote entity -- insert locally
          await adapter.insertLocal(change);
        } else if (localEntity.syncStatus == SyncStatus.pending) {
          // Local has unsaved changes -- conflict!
          final result = _conflictResolver.resolve(
            localState: localEntity.toMap(),
            remoteState: change.data,
            localUpdatedAt: localEntity.updatedAt,
            remoteUpdatedAt: change.updatedAt,
            localIsDelete: false,
            remoteIsDelete: change.isDeleted,
          );
          await _applyConflictResolution(localEntity, result);
        } else {
          // No local changes -- update from remote
          await adapter.updateLocal(change);
        }
      }
    } on Exception catch (e) {
      // Pull failure is non-fatal -- local data remains valid
      _statusManager.emitEvent(
        SyncEvent.pullError(
          entityType: adapter.entityType,
          error: e.toString(),
        ),
      );
    }
  }
}
```

#### 4.3.4 Full Sync

```dart
/// Complete bidirectional sync: push local changes, then pull remote.
Future<void> fullSync() async {
  if (_state == SyncEngineState.stopped) return;
  if (!_connectivityService.isOnline) return;

  _statusManager.emitState(SyncState.syncing);

  try {
    // Phase 1: Push all pending local operations
    final pushResult = await _pushPendingOperations();

    // Phase 2: Pull latest remote state
    await _pullRemoteChanges(_currentFamilyId);

    // Determine final state
    if (pushResult.failureCount > 0) {
      _statusManager.emitState(SyncState.syncingWithErrors(
        pendingCount: pushResult.failureCount,
      ));
    } else {
      _statusManager.emitState(SyncState.idle);
    }
  } on Exception catch (e) {
    _statusManager.emitState(SyncState.error(message: e.toString()));
  }
}
```

### 4.4 Entity Sync Adapter Pattern

Each entity type provides a sync adapter that the engine uses for type-specific serialization and Firestore interaction:

```dart
// lib/core/sync/entity_sync_adapter.dart

/// Type-specific adapter for syncing a particular entity type.
/// Implemented per entity (TaskSyncAdapter, MemberSyncAdapter, etc.)
abstract class EntitySyncAdapter {
  /// The entity type string (e.g., "task", "member").
  String get entityType;

  /// Timestamp of the last successful pull for this entity type.
  DateTime? get lastSyncTimestamp;

  /// Pushes a single operation to Firestore.
  /// Throws [SyncConflictException] if a conflict is detected.
  /// Throws other exceptions for transient failures.
  Future<void> pushToRemote({
    required String entityId,
    required OperationType operationType,
    required String payload,
  });

  /// Fetches changes from Firestore since the given timestamp.
  Future<List<RemoteChange>> fetchChangesSince({
    required String familyId,
    required DateTime? since,
  });

  /// Finds a local entity by its Firestore remote ID.
  Future<SyncableEntity?> findLocalByRemoteId(String remoteId);

  /// Inserts a remote entity into the local database.
  Future<void> insertLocal(RemoteChange change);

  /// Updates a local entity from remote state.
  Future<void> updateLocal(RemoteChange change);

  /// Deletes a local entity.
  Future<void> deleteLocal(String remoteId);
}
```

### 4.5 Isolate Strategy

The sync engine runs heavy operations in a separate Dart isolate to prevent UI jank:

```dart
// lib/core/sync/sync_isolate.dart

/// Sync processing runs in a separate isolate.
/// Communication with the main isolate uses SendPort/ReceivePort.
///
/// Architecture:
/// Main Isolate <-> SendPort/ReceivePort <-> Sync Isolate
///                                             |
///                                        Opens own Isar instance
///                                        Opens own Firestore instance
///
/// The sync isolate opens the SAME Isar database (same name + directory)
/// which Isar supports for concurrent multi-isolate access.

class SyncIsolateManager {
  Isolate? _isolate;
  SendPort? _sendPort;
  final ReceivePort _receivePort = ReceivePort();

  /// Spawns the sync isolate and establishes communication.
  Future<void> spawn({
    required String isarDirectory,
    required String familyId,
  }) async {
    _isolate = await Isolate.spawn(
      _syncIsolateEntryPoint,
      SyncIsolateConfig(
        sendPort: _receivePort.sendPort,
        isarDirectory: isarDirectory,
        familyId: familyId,
      ),
    );

    // Wait for the isolate to send back its SendPort
    _sendPort = await _receivePort.first as SendPort;
  }

  /// Sends a sync command to the isolate.
  void requestSync(SyncCommand command) {
    _sendPort?.send(command);
  }

  /// Kills the sync isolate.
  void dispose() {
    _isolate?.kill();
    _receivePort.close();
  }
}

/// Entry point for the sync isolate.
void _syncIsolateEntryPoint(SyncIsolateConfig config) async {
  final receivePort = ReceivePort();
  config.sendPort.send(receivePort.sendPort);

  // Open Isar in this isolate (same DB, concurrent access)
  final isar = await openDatabaseInIsolate(config.isarDirectory);

  // Process commands from main isolate
  await for (final command in receivePort) {
    if (command is SyncCommand) {
      // Execute sync operation and send result back
      // ...
    }
  }
}
```

**Simplification note:** For Phase 1, the isolate strategy can be implemented using `Isolate.run()` for individual sync batches rather than a long-lived isolate. The long-lived isolate pattern becomes necessary in Phase 3+ when real-time Firestore listeners are added.

### 4.6 Sync State Management

```dart
// lib/core/sync/sync_status.dart

/// High-level sync engine state.
sealed class SyncState {
  const SyncState();

  /// Engine is idle, all data is synced.
  const factory SyncState.idle() = SyncIdle;

  /// Engine is actively syncing.
  const factory SyncState.syncing() = SyncSyncing;

  /// Engine completed sync but some operations failed.
  const factory SyncState.syncingWithErrors({
    required int pendingCount,
  }) = SyncSyncingWithErrors;

  /// Engine encountered a critical error.
  const factory SyncState.error({required String message}) = SyncError;

  /// Engine is stopped (not running).
  const factory SyncState.stopped() = SyncStopped;
}

class SyncIdle extends SyncState {
  const SyncIdle();
}

class SyncSyncing extends SyncState {
  const SyncSyncing();
}

class SyncSyncingWithErrors extends SyncState {
  final int pendingCount;
  const SyncSyncingWithErrors({required this.pendingCount});
}

class SyncError extends SyncState {
  final String message;
  const SyncError({required this.message});
}

class SyncStopped extends SyncState {
  const SyncStopped();
}
```

```dart
// lib/core/sync/sync_event.dart

/// Individual sync events for UI consumption.
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
}
```

---

## 5. Partial Failure Handling

From `specs/00_project_foundation.md` Section 4.4.4:

### 5.1 Behavior Specification

When a sync batch partially fails:

1. **Successful operations** are marked `status = "completed"` in the queue and eligible for purge.
2. **Failed operations** remain in the queue with `retryCount` incremented and `errorMessage` set.
3. **UI shows:** "Most changes synced. N items pending." (non-blocking status, not an error).
4. Failed operations are retried on the next sync trigger.
5. After 3 consecutive failures, the operation is flagged `status = "failed"` and the user sees: "Some changes could not be saved to the cloud. Tap to review."

### 5.2 User-Facing Messages

| Queue State | UI Message | Component |
|-------------|-----------|-----------|
| 0 pending, 0 failed | No indicator | App bar (no icon) |
| N pending, 0 failed | "Syncing..." | Animated sync icon |
| 0 pending after sync | No indicator | Sync icon disappears |
| N pending after partial failure | "N items pending" | Orange dot on sync icon |
| N failed after max retries | "Some changes could not be saved. Tap to review." | Banner below app bar |

---

## 6. Edge Cases

### 6.1 App Killed Mid-Sync

**Scenario:** The app process is killed while the sync engine is processing operation #5 of 10.

**Behavior:**
- Operations 1-4 were marked `completed` before the kill. They are safe.
- Operation 5 was marked `inProgress`. On next app start, the engine queries for `inProgress` operations and resets them to `pending` with no retry count increment (the retry did not complete).
- Operations 6-10 remain `pending`.
- On next app start, sync resumes from operation 5.

```dart
/// Called on engine start to recover from interrupted syncs.
Future<void> _recoverInterruptedOperations() async {
  await _isar.writeTxn(() async {
    final interrupted = await _isar.syncOperationEntitys
        .filter()
        .statusEqualTo('inProgress')
        .findAll();

    for (final op in interrupted) {
      op.status = 'pending';
      // Do NOT increment retryCount -- the retry was interrupted, not failed
      await _isar.syncOperationEntitys.put(op);
    }
  });
}
```

### 6.2 Clock Skew Between Devices

**Scenario:** Device A's clock is 5 minutes ahead of Device B's clock.

**Behavior:** Local device timestamps are used only for FIFO queue ordering. Conflict resolution uses Firestore server timestamps (`FieldValue.serverTimestamp()`), which are authoritative and not affected by device clock skew.

### 6.3 Extremely Long Offline Period

**Scenario:** A device is offline for 2 weeks with 200 queued operations.

**Behavior:**
1. On reconnection, the engine performs a full reconciliation pull BEFORE pushing queued operations.
2. The pull detects that many remote entities have changed.
3. Each queued operation is checked against current remote state before being pushed.
4. Stale operations (editing an entity that has since been deleted) are detected and moved to failed with an explanatory message.
5. Non-stale operations are pushed normally.

### 6.4 Auth Token Expired During Sync

**Scenario:** The Firebase Auth token expires mid-sync (tokens last 1 hour).

**Behavior:**
1. A Firestore write fails with an auth error.
2. The engine pauses sync and emits `SyncEvent.authRequired`.
3. The auth layer attempts silent re-authentication (Firebase SDK handles token refresh).
4. If re-auth succeeds, sync resumes.
5. If re-auth fails (e.g., user's account was disabled), the user is prompted to sign in again. Sync remains paused.

### 6.5 Firestore Quota Exceeded

**Scenario:** The free tier daily quota is reached.

**Behavior:** Sync pauses with exponential backoff at the engine level (not per-operation). The engine retries after 1 minute, 5 minutes, 15 minutes. The user is informed: "Cloud sync is temporarily unavailable. Your data is safe locally."

---

## 7. Impact Analysis

### 7.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| SyncEngine | New | **High** | Core component, correctness is critical |
| OperationQueue | New | **High** | Data integrity depends on correct queue management |
| ConflictResolver | New | **High** | Incorrect resolution = data loss or data corruption |
| SyncOperationEntity | Dependency | Medium | Schema defined in specs/02, consumed here |
| ConnectivityService | Dependency | Medium | Trigger source, defined in specs/04 |
| Repository implementations | Consumer | Medium | All repos must enqueue operations correctly |
| BLoC/Cubit layer | Consumer | Medium | Subscribes to sync streams for UI updates |

### 7.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Conflict resolution produces incorrect winner | Medium | **High** | Comprehensive unit tests for all 5 conflict scenarios. Audit log preserves losing writes. |
| Queue corruption causes operation loss | Low | **High** | Isar transactions ensure atomicity. Recovery logic for interrupted operations. |
| Isolate communication failure | Medium | Medium | Fallback to main-isolate sync with warning about potential UI jank. |
| Exponential backoff causes sync starvation | Low | Medium | Cap maximum backoff at 16s (3 retries then fail). Periodic sync resets the backoff. |
| Memory pressure from large payloads in queue | Low | Medium | Payload is JSON string, typically < 1 KB. Monitor queue size. |
| Race condition between push and pull | Medium | Medium | Push completes before pull starts (sequential in fullSync). Firestore transactions for writes. |

---

## 8. Functional Tests

### 8.1 Operation Queue Tests

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| SE-FT-001 | Enqueue creates pending operation | Empty queue | `enqueue()` called with a task create | Operation exists with status="pending", retryCount=0 | High |
| SE-FT-002 | Dequeue returns oldest first (FIFO) | 3 operations queued at T1, T2, T3 | `dequeueNext()` called | Returns operation from T1 | High |
| SE-FT-003 | markCompleted removes operation | Operation with status="inProgress" | `markCompleted()` called | Operation no longer in pending or inProgress queries | High |
| SE-FT-004 | markRetry increments count | Operation with retryCount=0 | `markRetry()` called | retryCount=1, status="pending", errorMessage set | High |
| SE-FT-005 | Third failure marks as failed | Operation with retryCount=2 | `markRetry()` called | status="failed", retryCount=3 | High |
| SE-FT-006 | Queue capacity check at 1000 | Queue has 999 operations | 1001st enqueue attempted | Event emitted: queueFull | Medium |
| SE-FT-007 | Purge removes completed ops | 5 completed, 3 pending operations | `purgeCompleted()` called | Only 3 pending remain | Medium |
| SE-FT-008 | Empty queue returns null | No pending operations | `dequeueNext()` called | Returns null | High |
| SE-FT-009 | Failed operations retrievable | 2 failed, 3 pending operations | `getFailedOperations()` called | Returns exactly 2 failed operations | Medium |

### 8.2 Conflict Resolution Tests

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| SE-FT-010 | Remote timestamp newer wins | Local updatedAt=T1, remote updatedAt=T2 (T2 > T1) | `resolve()` called | winner=remote, loserState=localState | High |
| SE-FT-011 | Local timestamp newer wins | Local updatedAt=T2, remote updatedAt=T1 (T2 > T1) | `resolve()` called | winner=local, loserState=remoteState | High |
| SE-FT-012 | Tie goes to remote | Both updatedAt=T1 | `resolve()` called | winner=remote, reason contains "server is authoritative" | High |
| SE-FT-013 | Local delete beats remote edit | localIsDelete=true, remoteIsDelete=false | `resolve()` called | winner=local, winnerState=null (delete) | High |
| SE-FT-014 | Remote delete beats local edit | localIsDelete=false, remoteIsDelete=true | `resolve()` called | winner=remote, winnerState=null (delete) | High |
| SE-FT-015 | Both delete is no conflict | localIsDelete=true, remoteIsDelete=true | `resolve()` called | winner=remote, loserState=null | Medium |
| SE-FT-016 | Audit log created for loser | Conflict resolved, local wins | `createAuditLogEntry()` called | Audit entry has before/after state, syncConflict=true | High |

### 8.3 Sync Orchestrator Tests

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| SE-FT-017 | Full sync pushes then pulls | 3 pending operations, remote has 2 changes | `syncNow()` called | All 3 pushed, then 2 pulled. State=idle. | High |
| SE-FT-018 | Partial failure preserves successful ops | 3 operations: 2 succeed, 1 fails | Push processes queue | 2 marked completed, 1 marked retry. State=syncingWithErrors. | High |
| SE-FT-019 | Connectivity lost mid-sync pauses | 5 operations, connectivity drops after 3 | Push processes queue | 3 completed, 2 remain pending. Event: syncPausedOffline. | High |
| SE-FT-020 | Interrupted operations recovered | 1 operation with status="inProgress" from crash | Engine starts | Operation reset to status="pending", retryCount unchanged | High |
| SE-FT-021 | Sync skipped when offline | Engine started, device offline | `syncNow()` called | No operations processed. No error. | Medium |
| SE-FT-022 | Sync skipped when stopped | Engine stopped | `syncNow()` called | No operations processed. No error. | Medium |
| SE-FT-023 | Online write triggers immediate push | Device online, user creates task | `enqueueOperation()` called | Operation pushed immediately (not waiting for periodic) | High |
| SE-FT-024 | Periodic sync fires every 5 minutes | Engine started, device online, no user activity | 5 minutes elapse | Pull triggered automatically | Medium |

### 8.4 Edge Case Tests

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| SE-FT-025 | Retry delay is exponential | Operation fails 3 times | Retry delays measured | Delays are 1s, 4s, 16s respectively | High |
| SE-FT-026 | Stale edit on deleted entity | Local edit queued, remote entity deleted | Push attempted | Operation marked failed with "entity deleted remotely" | Medium |
| SE-FT-027 | Duplicate operation deduplication | Two enqueues for same entity + operation type | Queue examined | Both exist (no dedup -- each is a distinct operation) | Medium |
| SE-FT-028 | 1000 operations processes correctly | Queue has 1000 pending operations | Full sync runs | All processed in FIFO order, performance < 5 seconds | Medium |

---

## 9. Implementation Recommendations

### 9.1 Suggested Approach

1. Implement `SyncConfig` constants.
2. Implement `OperationQueue` backed by Isar `SyncOperationEntity`.
3. Write all queue unit tests (SE-FT-001 through SE-FT-009).
4. Implement `ConflictResolver` with LWW algorithm.
5. Write all conflict resolution tests (SE-FT-010 through SE-FT-016).
6. Implement `SyncState` and `SyncEvent` sealed classes.
7. Implement `SyncEngine` orchestrator with push/pull flows.
8. Write orchestrator tests (SE-FT-017 through SE-FT-024).
9. Implement isolate strategy (start with `Isolate.run()`, upgrade later).
10. Write edge case tests (SE-FT-025 through SE-FT-028).
11. Implement recovery logic for interrupted operations.

### 9.2 Estimated Effort

**T-shirt size: L** (5-7 days)

The sync engine is the highest-complexity, highest-risk component. Extensive testing is required.

### 9.3 Testing Strategy

- **Unit tests:** Mock Isar and Firestore. Test all paths through the queue, resolver, and orchestrator.
- **Integration tests:** Use real Isar (in-memory) and Firestore emulator. Test full sync flow.
- **Mocking:** Use `mocktail` for all external dependencies. Create `FakeIsar` for in-memory testing.

See `specs/07_phase1_test_plan.md` for the complete test plan.

---

## 10. Open Questions

- [ ] Should the sync engine support batched Firestore writes (writing multiple documents in a single network round-trip), or process one operation at a time? Batching improves network efficiency but complicates partial failure handling.
- [ ] Should the `EntitySyncAdapter` pattern use generics (`EntitySyncAdapter<T>`) or rely on `Map<String, dynamic>` payloads? Generics add type safety but increase boilerplate.
- [ ] Should the isolate strategy use `Isolate.run()` (simpler, per-batch) or a long-lived isolate with message passing (more complex, better for real-time listeners)? Recommendation: start with `Isolate.run()` in Phase 1, upgrade in Phase 3.

---

*Generated by Software Architect Analyst*
*Date: 2026-03-05*
