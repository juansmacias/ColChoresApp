abstract class ErrorCodes {
  // Auth
  static const String authInvalidEmail = 'AUTH_INVALID_EMAIL';
  static const String authWrongPassword = 'AUTH_WRONG_PASSWORD';
  static const String authUserNotFound = 'AUTH_USER_NOT_FOUND';

  // PIN
  static const String pinInvalid = 'PIN_INVALID';
  static const String pinLocked = 'PIN_LOCKED';
  static const String pinMaxAttempts = 'PIN_MAX_ATTEMPTS';

  // Sync
  static const String syncConflict = 'SYNC_CONFLICT';
  static const String syncQueueFull = 'SYNC_QUEUE_FULL';
  static const String syncMaxRetries = 'SYNC_MAX_RETRIES';

  // Database
  static const String dbWriteFailed = 'DB_WRITE_FAILED';
  static const String dbReadFailed = 'DB_READ_FAILED';
}
