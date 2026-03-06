import 'package:family_chores_app/core/error/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Failure', () {
    group('NetworkFailure', () {
      test('should use default message when none provided', () {
        const failure = NetworkFailure();
        expect(failure.message, 'Network error occurred');
      });

      test('should use provided message', () {
        const failure = NetworkFailure('Custom network error');
        expect(failure.message, 'Custom network error');
      });

      test('should support value equality', () {
        const a = NetworkFailure();
        const b = NetworkFailure();
        expect(a, equals(b));
      });
    });

    group('DatabaseFailure', () {
      test('should use default message when none provided', () {
        const failure = DatabaseFailure();
        expect(failure.message, 'Database error occurred');
      });
    });

    group('ValidationFailure', () {
      test('should store custom message', () {
        const failure = ValidationFailure('Field is required');
        expect(failure.message, 'Field is required');
      });
    });
  });
}
