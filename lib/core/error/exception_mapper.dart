import 'dart:async';
import 'dart:io';

import '../sync/exceptions/sync_conflict_exception.dart';
import 'error_codes.dart';
import 'exceptions.dart';
import 'failures.dart';

abstract class ExceptionMapper {
  ExceptionMapper._();

  static Failure map(
    Object exception,
    StackTrace stackTrace, {
    String? fallbackMessage,
  }) {
    return switch (exception) {
      DatabaseException(:final message, :final code) => DatabaseFailure(
          message: message,
          code: code,
          stackTrace: stackTrace,
        ),
      CacheException(:final message, :final code) => DatabaseFailure(
          message: message,
          code: code ?? ErrorCodes.dbNotFound,
          stackTrace: stackTrace,
        ),
      SyncException(:final message, :final code) => SyncFailure(
          message: message,
          code: code,
          stackTrace: stackTrace,
        ),
      NetworkException(:final message, :final code) => NetworkFailure(
          message: message,
          code: code,
          stackTrace: stackTrace,
        ),
      AuthException(:final message, :final code) => AuthFailure(
          message: message,
          code: code,
          stackTrace: stackTrace,
        ),
      SyncConflictException() => ConflictFailure(
          message: fallbackMessage ?? 'A sync conflict occurred.',
          code: ErrorCodes.syncConflictRemoteWins,
          stackTrace: stackTrace,
          entityType: 'unknown',
          entityId: 'unknown',
        ),
      FormatException(:final message) => ValidationFailure(
          message: message,
          code: ErrorCodes.validationFormat,
          stackTrace: stackTrace,
        ),
      TimeoutException() => NetworkFailure(
          message: fallbackMessage ?? 'The operation timed out.',
          code: ErrorCodes.networkTimeout,
          stackTrace: stackTrace,
        ),
      SocketException() => NetworkFailure(
          message: fallbackMessage ?? 'No internet connection available.',
          code: ErrorCodes.networkDnsFailure,
          stackTrace: stackTrace,
        ),
      _ => UnexpectedFailure(
          message:
              fallbackMessage ?? 'An unexpected error occurred: $exception',
          stackTrace: stackTrace,
          originalException: exception,
        ),
    };
  }
}
