import 'package:equatable/equatable.dart';

/// Base class for all domain-layer failures.
/// Use `Result<T>` to return failures from repository methods.
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error occurred']);
}

final class DatabaseFailure extends Failure {
  const DatabaseFailure([super.message = 'Database error occurred']);
}

final class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed']);
}

final class SyncFailure extends Failure {
  const SyncFailure([super.message = 'Sync operation failed']);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Resource not found']);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'An unexpected error occurred']);
}
