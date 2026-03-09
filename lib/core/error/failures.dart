import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  const Failure({
    required this.message,
    this.code,
    this.stackTrace,
  });

  final String message;
  final String? code;
  final StackTrace? stackTrace;

  @override
  List<Object?> get props => [message, code];
}

final class DatabaseFailure extends Failure {
  const DatabaseFailure({
    required super.message,
    super.code,
    super.stackTrace,
  });
}

final class SyncFailure extends Failure {
  const SyncFailure({
    required super.message,
    super.code,
    super.stackTrace,
    this.failedOperationCount,
  });

  final int? failedOperationCount;

  @override
  List<Object?> get props => [...super.props, failedOperationCount];
}

final class NetworkFailure extends Failure {
  const NetworkFailure({
    required super.message,
    super.code,
    super.stackTrace,
  });
}

final class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    super.code,
    super.stackTrace,
    this.fieldErrors,
  });

  final Map<String, String>? fieldErrors;

  @override
  List<Object?> get props => [...super.props, fieldErrors];
}

class AuthFailure extends Failure {
  const AuthFailure({
    required super.message,
    super.code,
    super.stackTrace,
  });
}

final class PermissionFailure extends Failure {
  const PermissionFailure({
    required super.message,
    super.code,
    super.stackTrace,
    this.remainingAttempts,
    this.lockoutDuration,
  });

  final int? remainingAttempts;
  final Duration? lockoutDuration;

  @override
  List<Object?> get props => [
        ...super.props,
        remainingAttempts,
        lockoutDuration,
      ];
}

final class ConflictFailure extends Failure {
  const ConflictFailure({
    required super.message,
    super.code,
    super.stackTrace,
    required this.entityType,
    required this.entityId,
  });

  final String entityType;
  final String entityId;

  @override
  List<Object?> get props => [...super.props, entityType, entityId];
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure({
    required super.message,
    super.code,
    super.stackTrace,
    this.originalException,
  });

  final Object? originalException;

  @override
  List<Object?> get props => [...super.props, originalException];
}
