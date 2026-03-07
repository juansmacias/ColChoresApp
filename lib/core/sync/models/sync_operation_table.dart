import 'package:drift/drift.dart';

import '../../database/converters/enum_converters.dart';

@TableIndex(
  name: 'sync_ops_status_created',
  columns: {#status, #createdAt},
)
class SyncOperationsTable extends Table {
  @override
  String get tableName => 'sync_operations';

  IntColumn get id => integer().autoIncrement()();

  /// Entity type: "task", "reward", "member", "family", "redemption", "category"
  TextColumn get entityType => text()();

  /// UUID of the affected entity.
  TextColumn get entityId => text()();

  /// CRUD operation type.
  TextColumn get operationType => text().map(const OperationTypeConverter())();

  /// JSON-serialized entity state at the time of the operation.
  TextColumn get payload => text()();

  /// Local device time — used for FIFO ordering only, NOT conflict resolution.
  DateTimeColumn get timestamp => dateTime()();

  /// Processing status: "pending", "inProgress", "completed", "failed"
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Number of sync attempts. Max 3 before moving to "failed".
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}
