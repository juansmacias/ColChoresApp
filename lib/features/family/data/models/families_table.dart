import 'package:drift/drift.dart';

import '../../../../core/database/converters/enum_converters.dart';

@TableIndex(name: 'families_remote_id', columns: {#remoteId}, unique: true)
class FamiliesTable extends Table {
  @override
  String get tableName => 'families';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get createdBy => text()();
  TextColumn get inviteCode => text().nullable()();
  DateTimeColumn get inviteCodeExpiresAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncStatus => text()
      .withDefault(const Constant('pending'))
      .map(const SyncStatusConverter())();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}
