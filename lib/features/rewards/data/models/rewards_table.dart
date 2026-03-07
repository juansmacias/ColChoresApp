import 'package:drift/drift.dart';

import '../../../../core/database/converters/enum_converters.dart';

@TableIndex(name: 'rewards_remote_id', columns: {#remoteId}, unique: true)
@TableIndex(name: 'rewards_family', columns: {#familyId})
class RewardsTable extends Table {
  @override
  String get tableName => 'rewards';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get familyId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get pointCost => integer()();
  TextColumn get iconName => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get createdBy => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncStatus => text()
      .withDefault(const Constant('pending'))
      .map(const SyncStatusConverter())();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}
