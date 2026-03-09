import 'package:family_chores_app/core/error/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Failure', () {
    group('NetworkFailure', () {
      test('should store message and code', () {
        const failure = NetworkFailure(
          message: 'Custom network error',
          code: 'NET_01',
        );

        expect(failure.message, 'Custom network error');
        expect(failure.code, 'NET_01');
      });

      test('should support value equality', () {
        const a = NetworkFailure(message: 'offline', code: 'NET_01');
        const b = NetworkFailure(message: 'offline', code: 'NET_01');
        expect(a, equals(b));
      });
    });

    test('should not be equal when codes differ', () {
      const a = DatabaseFailure(message: 'db error', code: 'DB_01');
      const b = DatabaseFailure(message: 'db error', code: 'DB_02');

      expect(a, isNot(equals(b)));
    });

    test('ValidationFailure should carry field errors', () {
      const failure = ValidationFailure(
        message: 'Validation failed',
        fieldErrors: {
          'name': 'Name is required',
          'age': 'Age must be positive',
        },
      );

      expect(failure.fieldErrors, {
        'name': 'Name is required',
        'age': 'Age must be positive',
      });
    });

    test('PermissionFailure should carry lockout info', () {
      const failure = PermissionFailure(
        message: 'Too many attempts',
        remainingAttempts: 0,
        lockoutDuration: Duration(minutes: 5),
      );

      expect(failure.remainingAttempts, 0);
      expect(failure.lockoutDuration, const Duration(minutes: 5));
    });
  });
}
