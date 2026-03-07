import 'package:family_chores_app/core/database/database_migrator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DatabaseMigrator', () {
    late SharedPreferences prefs;
    late DatabaseMigrator migrator;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      migrator = DatabaseMigrator(prefs);
    });

    group('migrateIfNeeded', () {
      test('should set schema version to current on first run', () async {
        await migrator.migrateIfNeeded();
        expect(prefs.getInt('db_schema_version'), 1);
      });

      test('should not run migrations if version is already current', () async {
        await prefs.setInt('db_schema_version', 1);
        // Should not throw
        await migrator.migrateIfNeeded();
        expect(prefs.getInt('db_schema_version'), 1);
      });

      test('should run migrations when stored version is behind', () async {
        await prefs.setInt('db_schema_version', 0);
        await migrator.migrateIfNeeded();
        expect(prefs.getInt('db_schema_version'), 1);
      });
    });
  });
}
