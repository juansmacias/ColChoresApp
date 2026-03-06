abstract class AppConstants {
  static const String appName = 'Family Chores';
  static const String dbName = 'family_chores.db';

  // PIN
  static const int pinMinLength = 4;
  static const int pinMaxLength = 6;
  static const int pinMaxAttempts = 5;
  static const int pinLockoutSeconds = 300; // 5 minutes

  // Rewards
  static const bool autoApproveRedemptions = true;

  // Task history
  static const int taskHistoryRetentionDays = 180; // 6 months

  // Emma (age 3) UI
  static const double emmaTouchTargetSize = 56.0;
  static const int emmaCelebrationDurationMs = 2500;
}
