# Task Data Layer

## 1. Overview

### 1.1 Summary

This specification defines the complete data layer for Task Management: Drift DAOs (local datasources), Firestore remote datasources, and repository implementations for both tasks and categories. The data layer implements the abstract interfaces defined in `specs/18_task_domain.md` and integrates with the SyncEngine from `specs/03_sync_engine.md`. All writes go to the local Drift database first, then enqueue a SyncOperation for asynchronous Firestore sync. All reads come exclusively from the local Drift database.

### 1.2 Business Context

The data layer is the bridge between the domain's pure business rules and the external infrastructure (SQLite via Drift, Firestore, Firebase Storage). Getting this layer right ensures offline-first reliability -- users can create, complete, and manage tasks without any internet connectivity. The SyncEngine integration ensures that changes eventually propagate to the cloud for multi-device sync and backup.

### 1.3 Scope

**In scope:**
- `TaskLocalDatasource` (Drift DAO): all CRUD + watch queries for tasks
- `CategoryLocalDatasource` (Drift DAO): all CRUD + watch queries for categories
- `TaskRemoteDatasource` (Firestore): upload, watch, delete operations
- `CategoryRemoteDatasource` (Firestore): upload, watch, delete operations
- `TaskRepositoryImpl`: implements `TaskRepository`, orchestrates local + sync
- `CategoryRepositoryImpl`: implements `CategoryRepository`, orchestrates local + sync
- Data model mappers: Drift companion <-> domain entity conversions
- Audit log remote datasource: write to Firestore subcollection

**Out of scope:**
- Domain entities and interfaces (see `specs/18_task_domain.md`)
- Presentation layer (see `specs/20_task_list_screen.md` through `specs/22_task_completion_flow.md`)
- SyncEngine internals (see `specs/03_sync_engine.md`)
- Drift table definitions (see `specs/02_isar_schemas.md`)

### 1.4 References

- `specs/02_isar_schemas.md` -- TasksTable, CategoriesTable, SyncOperationsTable definitions
- `specs/03_sync_engine.md` -- SyncEngine API, SyncOperation, OperationType
- `specs/06_error_handling.md` -- Failure types, Result wrapping
- `specs/18_task_domain.md` -- Task, Category entities, repository interfaces, failure types
- `CLAUDE.md` -- Offline-first architecture, sync metadata, conflict resolution

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| TDL-001 | TaskLocalDatasource provides reactive watch queries | High | `watchTasksForFamily` emits new list on any task insert/update/delete |
| TDL-002 | TaskLocalDatasource uses composite indexes for queries | High | Family + status + dueDate index used for dashboard queries |
| TDL-003 | TaskLocalDatasource inserts with syncStatus=pending | High | Every insert sets syncStatus to pending |
| TDL-004 | TaskLocalDatasource supports soft-delete | High | Soft-delete sets status to deleted, does not remove row |
| TDL-005 | TaskRemoteDatasource writes with server timestamps | High | All Firestore writes include `FieldValue.serverTimestamp()` |
| TDL-006 | TaskRemoteDatasource watches remote changes | High | Firestore `snapshots()` listener pushes changes to SyncEngine |
| TDL-007 | TaskRepositoryImpl creates tasks with UUID + sync enqueue | High | UUID generated, Drift insert, SyncOperation enqueued, Result returned |
| TDL-008 | TaskRepositoryImpl.completeTask awards points | High | Calls MemberRepository.addPoints on successful completion |
| TDL-009 | TaskRepositoryImpl wraps all exceptions in TaskFailure | High | No raw Drift/Firestore exceptions leak to callers |
| TDL-010 | CategoryLocalDatasource provides CRUD + watch | High | All operations work and emit stream updates |
| TDL-011 | CategoryRepositoryImpl seeds default categories | High | 8 defaults created idempotently on family creation |
| TDL-012 | Audit log entries written to Firestore subcollection | Medium | Every task state change produces an immutable audit entry |
| TDL-013 | Data mappers convert correctly in both directions | High | Drift row -> domain entity and domain entity -> Drift companion roundtrip without data loss |
| TDL-014 | Pending sync count watch query works | High | Returns correct count of pending SyncOperations for tasks |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| TDL-NFR-001 | Drift query performance | Time for watchTasksForFamily (100 tasks) | < 10ms |
| TDL-NFR-002 | Drift insert performance | Time for single task insert | < 5ms |
| TDL-NFR-003 | Drift update performance | Time for single task update | < 5ms |
| TDL-NFR-004 | Stream emission latency | Time from Drift write to stream emission | < 50ms |
| TDL-NFR-005 | Repository method response time | Time from call to Result return | < 20ms (excluding sync) |

### 2.3 Assumptions

- The Drift `AppDatabase` is already configured with `TasksTable` and `CategoriesTable` from Phase 1.
- The `SyncEngine` accepts `SyncOperation` objects via `enqueue(operation)` and processes them asynchronously.
- The `MemberRepository` from Phase 2 provides `addPoints(String memberId, int points)` for point awards.
- The `IdGenerator` from Phase 1 provides `generateId()` returning a UUID v4 string.
- Firestore collection paths follow the convention: `families/{familyId}/tasks/{taskId}`.

### 2.4 Constraints

- Drift DAOs must use `@DriftAccessor(tables: [TasksTable, ...])` annotations for code generation.
- Firestore writes from the remote datasource are never called directly by the repository -- they are triggered by the SyncEngine when processing the operation queue.
- The remote datasource's `watchRemoteTaskChanges` is used by the SyncEngine to detect incoming changes -- the repository does not subscribe to it directly.
- Subtasks are stored as JSON text in Drift (column type `TextColumn`) and deserialized on read.

---

## 3. Data Model Mappers

### 3.1 Task Mapper

```dart
// lib/features/tasks/data/mappers/task_mapper.dart
import '../../domain/entities/task.dart';
import '../../domain/entities/subtask.dart';
import '../../../../core/enums/age_group.dart';
import '../../../../core/enums/sync_status.dart';
import '../../../../core/enums/task_status.dart';
import 'dart:convert';

/// Converts between Drift TasksTableData and domain Task entity.
///
/// This mapper is the single point where data layer types
/// cross into domain types. It handles:
/// - Subtask JSON deserialization
/// - AssigneeIds JSON deserialization (stored as JSON array in Drift)
/// - Enum mapping (stored as strings in Drift)
abstract class TaskMapper {
  /// Converts a Drift row to a domain entity.
  static Task fromDrift(TasksTableData row) {
    return Task(
      id: row.id,
      familyId: row.familyId,
      title: row.title,
      description: row.description,
      category: row.category,
      assigneeIds: _parseStringList(row.assigneeIds),
      createdByMemberId: row.createdByMemberId,
      dueDate: row.dueDate,
      recurrenceRule: row.recurrenceRule,
      points: row.points,
      ageGroup: row.ageGroup,
      status: row.status,
      photoUrl: row.photoUrl,
      photoProofRequired: row.photoProofRequired,
      subtasks: _parseSubtasks(row.subtasks),
      completedAt: row.completedAt,
      completedByMemberId: row.completedByMemberId,
      parentTaskId: row.parentTaskId,
      isTemplate: row.isTemplate,
      remoteId: row.remoteId,
      syncStatus: row.syncStatus,
      lastSyncedAt: row.lastSyncedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// Converts a domain entity to a Drift companion for insert/update.
  static TasksTableCompanion toDriftCompanion(Task task) {
    return TasksTableCompanion(
      id: Value(task.id),
      familyId: Value(task.familyId),
      title: Value(task.title),
      description: Value(task.description),
      category: Value(task.category),
      assigneeIds: Value(_encodeStringList(task.assigneeIds)),
      createdByMemberId: Value(task.createdByMemberId),
      dueDate: Value(task.dueDate),
      recurrenceRule: Value(task.recurrenceRule),
      points: Value(task.points),
      ageGroup: Value(task.ageGroup),
      status: Value(task.status),
      photoUrl: Value(task.photoUrl),
      photoProofRequired: Value(task.photoProofRequired),
      subtasks: Value(_encodeSubtasks(task.subtasks)),
      completedAt: Value(task.completedAt),
      completedByMemberId: Value(task.completedByMemberId),
      parentTaskId: Value(task.parentTaskId),
      isTemplate: Value(task.isTemplate),
      remoteId: Value(task.remoteId),
      syncStatus: Value(task.syncStatus),
      lastSyncedAt: Value(task.lastSyncedAt),
      createdAt: Value(task.createdAt),
      updatedAt: Value(task.updatedAt),
    );
  }

  /// Converts a Firestore document map to a domain entity.
  static Task fromFirestore(
    String documentId,
    Map<String, dynamic> data,
    String familyId,
  ) {
    return Task(
      id: documentId, // Use Firestore doc ID as remoteId mapping
      familyId: familyId,
      title: data['title'] as String,
      description: data['description'] as String?,
      category: data['category'] as String,
      assigneeIds: List<String>.from(data['assigneeIds'] ?? []),
      createdByMemberId: data['createdByMemberId'] as String,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      recurrenceRule: data['recurrenceRule'] as String?,
      points: data['points'] as int,
      ageGroup: AgeGroup.values.byName(data['ageGroup'] as String),
      status: TaskStatus.values.byName(data['status'] as String),
      photoUrl: data['photoUrl'] as String?,
      photoProofRequired: data['photoProofRequired'] as bool? ?? false,
      subtasks: (data['subtasks'] as List<dynamic>?)
              ?.map((s) => Subtask(
                    title: s['title'] as String,
                    isCompleted: s['isCompleted'] as bool? ?? false,
                  ))
              .toList() ??
          [],
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      completedByMemberId: data['completedByMemberId'] as String?,
      parentTaskId: data['parentTaskId'] as String?,
      isTemplate: data['isTemplate'] as bool? ?? false,
      remoteId: documentId,
      syncStatus: SyncStatus.synced,
      lastSyncedAt: DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Converts a domain entity to a Firestore document map.
  static Map<String, dynamic> toFirestore(Task task) {
    return {
      'title': task.title,
      'description': task.description,
      'category': task.category,
      'assigneeIds': task.assigneeIds,
      'createdByMemberId': task.createdByMemberId,
      'dueDate': task.dueDate != null
          ? Timestamp.fromDate(task.dueDate!)
          : null,
      'recurrenceRule': task.recurrenceRule,
      'points': task.points,
      'ageGroup': task.ageGroup.name,
      'status': task.status.name,
      'photoUrl': task.photoUrl,
      'photoProofRequired': task.photoProofRequired,
      'subtasks': task.subtasks
          .map((s) => {'title': s.title, 'isCompleted': s.isCompleted})
          .toList(),
      'completedAt': task.completedAt != null
          ? Timestamp.fromDate(task.completedAt!)
          : null,
      'completedByMemberId': task.completedByMemberId,
      'parentTaskId': task.parentTaskId,
      'isTemplate': task.isTemplate,
      'createdAt': Timestamp.fromDate(task.createdAt),
      'updatedAt': FieldValue.serverTimestamp(), // Server timestamp for LWW
    };
  }

  // --- Private helpers ---

  static List<String> _parseStringList(String? json) {
    if (json == null || json.isEmpty) return [];
    return List<String>.from(jsonDecode(json) as List);
  }

  static String _encodeStringList(List<String> list) {
    return jsonEncode(list);
  }

  static List<Subtask> _parseSubtasks(String? json) {
    if (json == null || json.isEmpty) return [];
    final list = jsonDecode(json) as List;
    return list
        .map((item) => Subtask(
              title: item['title'] as String,
              isCompleted: item['isCompleted'] as bool? ?? false,
            ))
        .toList();
  }

  static String _encodeSubtasks(List<Subtask> subtasks) {
    return jsonEncode(subtasks
        .map((s) => {'title': s.title, 'isCompleted': s.isCompleted})
        .toList());
  }
}
```

### 3.2 Category Mapper

```dart
// lib/features/tasks/data/mappers/category_mapper.dart
import '../../domain/entities/category.dart';
import '../../../../core/enums/sync_status.dart';

/// Converts between Drift CategoriesTableData and domain Category entity.
abstract class CategoryMapper {
  static Category fromDrift(CategoriesTableData row) {
    return Category(
      id: row.id,
      familyId: row.familyId,
      name: row.name,
      icon: row.icon,
      color: row.color,
      isDefault: row.isDefault,
      remoteId: row.remoteId,
      syncStatus: row.syncStatus,
      lastSyncedAt: row.lastSyncedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static CategoriesTableCompanion toDriftCompanion(Category category) {
    return CategoriesTableCompanion(
      id: Value(category.id),
      familyId: Value(category.familyId),
      name: Value(category.name),
      icon: Value(category.icon),
      color: Value(category.color),
      isDefault: Value(category.isDefault),
      remoteId: Value(category.remoteId),
      syncStatus: Value(category.syncStatus),
      lastSyncedAt: Value(category.lastSyncedAt),
      createdAt: Value(category.createdAt),
      updatedAt: Value(category.updatedAt),
    );
  }

  static Category fromFirestore(
    String documentId,
    Map<String, dynamic> data,
    String familyId,
  ) {
    return Category(
      id: documentId,
      familyId: familyId,
      name: data['name'] as String,
      icon: data['icon'] as String,
      color: data['color'] as String,
      isDefault: data['isDefault'] as bool? ?? false,
      remoteId: documentId,
      syncStatus: SyncStatus.synced,
      lastSyncedAt: DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  static Map<String, dynamic> toFirestore(Category category) {
    return {
      'name': category.name,
      'icon': category.icon,
      'color': category.color,
      'isDefault': category.isDefault,
      'createdAt': Timestamp.fromDate(category.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
```

---

## 4. Local Datasources (Drift DAOs)

### 4.1 TaskLocalDatasource

```dart
// lib/features/tasks/data/datasources/task_local_datasource.dart
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/enums/sync_status.dart';
import '../../../../core/enums/task_status.dart';

part 'task_local_datasource.g.dart';

/// Drift DAO for task operations against the local SQLite database.
///
/// All queries use the composite indexes defined in specs/02_isar_schemas.md:
/// - Index 1: (familyId, status, dueDate) -- dashboard/pending tasks
/// - Index 2: (familyId, assigneeIds, status) -- member task list
/// - Index 3: (familyId, status, completedAt) -- fairness dashboard
///
/// This DAO is the ONLY way to access task data locally.
/// It is never called directly from UI -- always through TaskRepositoryImpl.
@DriftAccessor(tables: [TasksTable])
@lazySingleton
class TaskLocalDatasource extends DatabaseAccessor<AppDatabase>
    with _$TaskLocalDatasourceMixin {
  TaskLocalDatasource(super.db);

  /// Watches all non-template tasks for a family, ordered by due date.
  ///
  /// Uses Index 1: (familyId, status, dueDate).
  /// Excludes tasks with isTemplate=true (recurring templates).
  /// Excludes soft-deleted tasks.
  ///
  /// SQL equivalent:
  /// SELECT * FROM tasks
  /// WHERE family_id = ? AND is_template = 0
  ///   AND status != 'deleted'
  /// ORDER BY
  ///   CASE WHEN due_date IS NULL THEN 1 ELSE 0 END,
  ///   due_date ASC,
  ///   created_at DESC
  Stream<List<TasksTableData>> watchTasksForFamily(String familyId) {
    return (select(tasksTable)
          ..where((t) => t.familyId.equals(familyId))
          ..where((t) => t.isTemplate.equals(false))
          ..where((t) => t.status.isNotIn(
              [TaskStatus.deleted.name]))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.dueDate.isNull().caseMatch(
                  when: {const Constant(true): const Constant(1)},
                  orElse: const Constant(0),
                )),
            (t) => OrderingTerm.asc(t.dueDate),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  /// Watches tasks assigned to a specific member within a family.
  ///
  /// Uses Index 2: (familyId, assigneeIds, status).
  /// Includes tasks where assigneeIds contains the memberId
  /// OR assigneeIds is empty (shared pool).
  /// Excludes templates and soft-deleted tasks.
  ///
  /// Note: Since assigneeIds is stored as JSON text, we use LIKE
  /// for containment check. This is acceptable for family-sized datasets
  /// (< 200 tasks) but would need a junction table for larger scales.
  ///
  /// SQL equivalent:
  /// SELECT * FROM tasks
  /// WHERE family_id = ? AND is_template = 0
  ///   AND status != 'deleted'
  ///   AND (assignee_ids LIKE '%"memberId"%' OR assignee_ids = '[]')
  /// ORDER BY due_date ASC
  Stream<List<TasksTableData>> watchTasksForMember(
    String familyId,
    String memberId,
  ) {
    return (select(tasksTable)
          ..where((t) => t.familyId.equals(familyId))
          ..where((t) => t.isTemplate.equals(false))
          ..where((t) => t.status.isNotIn(
              [TaskStatus.deleted.name]))
          ..where((t) =>
              t.assigneeIds.like('%"$memberId"%') |
              t.assigneeIds.equals('[]'))
          ..orderBy([
            (t) => OrderingTerm.asc(t.dueDate),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  /// Gets a single task by its local ID.
  ///
  /// SQL equivalent:
  /// SELECT * FROM tasks WHERE id = ? LIMIT 1
  Future<TasksTableData?> getTask(String taskId) {
    return (select(tasksTable)..where((t) => t.id.equals(taskId)))
        .getSingleOrNull();
  }

  /// Inserts a new task with syncStatus=pending.
  ///
  /// SQL equivalent:
  /// INSERT INTO tasks (...) VALUES (...)
  Future<void> insertTask(TasksTableCompanion companion) {
    return into(tasksTable).insert(companion);
  }

  /// Updates an existing task, sets syncStatus=pending and bumps updatedAt.
  ///
  /// SQL equivalent:
  /// UPDATE tasks SET ... WHERE id = ?
  Future<void> updateTask(TasksTableCompanion companion) {
    return (update(tasksTable)
          ..where((t) => t.id.equals(companion.id.value)))
        .write(companion);
  }

  /// Marks a task as completed.
  /// Atomic update of status, completedAt, completedByMemberId, and subtasks.
  ///
  /// SQL equivalent:
  /// UPDATE tasks
  /// SET status = 'completed', completed_at = ?, completed_by_member_id = ?,
  ///     subtasks = ?, sync_status = 'pending', updated_at = ?
  /// WHERE id = ?
  Future<void> markCompleted({
    required String taskId,
    required String completedByMemberId,
    required DateTime completedAt,
    String? subtasksJson,
    String? photoUrl,
  }) {
    return (update(tasksTable)..where((t) => t.id.equals(taskId))).write(
      TasksTableCompanion(
        status: const Value(TaskStatus.completed),
        completedAt: Value(completedAt),
        completedByMemberId: Value(completedByMemberId),
        subtasks: subtasksJson != null ? Value(subtasksJson) : const Value.absent(),
        photoUrl: photoUrl != null ? Value(photoUrl) : const Value.absent(),
        syncStatus: const Value(SyncStatus.pending),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Marks a task as verified by a parent.
  ///
  /// SQL equivalent:
  /// UPDATE tasks SET status = 'verified', sync_status = 'pending',
  ///   updated_at = ? WHERE id = ?
  Future<void> markVerified(String taskId) {
    return (update(tasksTable)..where((t) => t.id.equals(taskId))).write(
      TasksTableCompanion(
        status: const Value(TaskStatus.verified),
        syncStatus: const Value(SyncStatus.pending),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Marks a task as skipped.
  ///
  /// SQL equivalent:
  /// UPDATE tasks SET status = 'skipped', sync_status = 'pending',
  ///   updated_at = ? WHERE id = ?
  Future<void> markSkipped(String taskId) {
    return (update(tasksTable)..where((t) => t.id.equals(taskId))).write(
      TasksTableCompanion(
        status: const Value(TaskStatus.skipped),
        syncStatus: const Value(SyncStatus.pending),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Soft-deletes a task by marking it with a deleted status.
  /// The row remains in the database until the SyncEngine confirms
  /// the Firestore delete, at which point it is hard-deleted.
  ///
  /// SQL equivalent:
  /// UPDATE tasks SET status = 'deleted', sync_status = 'pending',
  ///   updated_at = ? WHERE id = ?
  Future<void> softDeleteTask(String taskId) {
    return (update(tasksTable)..where((t) => t.id.equals(taskId))).write(
      TasksTableCompanion(
        status: const Value(TaskStatus.deleted),
        syncStatus: const Value(SyncStatus.pending),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Hard-deletes a task row from the database.
  /// Called by SyncEngine after confirming Firestore deletion.
  ///
  /// SQL equivalent:
  /// DELETE FROM tasks WHERE id = ?
  Future<void> hardDeleteTask(String taskId) {
    return (delete(tasksTable)..where((t) => t.id.equals(taskId))).go();
  }

  /// Updates the assigneeIds for a task (reassignment).
  ///
  /// SQL equivalent:
  /// UPDATE tasks SET assignee_ids = ?, sync_status = 'pending',
  ///   updated_at = ? WHERE id = ?
  Future<void> reassignTask(String taskId, String assigneeIdsJson) {
    return (update(tasksTable)..where((t) => t.id.equals(taskId))).write(
      TasksTableCompanion(
        assigneeIds: Value(assigneeIdsJson),
        syncStatus: const Value(SyncStatus.pending),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Gets all recurring task templates for a family.
  ///
  /// SQL equivalent:
  /// SELECT * FROM tasks
  /// WHERE family_id = ? AND is_template = 1
  ///   AND status != 'deleted'
  Future<List<TasksTableData>> getRecurringTemplates(String familyId) {
    return (select(tasksTable)
          ..where((t) => t.familyId.equals(familyId))
          ..where((t) => t.isTemplate.equals(true))
          ..where((t) => t.status.isNotIn(
              [TaskStatus.deleted.name])))
        .get();
  }

  /// Checks if a recurring instance already exists for a given
  /// parent template and due date (deduplication).
  ///
  /// SQL equivalent:
  /// SELECT COUNT(*) FROM tasks
  /// WHERE parent_task_id = ? AND due_date = ?
  Future<bool> instanceExists(String parentTaskId, DateTime dueDate) async {
    final count = await (select(tasksTable)
          ..where((t) => t.parentTaskId.equals(parentTaskId))
          ..where((t) => t.dueDate.equals(dueDate)))
        .get();
    return count.isNotEmpty;
  }

  /// Watches the count of pending sync operations for tasks.
  /// This drives the "pending sync" badge in the AppBar.
  ///
  /// Note: This queries the SyncOperationsTable, not TasksTable.
  /// The query filters by entityType = 'task' OR entityType = 'category'.
  Stream<int> watchPendingSyncCount(String familyId) {
    // This is implemented as a custom query since it crosses tables.
    // The actual implementation will use a custom select on
    // SyncOperationsTable filtered by familyId and entityType.
    return customSelect(
      'SELECT COUNT(*) AS c FROM sync_operations '
      'WHERE family_id = ? AND status = ? '
      'AND entity_type IN (?, ?)',
      variables: [
        Variable.withString(familyId),
        Variable.withString('pending'),
        Variable.withString('task'),
        Variable.withString('category'),
      ],
      readsFrom: {db.syncOperationsTable},
    ).map((row) => row.read<int>('c')).watch();
  }
}
```

### 4.2 CategoryLocalDatasource

```dart
// lib/features/tasks/data/datasources/category_local_datasource.dart
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/enums/sync_status.dart';

part 'category_local_datasource.g.dart';

/// Drift DAO for category operations against the local SQLite database.
@DriftAccessor(tables: [CategoriesTable])
@lazySingleton
class CategoryLocalDatasource extends DatabaseAccessor<AppDatabase>
    with _$CategoryLocalDatasourceMixin {
  CategoryLocalDatasource(super.db);

  /// Watches all categories for a family, ordered by name.
  /// Default categories appear first, then custom categories.
  ///
  /// SQL equivalent:
  /// SELECT * FROM categories
  /// WHERE family_id = ?
  /// ORDER BY is_default DESC, name ASC
  Stream<List<CategoriesTableData>> watchCategories(String familyId) {
    return (select(categoriesTable)
          ..where((c) => c.familyId.equals(familyId))
          ..orderBy([
            (c) => OrderingTerm.desc(c.isDefault),
            (c) => OrderingTerm.asc(c.name),
          ]))
        .watch();
  }

  /// Gets a single category by ID.
  Future<CategoriesTableData?> getCategory(String categoryId) {
    return (select(categoriesTable)
          ..where((c) => c.id.equals(categoryId)))
        .getSingleOrNull();
  }

  /// Gets a category by name within a family (for uniqueness check).
  Future<CategoriesTableData?> getCategoryByName(
    String familyId,
    String name,
  ) {
    return (select(categoriesTable)
          ..where((c) => c.familyId.equals(familyId))
          ..where((c) => c.name.equals(name)))
        .getSingleOrNull();
  }

  /// Inserts a new category with syncStatus=pending.
  Future<void> insertCategory(CategoriesTableCompanion companion) {
    return into(categoriesTable).insert(companion);
  }

  /// Updates an existing category.
  Future<void> updateCategory(CategoriesTableCompanion companion) {
    return (update(categoriesTable)
          ..where((c) => c.id.equals(companion.id.value)))
        .write(companion);
  }

  /// Deletes a category row from the database.
  Future<void> deleteCategory(String categoryId) {
    return (delete(categoriesTable)
          ..where((c) => c.id.equals(categoryId)))
        .go();
  }

  /// Counts non-completed tasks that reference a category name.
  /// Used before category deletion to warn the user.
  ///
  /// Note: This queries TasksTable by category name (string match),
  /// since categories are referenced by name, not ID.
  Future<int> countActiveTasksForCategory(
    String familyId,
    String categoryName,
  ) async {
    final result = await customSelect(
      'SELECT COUNT(*) AS c FROM tasks '
      'WHERE family_id = ? AND category = ? '
      'AND status NOT IN (?, ?, ?)',
      variables: [
        Variable.withString(familyId),
        Variable.withString(categoryName),
        Variable.withString(TaskStatus.completed.name),
        Variable.withString(TaskStatus.verified.name),
        Variable.withString(TaskStatus.skipped.name),
      ],
      readsFrom: {db.tasksTable},
    ).getSingle();
    return result.read<int>('c');
  }
}
```

---

## 5. Remote Datasources (Firestore)

### 5.1 TaskRemoteDatasource

```dart
// lib/features/tasks/data/datasources/task_remote_datasource.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/task.dart';
import '../../domain/entities/audit_log_entry.dart';
import '../mappers/task_mapper.dart';

/// Firestore operations for tasks.
///
/// IMPORTANT: This datasource is NEVER called directly from the UI
/// or from the repository. It is called exclusively by the SyncEngine
/// when processing the operation queue.
///
/// The only exception is `watchRemoteTaskChanges`, which the SyncEngine
/// subscribes to for incoming changes from other devices.
@lazySingleton
class TaskRemoteDatasource {
  TaskRemoteDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  /// Reference to the tasks collection for a family.
  CollectionReference<Map<String, dynamic>> _tasksRef(String familyId) =>
      _firestore
          .collection('families')
          .doc(familyId)
          .collection('tasks');

  /// Reference to the audit_log subcollection for a task.
  CollectionReference<Map<String, dynamic>> _auditLogRef(
    String familyId,
    String taskId,
  ) =>
      _tasksRef(familyId).doc(taskId).collection('audit_log');

  /// Uploads a task to Firestore.
  /// Used by SyncEngine for create and update operations.
  ///
  /// Uses `set` with merge to handle both create and update.
  /// The `updatedAt` field uses `FieldValue.serverTimestamp()`
  /// for LWW conflict resolution.
  Future<void> uploadTask(Task task) async {
    final data = TaskMapper.toFirestore(task);
    await _tasksRef(task.familyId)
        .doc(task.remoteId ?? task.id)
        .set(data, SetOptions(merge: true));
  }

  /// Deletes a task from Firestore.
  /// Used by SyncEngine for delete operations.
  Future<void> deleteTask(String familyId, String taskId) async {
    await _tasksRef(familyId).doc(taskId).delete();
  }

  /// Watches all task changes in a family's Firestore collection.
  /// Used by SyncEngine to detect incoming changes from other devices.
  ///
  /// Returns a stream of document change events (added, modified, removed).
  Stream<QuerySnapshot<Map<String, dynamic>>> watchRemoteTaskChanges(
    String familyId,
  ) {
    return _tasksRef(familyId).snapshots();
  }

  /// Gets a single task from Firestore by document ID.
  /// Used by SyncEngine during conflict resolution to get server version.
  Future<Task?> getTask(String familyId, String taskId) async {
    final doc = await _tasksRef(familyId).doc(taskId).get();
    if (!doc.exists || doc.data() == null) return null;
    return TaskMapper.fromFirestore(doc.id, doc.data()!, familyId);
  }

  /// Writes an audit log entry to the task's audit_log subcollection.
  /// Audit log entries are immutable -- they can never be updated or deleted.
  Future<void> writeAuditLogEntry(
    String familyId,
    String taskId,
    AuditLogEntry entry,
  ) async {
    await _auditLogRef(familyId, taskId).doc(entry.id).set({
      'eventType': entry.eventType.name,
      'memberId': entry.memberId,
      'timestamp': Timestamp.fromDate(entry.timestamp),
      'previousState': entry.previousState,
      'newState': entry.newState,
      'description': entry.description,
    });
  }

  /// Reads audit log entries for a task, ordered by timestamp descending.
  /// Used by TaskDetailScreen to display task history.
  Future<List<AuditLogEntry>> getAuditLog(
    String familyId,
    String taskId,
  ) async {
    final snapshot = await _auditLogRef(familyId, taskId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return AuditLogEntry(
        id: doc.id,
        eventType: AuditEventType.values.byName(data['eventType'] as String),
        memberId: data['memberId'] as String,
        timestamp: (data['timestamp'] as Timestamp).toDate(),
        previousState: data['previousState'] as String?,
        newState: data['newState'] as String?,
        description: data['description'] as String?,
      );
    }).toList();
  }
}
```

### 5.2 CategoryRemoteDatasource

```dart
// lib/features/tasks/data/datasources/category_remote_datasource.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/category.dart';
import '../mappers/category_mapper.dart';

/// Firestore operations for categories.
///
/// Same pattern as TaskRemoteDatasource: called by SyncEngine only,
/// never directly from UI or repository.
@lazySingleton
class CategoryRemoteDatasource {
  CategoryRemoteDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _categoriesRef(String familyId) =>
      _firestore
          .collection('families')
          .doc(familyId)
          .collection('categories');

  /// Uploads a category to Firestore.
  Future<void> uploadCategory(Category category) async {
    final data = CategoryMapper.toFirestore(category);
    await _categoriesRef(category.familyId)
        .doc(category.remoteId ?? category.id)
        .set(data, SetOptions(merge: true));
  }

  /// Deletes a category from Firestore.
  Future<void> deleteCategory(String familyId, String categoryId) async {
    await _categoriesRef(familyId).doc(categoryId).delete();
  }

  /// Watches all category changes in a family's Firestore collection.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchRemoteCategoryChanges(
    String familyId,
  ) {
    return _categoriesRef(familyId).snapshots();
  }
}
```

---

## 6. Repository Implementations

### 6.1 TaskRepositoryImpl

```dart
// lib/features/tasks/data/repositories/task_repository_impl.dart
import 'dart:convert';

import 'package:injectable/injectable.dart';

import '../../../../core/enums/sync_status.dart';
import '../../../../core/enums/task_status.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../core/sync/sync_operation.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/utils/result.dart';
import '../../../family/domain/repositories/member_repository.dart';
import '../../domain/entities/audit_log_entry.dart';
import '../../domain/entities/task.dart';
import '../../domain/enums/audit_event_type.dart';
import '../../domain/events/task_events.dart';
import '../../domain/failures/task_failures.dart';
import '../../domain/params/complete_task_params.dart';
import '../../domain/params/create_task_params.dart';
import '../../domain/params/update_task_params.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/task_local_datasource.dart';
import '../datasources/task_remote_datasource.dart';
import '../mappers/task_mapper.dart';

/// Concrete implementation of [TaskRepository].
///
/// Orchestrates:
/// - Local Drift operations (all reads + all initial writes)
/// - SyncEngine enqueue (for Firestore sync)
/// - MemberRepository (for point awards)
/// - Audit log entries (for traceability)
///
/// This class NEVER calls TaskRemoteDatasource directly.
/// All Firestore operations go through the SyncEngine.
@LazySingleton(as: TaskRepository)
class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl(
    this._localDatasource,
    this._remoteDatasource,
    this._syncEngine,
    this._memberRepository,
    this._idGenerator,
  );

  final TaskLocalDatasource _localDatasource;
  final TaskRemoteDatasource _remoteDatasource;
  final SyncEngine _syncEngine;
  final MemberRepository _memberRepository;
  final IdGenerator _idGenerator;

  @override
  Stream<List<Task>> watchTasksForFamily(String familyId) {
    return _localDatasource
        .watchTasksForFamily(familyId)
        .map((rows) => rows.map(TaskMapper.fromDrift).toList());
  }

  @override
  Stream<List<Task>> watchTasksForMember(
    String familyId,
    String memberId,
  ) {
    return _localDatasource
        .watchTasksForMember(familyId, memberId)
        .map((rows) => rows.map(TaskMapper.fromDrift).toList());
  }

  @override
  Future<Result<Task>> getTask(String taskId) async {
    try {
      final row = await _localDatasource.getTask(taskId);
      if (row == null) {
        return const Result.failure(TaskNotFoundFailure());
      }
      return Result.success(TaskMapper.fromDrift(row));
    } catch (e, st) {
      return Result.failure(
        TaskUnknownFailure(stackTrace: st),
      );
    }
  }

  @override
  Future<Result<Task>> createTask(CreateTaskParams params) async {
    try {
      final now = DateTime.now();
      final taskId = _idGenerator.generateId();

      final task = Task(
        id: taskId,
        familyId: params.familyId,
        title: params.title.trim(),
        description: params.description?.trim(),
        category: params.category,
        assigneeIds: params.assigneeIds,
        createdByMemberId: params.createdByMemberId,
        dueDate: params.dueDate,
        recurrenceRule: params.recurrenceRule,
        points: params.points,
        ageGroup: params.ageGroup,
        status: TaskStatus.pending,
        photoProofRequired: params.photoProofRequired,
        subtasks: params.subtasks,
        isTemplate: params.recurrenceRule != null,
        syncStatus: SyncStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      // 1. Write to local Drift DB
      final companion = TaskMapper.toDriftCompanion(task);
      await _localDatasource.insertTask(companion);

      // 2. Enqueue sync operation
      await _syncEngine.enqueue(
        SyncOperation(
          id: _idGenerator.generateId(),
          entityType: 'task',
          entityId: taskId,
          operationType: OperationType.create,
          familyId: params.familyId,
          payload: TaskMapper.toFirestore(task),
          createdAt: now,
        ),
      );

      // 3. Write audit log entry
      await _enqueueAuditLog(
        familyId: params.familyId,
        taskId: taskId,
        eventType: AuditEventType.created,
        memberId: params.createdByMemberId,
        description: 'Task "${params.title}" created',
      );

      return Result.success(task);
    } catch (e, st) {
      return Result.failure(
        TaskUnknownFailure(stackTrace: st),
      );
    }
  }

  @override
  Future<Result<Task>> updateTask(UpdateTaskParams params) async {
    try {
      // Get existing task
      final existingRow = await _localDatasource.getTask(params.taskId);
      if (existingRow == null) {
        return const Result.failure(TaskNotFoundFailure());
      }

      final existing = TaskMapper.fromDrift(existingRow);
      final now = DateTime.now();

      // Apply updates (only non-null params)
      final updated = existing.copyWith(
        title: params.title ?? existing.title,
        description: params.description ?? existing.description,
        category: params.category ?? existing.category,
        assigneeIds: params.assigneeIds ?? existing.assigneeIds,
        dueDate: params.clearDueDate ? null : (params.dueDate ?? existing.dueDate),
        recurrenceRule: params.clearRecurrenceRule
            ? null
            : (params.recurrenceRule ?? existing.recurrenceRule),
        points: params.points ?? existing.points,
        ageGroup: params.ageGroup ?? existing.ageGroup,
        photoProofRequired:
            params.photoProofRequired ?? existing.photoProofRequired,
        subtasks: params.subtasks ?? existing.subtasks,
        syncStatus: SyncStatus.pending,
        updatedAt: now,
      );

      // 1. Write to Drift
      final companion = TaskMapper.toDriftCompanion(updated);
      await _localDatasource.updateTask(companion);

      // 2. Enqueue sync
      await _syncEngine.enqueue(
        SyncOperation(
          id: _idGenerator.generateId(),
          entityType: 'task',
          entityId: params.taskId,
          operationType: OperationType.update,
          familyId: existing.familyId,
          payload: TaskMapper.toFirestore(updated),
          createdAt: now,
        ),
      );

      // 3. Audit log
      await _enqueueAuditLog(
        familyId: existing.familyId,
        taskId: params.taskId,
        eventType: AuditEventType.updated,
        memberId: existing.createdByMemberId, // TODO: use active profile
        description: 'Task updated',
      );

      return Result.success(updated);
    } catch (e, st) {
      return Result.failure(TaskUnknownFailure(stackTrace: st));
    }
  }

  @override
  Future<Result<void>> deleteTask(String taskId) async {
    try {
      final existingRow = await _localDatasource.getTask(taskId);
      if (existingRow == null) {
        return const Result.failure(TaskNotFoundFailure());
      }

      final existing = TaskMapper.fromDrift(existingRow);
      final now = DateTime.now();

      // 1. Soft-delete in Drift
      await _localDatasource.softDeleteTask(taskId);

      // 2. If this is a recurring template, also soft-delete all
      //    future pending instances
      if (existing.isTemplate) {
        // Get all instances of this template that are still pending
        final familyTasks = await _localDatasource
            .watchTasksForFamily(existing.familyId)
            .first;
        for (final instance in familyTasks) {
          if (instance.parentTaskId == taskId &&
              instance.status == TaskStatus.pending) {
            await _localDatasource.softDeleteTask(instance.id);
          }
        }
      }

      // 3. Enqueue sync (delete operation)
      await _syncEngine.enqueue(
        SyncOperation(
          id: _idGenerator.generateId(),
          entityType: 'task',
          entityId: taskId,
          operationType: OperationType.delete,
          familyId: existing.familyId,
          payload: {'taskId': taskId},
          createdAt: now,
        ),
      );

      // 4. Audit log
      await _enqueueAuditLog(
        familyId: existing.familyId,
        taskId: taskId,
        eventType: AuditEventType.deleted,
        memberId: existing.createdByMemberId,
        description: 'Task "${existing.title}" deleted',
      );

      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(TaskUnknownFailure(stackTrace: st));
    }
  }

  @override
  Future<Result<Task>> completeTask(CompleteTaskParams params) async {
    try {
      final existingRow = await _localDatasource.getTask(params.taskId);
      if (existingRow == null) {
        return const Result.failure(TaskNotFoundFailure());
      }

      final existing = TaskMapper.fromDrift(existingRow);
      final now = DateTime.now();

      // 1. Mark completed in Drift
      await _localDatasource.markCompleted(
        taskId: params.taskId,
        completedByMemberId: params.completedByMemberId,
        completedAt: now,
        subtasksJson: params.subtaskResults != null
            ? jsonEncode(params.subtaskResults!
                .map((s) => {'title': s.title, 'isCompleted': s.isCompleted})
                .toList())
            : null,
        photoUrl: params.photoUrl,
      );

      // 2. Award points to the completing member
      if (existing.points > 0) {
        await _memberRepository.addPoints(
          params.completedByMemberId,
          existing.points,
        );
      }

      // 3. Re-read the updated task
      final updatedRow = await _localDatasource.getTask(params.taskId);
      final updatedTask = TaskMapper.fromDrift(updatedRow!);

      // 4. Enqueue sync
      await _syncEngine.enqueue(
        SyncOperation(
          id: _idGenerator.generateId(),
          entityType: 'task',
          entityId: params.taskId,
          operationType: OperationType.update,
          familyId: existing.familyId,
          payload: TaskMapper.toFirestore(updatedTask),
          createdAt: now,
        ),
      );

      // 5. Audit log
      await _enqueueAuditLog(
        familyId: existing.familyId,
        taskId: params.taskId,
        eventType: AuditEventType.completed,
        memberId: params.completedByMemberId,
        description:
            'Task "${existing.title}" completed by ${params.completedByMemberId}',
      );

      // 6. Emit domain event for celebration animation
      _syncEngine.emitEvent(
        TaskCompletedEvent(
          taskId: params.taskId,
          taskTitle: existing.title,
          completedByMemberId: params.completedByMemberId,
          pointsAwarded: existing.points,
        ),
      );

      return Result.success(updatedTask);
    } catch (e, st) {
      return Result.failure(TaskUnknownFailure(stackTrace: st));
    }
  }

  @override
  Future<Result<void>> verifyTask(
    String taskId,
    String verifierMemberId,
  ) async {
    try {
      final existingRow = await _localDatasource.getTask(taskId);
      if (existingRow == null) {
        return const Result.failure(TaskNotFoundFailure());
      }

      final existing = TaskMapper.fromDrift(existingRow);
      final now = DateTime.now();

      // 1. Mark verified in Drift
      await _localDatasource.markVerified(taskId);

      // 2. Enqueue sync
      final updatedRow = await _localDatasource.getTask(taskId);
      await _syncEngine.enqueue(
        SyncOperation(
          id: _idGenerator.generateId(),
          entityType: 'task',
          entityId: taskId,
          operationType: OperationType.update,
          familyId: existing.familyId,
          payload: TaskMapper.toFirestore(TaskMapper.fromDrift(updatedRow!)),
          createdAt: now,
        ),
      );

      // 3. Audit log
      await _enqueueAuditLog(
        familyId: existing.familyId,
        taskId: taskId,
        eventType: AuditEventType.verified,
        memberId: verifierMemberId,
        description: 'Task "${existing.title}" verified',
      );

      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(TaskUnknownFailure(stackTrace: st));
    }
  }

  @override
  Future<Result<void>> skipTask(String taskId, String reason) async {
    try {
      final existingRow = await _localDatasource.getTask(taskId);
      if (existingRow == null) {
        return const Result.failure(TaskNotFoundFailure());
      }

      final existing = TaskMapper.fromDrift(existingRow);
      final now = DateTime.now();

      // 1. Mark skipped in Drift
      await _localDatasource.markSkipped(taskId);

      // 2. Enqueue sync
      final updatedRow = await _localDatasource.getTask(taskId);
      await _syncEngine.enqueue(
        SyncOperation(
          id: _idGenerator.generateId(),
          entityType: 'task',
          entityId: taskId,
          operationType: OperationType.update,
          familyId: existing.familyId,
          payload: TaskMapper.toFirestore(TaskMapper.fromDrift(updatedRow!)),
          createdAt: now,
        ),
      );

      // 3. Audit log
      await _enqueueAuditLog(
        familyId: existing.familyId,
        taskId: taskId,
        eventType: AuditEventType.skipped,
        memberId: existing.createdByMemberId,
        description: 'Task "${existing.title}" skipped. Reason: $reason',
      );

      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(TaskUnknownFailure(stackTrace: st));
    }
  }

  @override
  Future<Result<void>> reassignTask(
    String taskId,
    List<String> newAssigneeIds,
  ) async {
    try {
      final existingRow = await _localDatasource.getTask(taskId);
      if (existingRow == null) {
        return const Result.failure(TaskNotFoundFailure());
      }

      final existing = TaskMapper.fromDrift(existingRow);
      final now = DateTime.now();

      // 1. Update assignees in Drift
      await _localDatasource.reassignTask(
        taskId,
        jsonEncode(newAssigneeIds),
      );

      // 2. Enqueue sync
      final updatedRow = await _localDatasource.getTask(taskId);
      await _syncEngine.enqueue(
        SyncOperation(
          id: _idGenerator.generateId(),
          entityType: 'task',
          entityId: taskId,
          operationType: OperationType.update,
          familyId: existing.familyId,
          payload: TaskMapper.toFirestore(TaskMapper.fromDrift(updatedRow!)),
          createdAt: now,
        ),
      );

      // 3. Audit log
      await _enqueueAuditLog(
        familyId: existing.familyId,
        taskId: taskId,
        eventType: AuditEventType.reassigned,
        memberId: existing.createdByMemberId,
        description:
            'Task reassigned to ${newAssigneeIds.join(", ")}',
      );

      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(TaskUnknownFailure(stackTrace: st));
    }
  }

  @override
  Stream<int> watchPendingSyncCount(String familyId) {
    return _localDatasource.watchPendingSyncCount(familyId);
  }

  @override
  Future<Result<List<Task>>> getRecurringTemplates(String familyId) async {
    try {
      final rows = await _localDatasource.getRecurringTemplates(familyId);
      return Result.success(rows.map(TaskMapper.fromDrift).toList());
    } catch (e, st) {
      return Result.failure(TaskUnknownFailure(stackTrace: st));
    }
  }

  // --- Private Helpers ---

  /// Enqueues an audit log entry for Firestore write.
  /// Audit logs are not stored in Drift -- they go directly to Firestore
  /// via the SyncEngine when online, or are buffered as SyncOperations.
  Future<void> _enqueueAuditLog({
    required String familyId,
    required String taskId,
    required AuditEventType eventType,
    required String memberId,
    String? description,
    String? previousState,
    String? newState,
  }) async {
    final entry = AuditLogEntry(
      id: _idGenerator.generateId(),
      eventType: eventType,
      memberId: memberId,
      timestamp: DateTime.now(),
      previousState: previousState,
      newState: newState,
      description: description,
    );

    await _syncEngine.enqueue(
      SyncOperation(
        id: _idGenerator.generateId(),
        entityType: 'audit_log',
        entityId: entry.id,
        operationType: OperationType.create,
        familyId: familyId,
        payload: {
          'taskId': taskId,
          'eventType': entry.eventType.name,
          'memberId': entry.memberId,
          'timestamp': entry.timestamp.toIso8601String(),
          'previousState': entry.previousState,
          'newState': entry.newState,
          'description': entry.description,
        },
        createdAt: DateTime.now(),
      ),
    );
  }
}
```

### 6.2 CategoryRepositoryImpl

```dart
// lib/features/tasks/data/repositories/category_repository_impl.dart
import 'package:injectable/injectable.dart';

import '../../../../core/enums/sync_status.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../core/sync/sync_operation.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/utils/result.dart';
import '../../domain/constants/default_categories.dart';
import '../../domain/entities/category.dart';
import '../../domain/failures/task_failures.dart';
import '../../domain/params/create_category_params.dart';
import '../../domain/params/update_category_params.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/category_local_datasource.dart';
import '../mappers/category_mapper.dart';

/// Concrete implementation of [CategoryRepository].
@LazySingleton(as: CategoryRepository)
class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl(
    this._localDatasource,
    this._syncEngine,
    this._idGenerator,
  );

  final CategoryLocalDatasource _localDatasource;
  final SyncEngine _syncEngine;
  final IdGenerator _idGenerator;

  @override
  Stream<List<Category>> watchCategories(String familyId) {
    return _localDatasource
        .watchCategories(familyId)
        .map((rows) => rows.map(CategoryMapper.fromDrift).toList());
  }

  @override
  Future<Result<Category>> getCategory(String categoryId) async {
    try {
      final row = await _localDatasource.getCategory(categoryId);
      if (row == null) {
        return const Result.failure(CategoryNotFoundFailure());
      }
      return Result.success(CategoryMapper.fromDrift(row));
    } catch (e, st) {
      return Result.failure(TaskUnknownFailure(stackTrace: st));
    }
  }

  @override
  Future<Result<Category>> createCategory(CreateCategoryParams params) async {
    try {
      // Check for duplicate name
      final existing = await _localDatasource.getCategoryByName(
        params.familyId,
        params.name.trim(),
      );
      if (existing != null) {
        return Result.failure(
          const TaskValidationFailure(
            fieldErrors: {'name': 'A category with this name already exists.'},
          ),
        );
      }

      final now = DateTime.now();
      final categoryId = _idGenerator.generateId();

      final category = Category(
        id: categoryId,
        familyId: params.familyId,
        name: params.name.trim(),
        icon: params.icon,
        color: params.color,
        isDefault: false,
        syncStatus: SyncStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      // 1. Insert to Drift
      final companion = CategoryMapper.toDriftCompanion(category);
      await _localDatasource.insertCategory(companion);

      // 2. Enqueue sync
      await _syncEngine.enqueue(
        SyncOperation(
          id: _idGenerator.generateId(),
          entityType: 'category',
          entityId: categoryId,
          operationType: OperationType.create,
          familyId: params.familyId,
          payload: CategoryMapper.toFirestore(category),
          createdAt: now,
        ),
      );

      return Result.success(category);
    } catch (e, st) {
      return Result.failure(TaskUnknownFailure(stackTrace: st));
    }
  }

  @override
  Future<Result<Category>> updateCategory(UpdateCategoryParams params) async {
    try {
      final existingRow = await _localDatasource.getCategory(params.categoryId);
      if (existingRow == null) {
        return const Result.failure(CategoryNotFoundFailure());
      }

      final existing = CategoryMapper.fromDrift(existingRow);
      final now = DateTime.now();

      final updated = existing.copyWith(
        name: params.name ?? existing.name,
        icon: params.icon ?? existing.icon,
        color: params.color ?? existing.color,
        syncStatus: SyncStatus.pending,
        updatedAt: now,
      );

      // 1. Update in Drift
      final companion = CategoryMapper.toDriftCompanion(updated);
      await _localDatasource.updateCategory(companion);

      // 2. Enqueue sync
      await _syncEngine.enqueue(
        SyncOperation(
          id: _idGenerator.generateId(),
          entityType: 'category',
          entityId: params.categoryId,
          operationType: OperationType.update,
          familyId: existing.familyId,
          payload: CategoryMapper.toFirestore(updated),
          createdAt: now,
        ),
      );

      return Result.success(updated);
    } catch (e, st) {
      return Result.failure(TaskUnknownFailure(stackTrace: st));
    }
  }

  @override
  Future<Result<void>> deleteCategory(String categoryId) async {
    try {
      final existingRow = await _localDatasource.getCategory(categoryId);
      if (existingRow == null) {
        return const Result.failure(CategoryNotFoundFailure());
      }

      final existing = CategoryMapper.fromDrift(existingRow);

      // Check if it's a default category
      if (existing.isDefault) {
        return const Result.failure(DefaultCategoryFailure());
      }

      // Check for active tasks
      final activeCount = await _localDatasource.countActiveTasksForCategory(
        existing.familyId,
        existing.name,
      );
      if (activeCount > 0) {
        return Result.failure(
          CategoryInUseFailure(taskCount: activeCount),
        );
      }

      final now = DateTime.now();

      // 1. Delete from Drift
      await _localDatasource.deleteCategory(categoryId);

      // 2. Enqueue sync
      await _syncEngine.enqueue(
        SyncOperation(
          id: _idGenerator.generateId(),
          entityType: 'category',
          entityId: categoryId,
          operationType: OperationType.delete,
          familyId: existing.familyId,
          payload: {'categoryId': categoryId},
          createdAt: now,
        ),
      );

      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(TaskUnknownFailure(stackTrace: st));
    }
  }

  @override
  Future<Result<void>> seedDefaultCategories(String familyId) async {
    try {
      final now = DateTime.now();

      for (final categoryDef in kDefaultCategories) {
        // Check if already exists (idempotent)
        final existing = await _localDatasource.getCategoryByName(
          familyId,
          categoryDef['name']!,
        );
        if (existing != null) continue;

        final categoryId = _idGenerator.generateId();
        final category = Category(
          id: categoryId,
          familyId: familyId,
          name: categoryDef['name']!,
          icon: categoryDef['icon']!,
          color: categoryDef['color']!,
          isDefault: true,
          syncStatus: SyncStatus.pending,
          createdAt: now,
          updatedAt: now,
        );

        await _localDatasource.insertCategory(
          CategoryMapper.toDriftCompanion(category),
        );

        await _syncEngine.enqueue(
          SyncOperation(
            id: _idGenerator.generateId(),
            entityType: 'category',
            entityId: categoryId,
            operationType: OperationType.create,
            familyId: familyId,
            payload: CategoryMapper.toFirestore(category),
            createdAt: now,
          ),
        );
      }

      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(TaskUnknownFailure(stackTrace: st));
    }
  }

  @override
  Future<Result<int>> countActiveTasksForCategory(String categoryId) async {
    try {
      final existingRow = await _localDatasource.getCategory(categoryId);
      if (existingRow == null) {
        return const Result.failure(CategoryNotFoundFailure());
      }

      final existing = CategoryMapper.fromDrift(existingRow);
      final count = await _localDatasource.countActiveTasksForCategory(
        existing.familyId,
        existing.name,
      );
      return Result.success(count);
    } catch (e, st) {
      return Result.failure(TaskUnknownFailure(stackTrace: st));
    }
  }
}
```

---

## 7. File Structure

### 7.1 Data Layer File Tree

```
lib/features/tasks/
  data/
    datasources/
      task_local_datasource.dart      # Drift DAO for tasks
      task_local_datasource.g.dart    # Generated
      task_remote_datasource.dart     # Firestore operations for tasks
      category_local_datasource.dart  # Drift DAO for categories
      category_local_datasource.g.dart # Generated
      category_remote_datasource.dart # Firestore operations for categories
    mappers/
      task_mapper.dart                # Drift <-> Domain <-> Firestore
      category_mapper.dart            # Drift <-> Domain <-> Firestore
    repositories/
      task_repository_impl.dart       # TaskRepository implementation
      category_repository_impl.dart   # CategoryRepository implementation
```

---

## 8. Drift Schema Additions

### 8.1 TasksTable Additions

The existing TasksTable from `specs/02_isar_schemas.md` needs two additional columns for Phase 3:

```dart
// Additional columns needed in TasksTable:

/// Whether this task is a recurring template (not shown in list directly).
/// Templates generate instances via the RecurrenceEngine.
BoolColumn get isTemplate => boolean().withDefault(const Constant(false))();

/// For recurring task instances: ID of the parent template task.
/// Null for one-time tasks and for templates themselves.
TextColumn get parentTaskId => text().nullable()();

/// Whether photo proof is required for task completion.
BoolColumn get photoProofRequired => boolean().withDefault(const Constant(false))();
```

### 8.2 Migration

```dart
// Database schema version bump from 1 to 2
// Migration adds isTemplate, parentTaskId, and photoProofRequired columns
//
// @override
// int get schemaVersion => 2;
//
// @override
// MigrationStrategy get migration => MigrationStrategy(
//   onUpgrade: (migrator, from, to) async {
//     if (from < 2) {
//       await migrator.addColumn(tasksTable, tasksTable.isTemplate);
//       await migrator.addColumn(tasksTable, tasksTable.parentTaskId);
//       await migrator.addColumn(tasksTable, tasksTable.photoProofRequired);
//     }
//   },
// );
```

---

## 9. Impact Analysis

### 9.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| `lib/features/tasks/data/` | New | Low | Entire new directory |
| `lib/core/database/app_database.dart` | Modified | Medium | Schema version bump, new columns |
| `lib/core/sync/sync_engine.dart` | Used (not modified) | Low | Enqueue API already exists |
| `lib/features/family/domain/repositories/member_repository.dart` | Used (not modified) | Low | addPoints API needed |
| `specs/02_isar_schemas.md` | Upstream dependency | Medium | New columns must match schema spec |

### 9.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Schema migration breaks existing data | Low | High | Test migration with existing Phase 2 data; backup before upgrade |
| JSON serialization of assigneeIds/subtasks is fragile | Medium | Medium | Thorough roundtrip tests; defensive parsing with fallback defaults |
| SyncEngine API mismatch | Low | High | Verify SyncEngine.enqueue signature matches expected parameters |
| MemberRepository.addPoints not yet implemented | Medium | Medium | Define interface now; implement in Phase 3 if missing from Phase 2 |
| Audit log volume grows unbounded | Low | Low | Firestore only (not in Drift); 6-month retention applied server-side |

---

## 10. Functional Tests

### 10.1 Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| TDL-T001 | TaskMapper roundtrip Drift | Task entity with all fields | toDriftCompanion then fromDrift | All fields preserved | High |
| TDL-T002 | TaskMapper roundtrip Firestore | Task entity with all fields | toFirestore then fromFirestore | All fields preserved | High |
| TDL-T003 | TaskMapper handles null subtasks | Drift row with null subtasks JSON | fromDrift | Returns empty subtask list | Medium |
| TDL-T004 | TaskLocalDatasource watchTasksForFamily | 5 tasks in family, 1 template | Watch stream | Emits 4 tasks (excludes template) | High |
| TDL-T005 | TaskLocalDatasource watchTasksForMember | 5 tasks, 2 assigned to member | Watch for member | Emits 2 tasks + unassigned | High |
| TDL-T006 | TaskLocalDatasource softDeleteTask | Task exists | softDeleteTask | Status = deleted, syncStatus = pending | High |
| TDL-T007 | TaskRepositoryImpl.createTask | Valid params | createTask | Drift insert + SyncOp enqueued | High |
| TDL-T008 | TaskRepositoryImpl.completeTask awards points | Task with 10 points | completeTask | MemberRepository.addPoints called with 10 | High |
| TDL-T009 | TaskRepositoryImpl.completeTask emits event | Task completed | completeTask | TaskCompletedEvent emitted | High |
| TDL-T010 | TaskRepositoryImpl.deleteTask cascades template | Template with 3 instances | deleteTask(templateId) | Template + 3 instances soft-deleted | High |
| TDL-T011 | CategoryRepositoryImpl.seedDefaultCategories | Empty family | seedDefaultCategories | 8 categories created | High |
| TDL-T012 | CategoryRepositoryImpl.seedDefaultCategories idempotent | Family with 8 defaults | seedDefaultCategories | No duplicates | High |
| TDL-T013 | CategoryRepositoryImpl.deleteCategory blocked | Default category | deleteCategory | Returns DefaultCategoryFailure | High |
| TDL-T014 | CategoryRepositoryImpl.deleteCategory with tasks | Category has 2 active tasks | deleteCategory | Returns CategoryInUseFailure(2) | High |

---

## 11. Implementation Recommendations

### 11.1 Prototype Checklist

1. **What can a user do?** Not directly visible to users -- this is infrastructure. "As a developer, I can call TaskRepositoryImpl.createTask and see a task in Drift + a SyncOperation in the queue."
2. **Which screens are delivered?** None.
3. **What is the minimum data flow?** createTask -> Drift insert + SyncOp enqueue -> watch stream emits new list.
4. **What is the offline behavior?** All operations complete successfully without internet. SyncOps queue for later processing.
5. **What does "done" look like?** All repository integration tests pass against in-memory Drift DB with mocked SyncEngine.

### 11.2 Suggested Approach

1. Add new columns to TasksTable and create migration.
2. Implement TaskMapper and CategoryMapper with roundtrip tests.
3. Implement TaskLocalDatasource with DAO annotation and SQL queries.
4. Implement CategoryLocalDatasource.
5. Implement TaskRemoteDatasource (can be tested against Firestore emulator).
6. Implement CategoryRemoteDatasource.
7. Implement TaskRepositoryImpl with full integration test suite.
8. Implement CategoryRepositoryImpl with seed and delete guard tests.
9. Run `build_runner build --delete-conflicting-outputs`.

### 11.3 Estimated Effort

**L (5-8 days)** -- The data layer has the most code volume in Phase 3. Drift DAO queries, Firestore operations, mappers, and comprehensive repository orchestration logic all need thorough testing.

---

*Generated by Software Architect Analyst*
*Date: 2026-03-09*
