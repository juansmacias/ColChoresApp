import 'package:drift/drift.dart';
import 'package:family_chores_app/core/database/app_database.dart';
import 'package:family_chores_app/core/sync/sync_status.dart';

abstract class RewardFixtures {
  RewardFixtures._();

  static RewardsTableCompanion reward({
    String? remoteId,
    String familyId = 'family-1',
    String title = 'Movie Night',
    int pointCost = 50,
  }) {
    final now = DateTime(2026, 3, 1);
    return RewardsTableCompanion.insert(
      remoteId: Value(remoteId),
      familyId: familyId,
      title: title,
      description: const Value('Choose the family movie'),
      pointCost: pointCost,
      isActive: const Value(true),
      createdBy: 'sofia-1',
      createdAt: now,
      updatedAt: now,
      syncStatus: const Value(SyncStatus.synced),
      lastSyncedAt: Value(now),
    );
  }
}
