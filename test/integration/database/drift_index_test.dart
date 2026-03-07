import 'package:drift/drift.dart';
import 'package:family_chores_app/core/database/app_database.dart';
import 'package:family_chores_app/core/enums/task_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/task_fixtures.dart';
import '../../helpers/drift_test_helper.dart';

void main() {
  group('Drift index queries', () {
    late AppDatabase database;

    setUp(() async {
      database = await DriftTestHelper.createInMemoryDatabase();

      await database.batch((batch) {
        batch.insertAll(
          database.tasksTable,
          [
            TaskFixtures.pending(
              remoteId: 'task-a',
              familyId: 'family-1',
              dueDate: DateTime(2026, 3, 5, 9),
            ),
            TaskFixtures.pending(
              remoteId: 'task-b',
              familyId: 'family-1',
              dueDate: DateTime(2026, 3, 5, 12),
            ),
            TaskFixtures.completed(
              remoteId: 'task-c',
              familyId: 'family-1',
              completedAt: DateTime(2026, 3, 4),
            ),
            TaskFixtures.pending(
              remoteId: 'task-d',
              familyId: 'family-2',
              assigneeId: 'jamie-1',
            ),
          ],
        );
      });
    });

    tearDown(() async {
      await DriftTestHelper.closeDatabase(database);
    });

    test('family/status/dueDate query returns pending tasks in due order',
        () async {
      final results = await (database.select(database.tasksTable)
            ..where(
              (tbl) =>
                  tbl.familyId.equals('family-1') &
                  tbl.status.equalsValue(TaskStatus.pending),
            )
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.dueDate)]))
          .get();

      expect(results.map((task) => task.remoteId), ['task-a', 'task-b']);
    });

    test('family/completedAt query returns completed tasks only', () async {
      final results = await (database.select(database.tasksTable)
            ..where(
              (tbl) =>
                  tbl.familyId.equals('family-1') & tbl.completedAt.isNotNull(),
            ))
          .get();

      expect(results, hasLength(1));
      expect(results.single.remoteId, 'task-c');
    });

    test('assignee filter returns tasks containing specific member', () async {
      final results = await (database.select(database.tasksTable)
            ..where(
              (_) =>
                  const CustomExpression<bool>("assignee_ids LIKE '%alex-1%'"),
            ))
          .get();

      expect(results, isNotEmpty);
      expect(
        results.every((task) => task.assigneeIds.contains('alex-1')),
        isTrue,
      );
    });
  });
}
