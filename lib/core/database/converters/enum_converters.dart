import 'package:drift/drift.dart';

import '../../enums/age_group.dart';
import '../../enums/member_role.dart';
import '../../enums/operation_type.dart';
import '../../enums/redemption_status.dart';
import '../../enums/task_status.dart';
import '../../sync/sync_status.dart';

class SyncStatusConverter extends TypeConverter<SyncStatus, String> {
  const SyncStatusConverter();

  @override
  SyncStatus fromSql(String fromDb) => SyncStatus.values.byName(fromDb);

  @override
  String toSql(SyncStatus value) => value.name;
}

class TaskStatusConverter extends TypeConverter<TaskStatus, String> {
  const TaskStatusConverter();

  @override
  TaskStatus fromSql(String fromDb) => TaskStatus.values.byName(fromDb);

  @override
  String toSql(TaskStatus value) => value.name;
}

class AgeGroupConverter extends TypeConverter<AgeGroup, String> {
  const AgeGroupConverter();

  @override
  AgeGroup fromSql(String fromDb) => AgeGroup.values.byName(fromDb);

  @override
  String toSql(AgeGroup value) => value.name;
}

class MemberRoleConverter extends TypeConverter<MemberRole, String> {
  const MemberRoleConverter();

  @override
  MemberRole fromSql(String fromDb) => MemberRole.values.byName(fromDb);

  @override
  String toSql(MemberRole value) => value.name;
}

class OperationTypeConverter extends TypeConverter<OperationType, String> {
  const OperationTypeConverter();

  @override
  OperationType fromSql(String fromDb) => OperationType.values.byName(fromDb);

  @override
  String toSql(OperationType value) => value.name;
}

class RedemptionStatusConverter
    extends TypeConverter<RedemptionStatus, String> {
  const RedemptionStatusConverter();

  @override
  RedemptionStatus fromSql(String fromDb) =>
      RedemptionStatus.values.byName(fromDb);

  @override
  String toSql(RedemptionStatus value) => value.name;
}
