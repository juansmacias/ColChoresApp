import 'error_codes.dart';
import 'failures.dart';

abstract class ErrorMessages {
  ErrorMessages._();

  static String fromFailure(Failure failure) {
    return switch (failure) {
      DatabaseFailure() => _databaseMessage(failure),
      SyncFailure() => _syncMessage(failure),
      NetworkFailure() => _networkMessage(failure),
      ValidationFailure() => failure.message,
      AuthFailure() => _authMessage(failure),
      PermissionFailure() => _permissionMessage(failure),
      ConflictFailure() => 'A change you made was updated by another '
          'device. The latest version is now showing.',
      UnexpectedFailure() => 'Something unexpected happened. Please try again.',
    };
  }

  static String _databaseMessage(DatabaseFailure failure) {
    return switch (failure.code) {
      ErrorCodes.dbNotFound =>
        'The item you were looking for could not be found.',
      ErrorCodes.dbWriteFailed =>
        'Could not save your changes. Please try again.',
      _ => 'A local storage issue occurred. Please try again.',
    };
  }

  static String _syncMessage(SyncFailure failure) {
    return switch (failure.code) {
      ErrorCodes.syncQueueFull =>
        'You have many unsaved changes. Please connect to the internet to sync.',
      ErrorCodes.syncPartialFailure => 'Most changes synced. '
          '${failure.failedOperationCount} items are still pending.',
      ErrorCodes.syncEntityDeleted =>
        'An item you edited was removed by another family member.',
      _ => 'Some changes could not be saved to the cloud. '
          'They will be retried automatically.',
    };
  }

  static String _networkMessage(NetworkFailure failure) {
    return switch (failure.code) {
      ErrorCodes.networkOffline =>
        "You're offline. Changes will sync when you reconnect.",
      ErrorCodes.networkTimeout =>
        'The connection timed out. Please try again.',
      _ => 'A connection issue occurred. Please check your internet.',
    };
  }

  static String _authMessage(AuthFailure failure) {
    return switch (failure.code) {
      ErrorCodes.authInvalidCredentials =>
        'The email or password is incorrect.',
      ErrorCodes.authTokenExpired =>
        'Your session has expired. Please sign in again.',
      ErrorCodes.authAccountDisabled =>
        'This account has been disabled. Please contact support.',
      ErrorCodes.authEmailInUse =>
        'This email is already associated with an account.',
      ErrorCodes.authWeakPassword => 'Please choose a stronger password.',
      _ => 'A sign-in issue occurred. Please try again.',
    };
  }

  static String _permissionMessage(PermissionFailure failure) {
    return switch (failure.code) {
      ErrorCodes.pinIncorrect => failure.remainingAttempts != null
          ? 'Incorrect PIN. ${failure.remainingAttempts} attempts remaining.'
          : 'Incorrect PIN.',
      ErrorCodes.pinLockout => 'Too many attempts. Try again in '
          '${failure.lockoutDuration?.inMinutes ?? 5} minutes.',
      _ => 'You do not have permission to perform this action.',
    };
  }
}
