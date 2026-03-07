import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_constants.dart';

/// Checks if the local database needs migration and runs it.
/// Called on app startup after the database is opened.
class DatabaseMigrator {
  const DatabaseMigrator(this._prefs);

  final SharedPreferences _prefs;

  Future<void> migrateIfNeeded() async {
    final storedVersion = _prefs.getInt(StorageConstants.schemaVersionKey) ?? 0;

    if (storedVersion < StorageConstants.currentSchemaVersion) {
      await _runMigrations(fromVersion: storedVersion);
      await _prefs.setInt(
        StorageConstants.schemaVersionKey,
        StorageConstants.currentSchemaVersion,
      );
    }
  }

  Future<void> _runMigrations({required int fromVersion}) async {
    // Migration functions are added here as the schema evolves.
    // Example:
    // if (fromVersion < 2) await _migrateV1ToV2();
    // if (fromVersion < 3) await _migrateV2ToV3();
    //
    // Rules:
    // - Additive changes (new columns with defaults): Drift handles automatically.
    // - Type/removal changes: require a migration function.
    // - Every migration must have a unit test with fixture data.
  }
}
