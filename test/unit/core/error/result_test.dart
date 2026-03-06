import 'package:family_chores_app/core/error/failures.dart';
import 'package:family_chores_app/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    group('Ok', () {
      test('should return value on isOk', () {
        final result = ok(42);
        expect(result.isOk, isTrue);
        expect(result.isErr, isFalse);
      });

      test('should return value from getOrElse', () {
        final result = ok(42);
        expect(result.getOrElse(() => 0), 42);
      });

      test('should call onOk in fold', () {
        final result = ok(42);
        final output = result.fold((v) => v * 2, (_) => 0);
        expect(output, 84);
      });
    });

    group('Err', () {
      test('should return failure on isErr', () {
        final result = err<int>(const NetworkFailure());
        expect(result.isErr, isTrue);
        expect(result.isOk, isFalse);
      });

      test('should return default from getOrElse', () {
        final result = err<int>(const NetworkFailure());
        expect(result.getOrElse(() => 99), 99);
      });

      test('should call onErr in fold', () {
        final result = err<int>(const NetworkFailure('test error'));
        final output = result.fold((_) => '', (f) => f.message);
        expect(output, 'test error');
      });
    });
  });
}
