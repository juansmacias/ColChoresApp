import 'dart:async';

import 'package:family_chores_app/core/error/error_codes.dart';
import 'package:family_chores_app/core/error/exception_mapper.dart';
import 'package:family_chores_app/core/error/exceptions.dart';
import 'package:family_chores_app/core/error/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExceptionMapper', () {
    test('maps DatabaseException to DatabaseFailure', () {
      final stackTrace = StackTrace.current;
      final failure = ExceptionMapper.map(
        const DatabaseException(
          message: 'Write failed',
          code: ErrorCodes.dbWriteFailed,
        ),
        stackTrace,
      );

      expect(
        failure,
        isA<DatabaseFailure>()
            .having((f) => f.message, 'message', 'Write failed')
            .having((f) => f.code, 'code', ErrorCodes.dbWriteFailed)
            .having((f) => f.stackTrace, 'stackTrace', stackTrace),
      );
    });

    test('maps unknown exception to UnexpectedFailure', () {
      final stackTrace = StackTrace.current;
      final failure = ExceptionMapper.map(
        RangeError('out of range'),
        stackTrace,
        fallbackMessage: 'Failed to load tasks',
      );

      expect(
        failure,
        isA<UnexpectedFailure>()
            .having((f) => f.message, 'message', 'Failed to load tasks')
            .having((f) => f.originalException, 'original', isA<RangeError>()),
      );
    });

    test('maps TimeoutException to NetworkFailure', () {
      final stackTrace = StackTrace.current;
      final failure = ExceptionMapper.map(
        TimeoutException('slow'),
        stackTrace,
      );

      expect(
        failure,
        isA<NetworkFailure>()
            .having((f) => f.code, 'code', ErrorCodes.networkTimeout)
            .having((f) => f.stackTrace, 'stackTrace', stackTrace),
      );
    });
  });
}
