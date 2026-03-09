import 'package:drift/drift.dart';
import 'package:family_chores_app/core/database/app_database.dart';
import 'package:family_chores_app/core/enums/operation_type.dart';

abstract class SyncOperationFixtures {
  SyncOperationFixtures._();

  static SyncOperationsTableCompanion pendingCreate({
    String entityType = 'task',
    String entityId = 'task-1',
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime(2026, 3, 5, 10);
    return SyncOperationsTableCompanion.insert(
      entityType: entityType,
      entityId: entityId,
      operationType: OperationType.create,
      payload: '{"title":"Test task","points":10}',
      timestamp: now,
      createdAt: now,
    );
  }

  static SyncOperationsTableCompanion failed({
    String entityId = 'task-failed',
    int retryCount = 3,
    String errorMessage = 'Firestore write failed',
  }) {
    return pendingCreate(entityId: entityId).copyWith(
      status: const Value('failed'),
      retryCount: Value(retryCount),
      errorMessage: Value(errorMessage),
    );
  }
}
