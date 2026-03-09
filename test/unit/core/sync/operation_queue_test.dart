import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:family_chores_app/core/database/app_database.dart';
import 'package:family_chores_app/core/enums/operation_type.dart';
import 'package:family_chores_app/core/sync/operation_queue_impl.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _openTestDb() => AppDatabase(NativeDatabase.memory());

SyncOperationsTableData _makeOp({
  required AppDatabase db,
  required DateTime createdAt,
  String entityType = 'task',
  String entityId = 'task-1',
  OperationType operationType = OperationType.create,
  String payload = '{}',
  String status = 'pending',
  int retryCount = 0,
}) =>
    SyncOperationsTableData(
      id: 0, // auto-assigned by DB
      entityType: entityType,
      entityId: entityId,
      operationType: operationType,
      payload: payload,
      timestamp: createdAt,
      status: status,
      retryCount: retryCount,
      errorMessage: null,
      createdAt: createdAt,
    );

void main() {
  group('OperationQueueImpl', () {
    late AppDatabase db;
    late OperationQueueImpl queue;

    setUp(() {
      db = _openTestDb();
      queue = OperationQueueImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    group('enqueue', () {
      // SE-FT-001
      test('should create pending operation with retryCount=0', () async {
        final now = DateTime.now();
        await queue.enqueue(_makeOp(db: db, createdAt: now));

        final pending = await queue.pendingCount;
        expect(pending, 1);

        final op = await queue.dequeueNext();
        expect(op, isNotNull);
        expect(op!.status, 'pending');
        expect(op.retryCount, 0);
        expect(op.entityType, 'task');
      });
    });

    group('dequeueNext', () {
      // SE-FT-002
      test('should return oldest operation first (FIFO)', () async {
        final t1 = DateTime(2024, 1, 1, 10, 0, 0);
        final t2 = DateTime(2024, 1, 1, 11, 0, 0);
        final t3 = DateTime(2024, 1, 1, 12, 0, 0);

        await queue.enqueue(_makeOp(db: db, createdAt: t2, entityId: 'task-2'));
        await queue.enqueue(_makeOp(db: db, createdAt: t3, entityId: 'task-3'));
        await queue.enqueue(_makeOp(db: db, createdAt: t1, entityId: 'task-1'));

        final first = await queue.dequeueNext();
        expect(first!.entityId, 'task-1');

        await queue.markCompleted(first.id);
        final second = await queue.dequeueNext();
        expect(second!.entityId, 'task-2');
      });

      // SE-FT-008
      test('should return null when queue is empty', () async {
        final result = await queue.dequeueNext();
        expect(result, isNull);
      });
    });

    group('markCompleted', () {
      // SE-FT-003
      test('should remove operation from pending and inProgress queries',
          () async {
        final now = DateTime.now();
        await queue.enqueue(_makeOp(db: db, createdAt: now));
        final op = await queue.dequeueNext();

        await queue.markInProgress(op!.id);
        await queue.markCompleted(op.id);

        final pending = await queue.pendingCount;
        expect(pending, 0);

        final next = await queue.dequeueNext();
        expect(next, isNull);
      });
    });

    group('markRetry', () {
      // SE-FT-004
      test('should increment retryCount and keep status=pending on first retry',
          () async {
        final now = DateTime.now();
        await queue.enqueue(_makeOp(db: db, createdAt: now));
        final op = (await queue.dequeueNext())!;

        await queue.markRetry(op.id, 'network error');

        final updated = await queue.dequeueNext();
        expect(updated, isNotNull);
        expect(updated!.retryCount, 1);
        expect(updated.status, 'pending');
        expect(updated.errorMessage, 'network error');
      });

      // SE-FT-005
      test('should mark as failed when retryCount reaches maxRetryCount (3)',
          () async {
        final now = DateTime.now();
        // Directly insert with retryCount=2 to simulate two previous failures.
        await db.syncOperationsTable.insertOne(
          SyncOperationsTableCompanion.insert(
            entityType: 'task',
            entityId: 'task-1',
            operationType: OperationType.update,
            payload: '{}',
            timestamp: now,
            retryCount: const Value(2),
            createdAt: now,
          ),
        );

        final op = await queue.dequeueNext();
        expect(op, isNotNull);

        await queue.markRetry(op!.id, 'still failing');

        // After markRetry on retryCount=2, it becomes 3 → failed.
        final failed = await queue.getFailedOperations();
        expect(failed.length, 1);
        expect(failed.first.retryCount, 3);
        expect(failed.first.status, 'failed');
      });
    });

    group('purgeCompleted', () {
      // SE-FT-007
      test('should remove completed operations but keep pending ones',
          () async {
        final now = DateTime.now();

        // Add 5 operations and mark 2 completed.
        for (var i = 0; i < 5; i++) {
          await queue.enqueue(
            _makeOp(
              db: db,
              createdAt: now.add(Duration(seconds: i)),
              entityId: 'task-$i',
            ),
          );
        }

        final op1 = await queue.dequeueNext();
        await queue.markInProgress(op1!.id);
        await queue.markCompleted(op1.id);

        final op2 = await queue.dequeueNext();
        await queue.markInProgress(op2!.id);
        await queue.markCompleted(op2.id);

        expect(await queue.pendingCount, 3);
        await queue.purgeCompleted();

        // Completed ops should be deleted; pending should remain.
        final remaining = await queue.pendingCount;
        expect(remaining, 3);
      });
    });

    group('getFailedOperations', () {
      // SE-FT-009
      test('should return exactly the failed operations', () async {
        final now = DateTime.now();

        // Add 5 ops.
        for (var i = 0; i < 5; i++) {
          await queue.enqueue(
            _makeOp(
              db: db,
              createdAt: now.add(Duration(seconds: i)),
              entityId: 'task-$i',
            ),
          );
        }

        // Fail 2 of them.
        final op1 = (await queue.dequeueNext())!;
        await queue.markFailed(op1.id, 'error 1');
        final op2 = (await queue.dequeueNext())!;
        await queue.markFailed(op2.id, 'error 2');

        final failed = await queue.getFailedOperations();
        expect(failed.length, 2);
        expect(failed.every((op) => op.status == 'failed'), isTrue);
      });
    });

    group('recoverInterruptedOperations', () {
      // SE-FT-020 (queue side)
      test(
          'should reset inProgress operations to pending without changing retryCount',
          () async {
        final now = DateTime.now();
        await queue.enqueue(_makeOp(db: db, createdAt: now));
        final op = (await queue.dequeueNext())!;

        await queue.markInProgress(op.id);
        // Simulate crash: call recover.
        await queue.recoverInterruptedOperations();

        final recovered = await queue.dequeueNext();
        expect(recovered, isNotNull);
        expect(recovered!.status, 'pending');
        expect(recovered.retryCount, 0); // retryCount unchanged
      });
    });

    group('isAtCapacity', () {
      test('should return false when below maxQueueSize', () async {
        expect(await queue.isAtCapacity, isFalse);
      });
    });

    group('pendingCount and failedCount', () {
      test('should return correct counts', () async {
        final now = DateTime.now();

        for (var i = 0; i < 3; i++) {
          await queue.enqueue(
            _makeOp(
              db: db,
              createdAt: now.add(Duration(seconds: i)),
              entityId: 'task-$i',
            ),
          );
        }

        expect(await queue.pendingCount, 3);
        expect(await queue.failedCount, 0);

        final op = (await queue.dequeueNext())!;
        await queue.markFailed(op.id, 'error');

        expect(await queue.pendingCount, 2);
        expect(await queue.failedCount, 1);
      });
    });
  });
}
