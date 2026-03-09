import 'package:family_chores_app/core/database/app_database.dart';
import 'package:family_chores_app/core/sync/sync_status.dart';
import 'package:drift/drift.dart';

abstract class FamilyFixtures {
  FamilyFixtures._();

  static FamiliesTableCompanion family({
    String? remoteId,
    String name = 'The Riveras',
    String createdBy = 'sofia-1',
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime(2026, 3, 1);
    return FamiliesTableCompanion.insert(
      remoteId: Value(remoteId),
      name: name,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
      syncStatus: const Value(SyncStatus.synced),
      lastSyncedAt: Value(now),
    );
  }
}
