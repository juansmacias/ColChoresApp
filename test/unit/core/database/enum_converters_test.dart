import 'package:family_chores_app/core/database/converters/enum_converters.dart';
import 'package:family_chores_app/core/enums/task_status.dart';
import 'package:family_chores_app/core/enums/member_role.dart';
import 'package:family_chores_app/core/enums/operation_type.dart';
import 'package:family_chores_app/core/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncStatusConverter', () {
    const converter = SyncStatusConverter();

    test('should convert synced to string and back', () {
      expect(converter.toSql(SyncStatus.synced), 'synced');
      expect(converter.fromSql('synced'), SyncStatus.synced);
    });

    test('should convert pending to string and back', () {
      expect(converter.toSql(SyncStatus.pending), 'pending');
      expect(converter.fromSql('pending'), SyncStatus.pending);
    });
  });

  group('TaskStatusConverter', () {
    const converter = TaskStatusConverter();

    test('should convert all values by name', () {
      for (final status in TaskStatus.values) {
        expect(converter.fromSql(converter.toSql(status)), status);
      }
    });
  });

  group('MemberRoleConverter', () {
    const converter = MemberRoleConverter();

    test('should roundtrip parent', () {
      expect(
        converter.fromSql(converter.toSql(MemberRole.parent)),
        MemberRole.parent,
      );
    });

    test('should roundtrip child', () {
      expect(
        converter.fromSql(converter.toSql(MemberRole.child)),
        MemberRole.child,
      );
    });
  });

  group('OperationTypeConverter', () {
    const converter = OperationTypeConverter();

    test('should convert all values by name', () {
      for (final type in OperationType.values) {
        expect(converter.fromSql(converter.toSql(type)), type);
      }
    });
  });
}
