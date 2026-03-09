# Phase 3 Test Plan

## 1. Overview

### 1.1 Summary

This specification defines the complete test plan for Phase 3: Task Management Core. It consolidates all test scenarios from the individual Phase 3 specs (17 through 24) into a unified plan, adds integration tests, end-to-end tests, test infrastructure (fixtures, mocks, helpers), and defines coverage targets. Every test traces back to a requirement in the corresponding component spec. Phase 3 is the first phase that delivers the core value proposition -- the chore loop -- making thorough testing essential for user trust.

### 1.2 Business Context

Phase 3 delivers the daily-use features: task creation, assignment, completion, verification, recurrence, and categorization. A bug in any of these flows means broken chore management -- the primary reason families download the app. The completion flow (with celebration animations) is the emotional highlight of the app experience; it must work flawlessly. The offline-first architecture means every operation must be tested both online and offline. Testing must validate the full data flow from user tap to Drift write to SyncEngine enqueue and back to UI update.

### 1.3 Scope

**In scope:**
- Unit tests for all domain entities, use cases, repositories, and cubits/blocs
- Widget tests for all Phase 3 screens and widgets
- Integration tests for task lifecycle, recurrence, and category management
- Cloud Function unit tests (Jest)
- End-to-end test for full task lifecycle
- Test fixtures, mock factories, and helpers
- Coverage targets and enforcement

**Out of scope:**
- Performance testing (Phase 8)
- Accessibility testing beyond basic semantics (Phase 7)
- Visual regression testing (Phase 8)
- Load testing on Cloud Functions (Phase 8)

### 1.4 References

- `specs/07_phase1_test_plan.md` -- Phase 1 test infrastructure and conventions
- `specs/15_phase2_test_plan.md` -- Phase 2 test patterns (established conventions)
- `specs/18_task_domain.md` -- Section 12 (Domain layer tests)
- `specs/19_task_data_layer.md` -- Section 10 (Data layer tests)
- `specs/20_task_list_screen.md` -- Section 12 (TaskListBloc and widget tests)
- `specs/21_task_creation_screen.md` -- Section 8 (TaskCreationCubit and widget tests)
- `specs/22_task_completion_flow.md` -- Section 12 (Completion flow tests)
- `specs/23_recurrence_engine.md` -- Section 9 (Recurrence tests)
- `specs/24_category_management.md` -- Section 10 (Category tests)
- `docs/development-rules.md` -- TDD, Arrange-Act-Assert, test naming

---

## 2. Test Infrastructure

### 2.1 Test Directory Structure

```
test/
  unit/
    features/
      tasks/
        data/
          datasources/
            task_local_datasource_test.dart
            category_local_datasource_test.dart
          mappers/
            task_mapper_test.dart
            category_mapper_test.dart
          repositories/
            task_repository_impl_test.dart
            category_repository_impl_test.dart
          services/
            recurrence_engine_impl_test.dart
            task_instance_generator_test.dart
        domain/
          entities/
            task_test.dart
            subtask_test.dart
            category_test.dart
          use_cases/
            create_task_test.dart
            update_task_test.dart
            delete_task_test.dart
            complete_task_test.dart
            verify_task_test.dart
            skip_task_test.dart
            reassign_task_test.dart
            create_category_test.dart
            delete_category_test.dart
        presentation/
          bloc/
            task_list_bloc_test.dart
          cubit/
            task_creation_cubit_test.dart
            task_completion_cubit_test.dart
            task_detail_cubit_test.dart
            category_management_cubit_test.dart
  widget/
    features/
      tasks/
        screens/
          task_list_screen_test.dart
          task_detail_screen_test.dart
          task_creation_screen_test.dart
          task_completion_screen_test.dart
          category_management_screen_test.dart
          category_create_screen_test.dart
        widgets/
          task_card_test.dart
          points_flash_widget_test.dart
          sync_status_icon_test.dart
          category_picker_test.dart
          recurrence_builder_test.dart
          member_picker_test.dart
          subtask_builder_test.dart
  integration/
    features/
      tasks/
        task_lifecycle_test.dart
        recurring_task_test.dart
        category_management_test.dart
        offline_task_test.dart
  fixtures/
    task_fixtures.dart
    category_fixtures.dart
    member_fixtures.dart
  mocks/
    mock_task_repository.dart
    mock_category_repository.dart
    mock_recurrence_engine.dart
    mock_sync_engine.dart
    mock_member_repository.dart
    mock_id_generator.dart
  helpers/
    drift_test_helper.dart
    bloc_test_helper.dart
```

### 2.2 Test Naming Convention

Following the convention from Phase 1 and Phase 2:

```dart
group('ClassName', () {
  group('methodName', () {
    test('should [expected behavior] when [condition]', () {
      // Arrange
      // Act
      // Assert
    });
  });
});
```

### 2.3 Coverage Targets

| Component | Target | Rationale |
|-----------|--------|-----------|
| `lib/features/tasks/domain/entities/` | >= 95% | Pure data classes, computed properties must all be covered |
| `lib/features/tasks/domain/use_cases/` | >= 95% | Core business logic, every validation rule tested |
| `lib/features/tasks/domain/failures/` | >= 90% | Sealed class variants all instantiated |
| `lib/features/tasks/data/repositories/` | >= 90% | Complex orchestration logic with sync, points, and audit |
| `lib/features/tasks/data/datasources/` | >= 85% | Drift queries, some platform-specific behavior |
| `lib/features/tasks/data/mappers/` | >= 95% | Pure conversion logic, roundtrips |
| `lib/features/tasks/data/services/` | >= 90% | Recurrence engine and instance generator |
| `lib/features/tasks/presentation/bloc/` | >= 90% | State machine transitions |
| `lib/features/tasks/presentation/cubit/` | >= 90% | Form state, completion states |
| **Overall Phase 3** | >= 80% | Per NFR-010 of foundation spec |

### 2.4 Coverage Enforcement

```bash
# Run Phase 3 tests only
flutter test test/unit/features/tasks/ test/widget/features/tasks/ --coverage

# Run full suite with coverage
flutter test --coverage

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Check coverage threshold (CI)
lcov --summary coverage/lcov.info | grep "lines" | awk '{print $2}' | \
  awk -F'%' '{ if ($1 < 80) exit 1; }'
```

---

## 3. Test Fixtures

### 3.1 Task Fixtures

```dart
// test/fixtures/task_fixtures.dart
import 'package:family_chores/core/enums/age_group.dart';
import 'package:family_chores/core/enums/sync_status.dart';
import 'package:family_chores/core/enums/task_status.dart';
import 'package:family_chores/features/tasks/domain/entities/task.dart';
import 'package:family_chores/features/tasks/domain/entities/subtask.dart';

abstract class TaskFixtures {
  static const familyId = 'family-001';
  static const parentMemberId = 'marcus-001';
  static const childMemberId = 'alex-001';
  static const emmaMemberId = 'emma-001';

  /// A standard pending task with no special attributes.
  static Task pendingTask({
    String id = 'task-001',
    String title = 'Wash Dishes',
    int points = 10,
    List<String> assigneeIds = const ['alex-001'],
  }) =>
      Task(
        id: id,
        familyId: familyId,
        title: title,
        description: 'Wash all dishes in the sink',
        category: 'Kitchen',
        assigneeIds: assigneeIds,
        createdByMemberId: parentMemberId,
        dueDate: DateTime.now().add(const Duration(hours: 8)),
        points: points,
        ageGroup: AgeGroup.child,
        status: TaskStatus.pending,
        syncStatus: SyncStatus.synced,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      );

  /// A completed task with completion metadata.
  static Task completedTask({
    String id = 'task-002',
    String title = 'Make Bed',
    int points = 5,
  }) =>
      Task(
        id: id,
        familyId: familyId,
        title: title,
        category: 'Bedroom',
        assigneeIds: const ['alex-001'],
        createdByMemberId: parentMemberId,
        dueDate: DateTime.now().subtract(const Duration(hours: 2)),
        points: points,
        ageGroup: AgeGroup.child,
        status: TaskStatus.completed,
        completedAt: DateTime.now().subtract(const Duration(hours: 1)),
        completedByMemberId: childMemberId,
        syncStatus: SyncStatus.synced,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

  /// A recurring task template (not shown in list).
  static Task recurringTemplate({
    String id = 'task-003',
    String title = 'Vacuum Living Room',
    String rrule = 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
  }) =>
      Task(
        id: id,
        familyId: familyId,
        title: title,
        category: 'Living Room',
        assigneeIds: const ['alex-001'],
        createdByMemberId: parentMemberId,
        dueDate: DateTime.now(),
        recurrenceRule: rrule,
        points: 15,
        ageGroup: AgeGroup.child,
        status: TaskStatus.pending,
        isTemplate: true,
        syncStatus: SyncStatus.synced,
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        updatedAt: DateTime.now().subtract(const Duration(days: 7)),
      );

  /// A recurring task instance (shown in list).
  static Task recurringInstance({
    String id = 'task-004',
    String parentTaskId = 'task-003',
    DateTime? dueDate,
  }) =>
      Task(
        id: id,
        familyId: familyId,
        title: 'Vacuum Living Room',
        category: 'Living Room',
        assigneeIds: const ['alex-001'],
        createdByMemberId: parentMemberId,
        dueDate: dueDate ?? DateTime.now(),
        points: 15,
        ageGroup: AgeGroup.child,
        status: TaskStatus.pending,
        parentTaskId: parentTaskId,
        isTemplate: false,
        syncStatus: SyncStatus.synced,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      );

  /// An overdue task.
  static Task overdueTask({
    String id = 'task-005',
    String title = 'Take Out Trash',
  }) =>
      Task(
        id: id,
        familyId: familyId,
        title: title,
        category: 'General',
        assigneeIds: const ['alex-001'],
        createdByMemberId: parentMemberId,
        dueDate: DateTime.now().subtract(const Duration(days: 2)),
        points: 5,
        ageGroup: AgeGroup.child,
        status: TaskStatus.pending,
        syncStatus: SyncStatus.synced,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      );

  /// A task with subtasks.
  static Task taskWithSubtasks({
    String id = 'task-006',
    String title = 'Clean Kitchen',
  }) =>
      Task(
        id: id,
        familyId: familyId,
        title: title,
        category: 'Kitchen',
        assigneeIds: const ['alex-001'],
        createdByMemberId: parentMemberId,
        dueDate: DateTime.now().add(const Duration(hours: 4)),
        points: 20,
        ageGroup: AgeGroup.child,
        status: TaskStatus.pending,
        subtasks: const [
          Subtask(title: 'Wipe counters', isCompleted: false),
          Subtask(title: 'Sweep floor', isCompleted: true),
          Subtask(title: 'Take out trash', isCompleted: false),
        ],
        syncStatus: SyncStatus.synced,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      );

  /// A task requiring photo proof.
  static Task photoProofTask({
    String id = 'task-007',
    String title = 'Clean Bedroom',
  }) =>
      Task(
        id: id,
        familyId: familyId,
        title: title,
        category: 'Bedroom',
        assigneeIds: const ['alex-001'],
        createdByMemberId: parentMemberId,
        dueDate: DateTime.now().add(const Duration(hours: 6)),
        points: 15,
        ageGroup: AgeGroup.child,
        status: TaskStatus.pending,
        photoProofRequired: true,
        syncStatus: SyncStatus.synced,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      );

  /// A pending-sync task.
  static Task pendingSyncTask({
    String id = 'task-008',
    String title = 'Feed Pets',
  }) =>
      Task(
        id: id,
        familyId: familyId,
        title: title,
        category: 'Pets',
        assigneeIds: const ['alex-001'],
        createdByMemberId: parentMemberId,
        dueDate: DateTime.now().add(const Duration(hours: 2)),
        points: 5,
        ageGroup: AgeGroup.child,
        status: TaskStatus.pending,
        syncStatus: SyncStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  /// An unassigned (shared pool) task.
  static Task unassignedTask({
    String id = 'task-009',
    String title = 'Tidy Entryway',
  }) =>
      Task(
        id: id,
        familyId: familyId,
        title: title,
        category: 'General',
        assigneeIds: const [],
        createdByMemberId: parentMemberId,
        dueDate: DateTime.now().add(const Duration(hours: 12)),
        points: 10,
        ageGroup: AgeGroup.adult,
        status: TaskStatus.pending,
        syncStatus: SyncStatus.synced,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      );

  /// A toddler task for Emma.
  static Task emmaTask({
    String id = 'task-010',
    String title = 'Put Away Toys',
  }) =>
      Task(
        id: id,
        familyId: familyId,
        title: title,
        category: 'Bedroom',
        assigneeIds: const ['emma-001'],
        createdByMemberId: parentMemberId,
        dueDate: DateTime.now().add(const Duration(hours: 3)),
        points: 5,
        ageGroup: AgeGroup.toddler,
        status: TaskStatus.pending,
        syncStatus: SyncStatus.synced,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
}
```

### 3.2 Category Fixtures

```dart
// test/fixtures/category_fixtures.dart
import 'package:family_chores/core/enums/sync_status.dart';
import 'package:family_chores/features/tasks/domain/entities/category.dart';

abstract class CategoryFixtures {
  static const familyId = 'family-001';

  /// A default category (Kitchen).
  static Category defaultCategory({
    String id = 'cat-001',
    String name = 'Kitchen',
    String icon = 'kitchen',
    String color = '#FFB74D',
  }) =>
      Category(
        id: id,
        familyId: familyId,
        name: name,
        icon: icon,
        color: color,
        isDefault: true,
        syncStatus: SyncStatus.synced,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  /// A custom category.
  static Category customCategory({
    String id = 'cat-custom-001',
    String name = 'Garden Shed',
    String icon = 'yard',
    String color = '#81C784',
  }) =>
      Category(
        id: id,
        familyId: familyId,
        name: name,
        icon: icon,
        color: color,
        isDefault: false,
        syncStatus: SyncStatus.synced,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

  /// All 8 default categories.
  static List<Category> allDefaults() => [
        defaultCategory(id: 'cat-001', name: 'Kitchen', icon: 'kitchen', color: '#FFB74D'),
        defaultCategory(id: 'cat-002', name: 'Bathroom', icon: 'bathroom', color: '#4FC3F7'),
        defaultCategory(id: 'cat-003', name: 'Bedroom', icon: 'bed', color: '#CE93D8'),
        defaultCategory(id: 'cat-004', name: 'Living Room', icon: 'weekend', color: '#A5D6A7'),
        defaultCategory(id: 'cat-005', name: 'Yard', icon: 'yard', color: '#81C784'),
        defaultCategory(id: 'cat-006', name: 'Laundry', icon: 'local_laundry_service', color: '#90CAF9'),
        defaultCategory(id: 'cat-007', name: 'Pets', icon: 'pets', color: '#FFAB91'),
        defaultCategory(id: 'cat-008', name: 'General', icon: 'home', color: '#B0BEC5'),
      ];
}
```

### 3.3 Member Fixtures (Phase 3 additions)

```dart
// test/fixtures/member_fixtures.dart (additions for Phase 3)
//
// Re-export existing Phase 2 member fixtures and add:
//
// static Member marcus = Member(
//   id: 'marcus-001',
//   familyId: 'family-001',
//   name: 'Marcus',
//   role: MemberRole.parent,
//   ageGroup: AgeGroup.adult,
//   points: 0,
// );
//
// static Member alex = Member(
//   id: 'alex-001',
//   familyId: 'family-001',
//   name: 'Alex',
//   role: MemberRole.child,
//   ageGroup: AgeGroup.child,
//   points: 50,
// );
//
// static Member emma = Member(
//   id: 'emma-001',
//   familyId: 'family-001',
//   name: 'Emma',
//   role: MemberRole.child,
//   ageGroup: AgeGroup.toddler,
//   points: 10,
// );
```

---

## 4. Mock Factories

### 4.1 Mock Definitions

```dart
// test/mocks/mock_task_repository.dart
import 'package:mocktail/mocktail.dart';
import 'package:family_chores/features/tasks/domain/repositories/task_repository.dart';

class MockTaskRepository extends Mock implements TaskRepository {}

// test/mocks/mock_category_repository.dart
class MockCategoryRepository extends Mock implements CategoryRepository {}

// test/mocks/mock_recurrence_engine.dart
class MockRecurrenceEngine extends Mock implements RecurrenceEngine {}

// test/mocks/mock_sync_engine.dart
class MockSyncEngine extends Mock implements SyncEngine {}

// test/mocks/mock_member_repository.dart
class MockMemberRepository extends Mock implements MemberRepository {}

// test/mocks/mock_id_generator.dart
class MockIdGenerator extends Mock implements IdGenerator {}

// test/mocks/mock_task_local_datasource.dart
class MockTaskLocalDatasource extends Mock implements TaskLocalDatasource {}

// test/mocks/mock_task_remote_datasource.dart
class MockTaskRemoteDatasource extends Mock implements TaskRemoteDatasource {}

// test/mocks/mock_category_local_datasource.dart
class MockCategoryLocalDatasource extends Mock implements CategoryLocalDatasource {}
```

### 4.2 Fallback Values

```dart
// test/mocks/register_fallback_values.dart
import 'package:mocktail/mocktail.dart';

void registerFallbackValues() {
  registerFallbackValue(CreateTaskParams(
    title: '',
    category: '',
    createdByMemberId: '',
    familyId: '',
  ));
  registerFallbackValue(UpdateTaskParams(taskId: ''));
  registerFallbackValue(CompleteTaskParams(
    taskId: '',
    completedByMemberId: '',
  ));
  registerFallbackValue(CreateCategoryParams(
    name: '',
    icon: '',
    color: '',
    familyId: '',
  ));
  registerFallbackValue(UpdateCategoryParams(categoryId: ''));
  registerFallbackValue(SyncOperation(
    id: '',
    entityType: '',
    entityId: '',
    operationType: OperationType.create,
    familyId: '',
    payload: {},
    createdAt: DateTime.now(),
  ));
  registerFallbackValue(TasksTableCompanion());
  registerFallbackValue(CategoriesTableCompanion());
}
```

---

## 5. Unit Tests

### 5.1 Task Entity Tests (task_test.dart)

```dart
// test/unit/features/tasks/domain/entities/task_test.dart
//
// 12 tests covering all computed properties:

group('Task', () {
  group('isOverdue', () {
    test('should return true when dueDate is past and status is pending', ...);
    test('should return false when dueDate is past but status is completed', ...);
    test('should return false when dueDate is null', ...);
    test('should return false when dueDate is in the future', ...);
  });

  group('isRecurring', () {
    test('should return true when recurrenceRule is non-empty', ...);
    test('should return false when recurrenceRule is null', ...);
  });

  group('isAssignedTo', () {
    test('should return true when memberId is in assigneeIds', ...);
    test('should return false when memberId is not in assigneeIds', ...);
  });

  group('dueDateLabel', () {
    test('should return "Today" for today', ...);
    test('should return "Tomorrow" for tomorrow', ...);
    test('should return "Overdue" for yesterday', ...);
    test('should return null for dueDate more than 7 days away', ...);
  });
});
```

### 5.2 TaskRepositoryImpl Tests (task_repository_impl_test.dart)

```dart
// test/unit/features/tasks/data/repositories/task_repository_impl_test.dart
//
// 14 tests:

group('TaskRepositoryImpl', () {
  group('createTask', () {
    test('should generate UUID and insert to Drift with syncStatus=pending', ...);
    test('should enqueue SyncOperation with type=create', ...);
    test('should enqueue audit log entry with type=created', ...);
    test('should set isTemplate=true when recurrenceRule provided', ...);
  });

  group('completeTask', () {
    test('should mark task as completed in Drift', ...);
    test('should award points to completing member via MemberRepository', ...);
    test('should emit TaskCompletedEvent via SyncEngine', ...);
    test('should enqueue SyncOperation with type=update', ...);
    test('should return TaskNotFoundFailure when task does not exist', ...);
  });

  group('deleteTask', () {
    test('should soft-delete task in Drift', ...);
    test('should soft-delete pending instances when deleting template', ...);
    test('should enqueue SyncOperation with type=delete', ...);
  });

  group('reassignTask', () {
    test('should update assigneeIds in Drift', ...);
    test('should enqueue SyncOperation and audit log', ...);
  });
});
```

### 5.3 Use Case Tests

```dart
// CreateTask tests (create_task_test.dart) -- 6 tests
group('CreateTask', () {
  test('should return TaskValidationFailure when title is empty', ...);
  test('should return TaskValidationFailure when title exceeds 100 chars', ...);
  test('should return TaskValidationFailure when points out of range', ...);
  test('should return TaskValidationFailure when category is empty', ...);
  test('should return TaskValidationFailure when dueDate is in past', ...);
  test('should delegate to repository when params are valid', ...);
});

// CompleteTask tests (complete_task_test.dart) -- 5 tests
group('CompleteTask', () {
  test('should return TaskInvalidStateFailure when task is not actionable', ...);
  test('should return TaskValidationFailure when photo required but missing', ...);
  test('should delegate to repository when task is actionable', ...);
  test('should return TaskNotFoundFailure when task does not exist', ...);
  test('should succeed with zero-point task', ...);
});

// VerifyTask tests (verify_task_test.dart) -- 3 tests
group('VerifyTask', () {
  test('should return TaskInvalidStateFailure when task is not completed', ...);
  test('should delegate to repository when task is completed', ...);
  test('should return TaskNotFoundFailure when task does not exist', ...);
});

// SkipTask tests (skip_task_test.dart) -- 3 tests
group('SkipTask', () {
  test('should return TaskValidationFailure when reason is empty', ...);
  test('should return TaskInvalidStateFailure when task is not actionable', ...);
  test('should delegate to repository when reason is provided', ...);
});

// ReassignTask tests (reassign_task_test.dart) -- 2 tests
group('ReassignTask', () {
  test('should return TaskInvalidStateFailure when task is not actionable', ...);
  test('should delegate to repository when task is actionable', ...);
});

// DeleteCategory tests (delete_category_test.dart) -- 3 tests
group('DeleteCategory', () {
  test('should delegate to repository', ...);
  test('should return DefaultCategoryFailure from repository', ...);
  test('should return CategoryInUseFailure from repository', ...);
});

// CreateCategory tests (create_category_test.dart) -- 4 tests
group('CreateCategory', () {
  test('should return TaskValidationFailure when name too short', ...);
  test('should return TaskValidationFailure when name too long', ...);
  test('should return TaskValidationFailure when icon is empty', ...);
  test('should delegate to repository when valid', ...);
});
```

### 5.4 TaskListBloc Tests (task_list_bloc_test.dart)

```dart
// 12 tests:

group('TaskListBloc', () {
  group('TaskListStarted', () {
    test('should emit Loading then Loaded for parent with all tasks', ...);
    test('should emit Loading then Loaded for child with filtered tasks', ...);
    test('should use WatchTasksForFamily for parent profile', ...);
    test('should use WatchTasksForMember for child profile', ...);
    test('should subscribe to pending sync count stream', ...);
  });

  group('TaskFilterChanged', () {
    test('should filter to pending tasks only', ...);
    test('should filter to overdue tasks only', ...);
    test('should filter to completed tasks only', ...);
    test('should filter to mine tasks only', ...);
  });

  group('TaskCompletionToggled', () {
    test('should call CompleteTask use case', ...);
  });

  group('date grouping', () {
    test('should group tasks into correct date categories', ...);
    test('should put tasks with no due date in noDate group', ...);
  });
});
```

### 5.5 TaskCreationCubit Tests (task_creation_cubit_test.dart)

```dart
// 12 tests:

group('TaskCreationCubit', () {
  group('field changes', () {
    test('should update draft.title when titleChanged called', ...);
    test('should update draft.category when categorySelected called', ...);
    test('should update draft.assigneeIds when assigneesChanged called', ...);
    test('should add subtask when subtaskAdded called', ...);
    test('should remove subtask when subtaskRemoved called', ...);
    test('should update points when pointsChanged called', ...);
  });

  group('submit', () {
    test('should emit ValidationError when title is empty', ...);
    test('should emit ValidationError when category is empty', ...);
    test('should emit ValidationError when weekly recurrence has no days', ...);
    test('should emit TaskCreationSuccess on valid create', ...);
    test('should emit TaskCreationSuccess on valid edit', ...);
    test('should call UpdateTask for edit mode', ...);
  });
});
```

### 5.6 TaskCompletionCubit Tests (task_completion_cubit_test.dart)

```dart
// 10 tests:

group('TaskCompletionCubit', () {
  group('completeRequested', () {
    test('should emit CompletionSuccess when no photo required', ...);
    test('should emit CompletionRequiresPhoto when photo required', ...);
    test('should emit CompletionFailure when task not found', ...);
    test('should set isEmma flag for toddler age group', ...);
  });

  group('photoAttached', () {
    test('should emit CompletionPhotoReady with photo path', ...);
  });

  group('confirmCompletion', () {
    test('should emit CompletionSuccess after photo attached', ...);
    test('should include photoUrl in CompleteTaskParams', ...);
  });

  group('cancelCompletion', () {
    test('should emit CompletionIdle', ...);
    test('should clear photo path', ...);
  });

  group('points', () {
    test('should report correct pointsAwarded in CompletionSuccess', ...);
  });
});
```

### 5.7 RecurrenceEngine Tests (recurrence_engine_impl_test.dart)

```dart
// 15 tests:

group('RecurrenceEngineImpl', () {
  group('parseRrule', () {
    test('should parse FREQ=DAILY as daily', ...);
    test('should parse FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR as weekdays', ...);
    test('should parse FREQ=WEEKLY;BYDAY=MO,WE as weekly', ...);
    test('should parse FREQ=WEEKLY;INTERVAL=2;BYDAY=SA as biweekly', ...);
    test('should parse FREQ=MONTHLY;BYMONTHDAY=15 as monthly', ...);
    test('should parse COUNT', ...);
    test('should return none frequency for invalid RRULE', ...);
  });

  group('buildRrule', () {
    test('should build daily RRULE', ...);
    test('should build weekday RRULE', ...);
    test('should build weekly RRULE with BYDAY', ...);
    test('should round-trip parse and build', ...);
  });

  group('getNextOccurrences', () {
    test('should return correct dates for daily', ...);
    test('should return correct dates for weekly multi-day', ...);
    test('should respect limit parameter', ...);
  });

  group('getHumanReadableDescription', () {
    test('should return "Every day" for daily', ...);
    test('should return "Every Monday and Wednesday" for weekly', ...);
  });
});
```

### 5.8 TaskInstanceGenerator Tests (task_instance_generator_test.dart)

```dart
// 8 tests:

group('TaskInstanceGenerator', () {
  group('generateForTemplate', () {
    test('should generate 7 instances for daily template with 7-day window', ...);
    test('should skip existing instances (deduplication)', ...);
    test('should return 0 for non-template tasks', ...);
    test('should respect daysAhead window', ...);
    test('should set parentTaskId on generated instances', ...);
    test('should set recurrenceRule to null on instances', ...);
    test('should copy assigneeIds from template', ...);
  });

  group('generateForFamily', () {
    test('should process all templates in family', ...);
  });
});
```

### 5.9 CategoryManagementCubit Tests (category_management_cubit_test.dart)

```dart
// 8 tests:

group('CategoryManagementCubit', () {
  group('loadCategories', () {
    test('should emit Loading then Loaded with categories', ...);
    test('should emit Error on stream error', ...);
  });

  group('createCategory', () {
    test('should create and let stream update UI', ...);
    test('should emit deleteError on failure', ...);
  });

  group('deleteCategory', () {
    test('should delete and let stream update UI', ...);
    test('should emit deleteError for default category', ...);
    test('should emit deleteError for category with active tasks', ...);
  });

  group('clearError', () {
    test('should clear deleteError from state', ...);
  });
});
```

### 5.10 Data Mapper Tests

```dart
// TaskMapper tests (task_mapper_test.dart) -- 5 tests
group('TaskMapper', () {
  test('should roundtrip Drift conversion without data loss', ...);
  test('should roundtrip Firestore conversion without data loss', ...);
  test('should handle null subtasks as empty list', ...);
  test('should handle empty assigneeIds as empty list', ...);
  test('should use serverTimestamp for updatedAt in Firestore', ...);
});

// CategoryMapper tests (category_mapper_test.dart) -- 3 tests
group('CategoryMapper', () {
  test('should roundtrip Drift conversion without data loss', ...);
  test('should roundtrip Firestore conversion without data loss', ...);
  test('should handle isDefault field correctly', ...);
});
```

---

## 6. Widget Tests

### 6.1 TaskCard Widget Tests (task_card_test.dart)

```dart
// 8 tests:

group('TaskCard', () {
  test('should render task title', ...);
  test('should show overdue background for overdue tasks', ...);
  test('should show completed background and strikethrough for completed tasks', ...);
  test('should show sync indicator for pending sync tasks', ...);
  test('should hide checkbox for completed tasks', ...);
  test('should show points badge when points > 0', ...);
  test('should show assignee avatars', ...);
  test('should trigger onComplete callback when checkbox tapped', ...);
});
```

### 6.2 TaskListScreen Widget Tests (task_list_screen_test.dart)

```dart
// 10 tests:

group('TaskListScreen', () {
  test('should show filter chips', ...);
  test('should show 5 filter chips for parent', ...);
  test('should show 3 filter chips for child', ...);
  test('should show FAB for parent profile', ...);
  test('should hide FAB for child profile', ...);
  test('should show empty state when no tasks', ...);
  test('should show section headers for date groups', ...);
  test('should show pull-to-refresh indicator', ...);
  test('should show sync status icon in AppBar', ...);
  test('should navigate to detail on card tap', ...);
});
```

### 6.3 TaskCreationScreen Widget Tests (task_creation_screen_test.dart)

```dart
// 12 tests:

group('TaskCreationScreen', () {
  test('should show title field with hint text', ...);
  test('should show category picker chips', ...);
  test('should show "New" chip in category picker', ...);
  test('should show member assignment chips', ...);
  test('should show date picker button', ...);
  test('should show recurrence dropdown when date is set', ...);
  test('should show weekday chips when weekly selected', ...);
  test('should show points slider with value', ...);
  test('should show subtask add field', ...);
  test('should show validation error on empty title submit', ...);
  test('should call submit on checkmark tap', ...);
  test('should show discard dialog on dirty back', ...);
});
```

### 6.4 Other Widget Tests

```dart
// PointsFlashWidget tests (3 tests)
group('PointsFlashWidget', () {
  test('should render correct points text', ...);
  test('should animate on mount', ...);
  test('should call onComplete after animation', ...);
});

// SyncStatusIcon tests (4 tests)
group('SyncStatusIcon', () {
  test('should show cloud_done when all synced', ...);
  test('should show cloud_off when offline', ...);
  test('should show badge with count when pending', ...);
  test('should show rotating icon when syncing', ...);
});

// CategoryManagementScreen tests (6 tests)
group('CategoryManagementScreen', () {
  test('should render default and custom categories', ...);
  test('should allow swipe-to-delete for custom', ...);
  test('should block swipe for default', ...);
  test('should show FAB for new category', ...);
  test('should show delete error in SnackBar', ...);
  test('should show loading state', ...);
});

// RecurrenceBuilder tests (6 tests)
group('RecurrenceBuilder', () {
  test('should show frequency dropdown', ...);
  test('should show weekday chips when weekly selected', ...);
  test('should show day picker when monthly selected', ...);
  test('should show preview dates', ...);
  test('should hide preview when "none" selected', ...);
  test('should allow multi-select weekdays', ...);
});
```

---

## 7. Integration Tests

### 7.1 Task Lifecycle (task_lifecycle_test.dart)

```dart
// Tests against in-memory Drift DB with mocked SyncEngine and MemberRepository
//
// 6 tests:

group('Task Lifecycle Integration', () {
  test('should create task and see it in watch stream', ...);
  // Arrange: in-memory Drift DB
  // Act: TaskRepositoryImpl.createTask(params)
  // Assert: watchTasksForFamily emits list containing new task

  test('should complete task and award points', ...);
  // Arrange: existing pending task in Drift
  // Act: TaskRepositoryImpl.completeTask(params)
  // Assert: task status=completed, MemberRepo.addPoints called

  test('should verify completed task', ...);
  // Arrange: completed task in Drift
  // Act: TaskRepositoryImpl.verifyTask(taskId, memberId)
  // Assert: task status=verified

  test('should soft-delete task and remove from watch stream', ...);
  // Arrange: existing task in Drift
  // Act: TaskRepositoryImpl.deleteTask(taskId)
  // Assert: watchTasksForFamily no longer emits this task

  test('should reassign task and update assigneeIds', ...);
  // Arrange: task assigned to alex
  // Act: TaskRepositoryImpl.reassignTask(taskId, ["marcus-001"])
  // Assert: task.assigneeIds = ["marcus-001"]

  test('should skip task with reason', ...);
  // Arrange: pending task
  // Act: TaskRepositoryImpl.skipTask(taskId, "Not needed")
  // Assert: task status=skipped, audit log enqueued
});
```

### 7.2 Recurring Task (recurring_task_test.dart)

```dart
// 4 tests:

group('Recurring Task Integration', () {
  test('should generate instances for daily template', ...);
  // Arrange: daily template in Drift, RecurrenceEngineImpl
  // Act: TaskInstanceGenerator.generateForTemplate(template, daysAhead: 7)
  // Assert: 7 instances created in Drift, each with parentTaskId=template.id

  test('should not create duplicate instances', ...);
  // Arrange: daily template, instances already exist for Mon-Wed
  // Act: generateForTemplate(template, daysAhead: 7)
  // Assert: only Thu-Sun instances created

  test('should delete pending instances when template deleted', ...);
  // Arrange: template with 5 pending instances
  // Act: TaskRepositoryImpl.deleteTask(templateId)
  // Assert: template and all 5 instances soft-deleted

  test('should complete individual instance without affecting others', ...);
  // Arrange: template with Mon, Tue, Wed instances
  // Act: TaskRepositoryImpl.completeTask(monInstance)
  // Assert: Mon completed, Tue/Wed still pending
});
```

### 7.3 Category Management (category_management_test.dart)

```dart
// 4 tests:

group('Category Management Integration', () {
  test('should seed 8 default categories for new family', ...);
  // Arrange: empty Drift DB
  // Act: CategoryRepositoryImpl.seedDefaultCategories(familyId)
  // Assert: 8 categories with isDefault=true in Drift

  test('should create custom category visible in watch stream', ...);
  // Arrange: family with defaults
  // Act: CategoryRepositoryImpl.createCategory(params)
  // Assert: watchCategories emits 9 categories

  test('should block deletion of default category', ...);
  // Arrange: Kitchen default
  // Act: CategoryRepositoryImpl.deleteCategory(kitchenId)
  // Assert: Result.failure(DefaultCategoryFailure)

  test('should block deletion when active tasks reference category', ...);
  // Arrange: custom category, 2 pending tasks reference it
  // Act: CategoryRepositoryImpl.deleteCategory(customId)
  // Assert: Result.failure(CategoryInUseFailure(taskCount: 2))
});
```

### 7.4 Offline Task Operations (offline_task_test.dart)

```dart
// 3 tests:

group('Offline Task Operations', () {
  test('should create task offline and enqueue sync operation', ...);
  // Arrange: in-memory Drift, mocked SyncEngine, no connectivity
  // Act: TaskRepositoryImpl.createTask(params)
  // Assert: task in Drift with syncStatus=pending, SyncOp enqueued

  test('should complete task offline with local points award', ...);
  // Arrange: pending task, no connectivity
  // Act: TaskRepositoryImpl.completeTask(params)
  // Assert: task completed in Drift, points added via MemberRepo, SyncOp enqueued

  test('should show pending sync count from SyncOperationsTable', ...);
  // Arrange: 3 pending SyncOps for tasks
  // Act: watchPendingSyncCount(familyId)
  // Assert: stream emits 3
});
```

---

## 8. Cloud Function Tests

### 8.1 generateRecurringInstances (Jest)

```typescript
// functions/test/generateRecurringInstances.test.ts

describe('generateRecurringInstances', () => {
  test('should generate instances for daily template', async () => {
    // Arrange: family with daily template in Firestore emulator
    // Act: invoke function
    // Assert: 7 new task documents created in tasks collection
  });

  test('should handle family with no templates', async () => {
    // Arrange: family with zero recurring templates
    // Act: invoke function
    // Assert: no errors, no new documents
  });

  test('should deduplicate existing instances', async () => {
    // Arrange: template with 3 existing instances (Mon, Tue, Wed)
    // Act: invoke function
    // Assert: only Thu-Sun instances created (no duplicates)
  });

  test('should skip deleted templates', async () => {
    // Arrange: template with status='deleted'
    // Act: invoke function
    // Assert: no instances created
  });

  test('should handle invalid RRULE gracefully', async () => {
    // Arrange: template with recurrenceRule='INVALID'
    // Act: invoke function
    // Assert: error logged, no crash, other templates processed
  });
});
```

---

## 9. End-to-End Test

### 9.1 Full Task Lifecycle E2E

```dart
// test/e2e/task_lifecycle_e2e_test.dart
//
// Prerequisites: Firebase emulators running, app built
//
// This test exercises the full user journey:

testWidgets('full task lifecycle: create, complete, verify', (tester) async {
  // 1. Sign in as Marcus (parent)
  //    - Enter email/password on SignInScreen
  //    - Wait for TaskListScreen to appear

  // 2. Create a new task
  //    - Tap FAB "+" button
  //    - Verify PIN entry (enter PIN)
  //    - Fill in title: "E2E Test Task"
  //    - Select category: "Kitchen"
  //    - Select assignee: "Alex"
  //    - Set points: 20
  //    - Add subtask: "Step 1"
  //    - Tap save checkmark
  //    - Verify task appears in TaskListScreen

  // 3. Switch profile to Alex
  //    - Tap profile avatar
  //    - Select Alex from profile switcher
  //    - Verify "E2E Test Task" appears in Alex's task list

  // 4. Complete the task
  //    - Tap on "E2E Test Task" card
  //    - Verify TaskDetailScreen shows correct details
  //    - Tap "Mark Complete" button
  //    - Verify confetti animation plays
  //    - Verify "+20 pts" flash shown
  //    - Verify task status changes to completed

  // 5. Switch back to Marcus and verify
  //    - Tap profile avatar
  //    - Select Marcus
  //    - Enter PIN
  //    - Navigate to task detail
  //    - Tap "Verify" button
  //    - Confirm verification dialog
  //    - Verify task status changes to verified

  // 6. Check task appears in completed filter
  //    - Tap "Completed" filter chip
  //    - Verify "E2E Test Task" visible with verified badge
});
```

### 9.2 Recurring Task E2E

```dart
testWidgets('recurring task creates instances automatically', (tester) async {
  // 1. Sign in as Marcus
  // 2. Create recurring task:
  //    - Title: "Recurring E2E"
  //    - Recurrence: Daily
  //    - Set due date to today
  // 3. Verify task list shows instances for today and tomorrow
  // 4. Complete today's instance
  // 5. Verify tomorrow's instance remains pending
  // 6. Verify completed instance shows in completed filter
});
```

---

## 10. Test Execution Strategy

### 10.1 CI Pipeline

```bash
# Step 1: Run unit tests
flutter test test/unit/ --coverage

# Step 2: Run widget tests
flutter test test/widget/ --coverage

# Step 3: Run integration tests (requires Drift in-memory)
flutter test test/integration/ --coverage

# Step 4: Run Cloud Function tests
cd functions && npm test

# Step 5: Merge coverage and check threshold
lcov --add-tracefile coverage/lcov.info \
     -a coverage/unit.info \
     -a coverage/widget.info \
     -a coverage/integration.info \
     -o coverage/merged.info

lcov --summary coverage/merged.info | grep "lines" | awk '{print $2}' | \
  awk -F'%' '{ if ($1 < 80) exit 1; }'
```

### 10.2 Test Counts Summary

| Category | File Count | Test Count |
|----------|-----------|------------|
| Domain entity tests | 3 | 12 |
| Use case tests | 7 | 26 |
| Repository impl tests | 2 | 14 |
| Data mapper tests | 2 | 8 |
| RecurrenceEngine tests | 1 | 15 |
| TaskInstanceGenerator tests | 1 | 8 |
| BLoC/Cubit tests | 5 | 52 |
| Widget tests | 10 | 57 |
| Integration tests | 4 | 17 |
| Cloud Function tests | 1 | 5 |
| E2E tests | 1 | 2 |
| **Total** | **37** | **~216** |

### 10.3 Test Priority Matrix

| Priority | Must Pass for Merge | Count |
|----------|-------------------|-------|
| High | Yes | ~120 |
| Medium | Yes (warn only in dev) | ~70 |
| Low | No (tracked as tech debt) | ~26 |

---

## 11. Implementation Recommendations

### 11.1 Prototype Checklist

1. **What can a user do?** N/A -- this is the test plan, not a feature.
2. **Which screens are delivered?** N/A.
3. **What is the minimum data flow?** Tests validate all data flows from specs 17-24.
4. **What is the offline behavior?** Offline tests explicitly validate all CRUD operations without connectivity.
5. **What does "done" look like?** All 216 tests pass. Overall coverage >= 80%. CI pipeline green.

### 11.2 Suggested Approach

1. Set up test fixtures first (TaskFixtures, CategoryFixtures, MemberFixtures).
2. Set up mock factories and register fallback values.
3. Write entity tests (pure logic, fastest to implement).
4. Write use case tests (validation logic).
5. Write repository impl tests (orchestration with mocks).
6. Write BLoC/Cubit tests (state machine transitions).
7. Write widget tests (UI rendering and interaction).
8. Write integration tests (real Drift DB with mocked externals).
9. Write Cloud Function tests (Jest against Firestore emulator).
10. Write E2E test (full app with emulators).
11. Run coverage report and fill gaps.

### 11.3 Estimated Effort

**L (5-8 days)** -- 216 tests across all layers. Domain and use case tests are fast. Widget tests require more setup. Integration and E2E tests require database and emulator configuration.

---

*Generated by Software Architect Analyst*
*Date: 2026-03-09*
