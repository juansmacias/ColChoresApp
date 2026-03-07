import 'package:drift/drift.dart';

import '../constants/app_constants.dart';
import '../enums/task_status.dart';
import 'app_database.dart';

/// Removes stale data from the local database to prevent unbounded growth.
/// Called on app startup after sync.
class DatabaseCleanup {
  const DatabaseCleanup(this._db);

  final AppDatabase _db;

  /// Deletes completed/verified tasks older than [AppConstants.taskHistoryRetentionDays].
  /// Returns the number of rows deleted.
  Future<int> cleanupOldTasks() async {
    final cutoff = DateTime.now().subtract(
      const Duration(days: AppConstants.taskHistoryRetentionDays),
    );

    return (_db.delete(_db.tasksTable)
          ..where(
            (t) =>
                t.status.equalsValue(TaskStatus.completed) |
                t.status.equalsValue(TaskStatus.verified),
          )
          ..where((t) => t.completedAt.isSmallerThanValue(cutoff)))
        .go();
  }

  /// Removes completed sync operations immediately after successful sync.
  /// Failed operations are retained for diagnostics.
  Future<int> cleanupCompletedSyncOperations() async {
    return (_db.delete(_db.syncOperationsTable)
          ..where((t) => t.status.equals('completed')))
        .go();
  }
}
