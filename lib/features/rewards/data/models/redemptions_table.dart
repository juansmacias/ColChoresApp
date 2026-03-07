import 'package:drift/drift.dart';

import '../../../../core/database/converters/enum_converters.dart';

@TableIndex(name: 'redemptions_remote_id', columns: {#remoteId}, unique: true)
@TableIndex(
  name: 'redemptions_member_date',
  columns: {#memberId, #redeemedAt},
)
class RedemptionsTable extends Table {
  @override
  String get tableName => 'redemptions';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get familyId => text()();
  TextColumn get rewardId => text()();
  TextColumn get memberId => text()();
  IntColumn get pointsSpent => integer()();
  DateTimeColumn get redeemedAt => dateTime()();
  TextColumn get approvedBy => text().nullable()();
  TextColumn get status => text()
      .withDefault(const Constant('pending'))
      .map(const RedemptionStatusConverter())();
  TextColumn get syncStatus => text()
      .withDefault(const Constant('pending'))
      .map(const SyncStatusConverter())();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}
