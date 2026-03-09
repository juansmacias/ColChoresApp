import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/database/app_database.dart';

@lazySingleton
class MemberLocalDataSource {
  MemberLocalDataSource(this._db);

  final AppDatabase _db;

  Future<int> insertMember(MembersTableCompanion member) {
    return _db.into(_db.membersTable).insert(member);
  }

  Future<List<MembersTableData>> getMembersForFamily(String familyId) {
    return (_db.select(_db.membersTable)
          ..where((t) => t.familyId.equals(familyId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Stream<List<MembersTableData>> watchMembersForFamily(String familyId) {
    return (_db.select(_db.membersTable)
          ..where((t) => t.familyId.equals(familyId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<MembersTableData?> getMember(int localId) {
    return (_db.select(_db.membersTable)..where((t) => t.id.equals(localId)))
        .getSingleOrNull();
  }

  Future<MembersTableData?> getMemberForUser(String uid) {
    return (_db.select(_db.membersTable)..where((t) => t.userId.equals(uid)))
        .getSingleOrNull();
  }

  Future<void> updateMember(
    int localId,
    MembersTableCompanion updates,
  ) async {
    await (_db.update(_db.membersTable)..where((t) => t.id.equals(localId)))
        .write(updates);
  }

  Future<void> deleteMember(int localId) async {
    await (_db.delete(_db.membersTable)..where((t) => t.id.equals(localId)))
        .go();
  }
}
