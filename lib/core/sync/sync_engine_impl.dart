import 'dart:async';
import 'dart:convert';

import 'package:injectable/injectable.dart';

import '../database/app_database.dart';
import '../enums/operation_type.dart';
import '../network/connectivity_service.dart';
import 'conflict_resolver.dart';
import 'entity_sync_adapter.dart';
import 'exceptions/sync_conflict_exception.dart';
import 'operation_queue.dart';
import 'sync_config.dart';
import 'sync_engine.dart';
import 'sync_event.dart';
import 'sync_state.dart';
import 'sync_status_manager.dart';

enum _SyncEngineState { stopped, running }

@Singleton(as: SyncEngine)
class SyncEngineImpl implements SyncEngine {
  SyncEngineImpl({
    required OperationQueue operationQueue,
    required ConflictResolver conflictResolver,
    required ConnectivityService connectivityService,
    required SyncStatusManager statusManager,
    required AppDatabase database,
  })  : _operationQueue = operationQueue,
        _conflictResolver = conflictResolver,
        _connectivityService = connectivityService,
        _statusManager = statusManager,
        _database = database;

  final OperationQueue _operationQueue;
  final ConflictResolver _conflictResolver;
  final ConnectivityService _connectivityService;
  final SyncStatusManager _statusManager;
  final AppDatabase _database;

  final Map<String, EntitySyncAdapter> _adapters = {};

  _SyncEngineState _engineState = _SyncEngineState.stopped;
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _periodicSyncTimer;
  bool _isOnline = false;

  // ── Public API ────────────────────────────────────────────────────────────

  @override
  Stream<SyncState> get stateStream => _statusManager.stateStream;

  @override
  Stream<SyncEvent> get eventStream => _statusManager.eventStream;

  @override
  SyncState get currentState => _statusManager.currentState;

  @override
  Future<int> get pendingOperationCount => _operationQueue.pendingCount;

  /// Registers an entity sync adapter. Call once per entity type at startup.
  void registerAdapter(EntitySyncAdapter adapter) {
    _adapters[adapter.entityType] = adapter;
  }

  @override
  Future<void> start() async {
    if (_engineState == _SyncEngineState.running) return;
    _engineState = _SyncEngineState.running;
    _statusManager.emitState(const SyncState.idle());

    await _operationQueue.recoverInterruptedOperations();

    _isOnline = await _connectivityService.isConnected;
    _connectivitySubscription =
        _connectivityService.onConnectivityChanged.listen((isOnline) async {
      _isOnline = isOnline;
      if (isOnline) await syncNow();
    });

    _periodicSyncTimer = Timer.periodic(
      const Duration(seconds: SyncConfig.periodicSyncIntervalSeconds),
      (_) async {
        if (_isOnline) await _pullOnly();
      },
    );

    if (_isOnline) await syncNow();
  }

  @override
  Future<void> stop() async {
    _engineState = _SyncEngineState.stopped;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    _statusManager.emitState(const SyncState.stopped());
  }

  @override
  Future<void> syncNow() async {
    if (_engineState == _SyncEngineState.stopped) return;
    if (!_isOnline) return;

    _statusManager.emitState(const SyncState.syncing());

    try {
      final pushResult = await _pushPendingOperations();
      await _checkQueueCapacity();

      if (pushResult.failureCount > 0) {
        _statusManager.emitState(
          SyncState.syncingWithErrors(pendingCount: pushResult.failureCount),
        );
      } else {
        _statusManager.emitState(const SyncState.idle());
      }
    } on Exception catch (e) {
      _statusManager.emitState(SyncState.error(message: e.toString()));
    }
  }

  @override
  Future<void> enqueueOperation({
    required String entityType,
    required String entityId,
    required OperationType operationType,
    required String payload,
  }) async {
    final now = DateTime.now();
    await _database.into(_database.syncOperationsTable).insert(
          SyncOperationsTableCompanion.insert(
            entityType: entityType,
            entityId: entityId,
            operationType: operationType,
            payload: payload,
            timestamp: now,
            createdAt: now,
          ),
        );

    await _checkQueueCapacity();

    if (_isOnline && _engineState == _SyncEngineState.running) {
      await syncNow();
    }
  }

  // ── Private: Push ─────────────────────────────────────────────────────────

  Future<_PushResult> _pushPendingOperations() async {
    var successCount = 0;
    var failureCount = 0;

    while (true) {
      final operation = await _operationQueue.dequeueNext();
      if (operation == null) break;

      await _operationQueue.markInProgress(operation.id);

      try {
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
        final result = _conflictResolver.resolve(
          localState: jsonDecode(operation.payload) as Map<String, dynamic>,
          remoteState: e.remoteState,
          localUpdatedAt: operation.timestamp,
          remoteUpdatedAt: e.remoteUpdatedAt,
          localIsDelete: operation.operationType == OperationType.delete,
          remoteIsDelete: e.remoteIsDeleted,
        );

        await _operationQueue.markCompleted(operation.id);
        successCount++;

        _statusManager.emitEvent(
          SyncEvent.conflictResolved(
            entityType: operation.entityType,
            entityId: operation.entityId,
            winner: result.winner,
          ),
        );
      } on Exception catch (e) {
        await _operationQueue.markRetry(operation.id, e.toString());
        failureCount++;

        final willPermanentlyFail =
            operation.retryCount + 1 >= SyncConfig.maxRetryCount;
        if (willPermanentlyFail) {
          _statusManager.emitEvent(
            SyncEvent.operationFailed(
              entityType: operation.entityType,
              entityId: operation.entityId,
              error: e.toString(),
            ),
          );
        } else {
          final delay = SyncConfig.retryDelay(operation.retryCount);
          await Future<void>.delayed(delay);
        }
      }

      if (!_isOnline) {
        final remaining = await _operationQueue.pendingCount;
        _statusManager.emitEvent(
          SyncEvent.syncPausedOffline(remainingOperations: remaining),
        );
        break;
      }
    }

    return _PushResult(successCount: successCount, failureCount: failureCount);
  }

  // ── Private: Pull ─────────────────────────────────────────────────────────

  /// Periodic pull — entity adapters handle Firestore listener subscriptions.
  /// Full implementation is Phase 3 (long-lived isolate with real-time listeners).
  Future<void> _pullOnly() async {
    if (_engineState == _SyncEngineState.stopped) return;
    // Phase 1: no-op. Entity adapters trigger pulls via Firestore listeners.
  }

  // ── Private: Queue capacity ────────────────────────────────────────────────

  Future<void> _checkQueueCapacity() async {
    final count = await _operationQueue.pendingCount;

    if (count >= SyncConfig.maxQueueSize) {
      await _operationQueue.purgeCompleted();
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
}

class _PushResult {
  const _PushResult({required this.successCount, required this.failureCount});
  final int successCount;
  final int failureCount;
}
