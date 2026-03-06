import '../error/failures.dart';

/// Result type for expected failures in domain-layer operations.
/// Use [Ok] for success, [Err] for expected failures.
/// Throw exceptions only for unexpected failures.
sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  T getOrElse(T Function() defaultValue) => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => defaultValue(),
      };

  R fold<R>(
    R Function(T value) onOk,
    R Function(Failure failure) onErr,
  ) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}

// Convenience constructors
Result<T> ok<T>(T value) => Ok(value);
Result<T> err<T>(Failure failure) => Err(failure);
