import 'package:drift/drift.dart';

import '../../../../core/database/converters/enum_converters.dart';
import '../../../../core/database/converters/list_converter.dart';

@TableIndex(name: 'members_remote_id', columns: {#remoteId}, unique: true)
@TableIndex(name: 'members_family_role', columns: {#familyId, #role})
class MembersTable extends Table {
  @override
  String get tableName => 'members';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get familyId => text()();
  TextColumn get name => text()();
  TextColumn get role => text().map(const MemberRoleConverter())();
  IntColumn get age => integer()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get accentColor => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get pinHash => text().nullable()();
  TextColumn get pinSalt => text().nullable()();

  /// JSON-encoded `List<String>` of device IDs.
  TextColumn get deviceIds => text()
      .withDefault(const Constant('[]'))
      .map(const StringListConverter())();

  IntColumn get points => integer().withDefault(const Constant(0))();
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncStatus => text()
      .withDefault(const Constant('pending'))
      .map(const SyncStatusConverter())();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}
