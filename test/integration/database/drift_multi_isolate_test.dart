import 'dart:io';

import 'package:drift/drift.dart';
import 'package:family_chores_app/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/family_fixtures.dart';
import '../../helpers/drift_test_helper.dart';

void main() {
  group('Drift file-backed access', () {
    late AppDatabase writerDb;
    late AppDatabase readerDb;

    setUp(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final directory = await Directory.systemTemp.createTemp(
        'chores_app_multi_db_',
      );
      final path = '${directory.path}/shared.sqlite';
      writerDb = DriftTestHelper.openFileDatabase(path);
      readerDb = DriftTestHelper.openFileDatabase(path);
    });

    tearDown(() async {
      await writerDb.close();
      await readerDb.close();
    });

    test('separate database instances observe committed writes', () async {
      await writerDb.into(writerDb.familiesTable).insert(
            FamilyFixtures.family(remoteId: 'shared-family'),
          );

      final families = await (readerDb.select(readerDb.familiesTable)
            ..where((tbl) => tbl.remoteId.equals('shared-family')))
          .get();

      expect(families, hasLength(1));
      expect(families.single.name, 'The Riveras');
    });
  });
}
