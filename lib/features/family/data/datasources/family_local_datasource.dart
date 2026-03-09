import 'package:injectable/injectable.dart';

import '../../../../core/database/app_database.dart';

@lazySingleton
class FamilyLocalDataSource {
  FamilyLocalDataSource(this._db);

  final AppDatabase _db;

  Future<int> insertFamily(FamiliesTableCompanion family) {
    return _db.into(_db.familiesTable).insert(family);
  }

  Future<FamiliesTableData?> getFamilyById(int localId) {
    return (_db.select(_db.familiesTable)..where((t) => t.id.equals(localId)))
        .getSingleOrNull();
  }

  Future<FamiliesTableData?> getFamilyByRemoteId(String remoteId) {
    return (_db.select(_db.familiesTable)
          ..where((t) => t.remoteId.equals(remoteId)))
        .getSingleOrNull();
  }

  Stream<FamiliesTableData?> watchFamilyByRemoteId(String remoteId) {
    return (_db.select(_db.familiesTable)
          ..where((t) => t.remoteId.equals(remoteId)))
        .watchSingleOrNull();
  }

  Future<void> updateFamilyByRemoteId(
    String remoteId,
    FamiliesTableCompanion updates,
  ) async {
    await (_db.update(_db.familiesTable)
          ..where((t) => t.remoteId.equals(remoteId)))
        .write(updates);
  }
}
