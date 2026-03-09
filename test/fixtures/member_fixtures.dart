import 'package:drift/drift.dart';
import 'package:family_chores_app/core/database/app_database.dart';
import 'package:family_chores_app/core/enums/member_role.dart';
import 'package:family_chores_app/core/sync/sync_status.dart';

abstract class MemberFixtures {
  MemberFixtures._();

  static MembersTableCompanion parent({
    String remoteId = 'sofia-1',
    String familyId = 'family-1',
    String name = 'Sofia',
  }) {
    final now = DateTime(2026, 3, 1);
    return MembersTableCompanion.insert(
      remoteId: const Value('sofia-1'),
      familyId: familyId,
      name: name,
      role: MemberRole.parent,
      age: 36,
      accentColor: '#D5C8E6',
      userId: const Value('firebase-uid-sofia'),
      pinHash: const Value('sha256-hash'),
      pinSalt: const Value('device-salt'),
      deviceIds: const Value(['device-1']),
      points: const Value(0),
      currentStreak: const Value(0),
      longestStreak: const Value(0),
      createdAt: now,
      updatedAt: now,
      syncStatus: const Value(SyncStatus.synced),
      lastSyncedAt: Value(now),
    ).copyWith(remoteId: Value(remoteId));
  }

  static MembersTableCompanion child({
    String remoteId = 'alex-1',
    String familyId = 'family-1',
    String name = 'Alex',
    int age = 10,
  }) {
    final now = DateTime(2026, 3, 1);
    return MembersTableCompanion.insert(
      remoteId: Value(remoteId),
      familyId: familyId,
      name: name,
      role: MemberRole.child,
      age: age,
      accentColor: '#B5E6C5',
      deviceIds: const Value([]),
      points: const Value(45),
      currentStreak: const Value(3),
      longestStreak: const Value(7),
      createdAt: now,
      updatedAt: now,
      syncStatus: const Value(SyncStatus.synced),
      lastSyncedAt: Value(now),
    );
  }
}
