import 'package:family_chores_app/core/database/app_database.dart';
import 'package:family_chores_app/core/enums/task_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/family_fixtures.dart';
import '../../fixtures/task_fixtures.dart';
import '../../helpers/drift_test_helper.dart';

void main() {
  group('Drift schema integration', () {
    late AppDatabase database;

    setUp(() async {
      database = await DriftTestHelper.createInMemoryDatabase();
    });

    tearDown(() async {
      await DriftTestHelper.closeDatabase(database);
    });

    test('opens database and supports family roundtrip', () async {
      await database.into(database.familiesTable).insert(
            FamilyFixtures.family(
              remoteId: 'family-1',
            ),
          );

      final families = await database.select(database.familiesTable).get();

      expect(families, hasLength(1));
      expect(families.first.remoteId, 'family-1');
      expect(families.first.name, 'The Riveras');
    });

    test('writes and reads task with all key fields', () async {
      await database.into(database.tasksTable).insert(
            TaskFixtures.pending(
              remoteId: 'task-1',
            ),
          );

      final task = await (database.select(database.tasksTable)
            ..where((tbl) => tbl.remoteId.equals('task-1')))
          .getSingle();

      expect(task.title, 'Unload dishwasher');
      expect(task.status, TaskStatus.pending);
      expect(task.assigneeIds, contains('alex-1'));
    });

    test('roundtrips embedded subtasks', () async {
      await database.into(database.tasksTable).insert(
            TaskFixtures.withSubtasks(
              remoteId: 'task-subtasks',
            ),
          );

      final task = await (database.select(database.tasksTable)
            ..where((tbl) => tbl.remoteId.equals('task-subtasks')))
          .getSingle();

      expect(task.subtasks, hasLength(3));
      expect(task.subtasks.first.title, 'Top rack');
      expect(task.subtasks.first.completed, isTrue);
    });

    test('enforces unique remoteId on tasks', () async {
      await database.into(database.tasksTable).insert(
            TaskFixtures.pending(remoteId: 'duplicate-task'),
          );

      expect(
        () => database.into(database.tasksTable).insert(
              TaskFixtures.pending(remoteId: 'duplicate-task'),
            ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
