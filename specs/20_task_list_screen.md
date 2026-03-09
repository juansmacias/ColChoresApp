# Task List Screen

## 1. Overview

### 1.1 Summary

This specification defines the Task List Screen -- the main screen of Phase 3 and the primary daily interaction point for all family members. It covers the TaskListBloc (state management), TaskListScreen UI layout, TaskCard widget, TaskDetailScreen, filter system, sync status indicator, and role-aware behavior (parents see all tasks, children see their own). This screen is where families spend most of their time in the app.

### 1.2 Business Context

The task list is the dashboard families see every day. It must answer the question "What needs to get done?" at a glance. For parents (Marcus, Sofia), it shows the full family workload. For children (Alex), it shows their personal assignments. For Emma (toddler), it would show a simplified view (Phase 6). The list must work flawlessly offline, show sync status visually, and provide quick-complete functionality without navigating away.

### 1.3 Scope

**In scope:**
- `TaskListBloc` with complete state machine
- `TaskFilter` enum and filtering logic
- `TaskListScreen` UI layout and behavior
- `TaskCard` widget with all visual states
- `TaskDetailScreen` with action buttons
- Sync status indicator in AppBar
- Pull-to-refresh behavior
- Role-aware content filtering
- Date grouping (Today, Tomorrow, This Week, Later, Overdue)
- Empty state illustrations

**Out of scope:**
- Task creation form (see `specs/21_task_creation_screen.md`)
- Task completion animation (see `specs/22_task_completion_flow.md`)
- Recurrence engine (see `specs/23_recurrence_engine.md`)
- Category management (see `specs/24_category_management.md`)

### 1.4 References

- `specs/17_phase3_foundations.md` -- Routes, design tokens, sync indicator spec
- `specs/18_task_domain.md` -- Task entity, use cases, failure types
- `specs/05_bloc_foundation.md` -- BLoC patterns, error handling mixins
- `specs/11_member_profiles.md` -- ActiveProfileCubit, MemberRole
- `CLAUDE.md` -- Emma excluded from fairness, child cannot reassign tasks

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| TLS-001 | Task list loads tasks for the active family | High | Tasks appear within 200ms of screen mount |
| TLS-002 | Parent profile sees all family tasks | High | All non-template tasks visible, all filters available |
| TLS-003 | Child profile sees only assigned + shared pool tasks | High | Only tasks where assigneeIds contains memberId or is empty |
| TLS-004 | Tasks grouped by due date | High | Groups: Overdue, Today, Tomorrow, This Week, Later, No Date |
| TLS-005 | Filter chips filter tasks by status | High | All, Mine, Pending, Overdue, Completed filters work |
| TLS-006 | Quick-complete from TaskCard checkbox | High | Tapping checkbox completes task without navigating |
| TLS-007 | Pull-to-refresh triggers manual sync | High | Refresh indicator visible, SyncEngine triggered |
| TLS-008 | Pending sync badge shows count | High | Red badge on sync icon shows unsynced operation count |
| TLS-009 | FAB visible to parents only | High | "+" button hidden for child profiles |
| TLS-010 | Tap TaskCard navigates to TaskDetailScreen | High | Navigation to `/tasks/:taskId` |
| TLS-011 | TaskDetailScreen shows all task fields | High | Title, description, assignees, due date, points, subtasks, status |
| TLS-012 | TaskDetailScreen action buttons are role-aware | High | Complete visible to assignee/parent; Verify, Edit, Delete to parent only |
| TLS-013 | Empty states show contextual messages | Medium | Different messages per filter: "No pending tasks", "No overdue tasks" |
| TLS-014 | Overdue tasks have visual warning | High | Red background tint, "Overdue" badge |
| TLS-015 | Pending sync tasks show sync indicator | Medium | Small cloud icon on unsynced TaskCards |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| TLS-NFR-001 | Initial load time | Time from screen mount to tasks visible | < 200ms |
| TLS-NFR-002 | Scroll performance | Frame rate during list scroll | 60 FPS |
| TLS-NFR-003 | Filter switch time | Time from filter tap to list update | < 100ms |
| TLS-NFR-004 | Memory usage | Memory for 200-task list | < 20 MB additional |

### 2.3 Assumptions

- `ActiveProfileCubit` provides `state.activeProfile` with `memberId`, `role`, and `familyId`.
- `WatchTasksForFamily` and `WatchTasksForMember` use cases return reactive Drift streams.
- `ConnectivityMonitor` from Phase 1 provides connectivity state.
- Tasks are pre-sorted by due date from the Drift query.

### 2.4 Constraints

- The task list must work entirely offline with the same UX (minus sync status).
- Long lists (200+ tasks) must scroll smoothly at 60 FPS -- use `ListView.builder`, not `ListView`.
- TaskCard must not trigger unnecessary rebuilds -- use `const` constructors and equatable states.

---

## 3. TaskListBloc

### 3.1 States

```dart
// lib/features/tasks/presentation/bloc/task_list_bloc.dart
import 'package:equatable/equatable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/task.dart';
import '../../domain/failures/task_failures.dart';

/// States for the TaskListBloc.
sealed class TaskListState extends Equatable {
  const TaskListState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any data is loaded.
final class TaskListInitial extends TaskListState {
  const TaskListInitial();
}

/// Loading state while initial task query is executing.
final class TaskListLoading extends TaskListState {
  const TaskListLoading();
}

/// Tasks loaded successfully.
final class TaskListLoaded extends TaskListState {
  const TaskListLoaded({
    required this.allTasks,
    required this.filteredTasks,
    required this.groupedTasks,
    required this.activeFilter,
    required this.pendingSyncCount,
    required this.isParent,
  });

  /// All tasks from the repository (unfiltered).
  final List<Task> allTasks;

  /// Tasks after applying the active filter.
  final List<Task> filteredTasks;

  /// Filtered tasks grouped by due date category.
  final Map<TaskDateGroup, List<Task>> groupedTasks;

  /// The currently active filter.
  final TaskFilter activeFilter;

  /// Number of pending sync operations (for badge).
  final int pendingSyncCount;

  /// Whether the active profile is a parent (for FAB visibility).
  final bool isParent;

  @override
  List<Object?> get props => [
        allTasks,
        filteredTasks,
        groupedTasks,
        activeFilter,
        pendingSyncCount,
        isParent,
      ];
}

/// Error state with failure details.
final class TaskListError extends TaskListState {
  const TaskListError(this.failure);

  final TaskFailure failure;

  @override
  List<Object?> get props => [failure];
}
```

### 3.2 Events

```dart
// Events for the TaskListBloc.
sealed class TaskListEvent extends Equatable {
  const TaskListEvent();

  @override
  List<Object?> get props => [];
}

/// Start watching tasks for the active profile.
final class TaskListStarted extends TaskListEvent {
  const TaskListStarted({
    required this.familyId,
    required this.memberId,
    required this.isParent,
  });

  final String familyId;
  final String memberId;
  final bool isParent;

  @override
  List<Object?> get props => [familyId, memberId, isParent];
}

/// User changed the active filter.
final class TaskFilterChanged extends TaskListEvent {
  const TaskFilterChanged(this.filter);

  final TaskFilter filter;

  @override
  List<Object?> get props => [filter];
}

/// Pull-to-refresh triggered by user.
final class TaskListRefreshRequested extends TaskListEvent {
  const TaskListRefreshRequested();
}

/// Quick-complete toggled from TaskCard checkbox.
final class TaskCompletionToggled extends TaskListEvent {
  const TaskCompletionToggled({
    required this.taskId,
    required this.memberId,
  });

  final String taskId;
  final String memberId;

  @override
  List<Object?> get props => [taskId, memberId];
}

/// Internal: new task list received from stream.
final class _TaskListUpdated extends TaskListEvent {
  const _TaskListUpdated(this.tasks);

  final List<Task> tasks;

  @override
  List<Object?> get props => [tasks];
}

/// Internal: sync count updated from stream.
final class _SyncCountUpdated extends TaskListEvent {
  const _SyncCountUpdated(this.count);

  final int count;

  @override
  List<Object?> get props => [count];
}
```

### 3.3 Filter and Grouping Enums

```dart
// lib/features/tasks/presentation/bloc/task_filter.dart

/// Available filters for the task list.
enum TaskFilter {
  /// All tasks (parents) or all assigned tasks (children).
  all,

  /// Tasks assigned to the active profile only.
  mine,

  /// Tasks with status = pending or inProgress.
  pending,

  /// Tasks past their due date and not completed.
  overdue,

  /// Tasks with status = completed or verified.
  completed,
}

/// Date-based grouping for task list sections.
enum TaskDateGroup {
  overdue,
  today,
  tomorrow,
  thisWeek,
  later,
  noDate,
}
```

### 3.4 BLoC Implementation

```dart
// lib/features/tasks/presentation/bloc/task_list_bloc.dart (implementation)
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/enums/task_status.dart';
import '../../domain/use_cases/watch_tasks_for_family.dart';
import '../../domain/use_cases/watch_tasks_for_member.dart';
import '../../domain/use_cases/complete_task.dart';
import '../../domain/params/complete_task_params.dart';

@injectable
class TaskListBloc extends Bloc<TaskListEvent, TaskListState> {
  TaskListBloc(
    this._watchTasksForFamily,
    this._watchTasksForMember,
    this._completeTask,
    this._taskRepository,
  ) : super(const TaskListInitial()) {
    on<TaskListStarted>(_onStarted);
    on<TaskFilterChanged>(_onFilterChanged);
    on<TaskListRefreshRequested>(_onRefreshRequested);
    on<TaskCompletionToggled>(_onCompletionToggled);
    on<_TaskListUpdated>(_onTaskListUpdated);
    on<_SyncCountUpdated>(_onSyncCountUpdated);
  }

  final WatchTasksForFamily _watchTasksForFamily;
  final WatchTasksForMember _watchTasksForMember;
  final CompleteTask _completeTask;
  final TaskRepository _taskRepository;

  StreamSubscription<List<Task>>? _taskSubscription;
  StreamSubscription<int>? _syncCountSubscription;

  String _familyId = '';
  String _memberId = '';
  bool _isParent = false;
  TaskFilter _activeFilter = TaskFilter.all;
  int _pendingSyncCount = 0;

  Future<void> _onStarted(
    TaskListStarted event,
    Emitter<TaskListState> emit,
  ) async {
    _familyId = event.familyId;
    _memberId = event.memberId;
    _isParent = event.isParent;
    _activeFilter = event.isParent ? TaskFilter.all : TaskFilter.mine;

    emit(const TaskListLoading());

    // Subscribe to task stream based on role
    final taskStream = _isParent
        ? _watchTasksForFamily(_familyId)
        : _watchTasksForMember(_familyId, _memberId);

    _taskSubscription?.cancel();
    _taskSubscription = taskStream.listen(
      (tasks) => add(_TaskListUpdated(tasks)),
    );

    // Subscribe to sync count
    _syncCountSubscription?.cancel();
    _syncCountSubscription = _taskRepository
        .watchPendingSyncCount(_familyId)
        .listen((count) => add(_SyncCountUpdated(count)));
  }

  void _onTaskListUpdated(
    _TaskListUpdated event,
    Emitter<TaskListState> emit,
  ) {
    final filtered = _applyFilter(event.tasks, _activeFilter, _memberId);
    final grouped = _groupByDate(filtered);

    emit(TaskListLoaded(
      allTasks: event.tasks,
      filteredTasks: filtered,
      groupedTasks: grouped,
      activeFilter: _activeFilter,
      pendingSyncCount: _pendingSyncCount,
      isParent: _isParent,
    ));
  }

  void _onSyncCountUpdated(
    _SyncCountUpdated event,
    Emitter<TaskListState> emit,
  ) {
    _pendingSyncCount = event.count;
    if (state is TaskListLoaded) {
      final current = state as TaskListLoaded;
      emit(TaskListLoaded(
        allTasks: current.allTasks,
        filteredTasks: current.filteredTasks,
        groupedTasks: current.groupedTasks,
        activeFilter: current.activeFilter,
        pendingSyncCount: event.count,
        isParent: current.isParent,
      ));
    }
  }

  void _onFilterChanged(
    TaskFilterChanged event,
    Emitter<TaskListState> emit,
  ) {
    _activeFilter = event.filter;
    if (state is TaskListLoaded) {
      final current = state as TaskListLoaded;
      final filtered = _applyFilter(current.allTasks, event.filter, _memberId);
      final grouped = _groupByDate(filtered);
      emit(TaskListLoaded(
        allTasks: current.allTasks,
        filteredTasks: filtered,
        groupedTasks: grouped,
        activeFilter: event.filter,
        pendingSyncCount: current.pendingSyncCount,
        isParent: current.isParent,
      ));
    }
  }

  Future<void> _onRefreshRequested(
    TaskListRefreshRequested event,
    Emitter<TaskListState> emit,
  ) async {
    // Trigger SyncEngine manual sync.
    // The task stream will automatically emit updated data
    // when the sync completes and Drift is updated.
    // No explicit state change needed -- the stream handles it.
  }

  Future<void> _onCompletionToggled(
    TaskCompletionToggled event,
    Emitter<TaskListState> emit,
  ) async {
    await _completeTask(CompleteTaskParams(
      taskId: event.taskId,
      completedByMemberId: event.memberId,
    ));
    // Result handling: if failure, the task stream will not change
    // and the UI will remain in its current state (checkbox unchecks).
    // Success is handled by the stream update from Drift.
  }

  /// Applies the selected filter to the task list.
  List<Task> _applyFilter(
    List<Task> tasks,
    TaskFilter filter,
    String memberId,
  ) {
    return switch (filter) {
      TaskFilter.all => tasks.where((t) => !t.isTerminal).toList(),
      TaskFilter.mine => tasks
          .where((t) => t.isAssignedTo(memberId) && !t.isTerminal)
          .toList(),
      TaskFilter.pending => tasks
          .where((t) => t.status == TaskStatus.pending ||
              t.status == TaskStatus.inProgress)
          .toList(),
      TaskFilter.overdue => tasks.where((t) => t.isOverdue).toList(),
      TaskFilter.completed => tasks
          .where((t) => t.status == TaskStatus.completed ||
              t.status == TaskStatus.verified)
          .toList(),
    };
  }

  /// Groups tasks by their due date relative to today.
  Map<TaskDateGroup, List<Task>> _groupByDate(List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(const Duration(days: 7));

    final groups = <TaskDateGroup, List<Task>>{};

    for (final task in tasks) {
      final group = _getDateGroup(task, today, tomorrow, weekEnd);
      groups.putIfAbsent(group, () => []).add(task);
    }

    return groups;
  }

  TaskDateGroup _getDateGroup(
    Task task,
    DateTime today,
    DateTime tomorrow,
    DateTime weekEnd,
  ) {
    if (task.dueDate == null) return TaskDateGroup.noDate;
    final dueDay = DateTime(
      task.dueDate!.year,
      task.dueDate!.month,
      task.dueDate!.day,
    );
    if (dueDay.isBefore(today)) return TaskDateGroup.overdue;
    if (dueDay.isAtSameMomentAs(today)) return TaskDateGroup.today;
    if (dueDay.isAtSameMomentAs(tomorrow)) return TaskDateGroup.tomorrow;
    if (dueDay.isBefore(weekEnd)) return TaskDateGroup.thisWeek;
    return TaskDateGroup.later;
  }

  @override
  Future<void> close() {
    _taskSubscription?.cancel();
    _syncCountSubscription?.cancel();
    return super.close();
  }
}
```

---

## 4. TaskListScreen

### 4.1 Screen Layout

```dart
// lib/features/tasks/presentation/screens/task_list_screen.dart
//
// Layout specification:
//
// AppBar:
//   - Title: "Family Chores" (Nunito, 20sp, bold)
//   - Leading: none (first tab)
//   - Actions:
//     1. SyncStatusIcon (animated, with badge)
//     2. Profile avatar (tap -> profile switcher)
//
// Below AppBar:
//   - Offline banner (conditional, from ConnectivityMonitor)
//   - Filter chip row (horizontal scroll)
//
// Body:
//   - Grouped ListView with section headers
//   - Pull-to-refresh wrapping the list
//
// FAB:
//   - "+" icon, extended FAB with "New Chore" label
//   - Visible to parent profiles only
//   - Navigates to /tasks/new (PIN-gated)
//
// Dimensions:
//   - List item spacing: 4dp vertical
//   - Section header: Nunito 14sp, semibold, grey-600
//   - Section header padding: 16dp horizontal, 12dp top, 4dp bottom
//   - Filter chip row: 44dp height, 8dp horizontal padding, 8dp chip spacing
```

### 4.2 Filter Chips

```dart
// Filter chip row specification
//
// Chips are FilterChip widgets from Material 3.
// Selected chip uses primaryContainer color.
// Unselected chip uses surfaceContainerHighest color.
//
// Parent filter chips: All | Mine | Pending | Overdue | Completed
// Child filter chips: Mine | Pending | Completed
//
// "All" is default for parents, "Mine" is default for children.
//
// Overdue chip shows count badge if overdue tasks exist:
//   "Overdue (3)" -- count in red.
//
// Chip styling:
//   - Label: Nunito 13sp
//   - Height: 32dp
//   - Border radius: 16dp
//   - Selected: filled primaryContainer, checkmark icon
//   - Unselected: outlined, no icon
```

### 4.3 Date Group Headers

```dart
// Section headers for date groups
//
// Display order:
// 1. Overdue -- "Overdue" with red-600 color, warning icon
// 2. Today -- "Today" with primary color
// 3. Tomorrow -- "Tomorrow"
// 4. This Week -- "This Week"
// 5. Later -- "Later"
// 6. No Date -- "No Due Date"
//
// Each header shows task count: "Today (5)"
// Overdue header is sticky (remains visible when scrolled)
//
// Groups with zero tasks are not rendered.
```

### 4.4 Empty States

| Filter | Empty State Message | Icon |
|--------|-------------------|------|
| All | "No chores yet! Tap + to create your first chore." | `Icons.add_task` |
| Mine | "No chores assigned to you. Enjoy the break!" | `Icons.celebration` |
| Pending | "All caught up! No pending chores." | `Icons.check_circle_outline` |
| Overdue | "Nothing overdue. Great job staying on top!" | `Icons.thumb_up_outlined` |
| Completed | "No completed chores yet. Get started!" | `Icons.history` |

```dart
// Empty state widget specification
//
// Center-aligned vertically in the remaining space.
// Icon: 64dp, grey-400
// Message: Nunito 16sp, grey-600, center-aligned
// Max width: 280dp
// Vertical spacing between icon and text: 16dp
```

---

## 5. TaskCard Widget

### 5.1 TaskCard Layout

```dart
// lib/features/tasks/presentation/widgets/task_card.dart
//
// Layout:
// ┌─────────────────────────────────────────────────────────┐
// │ ┃  Title                                    [pts] [☐]  │
// │ ┃  👤👤 Assignees    📅 Due date label                  │
// │ ┃  🔄 Pending sync (conditional)                       │
// └─────────────────────────────────────────────────────────┘
//   ┃ = category color strip (4dp wide)
//
// Card properties:
//   - Material Card with elevation 1
//   - Border radius: 12dp
//   - Background color: status-dependent (see TaskColors)
//   - InkWell for tap (-> TaskDetailScreen) and long press (-> context menu)
//   - Margin: 4dp horizontal, 4dp vertical
//   - Padding: 12dp vertical, 16dp horizontal (after category strip)
//
// Title:
//   - Nunito 16sp, medium weight
//   - Max 2 lines, ellipsis overflow
//   - Strikethrough if completed/verified
//
// Points badge:
//   - Pill shape, amber-100 background
//   - Text: "{N} pts", Nunito 12sp bold
//   - Visible only if points > 0
//
// Checkbox:
//   - 24dp visual size, 40dp touch target
//   - Only visible for actionable tasks (pending/inProgress)
//   - Animated on check (scale bounce via flutter_animate)
//   - Triggers TaskCompletionToggled event
//
// Assignee avatars:
//   - 24dp diameter circles
//   - Stacked with 8dp overlap
//   - Show first 3 + "+N" overflow indicator
//   - Display member initials or avatar image
//
// Due date label:
//   - "Today", "Tomorrow", "Overdue", or formatted date
//   - Red color for "Overdue"
//   - Grey-600 for other dates
//   - Calendar icon prefix (Icons.event, 14dp)
//
// Pending sync indicator:
//   - Small animated cloud icon (16dp, blue-400)
//   - Only visible when task.syncStatus == SyncStatus.pending
//   - Tooltip: "Waiting to sync"
//
// Status-dependent background:
//   - pending: white (no tint)
//   - inProgress: white (no tint)
//   - completed: TaskColors.completedBackground
//   - verified: TaskColors.verifiedBackground
//   - overdue (computed): TaskColors.overdueBackground
//   - syncing: TaskColors.syncingBackground (only if pending sync)
```

### 5.2 TaskCard Context Menu

```dart
// Long-press context menu (PopupMenuButton or showModalBottomSheet)
//
// Menu items (role-aware):
//
// For parents:
//   - "Mark Complete" (if task is actionable)
//   - "Verify" (if task is completed, not yet verified)
//   - "Reassign" (if task is actionable)
//   - "Edit" (navigates to /tasks/:taskId/edit, PIN-gated)
//   - "Skip" (if task is actionable)
//   - "Delete" (PIN-gated, with confirmation dialog)
//
// For children:
//   - "Mark Complete" (if assigned to them and actionable)
//
// Context menu items use leading icons:
//   - Complete: Icons.check_circle
//   - Verify: Icons.verified
//   - Reassign: Icons.people
//   - Edit: Icons.edit
//   - Skip: Icons.skip_next
//   - Delete: Icons.delete (red color)
```

### 5.3 TaskCard Interactions

| Interaction | Behavior | Notes |
|------------|----------|-------|
| Tap | Navigate to TaskDetailScreen | `context.goNamed(RouteNames.taskDetail, pathParameters: {'taskId': task.id})` |
| Long press | Show context menu | Role-aware menu items |
| Checkbox tap | Quick-complete with haptic feedback | `HapticFeedback.mediumImpact()` then `TaskCompletionToggled` event |
| Swipe right | Mark complete (alternative to checkbox) | Only for actionable tasks, with dismissible background |

---

## 6. TaskDetailScreen

### 6.1 Screen Layout

```dart
// lib/features/tasks/presentation/screens/task_detail_screen.dart
//
// AppBar:
//   - Title: task title (Nunito 18sp, ellipsis if long)
//   - Back arrow leading
//   - Actions: overflow menu (Edit, Delete -- parent only)
//
// Body (SingleChildScrollView):
//   - Status chip: colored chip showing current status
//   - Category chip: category icon + name with color
//   - Points display: large "{N} pts" text (amber)
//
//   Section "Assignment":
//   - Assignee avatar list (larger, 36dp)
//   - "Unassigned (shared pool)" label if no assignees
//
//   Section "Schedule":
//   - Due date with calendar icon
//   - Recurrence description (human-readable, e.g., "Every weekday")
//   - "Overdue by X days" warning if overdue
//
//   Section "Description" (if present):
//   - Full description text
//
//   Section "Checklist" (if subtasks exist):
//   - CheckboxListTile for each subtask
//   - Subtask checkboxes are interactive (toggle in detail screen)
//   - Progress indicator: "3/5 completed"
//   - Checking all subtasks auto-prompts "Mark task as complete?"
//
//   Section "Photo Proof" (if photoUrl exists):
//   - CachedNetworkImage display (full width, max 300dp height)
//   - Tap to view full-screen
//   - "Photo proof required" badge if required but not yet provided
//
//   Section "History" (collapsible, parent-only):
//   - ExpansionTile with audit log entries
//   - Each entry: event type icon + description + timestamp
//   - Loaded from Firestore (via TaskRemoteDatasource.getAuditLog)
//   - Shows loading spinner while fetching
//   - Graceful empty state: "No history available"
//
// Bottom action bar (persistent):
//   - Primary action button (full-width):
//     - Assignee/Parent + actionable task: "Mark Complete"
//     - Parent + completed task: "Verify"
//   - Secondary actions (icon buttons row):
//     - Skip (parent, actionable)
//     - Reassign (parent, actionable)
//     - Edit (parent, PIN-gated)
//     - Delete (parent, PIN-gated)
```

### 6.2 TaskDetailCubit

```dart
// lib/features/tasks/presentation/cubit/task_detail_cubit.dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/task.dart';
import '../../domain/entities/audit_log_entry.dart';
import '../../domain/failures/task_failures.dart';

/// States for TaskDetailCubit.
sealed class TaskDetailState extends Equatable {
  const TaskDetailState();

  @override
  List<Object?> get props => [];
}

final class TaskDetailLoading extends TaskDetailState {
  const TaskDetailLoading();
}

final class TaskDetailLoaded extends TaskDetailState {
  const TaskDetailLoaded({
    required this.task,
    this.auditLog,
    this.isLoadingAuditLog = false,
  });

  final Task task;
  final List<AuditLogEntry>? auditLog;
  final bool isLoadingAuditLog;

  @override
  List<Object?> get props => [task, auditLog, isLoadingAuditLog];
}

final class TaskDetailError extends TaskDetailState {
  const TaskDetailError(this.failure);

  final TaskFailure failure;

  @override
  List<Object?> get props => [failure];
}

/// Cubit for the task detail screen.
///
/// Loads a single task from the repository and optionally
/// fetches the audit log from Firestore.
@injectable
class TaskDetailCubit extends Cubit<TaskDetailState> {
  TaskDetailCubit(
    this._taskRepository,
    this._taskRemoteDatasource,
  ) : super(const TaskDetailLoading());

  final TaskRepository _taskRepository;
  final TaskRemoteDatasource _taskRemoteDatasource;

  /// Loads the task by ID from local Drift DB.
  Future<void> loadTask(String taskId) async {
    emit(const TaskDetailLoading());
    final result = await _taskRepository.getTask(taskId);
    result.when(
      success: (task) => emit(TaskDetailLoaded(task: task)),
      failure: (failure) => emit(TaskDetailError(failure as TaskFailure)),
    );
  }

  /// Loads audit log from Firestore (parent-only, online-only).
  Future<void> loadAuditLog(String familyId, String taskId) async {
    if (state is! TaskDetailLoaded) return;
    final current = state as TaskDetailLoaded;
    emit(TaskDetailLoaded(
      task: current.task,
      auditLog: current.auditLog,
      isLoadingAuditLog: true,
    ));

    try {
      final entries = await _taskRemoteDatasource.getAuditLog(
        familyId,
        taskId,
      );
      emit(TaskDetailLoaded(
        task: current.task,
        auditLog: entries,
        isLoadingAuditLog: false,
      ));
    } catch (_) {
      // Silently fail -- audit log is supplementary
      emit(TaskDetailLoaded(
        task: current.task,
        auditLog: [],
        isLoadingAuditLog: false,
      ));
    }
  }

  /// Toggles a subtask's completion state.
  Future<void> toggleSubtask(int index) async {
    if (state is! TaskDetailLoaded) return;
    final current = state as TaskDetailLoaded;
    final task = current.task;

    final updatedSubtasks = List.of(task.subtasks);
    updatedSubtasks[index] = updatedSubtasks[index].copyWith(
      isCompleted: !updatedSubtasks[index].isCompleted,
    );

    // Update via repository
    await _taskRepository.updateTask(
      UpdateTaskParams(
        taskId: task.id,
        subtasks: updatedSubtasks,
      ),
    );

    // Re-load task to get updated state
    await loadTask(task.id);
  }
}
```

---

## 7. Sync Status Indicator

### 7.1 SyncStatusIcon Widget

```dart
// lib/features/tasks/presentation/widgets/sync_status_icon.dart
//
// A widget that displays the current sync status in the AppBar.
//
// Subscribes to:
// 1. ConnectivityMonitor (online/offline)
// 2. TaskListBloc (pending sync count)
//
// Visual states:
//
// State 1: Online, all synced (count = 0)
//   Icon: Icons.cloud_done
//   Color: green-600
//   Badge: none
//   Animation: none
//
// State 2: Online, syncing in progress
//   Icon: Icons.cloud_sync
//   Color: blue-600
//   Badge: none
//   Animation: slow rotation (2s per revolution)
//
// State 3: Online, pending operations (count > 0)
//   Icon: Icons.cloud_upload
//   Color: amber-600
//   Badge: red circle with count, white text
//   Animation: none
//
// State 4: Offline
//   Icon: Icons.cloud_off
//   Color: grey-400
//   Badge: red circle with count if pending > 0
//   Animation: none
//
// Tap action: shows tooltip with sync details
//   "All changes synced" / "3 changes pending sync" / "Offline"
//
// Badge specifications:
//   Position: top-right corner of icon
//   Size: 16dp diameter
//   Text: Nunito 10sp bold, white
//   Background: red-600
//   Max display: "99+" for counts > 99
```

---

## 8. Reassign Dialog

### 8.1 ReassignDialog Widget

```dart
// lib/features/tasks/presentation/widgets/reassign_dialog.dart
//
// Modal bottom sheet for reassigning a task to different members.
//
// Header: "Reassign Task"
// Body: List of family members with checkboxes (multi-select)
//   - Each item: avatar (32dp) + name + role badge
//   - Currently assigned members are pre-checked
//   - "Unassigned (shared pool)" option at bottom
//   - At least one selection required (or unassigned)
//
// Footer:
//   - "Cancel" text button
//   - "Reassign" primary button
//
// On submit: calls ReassignTask use case via TaskListBloc
//   then closes dialog
```

---

## 9. Skip Dialog

### 9.1 SkipTaskDialog Widget

```dart
// lib/features/tasks/presentation/widgets/skip_task_dialog.dart
//
// AlertDialog for skipping a task with a reason.
//
// Title: "Skip Task"
// Content:
//   - "Why are you skipping this chore?"
//   - TextFormField for reason (max 200 chars, min 1 char)
//   - Quick reason chips: "Not needed today", "Someone else did it",
//     "Rescheduled", "Other"
//
// Actions:
//   - "Cancel" text button
//   - "Skip" primary button (enabled when reason is non-empty)
//
// On submit: calls SkipTask use case, closes dialog
```

---

## 10. Delete Confirmation Dialog

### 10.1 DeleteTaskDialog Widget

```dart
// lib/features/tasks/presentation/widgets/delete_task_dialog.dart
//
// AlertDialog for confirming task deletion.
//
// Title: "Delete Task?"
// Content:
//   - "Are you sure you want to delete '{task.title}'?"
//   - If recurring template: "This will also delete all future instances."
//   - Warning icon (red)
//
// Actions:
//   - "Cancel" text button
//   - "Delete" red text button
//
// On confirm: calls DeleteTask use case, navigates back to TaskListScreen
```

---

## 11. Impact Analysis

### 11.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| `lib/features/tasks/presentation/` | New | Low | Entire new directory |
| `lib/app/router/app_router.dart` | Modified | Medium | Adding Phase 3 routes |
| `lib/app/app.dart` | Modified | Medium | Adding TaskListBloc to MultiBlocProvider |
| `lib/shared/theme/task_colors.dart` | New | Low | Design tokens |

### 11.2 Dependencies

- **Upstream:** `specs/18_task_domain.md` (entities, use cases), `specs/19_task_data_layer.md` (repository impl), `specs/05_bloc_foundation.md` (BLoC patterns), `specs/11_member_profiles.md` (ActiveProfileCubit)
- **Downstream:** `specs/21_task_creation_screen.md` (FAB navigates to creation), `specs/22_task_completion_flow.md` (checkbox triggers completion)

### 11.3 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| List scroll jank with 200+ tasks | Medium | Medium | Use ListView.builder with const TaskCard constructors; profile with DevTools |
| Stream subscription leak in BLoC | Low | High | Cancel subscriptions in close(); unit test for cleanup |
| Filter change causes visual flicker | Medium | Low | Use immutable state with equatable; BLoC only emits on actual change |
| Date grouping fails across timezone boundaries | Low | Medium | Normalize all dates to local timezone before comparison |

---

## 12. Functional Tests

### 12.1 Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| TLS-T001 | Parent sees all tasks | 5 family tasks, parent profile active | TaskListStarted | All 5 tasks in state | High |
| TLS-T002 | Child sees only assigned tasks | 5 tasks, 2 assigned to child | TaskListStarted as child | 2 assigned + unassigned tasks visible | High |
| TLS-T003 | Filter pending | 3 pending, 2 completed tasks | TaskFilterChanged(pending) | 3 tasks in filteredTasks | High |
| TLS-T004 | Filter overdue | 1 overdue task | TaskFilterChanged(overdue) | 1 task in filteredTasks | High |
| TLS-T005 | Quick-complete from checkbox | Actionable task | TaskCompletionToggled | CompleteTask use case called | High |
| TLS-T006 | Pending sync count updates | 3 pending ops | _SyncCountUpdated(3) | pendingSyncCount = 3 | Medium |
| TLS-T007 | Date grouping today | Task due today | Group tasks | Task in TaskDateGroup.today | High |
| TLS-T008 | Date grouping overdue | Task due yesterday | Group tasks | Task in TaskDateGroup.overdue | High |
| TLS-T009 | FAB visible for parent | Parent profile | Render screen | FAB is visible | High |
| TLS-T010 | FAB hidden for child | Child profile | Render screen | FAB is not visible | High |
| TLS-T011 | Empty state for pending | No pending tasks | Filter pending | "All caught up" message shown | Medium |
| TLS-T012 | Stream subscription cleaned up on close | Bloc active | bloc.close() | No stream subscription leaks | High |

### 12.2 Widget Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| TLS-W001 | TaskCard renders title | Task with title "Dishes" | Render TaskCard | "Dishes" text visible | High |
| TLS-W002 | TaskCard overdue styling | Task.isOverdue = true | Render TaskCard | Red background tint applied | High |
| TLS-W003 | TaskCard completed styling | Task.status = completed | Render TaskCard | Green background, strikethrough title | High |
| TLS-W004 | TaskCard sync indicator | Task.syncStatus = pending | Render TaskCard | Cloud icon visible | Medium |
| TLS-W005 | TaskCard checkbox hidden for completed | Task.status = completed | Render TaskCard | Checkbox not visible | Medium |
| TLS-W006 | TaskCard points badge | Task.points = 15 | Render TaskCard | "15 pts" badge visible | Medium |
| TLS-W007 | TaskCard assignee avatars | 2 assignees | Render TaskCard | 2 avatar circles visible | Medium |
| TLS-W008 | Filter chips render correctly | Parent profile | Render screen | 5 filter chips visible | High |

---

## 13. Implementation Recommendations

### 13.1 Prototype Checklist

1. **What can a user do?** "As Marcus, I can open the Tasks tab and see all my family's chores grouped by when they're due. I can filter to see only overdue tasks, tap a chore to see its details, and quickly mark a chore as complete by tapping the checkbox."
2. **Which screens are delivered?** TaskListScreen (`/tasks`), TaskDetailScreen (`/tasks/:taskId`).
3. **What is the minimum data flow?** TaskListBloc subscribes to Drift stream -> tasks displayed in grouped list -> user taps checkbox -> CompleteTask use case -> Drift update -> stream emits -> UI updates.
4. **What is the offline behavior?** Task list loads from Drift (fully offline). Quick-complete writes to Drift locally. Sync badge shows pending count. Offline banner visible.
5. **What does "done" look like?** Open app as parent -> see tasks grouped by date -> tap filter chips to change view -> tap task to see details -> tap checkbox to complete -> see task move to completed group.

### 13.2 Suggested Approach

1. Create TaskFilter and TaskDateGroup enums.
2. Implement TaskListBloc with states, events, and stream management.
3. Implement TaskCard widget with all visual states.
4. Implement TaskListScreen with filter chips and grouped list.
5. Implement TaskDetailCubit and TaskDetailScreen.
6. Implement SyncStatusIcon widget.
7. Implement dialogs (Reassign, Skip, Delete).
8. Widget tests for TaskCard and TaskListScreen.
9. BLoC tests for TaskListBloc (12 tests).

### 13.3 Estimated Effort

**L (5-8 days)** -- The task list screen is the most complex UI in Phase 3, with role-aware filtering, date grouping, multiple widget states, and stream management.

---

*Generated by Software Architect Analyst*
*Date: 2026-03-09*
