# Task Creation & Edit Screens

## 1. Overview

### 1.1 Summary

This specification defines the Task Creation and Task Edit screens -- the forms that parents use to create new chores and modify existing ones. It covers the `TaskCreationCubit` (shared by both screens), `TaskDraft` form state model, form validation rules, UI layout for all form sections (basic info, assignment, schedule, details, checklist), the recurrence builder UI, category picker integration, and the edit mode pre-fill behavior. These screens are PIN-gated -- only parents can access them.

### 1.2 Business Context

Task creation is the first step in the chore loop. The form must be comprehensive enough for Marcus to set up recurring weekly chores with rotation, yet simple enough that Sofia can quickly add a one-time "Pick up toys" task in under 15 seconds. The form is organized in progressive disclosure: the most common fields (title, category, assignee) are immediately visible, while advanced options (recurrence, subtasks, photo proof) are in collapsible sections.

### 1.3 Scope

**In scope:**
- `TaskCreationCubit` with form state management and validation
- `TaskDraft` model for in-progress form state
- `TaskCreationScreen` UI layout (create mode)
- `TaskEditScreen` UI layout (edit mode, pre-filled)
- Category picker widget (chip row + "New" action)
- Member assignment picker (avatar multi-select)
- Due date picker (calendar widget)
- Recurrence builder UI (dropdown + weekday chips + preview)
- Subtask checklist builder (add, remove, reorder)
- Points slider
- Age group selector
- Photo proof required toggle
- Form validation with inline error messages

**Out of scope:**
- Category management screen (see `specs/24_category_management.md`)
- Task completion flow (see `specs/22_task_completion_flow.md`)
- Recurrence engine internals (see `specs/23_recurrence_engine.md`)

### 1.4 References

- `specs/17_phase3_foundations.md` -- Routes (`/tasks/new`, `/tasks/:taskId/edit`), PIN guard
- `specs/18_task_domain.md` -- CreateTaskParams, UpdateTaskParams, validation rules
- `specs/23_recurrence_engine.md` -- RecurrenceEngine, RecurrenceConfig, RRULE builder
- `specs/24_category_management.md` -- Category entity, WatchCategories use case
- `specs/11_member_profiles.md` -- Member entity, avatars, family members list

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| TC-001 | Title field accepts 2-100 characters | High | Validation error shown for empty or > 100 chars |
| TC-002 | Category picker shows family categories | High | All categories from WatchCategories stream displayed |
| TC-003 | Category picker allows creating new category | Medium | "New" chip navigates to CategoryCreateScreen |
| TC-004 | Assignment picker shows all family members | High | Member avatars displayed as selectable chips |
| TC-005 | Assignment allows "Unassigned" option | High | "Shared pool" option available, deselects all members |
| TC-006 | Due date picker uses calendar widget | High | table_calendar widget for date selection |
| TC-007 | Recurrence builder generates valid RRULE | High | Selected options produce valid RFC 5545 RRULE |
| TC-008 | Recurrence preview shows next 3 occurrences | Medium | Dates displayed below recurrence selector |
| TC-009 | Points slider snaps to predefined values | High | Snaps to: 5, 10, 15, 20, 25, 30, 40, 50, 100 |
| TC-010 | Subtask builder supports add, remove, reorder | High | Dynamic list with + button, X delete, drag handle |
| TC-011 | Form validates on submit | High | All validation errors shown inline before submission |
| TC-012 | Edit mode pre-fills all fields | High | Existing task data populates every form field |
| TC-013 | Save button calls CreateTask or UpdateTask use case | High | Correct use case called based on mode |
| TC-014 | Success navigates back to TaskListScreen | High | Router pops to task list with new/updated task visible |
| TC-015 | Age group selector shows 4 options | Medium | Toddler, Child, Teen, Adult chips |
| TC-016 | Photo proof required toggle | Medium | Switch widget with label |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| TC-NFR-001 | Form render time | Time from route to interactive form | < 300ms |
| TC-NFR-002 | Form validation time | Time from submit tap to error display | < 50ms |
| TC-NFR-003 | Keyboard handling | Form scrolls to active field | Smooth scroll, field not obscured |
| TC-NFR-004 | State preservation | Form state survives keyboard dismiss | All fields retained |

### 2.3 Assumptions

- WatchCategories use case provides a reactive stream of family categories.
- Family members list is available from MemberRepository or ActiveProfileCubit.
- RecurrenceEngine provides `buildRrule` and `getHumanReadableDescription` methods.
- The `table_calendar` package is installed per `specs/17_phase3_foundations.md`.

### 2.4 Constraints

- PIN guard ensures only parents reach this screen -- no in-screen role check needed.
- The form must work offline -- category list and member list come from Drift.
- Photo proof is a toggle, not a capture -- actual photo capture happens during completion (see `specs/22_task_completion_flow.md`).

---

## 3. TaskCreationCubit

### 3.1 States

```dart
// lib/features/tasks/presentation/cubit/task_creation_cubit.dart
import 'package:equatable/equatable.dart';

import '../../domain/entities/task.dart';
import '../../domain/failures/task_failures.dart';

/// States for the task creation/edit form.
sealed class TaskCreationState extends Equatable {
  const TaskCreationState();

  @override
  List<Object?> get props => [];
}

/// Initial state with empty form.
final class TaskCreationInitial extends TaskCreationState {
  const TaskCreationInitial(this.draft);

  final TaskDraft draft;

  @override
  List<Object?> get props => [draft];
}

/// Form is submitting (saving to repository).
final class TaskCreationLoading extends TaskCreationState {
  const TaskCreationLoading();
}

/// Task created/updated successfully.
final class TaskCreationSuccess extends TaskCreationState {
  const TaskCreationSuccess(this.task);

  final Task task;

  @override
  List<Object?> get props => [task];
}

/// Task creation/update failed with a domain failure.
final class TaskCreationFailure extends TaskCreationState {
  const TaskCreationFailure(this.failure);

  final TaskFailure failure;

  @override
  List<Object?> get props => [failure];
}

/// Validation errors detected before submission.
final class TaskCreationValidationError extends TaskCreationState {
  const TaskCreationValidationError({
    required this.fieldErrors,
    required this.draft,
  });

  final Map<String, String> fieldErrors;
  final TaskDraft draft;

  @override
  List<Object?> get props => [fieldErrors, draft];
}
```

### 3.2 TaskDraft Model

```dart
// lib/features/tasks/presentation/models/task_draft.dart
import 'package:equatable/equatable.dart';

import '../../../../core/enums/age_group.dart';
import '../../domain/entities/subtask.dart';

/// In-memory form state for task creation/editing.
///
/// This is NOT a domain entity -- it's a presentation-layer model
/// that tracks user input before validation and submission.
class TaskDraft extends Equatable {
  const TaskDraft({
    this.title = '',
    this.description = '',
    this.category = '',
    this.assigneeIds = const [],
    this.dueDate,
    this.recurrenceFrequency = RecurrenceFrequency.none,
    this.recurrenceWeekdays = const [],
    this.recurrenceDayOfMonth,
    this.recurrenceInterval = 1,
    this.points = 10,
    this.ageGroup = AgeGroup.adult,
    this.subtasks = const [],
    this.photoProofRequired = false,
    this.isEditMode = false,
    this.existingTaskId,
  });

  final String title;
  final String description;
  final String category;
  final List<String> assigneeIds;
  final DateTime? dueDate;
  final RecurrenceFrequency recurrenceFrequency;
  final List<int> recurrenceWeekdays; // 1=Mon, 7=Sun (ISO 8601)
  final int? recurrenceDayOfMonth;
  final int recurrenceInterval;
  final int points;
  final AgeGroup ageGroup;
  final List<Subtask> subtasks;
  final bool photoProofRequired;
  final bool isEditMode;
  final String? existingTaskId;

  TaskDraft copyWith({
    String? title,
    String? description,
    String? category,
    List<String>? assigneeIds,
    DateTime? dueDate,
    bool clearDueDate = false,
    RecurrenceFrequency? recurrenceFrequency,
    List<int>? recurrenceWeekdays,
    int? recurrenceDayOfMonth,
    int? recurrenceInterval,
    int? points,
    AgeGroup? ageGroup,
    List<Subtask>? subtasks,
    bool? photoProofRequired,
  }) {
    return TaskDraft(
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      assigneeIds: assigneeIds ?? this.assigneeIds,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      recurrenceFrequency: recurrenceFrequency ?? this.recurrenceFrequency,
      recurrenceWeekdays: recurrenceWeekdays ?? this.recurrenceWeekdays,
      recurrenceDayOfMonth: recurrenceDayOfMonth ?? this.recurrenceDayOfMonth,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      points: points ?? this.points,
      ageGroup: ageGroup ?? this.ageGroup,
      subtasks: subtasks ?? this.subtasks,
      photoProofRequired: photoProofRequired ?? this.photoProofRequired,
      isEditMode: isEditMode,
      existingTaskId: existingTaskId,
    );
  }

  @override
  List<Object?> get props => [
        title,
        description,
        category,
        assigneeIds,
        dueDate,
        recurrenceFrequency,
        recurrenceWeekdays,
        recurrenceDayOfMonth,
        recurrenceInterval,
        points,
        ageGroup,
        subtasks,
        photoProofRequired,
        isEditMode,
        existingTaskId,
      ];
}

/// Human-readable recurrence frequency options shown in the dropdown.
enum RecurrenceFrequency {
  none,
  daily,
  weekdays,
  weekly,
  biweekly,
  monthly,
}
```

### 3.3 Cubit Implementation

```dart
// lib/features/tasks/presentation/cubit/task_creation_cubit.dart (implementation)
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/task.dart';
import '../../domain/params/create_task_params.dart';
import '../../domain/params/update_task_params.dart';
import '../../domain/use_cases/create_task.dart';
import '../../domain/use_cases/update_task.dart';
import '../models/task_draft.dart';

@injectable
class TaskCreationCubit extends Cubit<TaskCreationState> {
  TaskCreationCubit(
    this._createTask,
    this._updateTask,
    this._recurrenceEngine,
  ) : super(const TaskCreationInitial(TaskDraft()));

  final CreateTask _createTask;
  final UpdateTask _updateTask;
  final RecurrenceEngine _recurrenceEngine;

  TaskDraft _draft = const TaskDraft();

  /// Initialize for edit mode with existing task data.
  void initializeForEdit(Task task) {
    _draft = TaskDraft(
      title: task.title,
      description: task.description ?? '',
      category: task.category,
      assigneeIds: task.assigneeIds,
      dueDate: task.dueDate,
      recurrenceFrequency: _parseRecurrenceFrequency(task.recurrenceRule),
      recurrenceWeekdays: _parseRecurrenceWeekdays(task.recurrenceRule),
      recurrenceDayOfMonth: _parseRecurrenceDayOfMonth(task.recurrenceRule),
      points: task.points,
      ageGroup: task.ageGroup,
      subtasks: task.subtasks,
      photoProofRequired: task.photoProofRequired,
      isEditMode: true,
      existingTaskId: task.id,
    );
    emit(TaskCreationInitial(_draft));
  }

  // --- Field change methods ---

  void titleChanged(String title) {
    _draft = _draft.copyWith(title: title);
    _emitDraft();
  }

  void descriptionChanged(String description) {
    _draft = _draft.copyWith(description: description);
    _emitDraft();
  }

  void categorySelected(String category) {
    _draft = _draft.copyWith(category: category);
    _emitDraft();
  }

  void assigneesChanged(List<String> assigneeIds) {
    _draft = _draft.copyWith(assigneeIds: assigneeIds);
    _emitDraft();
  }

  void dueDateChanged(DateTime? dueDate) {
    if (dueDate == null) {
      _draft = _draft.copyWith(clearDueDate: true);
    } else {
      _draft = _draft.copyWith(dueDate: dueDate);
    }
    _emitDraft();
  }

  void recurrenceFrequencyChanged(RecurrenceFrequency frequency) {
    _draft = _draft.copyWith(
      recurrenceFrequency: frequency,
      recurrenceWeekdays: frequency == RecurrenceFrequency.none
          ? []
          : _draft.recurrenceWeekdays,
    );
    _emitDraft();
  }

  void recurrenceWeekdaysChanged(List<int> weekdays) {
    _draft = _draft.copyWith(recurrenceWeekdays: weekdays);
    _emitDraft();
  }

  void recurrenceDayOfMonthChanged(int? day) {
    _draft = _draft.copyWith(recurrenceDayOfMonth: day);
    _emitDraft();
  }

  void pointsChanged(int points) {
    _draft = _draft.copyWith(points: points);
    _emitDraft();
  }

  void ageGroupChanged(AgeGroup ageGroup) {
    _draft = _draft.copyWith(ageGroup: ageGroup);
    _emitDraft();
  }

  void photoProofRequiredToggled() {
    _draft = _draft.copyWith(
      photoProofRequired: !_draft.photoProofRequired,
    );
    _emitDraft();
  }

  void subtaskAdded(String title) {
    final updatedSubtasks = [
      ..._draft.subtasks,
      Subtask(title: title),
    ];
    _draft = _draft.copyWith(subtasks: updatedSubtasks);
    _emitDraft();
  }

  void subtaskRemoved(int index) {
    final updatedSubtasks = List.of(_draft.subtasks)..removeAt(index);
    _draft = _draft.copyWith(subtasks: updatedSubtasks);
    _emitDraft();
  }

  void subtasksReordered(int oldIndex, int newIndex) {
    final updatedSubtasks = List.of(_draft.subtasks);
    final item = updatedSubtasks.removeAt(oldIndex);
    updatedSubtasks.insert(
      newIndex > oldIndex ? newIndex - 1 : newIndex,
      item,
    );
    _draft = _draft.copyWith(subtasks: updatedSubtasks);
    _emitDraft();
  }

  // --- Submission ---

  Future<void> submit({
    required String familyId,
    required String createdByMemberId,
  }) async {
    // Validate
    final errors = _validate();
    if (errors.isNotEmpty) {
      emit(TaskCreationValidationError(
        fieldErrors: errors,
        draft: _draft,
      ));
      return;
    }

    emit(const TaskCreationLoading());

    // Build RRULE if recurring
    final rrule = _buildRrule();

    if (_draft.isEditMode) {
      // Update existing task
      final result = await _updateTask(UpdateTaskParams(
        taskId: _draft.existingTaskId!,
        title: _draft.title.trim(),
        description: _draft.description.trim().isEmpty
            ? null
            : _draft.description.trim(),
        category: _draft.category,
        assigneeIds: _draft.assigneeIds,
        dueDate: _draft.dueDate,
        clearDueDate: _draft.dueDate == null,
        recurrenceRule: rrule,
        clearRecurrenceRule: rrule == null,
        points: _draft.points,
        ageGroup: _draft.ageGroup,
        photoProofRequired: _draft.photoProofRequired,
        subtasks: _draft.subtasks,
      ));

      result.when(
        success: (task) => emit(TaskCreationSuccess(task)),
        failure: (failure) =>
            emit(TaskCreationFailure(failure as TaskFailure)),
      );
    } else {
      // Create new task
      final result = await _createTask(CreateTaskParams(
        title: _draft.title.trim(),
        description: _draft.description.trim().isEmpty
            ? null
            : _draft.description.trim(),
        category: _draft.category,
        assigneeIds: _draft.assigneeIds,
        createdByMemberId: createdByMemberId,
        familyId: familyId,
        dueDate: _draft.dueDate,
        recurrenceRule: rrule,
        points: _draft.points,
        ageGroup: _draft.ageGroup,
        photoProofRequired: _draft.photoProofRequired,
        subtasks: _draft.subtasks,
      ));

      result.when(
        success: (task) => emit(TaskCreationSuccess(task)),
        failure: (failure) =>
            emit(TaskCreationFailure(failure as TaskFailure)),
      );
    }
  }

  // --- Private helpers ---

  void _emitDraft() {
    emit(TaskCreationInitial(_draft));
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};

    if (_draft.title.trim().length < 2) {
      errors['title'] = 'Title must be at least 2 characters.';
    }
    if (_draft.title.trim().length > 100) {
      errors['title'] = 'Title must be 100 characters or less.';
    }
    if (_draft.category.isEmpty) {
      errors['category'] = 'Please select a category.';
    }
    if (_draft.points < 0 || _draft.points > 100) {
      errors['points'] = 'Points must be between 0 and 100.';
    }
    if (_draft.recurrenceFrequency == RecurrenceFrequency.weekly &&
        _draft.recurrenceWeekdays.isEmpty) {
      errors['recurrence'] = 'Please select at least one day for weekly recurrence.';
    }
    if (_draft.recurrenceFrequency == RecurrenceFrequency.monthly &&
        _draft.recurrenceDayOfMonth == null) {
      errors['recurrence'] = 'Please select a day of the month.';
    }

    return errors;
  }

  String? _buildRrule() {
    if (_draft.recurrenceFrequency == RecurrenceFrequency.none) return null;

    final config = RecurrenceConfig(
      frequency: _draft.recurrenceFrequency,
      interval: _draft.recurrenceInterval,
      weekdays: _draft.recurrenceWeekdays,
      dayOfMonth: _draft.recurrenceDayOfMonth,
    );

    return _recurrenceEngine.buildRrule(config);
  }

  RecurrenceFrequency _parseRecurrenceFrequency(String? rrule) {
    if (rrule == null || rrule.isEmpty) return RecurrenceFrequency.none;
    final config = _recurrenceEngine.parseRrule(rrule);
    return config.frequency;
  }

  List<int> _parseRecurrenceWeekdays(String? rrule) {
    if (rrule == null || rrule.isEmpty) return [];
    final config = _recurrenceEngine.parseRrule(rrule);
    return config.weekdays;
  }

  int? _parseRecurrenceDayOfMonth(String? rrule) {
    if (rrule == null || rrule.isEmpty) return null;
    final config = _recurrenceEngine.parseRrule(rrule);
    return config.dayOfMonth;
  }
}
```

---

## 4. Screen UI Layout

### 4.1 TaskCreationScreen / TaskEditScreen

```dart
// lib/features/tasks/presentation/screens/task_creation_screen.dart
//
// AppBar:
//   - Leading: X close button (pops back with discard confirmation if dirty)
//   - Title: "New Chore" (create) or "Edit Chore" (edit)
//   - Actions: checkmark save button
//     - Enabled only when form has changes (edit) or required fields filled (create)
//     - On tap: calls TaskCreationCubit.submit()
//
// Body (SingleChildScrollView with Form widget):
//   The form is organized in collapsible sections (ExpansionTile or
//   simply stacked cards). All sections are expanded by default on create.
//   On edit, all sections with values are expanded.
//
// Section 1: Basic Info (always expanded)
// Section 2: Assignment
// Section 3: Schedule
// Section 4: Details
// Section 5: Checklist
//
// Footer (persistent):
//   - "Last modified by {name} on {date}" (edit mode only)
//   - Padding: 16dp
//
// BlocListener:
//   - TaskCreationSuccess -> pop and show success SnackBar
//   - TaskCreationFailure -> show error SnackBar
//   - TaskCreationValidationError -> scroll to first error field
//
// Discard confirmation:
//   - If user taps X with unsaved changes, show AlertDialog:
//     "Discard changes? You have unsaved changes."
//     Actions: "Keep Editing" / "Discard"
```

### 4.2 Section 1: Basic Info

```dart
// Form Section: Basic Info
//
// Title TextFormField:
//   - Label: "Chore name"
//   - Hint: "e.g., Unload dishwasher"
//   - Max length: 100 (with counter)
//   - Auto-focus on create, no auto-focus on edit
//   - Validation: shown inline when field loses focus or on submit
//   - TextCapitalization.sentences
//   - onChanged -> cubit.titleChanged(value)
//
// Description TextFormField:
//   - Label: "Description (optional)"
//   - Hint: "Add instructions or details"
//   - Max lines: 3
//   - TextCapitalization.sentences
//   - onChanged -> cubit.descriptionChanged(value)
//
// Category Picker:
//   - Label: "Category" (above the chip row)
//   - Horizontal scroll row of ChoiceChip widgets
//   - Each chip: category icon + name, colored border
//   - Selected chip: filled with category color
//   - Last chip: "+ New" with outlined style
//     - Tap navigates to CategoryCreateScreen
//     - On return, new category auto-selected
//   - Populated from WatchCategories stream (BlocBuilder)
//   - onSelected -> cubit.categorySelected(category.name)
```

### 4.3 Section 2: Assignment

```dart
// Form Section: Assignment
//
// Label: "Assign to" (above the avatar chips)
//
// Member avatar chips:
//   - Row of FilterChip widgets with member avatar + name
//   - Multi-select (multiple family members can be assigned)
//   - Avatar: 28dp circle with member initials or image
//   - Selected: filled primary color, checkmark
//   - Unselected: outlined
//   - Source: family members from MemberRepository/ActiveProfileCubit
//
// "Unassigned" option:
//   - Special chip at end: "Shared Pool" with group icon
//   - When selected, deselects all member chips
//   - When any member is selected, deselects "Shared Pool"
//   - Shared pool means any family member can claim/complete the task
//
// onChanged -> cubit.assigneesChanged(selectedIds)
//
// Note: Emma (toddler) is shown in the list but with a "toddler" badge.
// Selecting Emma as an assignee auto-sets ageGroup to AgeGroup.toddler.
```

### 4.4 Section 3: Schedule

```dart
// Form Section: Schedule
//
// Due Date row:
//   - Label: "Due date"
//   - Current value display: formatted date or "No due date"
//   - Calendar icon button to open date picker
//   - X button to clear date (only visible when date is set)
//   - Date picker: table_calendar widget in a BottomSheet
//     - Shows current month with task dots (future feature)
//     - Min date: today
//     - Selected date highlighted with primary color
//     - "Today" button for quick selection
//   - onChanged -> cubit.dueDateChanged(date)
//
// Recurrence row (visible when due date is set):
//   - Label: "Repeat"
//   - Dropdown: None / Daily / Every weekday / Weekly / Biweekly / Monthly
//   - Default: None
//
// Conditional sub-fields (based on dropdown selection):
//
//   Weekly:
//     - Weekday chip picker: Mon Tue Wed Thu Fri Sat Sun
//     - Multi-select (e.g., Mon + Wed for "dishes every Mon and Wed")
//     - At least one day required
//     - onChanged -> cubit.recurrenceWeekdaysChanged(days)
//
//   Biweekly:
//     - Same weekday chip picker as Weekly
//     - Label: "Repeats every 2 weeks on:"
//
//   Monthly:
//     - Day-of-month number picker: 1-31
//     - If selected day doesn't exist in a month (31st in Feb),
//       falls back to last day of month
//     - onChanged -> cubit.recurrenceDayOfMonthChanged(day)
//
// Recurrence preview (below dropdown, if recurrence selected):
//   - "Next 3 occurrences:"
//   - List of 3 formatted dates: "Mon, Mar 10", "Wed, Mar 12", "Mon, Mar 17"
//   - Computed by RecurrenceEngine.getNextOccurrences(rrule, today, limit: 3)
//   - Grey-600 text, 13sp
//
// Rotation hint (below recurrence):
//   - If recurrence is weekly or daily, show info text:
//     "Tip: To rotate chores between family members, create separate
//      tasks for each day with different assignees."
//   - Icon: info_outline, grey-500
```

### 4.5 Section 4: Details

```dart
// Form Section: Details
//
// Points slider:
//   - Label: "Points earned"
//   - Slider widget: 0-100 range
//   - Snap values: 0, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100
//   - Current value display: large text "{N} pts" (amber)
//   - Quick-select chips below slider: 5, 10, 15, 20, 25 (most common)
//   - Default: 10
//   - onChanged -> cubit.pointsChanged(value)
//
// Age group selector:
//   - Label: "Appropriate for"
//   - Row of ChoiceChip widgets:
//     - Toddler (2-4) -- pink
//     - Child (5-12) -- blue
//     - Teen (13-17) -- purple
//     - Adult (18+) -- grey
//   - Default: Adult
//   - Selecting "Toddler" shows info text:
//     "Emma will see a simplified picture-based version of this task."
//   - onChanged -> cubit.ageGroupChanged(group)
//
// Photo proof required:
//   - SwitchListTile: "Require photo proof"
//   - Subtitle: "Assignee must take a photo when completing"
//   - Default: off
//   - onChanged -> cubit.photoProofRequiredToggled()
```

### 4.6 Section 5: Checklist

```dart
// Form Section: Checklist (Subtasks)
//
// Label: "Checklist" with count "(3 items)"
//
// Subtask list:
//   - ReorderableListView for drag-to-reorder
//   - Each item:
//     - Drag handle icon (left)
//     - Text showing subtask title
//     - X delete button (right)
//   - Max 20 subtasks (add button disabled at limit)
//
// Add subtask row (at bottom):
//   - TextFormField: "Add checklist item"
//   - Suffix: "+" icon button
//   - On submit (enter key or + tap):
//     - Adds subtask to list
//     - Clears text field
//     - Focus stays on text field for rapid entry
//   - onAdded -> cubit.subtaskAdded(title)
//   - onRemoved -> cubit.subtaskRemoved(index)
//   - onReordered -> cubit.subtasksReordered(oldIndex, newIndex)
//
// Empty state: "No checklist items. Add steps to break down this chore."
```

---

## 5. Form Validation Rules

### 5.1 Validation Matrix

| Field | Rule | Error Message | Timing |
|-------|------|--------------|--------|
| Title | Required | "Title is required." | On submit |
| Title | Min 2 chars | "Title must be at least 2 characters." | On submit |
| Title | Max 100 chars | "Title must be 100 characters or less." | On field change (counter) |
| Category | Required | "Please select a category." | On submit |
| Points | 0-100 range | "Points must be between 0 and 100." | Prevented by slider range |
| Due date | Not in past (create only) | "Due date cannot be in the past." | On date selection |
| Recurrence (weekly) | At least 1 weekday | "Please select at least one day." | On submit |
| Recurrence (monthly) | Day of month selected | "Please select a day of the month." | On submit |
| Subtask title | Non-empty | "Subtask title is required." | On add (prevented) |
| Subtask count | Max 20 | "Maximum 20 checklist items." | Add button disabled |

### 5.2 Validation UX

```dart
// Validation error display:
//
// Inline errors:
//   - TextFormField shows error text below the field
//   - Error text: red-600, 12sp, Nunito
//   - Field border changes to red
//
// Category picker error:
//   - Error text below the chip row
//
// On submit with errors:
//   - Scroll to the first field with an error
//   - Haptic feedback: HapticFeedback.lightImpact()
//   - All errors shown simultaneously (not one at a time)
//
// Error clearing:
//   - Errors clear when the user modifies the errored field
//   - No error re-validation until next submit
```

---

## 6. Recurrence Builder Widget

### 6.1 RecurrenceBuilder

```dart
// lib/features/tasks/presentation/widgets/recurrence_builder.dart
//
// A composite widget that manages recurrence rule selection.
//
// Props:
//   - frequency: RecurrenceFrequency (current selection)
//   - weekdays: List<int> (selected weekdays, 1=Mon..7=Sun)
//   - dayOfMonth: int? (selected day for monthly)
//   - onFrequencyChanged: (RecurrenceFrequency) -> void
//   - onWeekdaysChanged: (List<int>) -> void
//   - onDayOfMonthChanged: (int?) -> void
//   - recurrenceEngine: RecurrenceEngine (for preview)
//   - dueDate: DateTime? (start date for preview calculation)
//
// Layout:
//   - DropdownButtonFormField for frequency
//   - Conditional weekday chips (weekly/biweekly)
//   - Conditional day picker (monthly)
//   - Preview text (next 3 occurrences)
//
// Dropdown options:
//   - "Does not repeat" (RecurrenceFrequency.none)
//   - "Daily" (RecurrenceFrequency.daily)
//   - "Every weekday (Mon-Fri)" (RecurrenceFrequency.weekdays)
//   - "Weekly" (RecurrenceFrequency.weekly)
//   - "Every 2 weeks" (RecurrenceFrequency.biweekly)
//   - "Monthly" (RecurrenceFrequency.monthly)
//
// Weekday chips:
//   - Row of 7 ChoiceChip widgets
//   - Labels: M T W T F S S
//   - Color: primary when selected, outlined when not
//   - Multi-select for weekly, single-select for biweekly
//
// Preview:
//   - Only shown when recurrence is not "none"
//   - "Next 3 occurrences:" label
//   - 3 date chips or text list
//   - Computed using RecurrenceEngine.getNextOccurrences
```

---

## 7. Impact Analysis

### 7.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| `lib/features/tasks/presentation/cubit/task_creation_cubit.dart` | New | Low | New file |
| `lib/features/tasks/presentation/models/task_draft.dart` | New | Low | New file |
| `lib/features/tasks/presentation/screens/task_creation_screen.dart` | New | Low | New file |
| `lib/features/tasks/presentation/screens/task_edit_screen.dart` | New | Low | New file |
| `lib/features/tasks/presentation/widgets/recurrence_builder.dart` | New | Low | New file |
| `lib/features/tasks/presentation/widgets/category_picker.dart` | New | Low | New file |
| `lib/features/tasks/presentation/widgets/member_picker.dart` | New | Low | New file |
| `lib/features/tasks/presentation/widgets/subtask_builder.dart` | New | Low | New file |
| `lib/features/tasks/presentation/widgets/points_slider.dart` | New | Low | New file |

### 7.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Form state lost on keyboard dismiss | Low | Medium | Use Cubit to hold all state; TextEditingControllers synced |
| Recurrence RRULE generation is incorrect | Medium | High | Thorough unit tests on RecurrenceEngine.buildRrule |
| Category list empty on first use | Medium | Low | seedDefaultCategories called during family creation |
| Subtask reorder causes index errors | Low | Medium | Use UniqueKey on list items; test reorder edge cases |
| Date picker timezone issues | Low | High | Normalize all dates to local timezone before display |

---

## 8. Functional Tests

### 8.1 Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| TC-T001 | Title validation empty | Draft with title="" | submit() | Emits ValidationError with title error | High |
| TC-T002 | Title validation too long | Draft with 101-char title | submit() | Emits ValidationError with title error | High |
| TC-T003 | Category validation empty | Draft with category="" | submit() | Emits ValidationError with category error | High |
| TC-T004 | Successful create | Valid draft | submit() | Emits TaskCreationSuccess with new Task | High |
| TC-T005 | Successful edit | Valid draft, isEditMode=true | submit() | Emits TaskCreationSuccess, UpdateTask called | High |
| TC-T006 | Edit pre-fills all fields | Existing task | initializeForEdit(task) | Draft fields match task | High |
| TC-T007 | Weekly recurrence requires weekdays | frequency=weekly, weekdays=[] | submit() | Emits ValidationError | High |
| TC-T008 | Monthly recurrence requires day | frequency=monthly, dayOfMonth=null | submit() | Emits ValidationError | High |
| TC-T009 | Subtask add | Subtask title "Rinse plates" | subtaskAdded("Rinse plates") | Draft.subtasks has new item | Medium |
| TC-T010 | Subtask remove | 3 subtasks | subtaskRemoved(1) | 2 subtasks remain | Medium |
| TC-T011 | Assignee change | No assignees | assigneesChanged(["id1"]) | Draft.assigneeIds = ["id1"] | Medium |
| TC-T012 | Points change | points=10 | pointsChanged(25) | Draft.points = 25 | Medium |

### 8.2 Widget Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| TC-W001 | Title field renders | Create mode | Render screen | Title field visible with hint | High |
| TC-W002 | Category chips render | 3 categories + "New" | Render screen | 4 chips visible | High |
| TC-W003 | Save button calls submit | Valid form | Tap checkmark | submit() called | High |
| TC-W004 | Validation errors displayed | Empty title | Submit | Error text visible below title field | High |
| TC-W005 | Recurrence dropdown visible | Due date set | Render | Dropdown visible | Medium |
| TC-W006 | Weekday chips visible for weekly | frequency=weekly | Render | 7 weekday chips visible | Medium |
| TC-W007 | Subtask add from text field | Type "Rinse" and tap + | Tap add | "Rinse" appears in list | Medium |
| TC-W008 | Points slider shows value | points=25 | Render | "25 pts" visible | Medium |
| TC-W009 | Edit mode shows pre-filled title | Task with title "Dishes" | initializeForEdit | "Dishes" in title field | High |
| TC-W010 | Discard dialog shown on dirty back | Changed title | Tap X | Confirmation dialog appears | Medium |
| TC-W011 | Recurrence preview shows dates | weekly Mon+Wed | Select recurrence | 3 dates shown below | Medium |
| TC-W012 | "New" category chip navigates | Tap "New" chip | Tap | Navigates to CategoryCreateScreen | Medium |

---

## 9. Implementation Recommendations

### 9.1 Prototype Checklist

1. **What can a user do?** "As Marcus, I can tap the + button, fill in a chore name, pick a category, assign it to Alex, set it to repeat every weekday, and save it. The chore appears in the task list immediately."
2. **Which screens are delivered?** TaskCreationScreen (`/tasks/new`), TaskEditScreen (`/tasks/:taskId/edit`).
3. **What is the minimum data flow?** User fills form -> cubit.submit() -> CreateTask use case -> Drift insert -> TaskListBloc stream update -> new card in list.
4. **What is the offline behavior?** All form data is local. Category list and member list come from Drift. Submit writes to Drift with syncStatus=pending. No internet needed.
5. **What does "done" look like?** Create a recurring "Dishes" task with 3 subtasks, assigned to Alex, due tomorrow, 15 points. See it in the task list. Edit it to change the assignee. See the change reflected.

### 9.2 Suggested Approach

1. Implement TaskDraft model and RecurrenceFrequency enum.
2. Implement TaskCreationCubit with all field change methods and validation.
3. Build individual widgets: CategoryPicker, MemberPicker, PointsSlider, SubtaskBuilder, RecurrenceBuilder.
4. Compose TaskCreationScreen with all sections.
5. Implement TaskEditScreen (shares cubit, calls initializeForEdit).
6. Add discard confirmation dialog.
7. Write cubit unit tests (12 tests).
8. Write widget tests (12 tests).

### 9.3 Estimated Effort

**L (5-8 days)** -- The form has many interactive components (recurrence builder, subtask reorder, member picker) that each need individual implementation and testing.

---

*Generated by Software Architect Analyst*
*Date: 2026-03-09*
