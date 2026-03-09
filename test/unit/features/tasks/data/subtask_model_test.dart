import 'package:family_chores_app/features/tasks/data/models/subtask_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubtaskModel', () {
    const subtask = SubtaskModel(title: 'Rinse dishes', completed: false);

    group('toJson / fromJson', () {
      test('should roundtrip through JSON correctly', () {
        final json = subtask.toJson();
        final restored = SubtaskModel.fromJson(json);
        expect(restored.title, subtask.title);
        expect(restored.completed, subtask.completed);
      });
    });

    group('copyWith', () {
      test('should update completed field', () {
        final done = subtask.copyWith(completed: true);
        expect(done.completed, isTrue);
        expect(done.title, subtask.title);
      });

      test('should update title field', () {
        final renamed = subtask.copyWith(title: 'Load dishwasher');
        expect(renamed.title, 'Load dishwasher');
        expect(renamed.completed, subtask.completed);
      });
    });
  });

  group('SubtaskListConverter', () {
    const converter = SubtaskListConverter();

    test('should convert empty list to JSON and back', () {
      final json = converter.toSql([]);
      final restored = converter.fromSql(json);
      expect(restored, isEmpty);
    });

    test('should roundtrip a list of subtasks', () {
      const subtasks = [
        SubtaskModel(title: 'Top rack', completed: true),
        SubtaskModel(title: 'Bottom rack', completed: false),
      ];
      final json = converter.toSql(subtasks);
      final restored = converter.fromSql(json);
      expect(restored.length, 2);
      expect(restored[0].title, 'Top rack');
      expect(restored[0].completed, isTrue);
      expect(restored[1].title, 'Bottom rack');
      expect(restored[1].completed, isFalse);
    });
  });
}
