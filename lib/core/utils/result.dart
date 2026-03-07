import '../error/failures.dart';

sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(Failure failure) = FailureResult<T>;

  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  });

  T? get valueOrNull;
  Failure? get failureOrNull;
  bool get isSuccess;
  bool get isFailure;

  bool get isOk => isSuccess;
  bool get isErr => isFailure;

  R fold<R>(
    R Function(T value) onOk,
    R Function(Failure failure) onErr,
  ) {
    return when(success: onOk, failure: onErr);
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) {
    return success(value);
  }

  @override
  T? get valueOrNull => value;

  @override
  Failure? get failureOrNull => null;

  @override
  bool get isSuccess => true;

  @override
  bool get isFailure => false;
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);

  final Failure failure;

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) {
    return failure(this.failure);
  }

  @override
  T? get valueOrNull => null;

  @override
  Failure? get failureOrNull => failure;

  @override
  bool get isSuccess => false;

  @override
  bool get isFailure => true;
}

extension ResultExtensions<T> on Result<T> {
  Result<R> map<R>(R Function(T value) transform) {
    return when(
      success: (value) => Result.success(transform(value)),
      failure: Result.failure,
    );
  }

  Result<R> flatMap<R>(Result<R> Function(T value) transform) {
    return when(
      success: transform,
      failure: Result.failure,
    );
  }

  T getOrElse(T Function() defaultValue) {
    return when(
      success: (value) => value,
      failure: (_) => defaultValue(),
    );
  }

  T getOrThrow() {
    return when(
      success: (value) => value,
      failure: (failure) => throw StateError(
        'Attempted to unwrap a failed Result: ${failure.message}',
      ),
    );
  }
}

Result<T> ok<T>(T value) => Result.success(value);
Result<T> err<T>(Failure failure) => Result.failure(failure);
