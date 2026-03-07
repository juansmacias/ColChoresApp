abstract class ErrorCodes {
  ErrorCodes._();

  static const String dbWriteFailed = 'DB_WRITE_FAILED';
  static const String dbReadFailed = 'DB_READ_FAILED';
  static const String dbNotFound = 'DB_NOT_FOUND';
  static const String dbMigrationFailed = 'DB_MIGRATION_FAILED';
  static const String dbSchemaError = 'DB_SCHEMA_ERROR';

  static const String syncQueueFull = 'SYNC_QUEUE_FULL';
  static const String syncOperationFailed = 'SYNC_OPERATION_FAILED';
  static const String syncConflictLocalWins = 'SYNC_CONFLICT_LOCAL_WINS';
  static const String syncConflictRemoteWins = 'SYNC_CONFLICT_REMOTE_WINS';
  static const String syncEntityDeleted = 'SYNC_ENTITY_DELETED';
  static const String syncTimeout = 'SYNC_TIMEOUT';
  static const String syncPartialFailure = 'SYNC_PARTIAL_FAILURE';

  static const String networkOffline = 'NETWORK_OFFLINE';
  static const String networkTimeout = 'NETWORK_TIMEOUT';
  static const String networkDnsFailure = 'NETWORK_DNS_FAILURE';

  static const String authInvalidCredentials = 'AUTH_INVALID_CREDENTIALS';
  static const String authTokenExpired = 'AUTH_TOKEN_EXPIRED';
  static const String authAccountDisabled = 'AUTH_ACCOUNT_DISABLED';
  static const String authEmailInUse = 'AUTH_EMAIL_IN_USE';
  static const String authWeakPassword = 'AUTH_WEAK_PASSWORD';

  static const String pinIncorrect = 'PIN_INCORRECT';
  static const String pinLockout = 'PIN_LOCKOUT';
  static const String permissionDenied = 'PERMISSION_DENIED';

  static const String validationRequired = 'VALIDATION_REQUIRED';
  static const String validationFormat = 'VALIDATION_FORMAT';
  static const String validationRange = 'VALIDATION_RANGE';
  static const String validationBusinessRule = 'VALIDATION_BUSINESS_RULE';
}
