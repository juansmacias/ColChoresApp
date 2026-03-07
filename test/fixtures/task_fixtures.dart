import 'package:drift/drift.dart';
import 'package:family_chores_app/core/database/app_database.dart';
import 'package:family_chores_app/core/enums/age_group.dart';
import 'package:family_chores_app/core/enums/task_status.dart';
import 'package:family_chores_app/core/sync/sync_status.dart';
import 'package:family_chores_app/features/tasks/data/models/subtask_model.dart';

abstract class TaskFixtures {
  TaskFixtures._();

  static TasksTableCompanion pending({
    String? remoteId,
    String familyId = 'family-1',
    String title = 'Unload dishwasher',
    String assigneeId = 'alex-1',
    DateTime? dueDate,
    String category = 'Kitchen',
  }) {
    final now = DateTime(2026, 3, 1);
    return TasksTableCompanion.insert(
      remoteId: Value(remoteId),
      familyId: familyId,
      title: title,
      description: const Value('Empty the top and bottom racks'),
      category: category,
      assigneeIds: Value([assigneeId]),
      createdBy: 'sofia-1',
      dueDate: Value(dueDate ?? DateTime(2026, 3, 5, 17)),
      dueTime: const Value('17:00'),
      points: const Value(10),
      ageGroup: AgeGroup.child,
      status: const Value(TaskStatus.pending),
      requiresVerification: const Value(false),
      requiresPhoto: const Value(false),
      subtasks: const Value([]),
      createdAt: now,
      updatedAt: now,
      syncStatus: const Value(SyncStatus.synced),
      lastSyncedAt: Value(now),
    );
  }

  static TasksTableCompanion completed({
    String? remoteId,
    String familyId = 'family-1',
    DateTime? completedAt,
  }) {
    final doneAt = completedAt ?? DateTime(2026, 3, 5, 16, 30);
    return pending(
      remoteId: remoteId,
      familyId: familyId,
    ).copyWith(
      status: const Value(TaskStatus.completed),
      completedAt: Value(doneAt),
      completedBy: const Value('alex-1'),
    );
  }

  static TasksTableCompanion withSubtasks({
    String? remoteId,
    String familyId = 'family-1',
  }) {
    return pending(
      remoteId: remoteId,
      familyId: familyId,
    ).copyWith(
      subtasks: Value([
        const SubtaskModel(title: 'Top rack', completed: true),
        const SubtaskModel(title: 'Bottom rack', completed: false),
        const SubtaskModel(title: 'Silverware', completed: false),
      ]),
    );
  }
}
