import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../database/app_database.dart';
import 'operation_queue.dart';
import 'sync_config.dart';

@LazySingleton(as: OperationQueue)
class OperationQueueImpl implements OperationQueue {
  OperationQueueImpl(this._db);

  final AppDatabase _db;

  @override
  Future<void> enqueue(SyncOperationsTableData operation) async {
    await _db.into(_db.syncOperationsTable).insert(
          SyncOperationsTableCompanion.insert(
            entityType: operation.entityType,
            entityId: operation.entityId,
            operationType: operation.operationType,
            payload: operation.payload,
            timestamp: operation.timestamp,
            status: const Value('pending'),
            retryCount: const Value(0),
            createdAt: operation.createdAt,
          ),
        );
  }

  @override
  Future<SyncOperationsTableData?> dequeueNext() async {
    final results = await (_db.syncOperationsTable.select()
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(1))
        .get();
    return results.isEmpty ? null : results.first;
  }

  @override
  Future<void> markCompleted(int operationId) async {
    await (_db.syncOperationsTable.update()
          ..where((t) => t.id.equals(operationId)))
        .write(
      const SyncOperationsTableCompanion(
        status: Value('completed'),
      ),
    );
  }

  @override
  Future<void> markInProgress(int operationId) async {
    await (_db.syncOperationsTable.update()
          ..where((t) => t.id.equals(operationId)))
        .write(
      const SyncOperationsTableCompanion(
        status: Value('inProgress'),
      ),
    );
  }

  @override
  Future<void> markRetry(int operationId, String errorMessage) async {
    final op = await (_db.syncOperationsTable.select()
          ..where((t) => t.id.equals(operationId)))
        .getSingleOrNull();
    if (op == null) return;

    final newRetryCount = op.retryCount + 1;
    if (newRetryCount >= SyncConfig.maxRetryCount) {
      await (_db.syncOperationsTable.update()
            ..where((t) => t.id.equals(operationId)))
          .write(
        SyncOperationsTableCompanion(
          status: const Value('failed'),
          retryCount: Value(newRetryCount),
          errorMessage: Value(errorMessage),
        ),
      );
    } else {
      await (_db.syncOperationsTable.update()
            ..where((t) => t.id.equals(operationId)))
          .write(
        SyncOperationsTableCompanion(
          status: const Value('pending'),
          retryCount: Value(newRetryCount),
          errorMessage: Value(errorMessage),
        ),
      );
    }
  }

  @override
  Future<void> markFailed(int operationId, String errorMessage) async {
    await (_db.syncOperationsTable.update()
          ..where((t) => t.id.equals(operationId)))
        .write(
      SyncOperationsTableCompanion(
        status: const Value('failed'),
        errorMessage: Value(errorMessage),
      ),
    );
  }

  @override
  Future<int> get pendingCount async {
    final results = await (_db.syncOperationsTable.select()
          ..where((t) => t.status.equals('pending')))
        .get();
    return results.length;
  }

  @override
  Future<int> get failedCount async {
    final results = await (_db.syncOperationsTable.select()
          ..where((t) => t.status.equals('failed')))
        .get();
    return results.length;
  }

  @override
  Future<List<SyncOperationsTableData>> getFailedOperations() async {
    return (_db.syncOperationsTable.select()
          ..where((t) => t.status.equals('failed')))
        .get();
  }

  @override
  Future<void> purgeCompleted() async {
    await (_db.syncOperationsTable.delete()
          ..where((t) => t.status.equals('completed')))
        .go();
  }

  @override
  Future<void> recoverInterruptedOperations() async {
    await (_db.syncOperationsTable.update()
          ..where((t) => t.status.equals('inProgress')))
        .write(
      const SyncOperationsTableCompanion(
        status: Value('pending'),
      ),
    );
  }

  @override
  Future<bool> get isAtCapacity async {
    final count = await pendingCount;
    return count >= SyncConfig.maxQueueSize;
  }
}
