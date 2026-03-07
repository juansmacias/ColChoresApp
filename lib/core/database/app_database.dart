import 'package:drift/drift.dart';

import '../../features/family/data/models/families_table.dart';
import '../../features/family/data/models/members_table.dart';
import '../../features/rewards/data/models/redemptions_table.dart';
import '../../features/rewards/data/models/rewards_table.dart';
import '../../features/tasks/data/models/categories_table.dart';
import '../../features/tasks/data/models/tasks_table.dart';
import '../sync/models/sync_operation_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    FamiliesTable,
    MembersTable,
    TasksTable,
    RewardsTable,
    RedemptionsTable,
    CategoriesTable,
    SyncOperationsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
