import 'package:drift/drift.dart';

import '../../../../core/database/converters/enum_converters.dart';
import '../../../../core/database/converters/list_converter.dart';
import 'subtask_model.dart';

@TableIndex(name: 'tasks_remote_id', columns: {#remoteId}, unique: true)
@TableIndex(
  name: 'tasks_family_status_due',
  columns: {#familyId, #status, #dueDate},
)
@TableIndex(name: 'tasks_family_completed', columns: {#familyId, #completedAt})
@TableIndex(name: 'tasks_family_category', columns: {#familyId, #category})
class TasksTable extends Table {
  @override
  String get tableName => 'tasks';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get familyId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get category => text()();

  /// JSON-encoded `List<String>` of member IDs assigned to this task.
  TextColumn get assigneeIds => text()
      .withDefault(const Constant('[]'))
      .map(const StringListConverter())();

  TextColumn get createdBy => text()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get dueTime => text().nullable()();
  TextColumn get recurrenceRule => text().nullable()();
  IntColumn get points => integer().withDefault(const Constant(0))();
  TextColumn get ageGroup => text().map(const AgeGroupConverter())();
  TextColumn get status => text()
      .withDefault(const Constant('pending'))
      .map(const TaskStatusConverter())();
  BoolColumn get requiresVerification =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get requiresPhoto =>
      boolean().withDefault(const Constant(false))();

  /// JSON-encoded `List<SubtaskModel>`.
  TextColumn get subtasks => text()
      .withDefault(const Constant('[]'))
      .map(const SubtaskListConverter())();

  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get completedBy => text().nullable()();
  DateTimeColumn get verifiedAt => dateTime().nullable()();
  TextColumn get verifiedBy => text().nullable()();
  TextColumn get localPhotoPath => text().nullable()();
  TextColumn get photoUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncStatus => text()
      .withDefault(const Constant('pending'))
      .map(const SyncStatusConverter())();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}
