import 'package:family_chores_app/core/error/failures.dart';
import 'package:family_chores_app/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    group('success', () {
      test('should carry the value', () {
        const result = Result.success(42);

        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
        expect(result.valueOrNull, 42);
        expect(result.failureOrNull, isNull);
      });

      test('should execute success branch in when()', () {
        const result = Result.success(42);

        final output = result.when(
          success: (value) => 'Got $value',
          failure: (failure) => 'Failed: ${failure.message}',
        );

        expect(output, 'Got 42');
      });

      test('map should transform success value', () {
        const result = Result.success(2);
        final mapped = result.map((value) => value * 2);

        expect(mapped.valueOrNull, 4);
      });

      test('flatMap should transform success value', () {
        const result = Result.success(2);
        final mapped = result.flatMap((value) => Result.success(value * 3));

        expect(mapped.valueOrNull, 6);
      });
    });

    group('failure', () {
      test('should carry the failure', () {
        const failure = DatabaseFailure(message: 'Write failed');
        const result = Result<int>.failure(failure);

        expect(result.isSuccess, isFalse);
        expect(result.isFailure, isTrue);
        expect(result.valueOrNull, isNull);
        expect(result.failureOrNull, failure);
      });

      test('map should pass through failure', () {
        const failure = NetworkFailure(message: 'offline');
        final result = Result<int>.failure(failure);
        final mapped = result.map((value) => value * 2);

        expect(mapped.failureOrNull, failure);
      });

      test('getOrElse should return default on failure', () {
        const result = Result<int>.failure(
          NetworkFailure(message: 'offline'),
        );

        expect(result.getOrElse(() => 99), 99);
      });

      test('getOrThrow should throw on failure', () {
        const result = Result<int>.failure(
          NetworkFailure(message: 'test error'),
        );

        expect(result.getOrThrow, throwsStateError);
      });

      test('when should execute failure branch', () {
        const result = Result<int>.failure(
          NetworkFailure(message: 'test error'),
        );
        final output = result.when(
          success: (_) => '',
          failure: (failure) => failure.message,
        );

        expect(output, 'test error');
      });
    });
  });
}
