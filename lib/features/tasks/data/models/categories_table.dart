import 'package:drift/drift.dart';

import '../../../../core/database/converters/enum_converters.dart';

@TableIndex(
  name: 'categories_remote_id',
  columns: {#remoteId},
  unique: true,
)
@TableIndex(name: 'categories_family', columns: {#familyId})
class CategoriesTable extends Table {
  @override
  String get tableName => 'categories';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get familyId => text()();
  TextColumn get name => text()();
  TextColumn get iconName => text()();
  TextColumn get colorHex => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text()
      .withDefault(const Constant('pending'))
      .map(const SyncStatusConverter())();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}
