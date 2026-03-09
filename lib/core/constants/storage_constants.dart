abstract class StorageConstants {
  // Firestore collections
  static const String familiesCollection = 'families';
  static const String membersCollection = 'members';
  static const String tasksCollection = 'tasks';
  static const String rewardsCollection = 'rewards';
  static const String redemptionsCollection = 'redemptions';
  static const String categoriesCollection = 'categories';
  static const String auditLogCollection = 'audit_log';

  // Local DB
  static const String dbFileName = 'family_chores.db';

  // Schema versioning
  static const int currentSchemaVersion = 1;
  static const String schemaVersionKey = 'db_schema_version';

  // App preferences
  static const String hasSeenOnboardingKey = 'has_seen_onboarding';
}
