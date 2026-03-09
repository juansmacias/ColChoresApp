import 'package:family_chores_app/core/error/error_codes.dart';
import 'package:family_chores_app/core/error/error_messages.dart';
import 'package:family_chores_app/core/error/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorMessages', () {
    test('maps database not found failures', () {
      const failure = DatabaseFailure(
        message: 'Missing',
        code: ErrorCodes.dbNotFound,
      );

      expect(
        ErrorMessages.fromFailure(failure),
        'The item you were looking for could not be found.',
      );
    });

    test('maps sync partial failure with count', () {
      const failure = SyncFailure(
        message: 'Partial sync',
        code: ErrorCodes.syncPartialFailure,
        failedOperationCount: 2,
      );

      expect(
        ErrorMessages.fromFailure(failure),
        'Most changes synced. 2 items are still pending.',
      );
    });

    test('maps unknown network code to fallback message', () {
      const failure = NetworkFailure(
        message: 'Socket exploded',
      );

      expect(
        ErrorMessages.fromFailure(failure),
        'A connection issue occurred. Please check your internet.',
      );
    });

    test('maps permission lockout with duration', () {
      const failure = PermissionFailure(
        message: 'Locked out',
        code: ErrorCodes.pinLockout,
        lockoutDuration: Duration(minutes: 7),
      );

      expect(
        ErrorMessages.fromFailure(failure),
        'Too many attempts. Try again in 7 minutes.',
      );
    });
  });
}
