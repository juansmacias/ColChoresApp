# Task Domain Layer

## 1. Overview

### 1.1 Summary

This specification defines the complete domain layer for the Task Management feature: domain entities (`Task`, `Subtask`, `Category`), abstract repository interfaces (`TaskRepository`, `CategoryRepository`), parameter objects, failure types, and use cases. The domain layer is the heart of the application -- it contains all business rules for task creation, assignment, completion, verification, and deletion. Per the architecture rules, the domain layer has zero dependencies on Drift, Firestore, or any external SDK. It depends only on abstract interfaces and pure Dart types.

### 1.2 Business Context

Tasks are the core unit of work in the Family Chores App. Every family interaction revolves around creating, assigning, completing, and tracking tasks. The domain layer defines what a task is, what operations can be performed on it, who can perform those operations, and what rules govern those operations. Getting this layer right is critical -- every screen, sync operation, and notification depends on these entities and use cases.

### 1.3 Scope

**In scope:**
- `Task` entity with all fields and computed properties
- `Subtask` value object
- `Category` entity
- `TaskRepository` abstract interface with full method signatures
- `CategoryRepository` abstract interface
- Parameter objects: `CreateTaskParams`, `UpdateTaskParams`, `CompleteTaskParams`
- `TaskFailure` sealed class with typed error variants
- 12 use cases covering all task and category operations
- Audit log event type definitions
- Business rule documentation for each operation

**Out of scope:**
- Data layer implementations (see `specs/19_task_data_layer.md`)
- Presentation layer (see `specs/20_task_list_screen.md`, `specs/21_task_creation_screen.md`)
- Recurrence engine implementation (see `specs/23_recurrence_engine.md`)
- Category management UI (see `specs/24_category_management.md`)

### 1.4 References

- `specs/00_project_foundation.md` -- Section 4.5 (Data Model), Section 4.6 (Multi-User Model)
- `specs/02_isar_schemas.md` -- TasksTable, CategoriesTable, enums
- `specs/06_error_handling.md` -- Failure hierarchy, Result type
- `specs/09_firebase_auth.md` -- Domain entity patterns, AuthFailure patterns
- `specs/11_member_profiles.md` -- MemberRole enum, Member entity
- `CLAUDE.md` -- Resolved decisions: auto-approved rewards, parent-only reassignment, chore rotation, Emma excluded from fairness

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| TD-001 | Task entity represents all fields from Drift schema | High | Every TasksTable field has a corresponding Task entity field |
| TD-002 | Task entity provides computed properties for UI | High | `isOverdue`, `isRecurring`, `isAssignedTo`, `isCompletedBy`, `ageGroupLabel` all work correctly |
| TD-003 | TaskRepository interface defines all CRUD operations | High | Interface has methods for create, read, update, delete, complete, verify, skip, reassign |
| TD-004 | TaskRepository provides reactive streams | High | `watchTasksForFamily` and `watchTasksForMember` return `Stream<List<Task>>` |
| TD-005 | TaskRepository provides pending sync count stream | High | `watchPendingSyncCount` returns `Stream<int>` for badge display |
| TD-006 | CategoryRepository interface defines CRUD operations | High | Interface has methods for create, read, update, delete with streams |
| TD-007 | Use cases enforce business rules | High | Parent-only operations checked in use case layer, validation rules applied |
| TD-008 | CompleteTask awards points to completing member | High | Use case calls MemberRepository.addPoints with task.points |
| TD-009 | TaskFailure provides typed error variants | High | At least 5 failure types: NotFound, PermissionDenied, ValidationError, SyncError, Unknown |
| TD-010 | Subtask entity supports completion tracking | Medium | `isCompleted` field toggleable, list serializable |
| TD-011 | CreateTaskParams validates all required fields | High | Title required, points in range, assignees valid |
| TD-012 | Audit log event types defined as enum | Medium | All lifecycle events have a corresponding enum value |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| TD-NFR-001 | Domain layer has zero external SDK imports | N/A | No imports of `drift`, `cloud_firestore`, `firebase_auth` in `domain/` |
| TD-NFR-002 | Entity equality is value-based | N/A | Two Task instances with same fields are equal |
| TD-NFR-003 | Entities are immutable | N/A | All fields are `final`, modifications return new instances |
| TD-NFR-004 | Use case execution time | Excluding I/O | < 1ms (pure validation and delegation) |

### 2.3 Assumptions

- The `MemberRepository` from Phase 2 provides an `addPoints(memberId, points)` method for task completion.
- The `ActiveProfileCubit` from Phase 2 provides `state.activeProfile` with `memberId`, `role`, and `familyId`.
- The `SyncEngine` from Phase 1 accepts `SyncOperation` objects enqueued by repository implementations.
- The `Result` type from Phase 1 (`lib/core/utils/result.dart`) is used for all fallible operations.
- The `IdGenerator` from Phase 1 generates UUIDs for new entities.

### 2.4 Constraints

- Domain entities must not use `json_serializable` or `freezed` annotations that would pull in Drift/Firestore types. They may use `freezed` for immutability as long as the generated code stays in the domain layer.
- Use cases are single-purpose classes with a single `call()` method (or `execute()`) -- following the Command pattern.
- The `TaskRepository` interface must not expose sync-related methods (no `enqueueSync` or `markSynced`). Sync is an implementation detail of the data layer.

---

## 3. Domain Entities

### 3.1 Task Entity

```dart
// lib/features/tasks/domain/entities/task.dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/enums/age_group.dart';
import '../../../../core/enums/sync_status.dart';
import '../../../../core/enums/task_status.dart';
import 'subtask.dart';

part 'task.freezed.dart';

/// Core domain entity representing a household chore or task.
///
/// This entity is the single source of truth for task state in the domain
/// layer. It maps 1:1 to the Drift TasksTable but carries no Drift
/// dependencies. Presentation and data layers convert to/from this type.
@freezed
class Task with _$Task {
  const Task._(); // Enable custom getters on freezed class

  const factory Task({
    /// Unique identifier (UUID, generated client-side).
    required String id,

    /// Family this task belongs to.
    required String familyId,

    /// Human-readable task title. Min 2 chars, max 100 chars.
    required String title,

    /// Optional detailed description or instructions.
    String? description,

    /// Category name (references Category entity).
    required String category,

    /// Member IDs assigned to this task. Empty list = shared pool (unassigned).
    required List<String> assigneeIds,

    /// Member ID who created this task.
    required String createdByMemberId,

    /// When this task is due. Null = no due date.
    DateTime? dueDate,

    /// RFC 5545 RRULE string for recurring tasks. Null = one-time task.
    String? recurrenceRule,

    /// Points awarded on completion. Range: 0-100.
    required int points,

    /// Age group this task is appropriate for.
    required AgeGroup ageGroup,

    /// Current lifecycle status.
    required TaskStatus status,

    /// URL or local path to photo proof of completion.
    String? photoUrl,

    /// Whether photo proof is required for completion.
    @Default(false) bool photoProofRequired,

    /// Ordered list of subtasks (checklist items).
    @Default([]) List<Subtask> subtasks,

    /// When the task was marked as completed.
    DateTime? completedAt,

    /// Member ID who completed the task (may differ from assignee).
    String? completedByMemberId,

    /// For recurring task instances: ID of the parent template task.
    String? parentTaskId,

    /// Whether this task is a recurring template (not shown in list directly).
    @Default(false) bool isTemplate,

    // --- Sync metadata (exposed in entity for UI indicators) ---

    /// Firestore document ID (null if never synced).
    String? remoteId,

    /// Current sync status relative to Firestore.
    @Default(SyncStatus.pending) SyncStatus syncStatus,

    /// Last time this entity was synced with Firestore.
    DateTime? lastSyncedAt,

    /// When this task was created locally.
    required DateTime createdAt,

    /// When this task was last modified locally.
    required DateTime updatedAt,
  }) = _Task;

  // --- Computed Properties ---

  /// Whether this task is past its due date and not yet completed.
  bool get isOverdue =>
      dueDate != null &&
      DateTime.now().isAfter(dueDate!) &&
      status != TaskStatus.completed &&
      status != TaskStatus.verified &&
      status != TaskStatus.skipped;

  /// Whether this task has a recurrence rule (is a recurring task or template).
  bool get isRecurring => recurrenceRule != null && recurrenceRule!.isNotEmpty;

  /// Whether a specific member is assigned to this task.
  bool isAssignedTo(String memberId) => assigneeIds.contains(memberId);

  /// Whether a specific member completed this task.
  bool isCompletedBy(String memberId) => completedByMemberId == memberId;

  /// Whether this task is in a terminal state (completed, verified, or skipped).
  bool get isTerminal =>
      status == TaskStatus.completed ||
      status == TaskStatus.verified ||
      status == TaskStatus.skipped;

  /// Whether this task is actionable (can be completed).
  bool get isActionable =>
      status == TaskStatus.pending || status == TaskStatus.inProgress;

  /// Whether this task is unassigned (shared pool).
  bool get isUnassigned => assigneeIds.isEmpty;

  /// Whether this task has uncompleted subtasks.
  bool get hasIncompleteSubtasks =>
      subtasks.any((s) => !s.isCompleted);

  /// Whether all subtasks are completed.
  bool get allSubtasksCompleted =>
      subtasks.isNotEmpty && subtasks.every((s) => s.isCompleted);

  /// Number of completed subtasks.
  int get completedSubtaskCount =>
      subtasks.where((s) => s.isCompleted).length;

  /// Whether this task is pending sync to Firestore.
  bool get isPendingSync => syncStatus == SyncStatus.pending;

  /// Whether this task is a generated instance of a recurring template.
  bool get isRecurringInstance => parentTaskId != null && !isTemplate;

  /// Human-readable label for the age group.
  String get ageGroupLabel => switch (ageGroup) {
        AgeGroup.toddler => 'Toddler (2-4)',
        AgeGroup.child => 'Child (5-12)',
        AgeGroup.teen => 'Teen (13-17)',
        AgeGroup.adult => 'Adult (18+)',
      };

  /// Human-readable due date label for UI display.
  String? get dueDateLabel {
    if (dueDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final diff = taskDate.difference(today).inDays;

    if (diff < 0) return 'Overdue';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff <= 7) return 'This week';
    return null; // No special label for > 7 days
  }
}
```

### 3.2 Subtask Value Object

```dart
// lib/features/tasks/domain/entities/subtask.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'subtask.freezed.dart';

/// A checklist item within a task.
///
/// Subtasks are value objects -- they have no identity of their own.
/// They are stored as an embedded JSON list in the TasksTable.
@freezed
class Subtask with _$Subtask {
  const factory Subtask({
    /// The subtask description.
    required String title,

    /// Whether this subtask has been checked off.
    @Default(false) bool isCompleted,
  }) = _Subtask;
}
```

### 3.3 Category Entity

```dart
// lib/features/tasks/domain/entities/category.dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/enums/sync_status.dart';

part 'category.freezed.dart';

/// A task category with visual styling (icon + color).
///
/// Categories are family-scoped -- each family has their own set.
/// 8 default categories are seeded on family creation.
@freezed
class Category with _$Category {
  const factory Category({
    /// Unique identifier (UUID).
    required String id,

    /// Family this category belongs to.
    required String familyId,

    /// Display name (e.g., "Kitchen", "Bathroom").
    required String name,

    /// Material Icon name (e.g., "kitchen", "bathroom").
    required String icon,

    /// Hex color string (e.g., "#FFB74D").
    required String color,

    /// Whether this is a system default category (cannot be deleted).
    @Default(false) bool isDefault,

    // --- Sync metadata ---
    String? remoteId,
    @Default(SyncStatus.pending) SyncStatus syncStatus,
    DateTime? lastSyncedAt,

    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Category;
}
```

### 3.4 Default Categories

```dart
// lib/features/tasks/domain/constants/default_categories.dart

/// The 8 default categories seeded when a family is created.
/// These cannot be deleted by users.
const List<Map<String, String>> kDefaultCategories = [
  {'name': 'Kitchen', 'icon': 'kitchen', 'color': '#FFB74D'},
  {'name': 'Bathroom', 'icon': 'bathroom', 'color': '#4FC3F7'},
  {'name': 'Bedroom', 'icon': 'bed', 'color': '#CE93D8'},
  {'name': 'Living Room', 'icon': 'weekend', 'color': '#A5D6A7'},
  {'name': 'Yard', 'icon': 'yard', 'color': '#81C784'},
  {'name': 'Laundry', 'icon': 'local_laundry_service', 'color': '#90CAF9'},
  {'name': 'Pets', 'icon': 'pets', 'color': '#FFAB91'},
  {'name': 'General', 'icon': 'home', 'color': '#B0BEC5'},
];
```

---

## 4. Parameter Objects

### 4.1 CreateTaskParams

```dart
// lib/features/tasks/domain/params/create_task_params.dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/enums/age_group.dart';
import '../entities/subtask.dart';

part 'create_task_params.freezed.dart';

/// Parameters for creating a new task.
/// Validated by the CreateTask use case before execution.
@freezed
class CreateTaskParams with _$CreateTaskParams {
  const factory CreateTaskParams({
    /// Task title. Required, 2-100 characters.
    required String title,

    /// Optional description.
    String? description,

    /// Category name. Required.
    required String category,

    /// Assigned member IDs. Empty = shared pool.
    @Default([]) List<String> assigneeIds,

    /// Member ID of the creator (from ActiveProfileCubit).
    required String createdByMemberId,

    /// Family ID scope (from ActiveProfileCubit).
    required String familyId,

    /// Due date. Null = no deadline.
    DateTime? dueDate,

    /// RFC 5545 RRULE string. Null = one-time task.
    String? recurrenceRule,

    /// Points awarded on completion. 0-100.
    @Default(10) int points,

    /// Age group appropriateness.
    @Default(AgeGroup.adult) AgeGroup ageGroup,

    /// Whether photo proof is required for completion.
    @Default(false) bool photoProofRequired,

    /// Initial subtask list.
    @Default([]) List<Subtask> subtasks,
  }) = _CreateTaskParams;
}
```

### 4.2 UpdateTaskParams

```dart
// lib/features/tasks/domain/params/update_task_params.dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/enums/age_group.dart';
import '../entities/subtask.dart';

part 'update_task_params.freezed.dart';

/// Parameters for updating an existing task.
/// Only non-null fields are updated (partial update semantics).
@freezed
class UpdateTaskParams with _$UpdateTaskParams {
  const factory UpdateTaskParams({
    /// Task ID to update. Required.
    required String taskId,

    /// Updated title. Null = no change.
    String? title,

    /// Updated description. Null = no change.
    String? description,

    /// Updated category. Null = no change.
    String? category,

    /// Updated assignees. Null = no change.
    List<String>? assigneeIds,

    /// Updated due date. Null = no change.
    /// Use a sentinel value to clear due date.
    DateTime? dueDate,

    /// Whether to clear the due date.
    @Default(false) bool clearDueDate,

    /// Updated recurrence rule. Null = no change.
    String? recurrenceRule,

    /// Whether to clear the recurrence rule.
    @Default(false) bool clearRecurrenceRule,

    /// Updated points. Null = no change.
    int? points,

    /// Updated age group. Null = no change.
    AgeGroup? ageGroup,

    /// Updated photo proof requirement. Null = no change.
    bool? photoProofRequired,

    /// Updated subtask list. Null = no change.
    List<Subtask>? subtasks,
  }) = _UpdateTaskParams;
}
```

### 4.3 CompleteTaskParams

```dart
// lib/features/tasks/domain/params/complete_task_params.dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../entities/subtask.dart';

part 'complete_task_params.freezed.dart';

/// Parameters for completing a task.
@freezed
class CompleteTaskParams with _$CompleteTaskParams {
  const factory CompleteTaskParams({
    /// Task ID to complete.
    required String taskId,

    /// Member ID who completed the task.
    /// May differ from assignee (parent completing on behalf of child).
    required String completedByMemberId,

    /// Optional photo proof URL/path.
    String? photoUrl,

    /// Final subtask completion states.
    /// If provided, overrides current subtask states.
    List<Subtask>? subtaskResults,
  }) = _CompleteTaskParams;
}
```

### 4.4 CreateCategoryParams

```dart
// lib/features/tasks/domain/params/create_category_params.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'create_category_params.freezed.dart';

/// Parameters for creating a new category.
@freezed
class CreateCategoryParams with _$CreateCategoryParams {
  const factory CreateCategoryParams({
    /// Category name. Required, 2-30 characters.
    required String name,

    /// Material Icon name.
    required String icon,

    /// Hex color string.
    required String color,

    /// Family ID scope.
    required String familyId,
  }) = _CreateCategoryParams;
}
```

### 4.5 UpdateCategoryParams

```dart
// lib/features/tasks/domain/params/update_category_params.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'update_category_params.freezed.dart';

/// Parameters for updating an existing category.
@freezed
class UpdateCategoryParams with _$UpdateCategoryParams {
  const factory UpdateCategoryParams({
    /// Category ID to update.
    required String categoryId,

    /// Updated name. Null = no change.
    String? name,

    /// Updated icon. Null = no change.
    String? icon,

    /// Updated color. Null = no change.
    String? color,
  }) = _UpdateCategoryParams;
}
```

---

## 5. Failure Types

### 5.1 TaskFailure Sealed Class

```dart
// lib/features/tasks/domain/failures/task_failures.dart
import '../../../../core/error/failures.dart';

/// Typed task operation failure variants.
/// Each variant provides a specific, actionable error message.
sealed class TaskFailure extends Failure {
  const TaskFailure({
    required super.message,
    super.code,
    super.stackTrace,
  });
}

/// Task with the given ID was not found in the local database.
final class TaskNotFoundFailure extends TaskFailure {
  const TaskNotFoundFailure({
    super.message = 'Task not found.',
    super.code = 'task-not-found',
    super.stackTrace,
  });
}

/// The current user does not have permission for this operation.
/// Typically: child trying to create/edit/delete a task, or
/// non-assignee trying to complete a task.
final class TaskPermissionDeniedFailure extends TaskFailure {
  const TaskPermissionDeniedFailure({
    super.message = 'You do not have permission to perform this action.',
    super.code = 'task-permission-denied',
    super.stackTrace,
  });
}

/// Input validation failed on task creation or update.
/// Contains a map of field names to error messages.
final class TaskValidationFailure extends TaskFailure {
  const TaskValidationFailure({
    required this.fieldErrors,
    super.message = 'Please fix the errors below.',
    super.code = 'task-validation-error',
    super.stackTrace,
  });

  /// Map of field name -> error message.
  /// Example: {'title': 'Title is required', 'points': 'Points must be 0-100'}
  final Map<String, String> fieldErrors;
}

/// The sync engine encountered an error while syncing this task.
final class TaskSyncFailure extends TaskFailure {
  const TaskSyncFailure({
    super.message = 'Unable to sync task. Changes saved locally.',
    super.code = 'task-sync-error',
    super.stackTrace,
  });
}

/// Task is in an invalid state for the requested operation.
/// Example: trying to complete an already-completed task.
final class TaskInvalidStateFailure extends TaskFailure {
  const TaskInvalidStateFailure({
    required super.message,
    super.code = 'task-invalid-state',
    super.stackTrace,
  });
}

/// Category not found when referenced by a task.
final class CategoryNotFoundFailure extends TaskFailure {
  const CategoryNotFoundFailure({
    super.message = 'Category not found.',
    super.code = 'category-not-found',
    super.stackTrace,
  });
}

/// Category cannot be deleted because active tasks reference it.
final class CategoryInUseFailure extends TaskFailure {
  const CategoryInUseFailure({
    required this.taskCount,
    super.message = 'Category is still in use by active tasks.',
    super.code = 'category-in-use',
    super.stackTrace,
  });

  /// Number of non-completed tasks referencing this category.
  final int taskCount;
}

/// Default category cannot be deleted.
final class DefaultCategoryFailure extends TaskFailure {
  const DefaultCategoryFailure({
    super.message = 'Default categories cannot be deleted.',
    super.code = 'default-category',
    super.stackTrace,
  });
}

/// Unexpected error during task operation.
final class TaskUnknownFailure extends TaskFailure {
  const TaskUnknownFailure({
    super.message = 'An unexpected error occurred. Please try again.',
    super.code = 'task-unknown',
    super.stackTrace,
  });
}
```

### 5.2 Error Message Mapping

| Failure Type | User-Facing Message | When It Occurs |
|-------------|---------------------|----------------|
| `TaskNotFoundFailure` | "Task not found." | Task deleted by another device, stale reference |
| `TaskPermissionDeniedFailure` | "You do not have permission to perform this action." | Child tries to create/edit/delete task |
| `TaskValidationFailure` | "Please fix the errors below." | Invalid form input |
| `TaskSyncFailure` | "Unable to sync task. Changes saved locally." | Sync engine error (non-blocking) |
| `TaskInvalidStateFailure` | Dynamic message | Complete already-completed task, verify non-completed task |
| `CategoryNotFoundFailure` | "Category not found." | Orphaned category reference |
| `CategoryInUseFailure` | "Category is still in use by active tasks." | Delete category with active tasks |
| `DefaultCategoryFailure` | "Default categories cannot be deleted." | Attempt to delete system category |
| `TaskUnknownFailure` | "An unexpected error occurred. Please try again." | Drift exception, unexpected state |

---

## 6. Repository Interfaces

### 6.1 TaskRepository

```dart
// lib/features/tasks/domain/repositories/task_repository.dart
import '../../../../core/utils/result.dart';
import '../entities/task.dart';
import '../params/complete_task_params.dart';
import '../params/create_task_params.dart';
import '../params/update_task_params.dart';

/// Abstract interface for task operations.
///
/// Implementations must:
/// - Write to local Drift DB first (offline-first)
/// - Enqueue SyncOperation for Firestore sync
/// - Map all exceptions to TaskFailure types
/// - Never call Firestore directly -- all remote operations go through SyncEngine
abstract class TaskRepository {
  /// Watches all tasks for a family, ordered by due date ascending.
  /// Excludes template tasks (isTemplate = true).
  /// Emits a new list whenever any task in the family changes.
  Stream<List<Task>> watchTasksForFamily(String familyId);

  /// Watches tasks assigned to a specific member, ordered by due date.
  /// Includes tasks where the member is in assigneeIds.
  /// Also includes unassigned tasks (shared pool).
  Stream<List<Task>> watchTasksForMember(
    String familyId,
    String memberId,
  );

  /// Gets a single task by its local ID.
  /// Returns [TaskNotFoundFailure] if not found.
  Future<Result<Task>> getTask(String taskId);

  /// Creates a new task in the local database.
  /// Generates a UUID, sets syncStatus=pending, enqueues SyncOperation.
  /// Returns the created task with its generated ID.
  Future<Result<Task>> createTask(CreateTaskParams params);

  /// Updates an existing task in the local database.
  /// Only non-null fields in params are updated.
  /// Sets syncStatus=pending, bumps updatedAt, enqueues SyncOperation.
  Future<Result<Task>> updateTask(UpdateTaskParams params);

  /// Soft-deletes a task in the local database.
  /// Sets a deleted flag (for sync), enqueues SyncOperation.
  /// After sync completes, the SyncEngine hard-deletes locally.
  /// Returns [TaskPermissionDeniedFailure] if active profile is not a parent.
  Future<Result<void>> deleteTask(String taskId);

  /// Marks a task as completed.
  /// Updates status, completedAt, completedByMemberId, subtask states.
  /// Awards points to the completing member.
  /// Enqueues SyncOperation and emits TaskCompletedEvent.
  /// Returns [TaskInvalidStateFailure] if task is not actionable.
  Future<Result<Task>> completeTask(CompleteTaskParams params);

  /// Marks a completed task as verified by a parent.
  /// Changes status from completed -> verified.
  /// No additional points are awarded.
  /// Returns [TaskPermissionDeniedFailure] if active profile is not a parent.
  /// Returns [TaskInvalidStateFailure] if task status is not completed.
  Future<Result<void>> verifyTask(String taskId, String verifierMemberId);

  /// Marks a task as skipped with a reason.
  /// Changes status to skipped. No points awarded.
  /// Enqueues SyncOperation.
  Future<Result<void>> skipTask(String taskId, String reason);

  /// Reassigns a task to new assignees.
  /// Parent-only operation.
  /// Returns [TaskPermissionDeniedFailure] if active profile is not a parent.
  Future<Result<void>> reassignTask(
    String taskId,
    List<String> newAssigneeIds,
  );

  /// Watches the count of pending sync operations for tasks in a family.
  /// Used for the "pending sync" badge in the AppBar.
  Stream<int> watchPendingSyncCount(String familyId);

  /// Gets all recurring task templates for a family.
  /// Used by the recurrence engine to generate instances.
  Future<Result<List<Task>>> getRecurringTemplates(String familyId);
}
```

### 6.2 CategoryRepository

```dart
// lib/features/tasks/domain/repositories/category_repository.dart
import '../../../../core/utils/result.dart';
import '../entities/category.dart';
import '../params/create_category_params.dart';
import '../params/update_category_params.dart';

/// Abstract interface for category operations.
///
/// Categories are family-scoped. 8 defaults are seeded on family creation.
/// Default categories cannot be deleted. Custom categories can be deleted
/// unless active tasks reference them.
abstract class CategoryRepository {
  /// Watches all categories for a family, ordered by name.
  /// Includes both default and custom categories.
  Stream<List<Category>> watchCategories(String familyId);

  /// Gets a single category by ID.
  Future<Result<Category>> getCategory(String categoryId);

  /// Creates a new custom category.
  /// Sets isDefault=false, syncStatus=pending, enqueues SyncOperation.
  Future<Result<Category>> createCategory(CreateCategoryParams params);

  /// Updates an existing category.
  /// Only custom categories can have their name/icon/color changed.
  /// Default categories can only have their color changed.
  Future<Result<Category>> updateCategory(UpdateCategoryParams params);

  /// Deletes a custom category.
  /// Returns [DefaultCategoryFailure] if attempting to delete a default.
  /// Returns [CategoryInUseFailure] if non-completed tasks reference it.
  Future<Result<void>> deleteCategory(String categoryId);

  /// Seeds the 8 default categories for a new family.
  /// Called by CreateFamily use case in Phase 2.
  /// Idempotent -- skips categories that already exist.
  Future<Result<void>> seedDefaultCategories(String familyId);

  /// Counts non-completed tasks that reference a category.
  /// Used before deletion to warn the user.
  Future<Result<int>> countActiveTasksForCategory(String categoryId);
}
```

---

## 7. Use Cases

### 7.1 Use Case Pattern

All use cases follow this pattern:

```dart
// Pattern for use cases
import 'package:injectable/injectable.dart';
import '../../../../core/utils/result.dart';

@injectable
class UseCaseName {
  const UseCaseName(this._repository);

  final SomeRepository _repository;

  Future<Result<ReturnType>> call(ParamsType params) async {
    // 1. Validate params (if needed)
    // 2. Check permissions (if needed)
    // 3. Delegate to repository
    // 4. Return result
  }
}
```

### 7.2 WatchTasksForFamily

```dart
// lib/features/tasks/domain/use_cases/watch_tasks_for_family.dart
import 'package:injectable/injectable.dart';

import '../entities/task.dart';
import '../repositories/task_repository.dart';

/// Watches all tasks for the current family.
///
/// Used by TaskListBloc when the active profile is a parent.
/// Parents see all family tasks. This use case simply delegates
/// to the repository stream -- filtering is done in the BLoC layer.
@injectable
class WatchTasksForFamily {
  const WatchTasksForFamily(this._taskRepository);

  final TaskRepository _taskRepository;

  /// Returns a reactive stream of all family tasks.
  /// The stream emits a new list whenever any task changes.
  Stream<List<Task>> call(String familyId) {
    return _taskRepository.watchTasksForFamily(familyId);
  }
}
```

### 7.3 WatchTasksForMember

```dart
// lib/features/tasks/domain/use_cases/watch_tasks_for_member.dart
import 'package:injectable/injectable.dart';

import '../entities/task.dart';
import '../repositories/task_repository.dart';

/// Watches tasks assigned to a specific member.
///
/// Used by TaskListBloc when the active profile is a child.
/// Children only see their own assigned tasks plus unassigned (shared pool) tasks.
@injectable
class WatchTasksForMember {
  const WatchTasksForMember(this._taskRepository);

  final TaskRepository _taskRepository;

  /// Returns a reactive stream of tasks for the given member.
  Stream<List<Task>> call(String familyId, String memberId) {
    return _taskRepository.watchTasksForMember(familyId, memberId);
  }
}
```

### 7.4 CreateTask

```dart
// lib/features/tasks/domain/use_cases/create_task.dart
import 'package:injectable/injectable.dart';

import '../../../../core/utils/result.dart';
import '../entities/task.dart';
import '../failures/task_failures.dart';
import '../params/create_task_params.dart';
import '../repositories/task_repository.dart';

/// Creates a new task after validating all parameters.
///
/// Business rules:
/// - Title is required, 2-100 characters
/// - Points must be 0-100
/// - Due date, if provided, must not be in the past
/// - Category must be a non-empty string
/// - This use case does NOT check parent role -- the route is PIN-gated,
///   so only parents can reach the creation screen. The repository may
///   double-check if needed.
@injectable
class CreateTask {
  const CreateTask(this._taskRepository);

  final TaskRepository _taskRepository;

  Future<Result<Task>> call(CreateTaskParams params) async {
    // Validate params
    final errors = <String, String>{};

    if (params.title.trim().length < 2) {
      errors['title'] = 'Title must be at least 2 characters.';
    }
    if (params.title.trim().length > 100) {
      errors['title'] = 'Title must be 100 characters or less.';
    }
    if (params.points < 0 || params.points > 100) {
      errors['points'] = 'Points must be between 0 and 100.';
    }
    if (params.category.trim().isEmpty) {
      errors['category'] = 'Please select a category.';
    }
    if (params.dueDate != null) {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      if (params.dueDate!.isBefore(todayStart)) {
        errors['dueDate'] = 'Due date cannot be in the past.';
      }
    }

    if (errors.isNotEmpty) {
      return Result.failure(TaskValidationFailure(fieldErrors: errors));
    }

    return _taskRepository.createTask(params);
  }
}
```

### 7.5 UpdateTask

```dart
// lib/features/tasks/domain/use_cases/update_task.dart
import 'package:injectable/injectable.dart';

import '../../../../core/utils/result.dart';
import '../entities/task.dart';
import '../failures/task_failures.dart';
import '../params/update_task_params.dart';
import '../repositories/task_repository.dart';

/// Updates an existing task after validating changed fields.
///
/// Only non-null fields in the params are updated.
/// Validation runs only on provided (non-null) fields.
@injectable
class UpdateTask {
  const UpdateTask(this._taskRepository);

  final TaskRepository _taskRepository;

  Future<Result<Task>> call(UpdateTaskParams params) async {
    final errors = <String, String>{};

    if (params.title != null) {
      if (params.title!.trim().length < 2) {
        errors['title'] = 'Title must be at least 2 characters.';
      }
      if (params.title!.trim().length > 100) {
        errors['title'] = 'Title must be 100 characters or less.';
      }
    }
    if (params.points != null && (params.points! < 0 || params.points! > 100)) {
      errors['points'] = 'Points must be between 0 and 100.';
    }

    if (errors.isNotEmpty) {
      return Result.failure(TaskValidationFailure(fieldErrors: errors));
    }

    return _taskRepository.updateTask(params);
  }
}
```

### 7.6 DeleteTask

```dart
// lib/features/tasks/domain/use_cases/delete_task.dart
import 'package:injectable/injectable.dart';

import '../../../../core/utils/result.dart';
import '../repositories/task_repository.dart';

/// Deletes a task (soft-delete locally, hard-delete on sync).
///
/// Business rules:
/// - Parent-only operation (enforced by PIN gate + repository check)
/// - Deleting a recurring template also deletes all future pending instances
///   (handled by repository implementation)
@injectable
class DeleteTask {
  const DeleteTask(this._taskRepository);

  final TaskRepository _taskRepository;

  Future<Result<void>> call(String taskId) async {
    return _taskRepository.deleteTask(taskId);
  }
}
```

### 7.7 CompleteTask

```dart
// lib/features/tasks/domain/use_cases/complete_task.dart
import 'package:injectable/injectable.dart';

import '../../../../core/utils/result.dart';
import '../entities/task.dart';
import '../failures/task_failures.dart';
import '../params/complete_task_params.dart';
import '../repositories/task_repository.dart';

/// Completes a task, awarding points to the completing member.
///
/// Business rules:
/// - Task must be in an actionable state (pending or inProgress)
/// - If photoProofRequired, photoUrl must be provided
/// - Points are awarded to completedByMemberId (may differ from assignee
///   in "complete on behalf of" flow)
/// - Emits a TaskCompletedEvent for the presentation layer to trigger
///   celebration animations
///
/// This use case is called from:
/// 1. TaskCard checkbox tap (quick complete)
/// 2. TaskDetailScreen "Mark Complete" button
/// 3. All subtasks checked (auto-prompt)
/// 4. Parent "Complete on behalf of" flow
@injectable
class CompleteTask {
  const CompleteTask(this._taskRepository);

  final TaskRepository _taskRepository;

  Future<Result<Task>> call(CompleteTaskParams params) async {
    // Pre-check: get the task to validate state
    final taskResult = await _taskRepository.getTask(params.taskId);

    return taskResult.when(
      success: (task) async {
        // Validate task is actionable
        if (!task.isActionable) {
          return Result<Task>.failure(
            TaskInvalidStateFailure(
              message: 'This task has already been ${task.status.name}.',
            ),
          );
        }

        // Validate photo proof if required
        if (task.photoProofRequired && params.photoUrl == null) {
          return Result<Task>.failure(
            const TaskValidationFailure(
              fieldErrors: {'photoUrl': 'Photo proof is required for this task.'},
            ),
          );
        }

        return _taskRepository.completeTask(params);
      },
      failure: (failure) => Result<Task>.failure(failure),
    );
  }
}
```

### 7.8 VerifyTask

```dart
// lib/features/tasks/domain/use_cases/verify_task.dart
import 'package:injectable/injectable.dart';

import '../../../../core/enums/task_status.dart';
import '../../../../core/utils/result.dart';
import '../failures/task_failures.dart';
import '../repositories/task_repository.dart';

/// Verifies a completed task (parent-only).
///
/// Business rules:
/// - Only parents can verify tasks
/// - Task must be in "completed" status (not pending, not already verified)
/// - No additional points are awarded
/// - Status changes from completed -> verified
@injectable
class VerifyTask {
  const VerifyTask(this._taskRepository);

  final TaskRepository _taskRepository;

  Future<Result<void>> call(
    String taskId,
    String verifierMemberId,
  ) async {
    // Validate task state
    final taskResult = await _taskRepository.getTask(taskId);

    return taskResult.when(
      success: (task) async {
        if (task.status != TaskStatus.completed) {
          return Result<void>.failure(
            TaskInvalidStateFailure(
              message: 'Only completed tasks can be verified. '
                  'This task is ${task.status.name}.',
            ),
          );
        }

        return _taskRepository.verifyTask(taskId, verifierMemberId);
      },
      failure: (failure) => Result<void>.failure(failure),
    );
  }
}
```

### 7.9 SkipTask

```dart
// lib/features/tasks/domain/use_cases/skip_task.dart
import 'package:injectable/injectable.dart';

import '../../../../core/utils/result.dart';
import '../failures/task_failures.dart';
import '../repositories/task_repository.dart';

/// Skips a task with a reason.
///
/// Business rules:
/// - Task must be actionable (pending or inProgress)
/// - A reason is required (even if brief)
/// - No points are awarded or deducted
/// - Reason is logged in audit trail
@injectable
class SkipTask {
  const SkipTask(this._taskRepository);

  final TaskRepository _taskRepository;

  Future<Result<void>> call(String taskId, String reason) async {
    if (reason.trim().isEmpty) {
      return Result.failure(
        const TaskValidationFailure(
          fieldErrors: {'reason': 'Please provide a reason for skipping.'},
        ),
      );
    }

    // Validate task is actionable
    final taskResult = await _taskRepository.getTask(taskId);

    return taskResult.when(
      success: (task) async {
        if (!task.isActionable) {
          return Result<void>.failure(
            TaskInvalidStateFailure(
              message: 'Cannot skip a task that is ${task.status.name}.',
            ),
          );
        }
        return _taskRepository.skipTask(taskId, reason);
      },
      failure: (failure) => Result<void>.failure(failure),
    );
  }
}
```

### 7.10 ReassignTask

```dart
// lib/features/tasks/domain/use_cases/reassign_task.dart
import 'package:injectable/injectable.dart';

import '../../../../core/utils/result.dart';
import '../failures/task_failures.dart';
import '../repositories/task_repository.dart';

/// Reassigns a task to new assignees (parent-only).
///
/// Business rules:
/// - Parent-only operation (per CLAUDE.md: "Task reassignment: parent-only")
/// - At least one assignee, or empty list for shared pool
/// - Task must be actionable (cannot reassign completed/verified/skipped tasks)
@injectable
class ReassignTask {
  const ReassignTask(this._taskRepository);

  final TaskRepository _taskRepository;

  Future<Result<void>> call(
    String taskId,
    List<String> newAssigneeIds,
  ) async {
    // Validate task is actionable
    final taskResult = await _taskRepository.getTask(taskId);

    return taskResult.when(
      success: (task) async {
        if (!task.isActionable) {
          return Result<void>.failure(
            TaskInvalidStateFailure(
              message: 'Cannot reassign a task that is ${task.status.name}.',
            ),
          );
        }
        return _taskRepository.reassignTask(taskId, newAssigneeIds);
      },
      failure: (failure) => Result<void>.failure(failure),
    );
  }
}
```

### 7.11 Category Use Cases

```dart
// lib/features/tasks/domain/use_cases/watch_categories.dart
import 'package:injectable/injectable.dart';

import '../entities/category.dart';
import '../repositories/category_repository.dart';

/// Watches all categories for the current family.
@injectable
class WatchCategories {
  const WatchCategories(this._categoryRepository);

  final CategoryRepository _categoryRepository;

  Stream<List<Category>> call(String familyId) {
    return _categoryRepository.watchCategories(familyId);
  }
}
```

```dart
// lib/features/tasks/domain/use_cases/create_category.dart
import 'package:injectable/injectable.dart';

import '../../../../core/utils/result.dart';
import '../entities/category.dart';
import '../failures/task_failures.dart';
import '../params/create_category_params.dart';
import '../repositories/category_repository.dart';

/// Creates a new custom category after validation.
///
/// Business rules:
/// - Name is required, 2-30 characters
/// - Name must be unique within the family (case-insensitive)
/// - Icon must be a valid Material Icon name
/// - Color must be a valid hex string
@injectable
class CreateCategory {
  const CreateCategory(this._categoryRepository);

  final CategoryRepository _categoryRepository;

  Future<Result<Category>> call(CreateCategoryParams params) async {
    final errors = <String, String>{};

    if (params.name.trim().length < 2) {
      errors['name'] = 'Name must be at least 2 characters.';
    }
    if (params.name.trim().length > 30) {
      errors['name'] = 'Name must be 30 characters or less.';
    }
    if (params.icon.trim().isEmpty) {
      errors['icon'] = 'Please select an icon.';
    }
    if (params.color.trim().isEmpty) {
      errors['color'] = 'Please select a color.';
    }

    if (errors.isNotEmpty) {
      return Result.failure(TaskValidationFailure(fieldErrors: errors));
    }

    return _categoryRepository.createCategory(params);
  }
}
```

```dart
// lib/features/tasks/domain/use_cases/delete_category.dart
import 'package:injectable/injectable.dart';

import '../../../../core/utils/result.dart';
import '../repositories/category_repository.dart';

/// Deletes a custom category.
///
/// Business rules:
/// - Default categories cannot be deleted
/// - If non-completed tasks reference the category, warn user
///   (the UI handles the confirmation dialog; this use case just checks)
/// - Deletion is a soft-delete locally, hard-delete on sync
@injectable
class DeleteCategory {
  const DeleteCategory(this._categoryRepository);

  final CategoryRepository _categoryRepository;

  Future<Result<void>> call(String categoryId) async {
    return _categoryRepository.deleteCategory(categoryId);
  }
}
```

```dart
// lib/features/tasks/domain/use_cases/update_category.dart
import 'package:injectable/injectable.dart';

import '../../../../core/utils/result.dart';
import '../entities/category.dart';
import '../params/update_category_params.dart';
import '../repositories/category_repository.dart';

/// Updates an existing category.
@injectable
class UpdateCategory {
  const UpdateCategory(this._categoryRepository);

  final CategoryRepository _categoryRepository;

  Future<Result<Category>> call(UpdateCategoryParams params) async {
    return _categoryRepository.updateCategory(params);
  }
}
```

---

## 8. Audit Log Event Types

### 8.1 AuditEventType Enum

```dart
// lib/features/tasks/domain/enums/audit_event_type.dart

/// Types of events recorded in the task audit log.
///
/// Every state change on a task generates an audit log entry
/// in the Firestore audit_log subcollection. These entries are
/// immutable -- they can never be updated or deleted.
enum AuditEventType {
  /// Task was created.
  created,

  /// Task was assigned or reassigned to member(s).
  assigned,

  /// Task was marked as completed.
  completed,

  /// Completed task was verified by a parent.
  verified,

  /// Task was skipped with a reason.
  skipped,

  /// Task was soft-deleted.
  deleted,

  /// Task was reassigned to different member(s).
  reassigned,

  /// Task fields were updated (title, description, points, etc.).
  updated,

  /// Subtask was toggled (completed/uncompleted).
  subtaskToggled,

  /// Photo proof was attached.
  photoAttached,
}
```

### 8.2 AuditLogEntry Entity

```dart
// lib/features/tasks/domain/entities/audit_log_entry.dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../enums/audit_event_type.dart';

part 'audit_log_entry.freezed.dart';

/// An immutable event in a task's history.
///
/// Stored in Firestore at:
///   families/{familyId}/tasks/{taskId}/audit_log/{logId}
///
/// Never stored in Drift -- read directly from Firestore
/// for the task detail history section.
@freezed
class AuditLogEntry with _$AuditLogEntry {
  const factory AuditLogEntry({
    /// Unique log entry ID.
    required String id,

    /// Type of event.
    required AuditEventType eventType,

    /// Member who performed the action.
    required String memberId,

    /// When the event occurred.
    required DateTime timestamp,

    /// Previous state snapshot (JSON string, optional).
    String? previousState,

    /// New state snapshot (JSON string, optional).
    String? newState,

    /// Human-readable description (e.g., "Reassigned from Alex to Marcus").
    String? description,
  }) = _AuditLogEntry;
}
```

---

## 9. Domain Events

### 9.1 Task Events

```dart
// lib/features/tasks/domain/events/task_events.dart

/// Domain events emitted by task operations.
/// These are consumed by the presentation layer for side effects
/// (e.g., celebration animations, badge updates).
///
/// Events are distributed via SyncEventBus (see specs/03_sync_engine.md).

abstract class TaskDomainEvent {
  const TaskDomainEvent();
}

/// Emitted when a task is successfully completed.
/// Triggers celebration animation in the UI.
class TaskCompletedEvent extends TaskDomainEvent {
  const TaskCompletedEvent({
    required this.taskId,
    required this.taskTitle,
    required this.completedByMemberId,
    required this.pointsAwarded,
  });

  final String taskId;
  final String taskTitle;
  final String completedByMemberId;
  final int pointsAwarded;
}

/// Emitted when a task is verified by a parent.
class TaskVerifiedEvent extends TaskDomainEvent {
  const TaskVerifiedEvent({
    required this.taskId,
    required this.verifiedByMemberId,
  });

  final String taskId;
  final String verifiedByMemberId;
}

/// Emitted when new recurring task instances are generated.
class RecurringInstancesGeneratedEvent extends TaskDomainEvent {
  const RecurringInstancesGeneratedEvent({
    required this.templateTaskId,
    required this.instanceCount,
  });

  final String templateTaskId;
  final int instanceCount;
}
```

---

## 10. File Structure

### 10.1 Domain Layer File Tree

```
lib/features/tasks/
  domain/
    entities/
      task.dart                   # Task entity (freezed)
      task.freezed.dart           # Generated
      subtask.dart                # Subtask value object (freezed)
      subtask.freezed.dart        # Generated
      category.dart               # Category entity (freezed)
      category.freezed.dart       # Generated
      audit_log_entry.dart        # AuditLogEntry entity (freezed)
      audit_log_entry.freezed.dart # Generated
    enums/
      audit_event_type.dart       # AuditEventType enum
    events/
      task_events.dart            # Domain events
    failures/
      task_failures.dart          # TaskFailure sealed class
    params/
      create_task_params.dart     # CreateTaskParams (freezed)
      create_task_params.freezed.dart
      update_task_params.dart     # UpdateTaskParams (freezed)
      update_task_params.freezed.dart
      complete_task_params.dart   # CompleteTaskParams (freezed)
      complete_task_params.freezed.dart
      create_category_params.dart # CreateCategoryParams (freezed)
      create_category_params.freezed.dart
      update_category_params.dart # UpdateCategoryParams (freezed)
      update_category_params.freezed.dart
    repositories/
      task_repository.dart        # Abstract TaskRepository
      category_repository.dart    # Abstract CategoryRepository
    use_cases/
      watch_tasks_for_family.dart
      watch_tasks_for_member.dart
      create_task.dart
      update_task.dart
      delete_task.dart
      complete_task.dart
      verify_task.dart
      skip_task.dart
      reassign_task.dart
      watch_categories.dart
      create_category.dart
      update_category.dart
      delete_category.dart
    constants/
      default_categories.dart     # Default category definitions
```

---

## 11. Impact Analysis

### 11.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| `lib/features/tasks/domain/` | New | Low | Entire new directory, no modifications to existing code |
| `lib/core/enums/task_status.dart` | Existing | Low | Already defined in Phase 1 |
| `lib/core/enums/age_group.dart` | Existing | Low | Already defined in Phase 1 |
| `lib/core/enums/sync_status.dart` | Existing | Low | Already defined in Phase 1 |
| `lib/core/utils/result.dart` | Existing | Low | Used, not modified |
| `lib/core/error/failures.dart` | Modified | Low | TaskFailure extends existing Failure base class |

### 11.2 Dependencies

- **Upstream:** `freezed` (code generation), `core/utils/result.dart` (Result type), `core/error/failures.dart` (Failure base), `core/enums/` (shared enums)
- **Downstream:** `specs/19_task_data_layer.md` (implements these interfaces), `specs/20_task_list_screen.md` (consumes entities via use cases), `specs/21_task_creation_screen.md` (uses CreateTask/UpdateTask), `specs/22_task_completion_flow.md` (uses CompleteTask)

### 11.3 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Entity fields don't match Drift schema exactly | Low | High | Cross-reference with `specs/02_isar_schemas.md` during implementation |
| Freezed codegen conflicts with existing generated code | Low | Medium | Run `build_runner build --delete-conflicting-outputs` |
| Missing business rule in use case | Medium | Medium | TDD -- write test for every business rule before implementation |
| TaskFailure hierarchy doesn't cover all error cases | Low | Medium | Add new failure types as needed during data layer implementation |

---

## 12. Functional Tests

### 12.1 Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| TD-T001 | Task.isOverdue true for past due | Task with dueDate yesterday, status=pending | Check isOverdue | Returns true | High |
| TD-T002 | Task.isOverdue false for completed | Task with dueDate yesterday, status=completed | Check isOverdue | Returns false | High |
| TD-T003 | Task.isOverdue false for no dueDate | Task with dueDate=null | Check isOverdue | Returns false | Medium |
| TD-T004 | Task.isRecurring true with RRULE | Task with recurrenceRule="FREQ=DAILY" | Check isRecurring | Returns true | Medium |
| TD-T005 | Task.isAssignedTo matches memberId | Task with assigneeIds=["abc"] | isAssignedTo("abc") | Returns true | Medium |
| TD-T006 | Task.dueDateLabel returns "Today" | Task due today | Check dueDateLabel | Returns "Today" | Medium |
| TD-T007 | Task.dueDateLabel returns "Overdue" | Task due yesterday | Check dueDateLabel | Returns "Overdue" | Medium |
| TD-T008 | CreateTask validates title min length | Params with title="" | call(params) | Returns TaskValidationFailure | High |
| TD-T009 | CreateTask validates points range | Params with points=150 | call(params) | Returns TaskValidationFailure | High |
| TD-T010 | CreateTask validates past due date | Params with dueDate=yesterday | call(params) | Returns TaskValidationFailure | High |
| TD-T011 | CreateTask succeeds with valid params | Valid params | call(params) | Returns Result.success(task) | High |
| TD-T012 | CompleteTask rejects already completed | Task with status=completed | call(params) | Returns TaskInvalidStateFailure | High |
| TD-T013 | CompleteTask requires photo when required | Task with photoProofRequired=true, no photoUrl | call(params) | Returns TaskValidationFailure | High |
| TD-T014 | VerifyTask rejects non-completed task | Task with status=pending | call(taskId, memberId) | Returns TaskInvalidStateFailure | High |
| TD-T015 | SkipTask requires reason | Empty reason string | call(taskId, "") | Returns TaskValidationFailure | Medium |
| TD-T016 | ReassignTask rejects non-actionable task | Task with status=verified | call(taskId, assignees) | Returns TaskInvalidStateFailure | Medium |

### 12.2 Edge Cases

- Task with empty assigneeIds (shared pool) -- `isUnassigned` returns true
- Task with all subtasks completed -- `allSubtasksCompleted` returns true, `hasIncompleteSubtasks` returns false
- Task with zero points -- completion still succeeds, zero points awarded
- Task with 100 subtasks -- serialization works, performance acceptable
- Category name with unicode characters -- validation accepts
- Category name with only whitespace -- validation rejects
- UpdateTaskParams with all null fields -- no-op update succeeds (or returns current task unchanged)

---

## 13. Implementation Recommendations

### 13.1 Prototype Checklist

1. **What can a user do?** "As a developer, I can import Task, Category, and all use cases with full type safety and business rule validation."
2. **Which screens are delivered?** None -- this is the domain layer only.
3. **What is the minimum data flow?** N/A -- domain layer defines interfaces, not implementations.
4. **What is the offline behavior?** N/A -- offline behavior is implemented in the data layer.
5. **What does "done" look like?** All entities compile, all use case unit tests pass, `build_runner` generates freezed code without errors.

### 13.2 Suggested Approach

1. Create the `lib/features/tasks/domain/` directory structure.
2. Define enums (`AuditEventType`) and constants (`kDefaultCategories`).
3. Implement `Subtask` entity first (simplest, no dependencies).
4. Implement `Category` entity.
5. Implement `Task` entity with all computed properties.
6. Implement `AuditLogEntry` entity.
7. Define `TaskFailure` sealed class with all variants.
8. Define parameter objects (`CreateTaskParams`, `UpdateTaskParams`, `CompleteTaskParams`, etc.).
9. Define `TaskRepository` interface.
10. Define `CategoryRepository` interface.
11. Implement use cases in order: Create, Complete, Verify, Skip, Reassign, Delete, Watch, Category CRUD.
12. Write unit tests for every computed property and use case validation rule.
13. Run `build_runner build --delete-conflicting-outputs` to generate freezed code.

### 13.3 Estimated Effort

**M (3-5 days)** -- Pure domain layer, no I/O, straightforward TDD. The main effort is in the use case validation logic and comprehensive test coverage.

---

*Generated by Software Architect Analyst*
*Date: 2026-03-09*
