# Error Handling & Domain Failure Types

## 1. Overview

### 1.1 Summary

This specification defines the error handling strategy for the Family Chores App: the domain `Failure` hierarchy, data-layer `Exception` classes, the `Result<T>` type for expected failures, and the exception-to-failure mapping pattern enforced at repository boundaries. The goal is that no raw exception ever reaches the domain or presentation layers -- all errors are typed, meaningful, and actionable.

### 1.2 Business Context

An offline-first app with sync has more failure modes than a typical connected app: database write failures, sync conflicts, network timeouts, stale data, queue overflows, auth token expiration. Each failure type requires a different user-facing response. A generic "Something went wrong" is unacceptable. The error hierarchy defined here ensures every failure is categorized, logged, and presented appropriately.

### 1.3 Scope

**In scope:**
- `Failure` sealed class hierarchy (domain layer)
- `AppException` class hierarchy (data layer)
- `Result<T>` type using Dart 3 sealed classes
- Exception-to-Failure mapping pattern at repository boundaries
- Error code registry for sync-specific errors
- User-facing error message mapping table

**Out of scope:**
- Crashlytics integration (Phase 7)
- UI error widget implementations (feature-specific)
- Firebase-specific error codes (mapped in auth repository, Phase 2)

### 1.4 References

- `specs/00_project_foundation.md` -- Section 4.8 (Offline-First UI Communication)
- `specs/03_sync_engine.md` -- SyncFailure, ConflictFailure usage
- `specs/05_bloc_foundation.md` -- ErrorState carries Failure objects
- `docs/development-rules.md` -- Section 4.4 (Error Handling: Result types, domain errors)

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| EH-001 | Every expected failure is represented by a Failure subclass | High | No raw exceptions in domain/presentation layers. All repository methods return `Result<T>`. |
| EH-002 | Data layer exceptions are caught and mapped at repository boundary | High | Repository `catch` blocks convert every known exception to the corresponding Failure |
| EH-003 | Unknown exceptions become UnexpectedFailure | High | Any exception not explicitly mapped is wrapped in UnexpectedFailure with the original error |
| EH-004 | Failure types carry enough context for UI decisions | High | Each Failure has a message, optional code, and optional context map |
| EH-005 | Result type enables pattern matching in callers | High | Callers use `when()` or `switch` to handle success and failure exhaustively |
| EH-006 | Error codes are defined in a central registry | Medium | Sync-specific and domain-specific error codes are constants, not magic strings |
| EH-007 | User-facing error messages are centralized | Medium | A mapping from Failure type + code to user-visible string exists |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| EH-NFR-001 | Error handling overhead | Time to wrap exception in Failure | < 1ms (negligible) |
| EH-NFR-002 | Stack trace preservation | Original stack trace accessible | Always, via Failure.stackTrace |

### 2.3 Assumptions

- Dart 3.3+ sealed classes are used (not the `dartz` or `fpdart` Either type).
- All repository methods return `Future<Result<T>>` for operations that can fail.
- Pure domain functions that validate input use `ValidationFailure` (synchronous).
- The `throw` keyword is reserved for truly unexpected failures (bugs, assertions).

### 2.4 Constraints

- Per `docs/development-rules.md` Section 4.4: "Use Result types for expected failures. Reserve `throw` for unexpected failures."
- The domain layer must not catch exceptions. It only handles `Result<T>` return values.
- Failures must be equatable (for BLoC state deduplication).

---

## 3. Result Type

### 3.1 Definition

```dart
// lib/core/utils/result.dart

/// A discriminated union for operation outcomes.
/// Replaces exceptions as the primary error-handling mechanism
/// for expected failures.
///
/// Usage:
/// ```dart
/// final result = await taskRepository.getTask(id);
/// result.when(
///   success: (task) => emit(TaskLoaded(task)),
///   failure: (failure) => emit(TaskError(failure)),
/// );
/// ```
sealed class Result<T> {
  const Result();

  /// Creates a successful result.
  const factory Result.success(T value) = Success<T>;

  /// Creates a failure result.
  const factory Result.failure(Failure failure) = Failure_<T>;

  /// Pattern match on the result.
  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  });

  /// Returns the value if success, or null if failure.
  T? get valueOrNull;

  /// Returns the failure if failure, or null if success.
  Failure? get failureOrNull;

  /// Returns true if this is a success.
  bool get isSuccess;

  /// Returns true if this is a failure.
  bool get isFailure;
}

class Success<T> extends Result<T> {
  final T value;

  const Success(this.value);

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) => success(value);

  @override
  T? get valueOrNull => value;

  @override
  Failure? get failureOrNull => null;

  @override
  bool get isSuccess => true;

  @override
  bool get isFailure => false;
}

class Failure_<T> extends Result<T> {
  final Failure failure;

  const Failure_(this.failure);

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) => failure(this.failure);

  @override
  T? get valueOrNull => null;

  @override
  Failure? get failureOrNull => this.failure;

  @override
  bool get isSuccess => false;

  @override
  bool get isFailure => true;
}
```

### 3.2 Extension Methods

```dart
// lib/core/utils/result_extensions.dart

extension ResultExtensions<T> on Result<T> {
  /// Maps the success value.
  Result<R> map<R>(R Function(T value) transform) {
    return when(
      success: (value) => Result.success(transform(value)),
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Flat maps the success value.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) {
    return when(
      success: transform,
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Returns the value or a default.
  T getOrElse(T Function() defaultValue) {
    return when(
      success: (value) => value,
      failure: (_) => defaultValue(),
    );
  }

  /// Returns the value or throws.
  /// Use only in tests or when failure is logically impossible.
  T getOrThrow() {
    return when(
      success: (value) => value,
      failure: (failure) => throw StateError(
        'Attempted to unwrap a failed Result: ${failure.message}',
      ),
    );
  }
}
```

---

## 4. Failure Hierarchy

### 4.1 Base Failure Class

```dart
// lib/core/error/failures.dart

import 'package:equatable/equatable.dart';

/// Base class for all domain-level failures.
/// Extends Equatable for BLoC state deduplication.
///
/// Failures represent EXPECTED error conditions that the app
/// knows how to handle. They are returned via Result<T>,
/// never thrown as exceptions.
///
/// See docs/development-rules.md Section 4.4 for the error handling philosophy.
sealed class Failure extends Equatable {
  /// Human-readable description of what went wrong.
  /// NOT intended for user display -- use the error message mapper
  /// for user-facing strings.
  final String message;

  /// Optional error code for programmatic handling.
  /// Codes are defined in error_codes.dart.
  final String? code;

  /// Original stack trace from the caught exception, if any.
  final StackTrace? stackTrace;

  const Failure({
    required this.message,
    this.code,
    this.stackTrace,
  });

  @override
  List<Object?> get props => [message, code];
}
```

### 4.2 Concrete Failure Types

```dart
// lib/core/error/failures.dart (continued)

/// Failure from the local Isar database.
/// Covers: write errors, read errors, schema issues, migration failures.
class DatabaseFailure extends Failure {
  const DatabaseFailure({
    required super.message,
    super.code,
    super.stackTrace,
  });
}

/// Failure from the sync engine.
/// Covers: queue overflow, sync timeout, partial failure.
class SyncFailure extends Failure {
  /// Number of operations that failed, if applicable.
  final int? failedOperationCount;

  const SyncFailure({
    required super.message,
    super.code,
    super.stackTrace,
    this.failedOperationCount,
  });

  @override
  List<Object?> get props => [...super.props, failedOperationCount];
}

/// Failure from network/connectivity issues.
/// Covers: no internet, timeout, DNS failure.
class NetworkFailure extends Failure {
  const NetworkFailure({
    required super.message,
    super.code,
    super.stackTrace,
  });
}

/// Failure from input validation.
/// Covers: missing required fields, invalid formats, business rule violations.
class ValidationFailure extends Failure {
  /// Map of field name to validation error message.
  /// Enables per-field error display in forms.
  final Map<String, String>? fieldErrors;

  const ValidationFailure({
    required super.message,
    super.code,
    super.stackTrace,
    this.fieldErrors,
  });

  @override
  List<Object?> get props => [...super.props, fieldErrors];
}

/// Failure from Firebase Auth operations.
/// Covers: invalid credentials, expired token, account disabled.
class AuthFailure extends Failure {
  const AuthFailure({
    required super.message,
    super.code,
    super.stackTrace,
  });
}

/// Failure from permission/authorization violations.
/// Covers: PIN incorrect, role-based access denied, lockout.
class PermissionFailure extends Failure {
  /// Number of remaining attempts before lockout (for PIN).
  final int? remainingAttempts;

  /// Duration of lockout if currently locked out.
  final Duration? lockoutDuration;

  const PermissionFailure({
    required super.message,
    super.code,
    super.stackTrace,
    this.remainingAttempts,
    this.lockoutDuration,
  });

  @override
  List<Object?> get props => [
        ...super.props,
        remainingAttempts,
        lockoutDuration,
      ];
}

/// Failure from sync conflict resolution.
/// Covers: LWW conflict where remote wins and local state was rolled back.
class ConflictFailure extends Failure {
  /// The entity type that had a conflict (e.g., "task").
  final String entityType;

  /// The entity ID that had a conflict.
  final String entityId;

  const ConflictFailure({
    required super.message,
    super.code,
    super.stackTrace,
    required this.entityType,
    required this.entityId,
  });

  @override
  List<Object?> get props => [...super.props, entityType, entityId];
}

/// Catch-all for truly unexpected failures.
/// Wraps the original exception for logging/Crashlytics.
class UnexpectedFailure extends Failure {
  /// The original exception that was caught.
  final Object? originalException;

  const UnexpectedFailure({
    required super.message,
    super.code,
    super.stackTrace,
    this.originalException,
  });

  @override
  List<Object?> get props => [...super.props, originalException];
}
```

---

## 5. Exception Classes (Data Layer)

Exceptions are thrown in the data layer (datasources, external SDKs) and caught at the repository boundary. They are converted to the corresponding `Failure` type.

```dart
// lib/core/error/exceptions.dart

/// Base exception for data layer errors.
/// Never escapes the data layer -- always caught and mapped to a Failure.
sealed class AppException implements Exception {
  final String message;
  final String? code;

  const AppException({required this.message, this.code});
}

/// Thrown by Isar datasource operations.
class DatabaseException extends AppException {
  const DatabaseException({required super.message, super.code});
}

/// Thrown when a sync operation encounters a conflict.
class SyncConflictException extends AppException {
  final Map<String, dynamic> remoteState;
  final DateTime remoteUpdatedAt;
  final bool remoteIsDeleted;

  const SyncConflictException({
    required super.message,
    super.code,
    required this.remoteState,
    required this.remoteUpdatedAt,
    this.remoteIsDeleted = false,
  });
}

/// Thrown by sync operations for non-conflict failures.
class SyncException extends AppException {
  const SyncException({required super.message, super.code});
}

/// Thrown by network operations.
class NetworkException extends AppException {
  const NetworkException({required super.message, super.code});
}

/// Thrown by Firebase Auth operations.
class AuthException extends AppException {
  const AuthException({required super.message, super.code});
}

/// Thrown when a cached resource is not found.
class CacheException extends AppException {
  const CacheException({required super.message, super.code});
}
```

---

## 6. Exception-to-Failure Mapping

### 6.1 Pattern

Every repository implementation follows this pattern:

```dart
// Repository boundary: catch exceptions, return Result<Failure, T>

class TaskRepositoryImpl implements TaskRepository {
  final TaskLocalDatasource _localDatasource;
  final SyncEngine _syncEngine;

  TaskRepositoryImpl(this._localDatasource, this._syncEngine);

  @override
  Future<Result<List<Task>>> getTasksForMember(String memberId) async {
    try {
      final entities = await _localDatasource.getTasksByAssignee(memberId);
      final tasks = entities.map((e) => e.toDomain()).toList();
      return Result.success(tasks);
    } on DatabaseException catch (e, stackTrace) {
      return Result.failure(DatabaseFailure(
        message: e.message,
        code: e.code,
        stackTrace: stackTrace,
      ));
    } on Exception catch (e, stackTrace) {
      return Result.failure(UnexpectedFailure(
        message: 'Failed to load tasks: $e',
        stackTrace: stackTrace,
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<Task>> completeTask(String taskId) async {
    try {
      // 1. Update local DB
      final entity = await _localDatasource.markTaskCompleted(taskId);

      // 2. Enqueue sync operation
      await _syncEngine.enqueueOperation(
        entityType: 'task',
        entityId: entity.remoteId ?? taskId,
        operationType: OperationType.update,
        payload: jsonEncode(entity.toFirestoreMap()),
      );

      return Result.success(entity.toDomain());
    } on DatabaseException catch (e, stackTrace) {
      return Result.failure(DatabaseFailure(
        message: e.message,
        code: e.code,
        stackTrace: stackTrace,
      ));
    } on SyncException catch (e, stackTrace) {
      // Sync enqueue failed, but local write succeeded.
      // Return success but log the sync issue.
      return Result.failure(SyncFailure(
        message: e.message,
        code: e.code,
        stackTrace: stackTrace,
      ));
    } on Exception catch (e, stackTrace) {
      return Result.failure(UnexpectedFailure(
        message: 'Failed to complete task: $e',
        stackTrace: stackTrace,
        originalException: e,
      ));
    }
  }
}
```

### 6.2 Mapping Table

| Exception Type | Maps To | When |
|---------------|---------|------|
| `DatabaseException` | `DatabaseFailure` | Isar read/write errors |
| `SyncConflictException` | `ConflictFailure` | Sync conflict detected |
| `SyncException` | `SyncFailure` | Sync queue or push/pull errors |
| `NetworkException` | `NetworkFailure` | Connectivity or timeout errors |
| `AuthException` | `AuthFailure` | Firebase Auth errors |
| `CacheException` | `DatabaseFailure` | Cache miss (treated as DB issue) |
| `FormatException` | `ValidationFailure` | Data parsing errors |
| `TimeoutException` | `NetworkFailure` | Network timeout |
| `SocketException` | `NetworkFailure` | DNS or connection errors |
| `Any other Exception` | `UnexpectedFailure` | Unknown/unexpected errors |

---

## 7. Error Code Registry

```dart
// lib/core/error/error_codes.dart

/// Centralized error codes for programmatic error handling.
/// Used in Failure.code to enable specific UI responses.
abstract class ErrorCodes {
  ErrorCodes._();

  // --- Database ---
  static const String dbWriteFailed = 'DB_WRITE_FAILED';
  static const String dbReadFailed = 'DB_READ_FAILED';
  static const String dbNotFound = 'DB_NOT_FOUND';
  static const String dbMigrationFailed = 'DB_MIGRATION_FAILED';
  static const String dbSchemaError = 'DB_SCHEMA_ERROR';

  // --- Sync ---
  static const String syncQueueFull = 'SYNC_QUEUE_FULL';
  static const String syncOperationFailed = 'SYNC_OPERATION_FAILED';
  static const String syncConflictLocalWins = 'SYNC_CONFLICT_LOCAL_WINS';
  static const String syncConflictRemoteWins = 'SYNC_CONFLICT_REMOTE_WINS';
  static const String syncEntityDeleted = 'SYNC_ENTITY_DELETED';
  static const String syncTimeout = 'SYNC_TIMEOUT';
  static const String syncPartialFailure = 'SYNC_PARTIAL_FAILURE';

  // --- Network ---
  static const String networkOffline = 'NETWORK_OFFLINE';
  static const String networkTimeout = 'NETWORK_TIMEOUT';
  static const String networkDnsFailure = 'NETWORK_DNS_FAILURE';

  // --- Auth ---
  static const String authInvalidCredentials = 'AUTH_INVALID_CREDENTIALS';
  static const String authTokenExpired = 'AUTH_TOKEN_EXPIRED';
  static const String authAccountDisabled = 'AUTH_ACCOUNT_DISABLED';
  static const String authEmailInUse = 'AUTH_EMAIL_IN_USE';
  static const String authWeakPassword = 'AUTH_WEAK_PASSWORD';

  // --- Permission ---
  static const String pinIncorrect = 'PIN_INCORRECT';
  static const String pinLockout = 'PIN_LOCKOUT';
  static const String permissionDenied = 'PERMISSION_DENIED';

  // --- Validation ---
  static const String validationRequired = 'VALIDATION_REQUIRED';
  static const String validationFormat = 'VALIDATION_FORMAT';
  static const String validationRange = 'VALIDATION_RANGE';
  static const String validationBusinessRule = 'VALIDATION_BUSINESS_RULE';
}
```

---

## 8. User-Facing Error Messages

```dart
// lib/core/error/error_messages.dart

/// Maps Failure types and codes to user-facing messages.
///
/// All messages follow the design principles from design-system.md:
/// "Celebrate, don't punish" -- errors are gentle and informative.
abstract class ErrorMessages {
  ErrorMessages._();

  static String fromFailure(Failure failure) {
    return switch (failure) {
      DatabaseFailure() => _databaseMessage(failure),
      SyncFailure() => _syncMessage(failure),
      NetworkFailure() => _networkMessage(failure),
      ValidationFailure() => failure.message,
      AuthFailure() => _authMessage(failure),
      PermissionFailure() => _permissionMessage(failure),
      ConflictFailure() => 'A change you made was updated by another '
          'device. The latest version is now showing.',
      UnexpectedFailure() =>
        'Something unexpected happened. Please try again.',
    };
  }

  static String _databaseMessage(DatabaseFailure failure) {
    return switch (failure.code) {
      ErrorCodes.dbNotFound =>
        'The item you were looking for could not be found.',
      ErrorCodes.dbWriteFailed =>
        'Could not save your changes. Please try again.',
      _ => 'A local storage issue occurred. Please try again.',
    };
  }

  static String _syncMessage(SyncFailure failure) {
    return switch (failure.code) {
      ErrorCodes.syncQueueFull =>
        'You have many unsaved changes. Please connect '
            'to the internet to sync.',
      ErrorCodes.syncPartialFailure =>
        'Most changes synced. ${failure.failedOperationCount} '
            'items are still pending.',
      ErrorCodes.syncEntityDeleted =>
        'An item you edited was removed by another family member.',
      _ => 'Some changes could not be saved to the cloud. '
          'They will be retried automatically.',
    };
  }

  static String _networkMessage(NetworkFailure failure) {
    return switch (failure.code) {
      ErrorCodes.networkOffline =>
        "You're offline. Changes will sync when you reconnect.",
      ErrorCodes.networkTimeout =>
        'The connection timed out. Please try again.',
      _ => 'A connection issue occurred. Please check your internet.',
    };
  }

  static String _authMessage(AuthFailure failure) {
    return switch (failure.code) {
      ErrorCodes.authInvalidCredentials =>
        'The email or password is incorrect.',
      ErrorCodes.authTokenExpired =>
        'Your session has expired. Please sign in again.',
      ErrorCodes.authAccountDisabled =>
        'This account has been disabled. Please contact support.',
      ErrorCodes.authEmailInUse =>
        'This email is already associated with an account.',
      ErrorCodes.authWeakPassword =>
        'Please choose a stronger password.',
      _ => 'A sign-in issue occurred. Please try again.',
    };
  }

  static String _permissionMessage(PermissionFailure failure) {
    return switch (failure.code) {
      ErrorCodes.pinIncorrect =>
        failure.remainingAttempts != null
            ? 'Incorrect PIN. ${failure.remainingAttempts} '
                'attempts remaining.'
            : 'Incorrect PIN.',
      ErrorCodes.pinLockout =>
        'Too many attempts. Try again in '
            '${failure.lockoutDuration?.inMinutes ?? 5} minutes.',
      _ => 'You do not have permission to perform this action.',
    };
  }
}
```

---

## 9. Testing

### 9.1 Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| EH-FT-001 | Result.success carries value | A successful operation | `Result.success(task)` created | `isSuccess == true`, `valueOrNull == task` | High |
| EH-FT-002 | Result.failure carries Failure | A failed operation | `Result.failure(DatabaseFailure(...))` created | `isFailure == true`, `failureOrNull` is DatabaseFailure | High |
| EH-FT-003 | when() exhaustively matches | Result is success or failure | `.when()` called | Correct branch executes | High |
| EH-FT-004 | map() transforms success value | Result.success(1) | `.map((n) => n * 2)` | Result.success(2) | Medium |
| EH-FT-005 | map() passes through failure | Result.failure(f) | `.map((n) => n * 2)` | Result.failure(f) unchanged | Medium |
| EH-FT-006 | DatabaseException maps to DatabaseFailure | Repository catches DatabaseException | Mapping logic executes | Result.failure(DatabaseFailure) returned | High |
| EH-FT-007 | Unknown exception maps to UnexpectedFailure | Repository catches a RangeError | Mapping logic executes | Result.failure(UnexpectedFailure) with original exception | High |
| EH-FT-008 | Stack trace is preserved | Exception thrown with stack trace | Mapped to Failure | Failure.stackTrace matches original | Medium |
| EH-FT-009 | Failure equality works | Two DatabaseFailure with same message+code | Compared | They are equal (Equatable) | Medium |
| EH-FT-010 | Failure inequality works | Two DatabaseFailure with different codes | Compared | They are NOT equal | Medium |
| EH-FT-011 | ValidationFailure carries field errors | Validation fails on 2 fields | ValidationFailure created | fieldErrors map has both entries | Medium |
| EH-FT-012 | PermissionFailure carries lockout info | PIN lockout triggered | PermissionFailure created | remainingAttempts and lockoutDuration set | Medium |
| EH-FT-013 | ErrorMessages produces correct string for each type | Each Failure subclass | `ErrorMessages.fromFailure()` called | Non-empty, user-appropriate message returned | Medium |
| EH-FT-014 | ErrorMessages handles unknown codes | Failure with code=null | `ErrorMessages.fromFailure()` called | Fallback message returned (not a crash) | Medium |
| EH-FT-015 | getOrElse returns default on failure | Result.failure | `.getOrElse(() => defaultTask)` | Returns defaultTask | Low |
| EH-FT-016 | getOrThrow throws on failure | Result.failure | `.getOrThrow()` | StateError thrown | Low |

### 9.2 Test Pattern Example

```dart
import 'package:test/test.dart';

void main() {
  group('Result', () {
    group('success', () {
      test('should carry the value', () {
        // Arrange
        const value = 42;

        // Act
        const result = Result.success(value);

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
        expect(result.valueOrNull, equals(42));
        expect(result.failureOrNull, isNull);
      });

      test('should execute success branch in when()', () {
        // Arrange
        const result = Result.success(42);

        // Act
        final output = result.when(
          success: (value) => 'Got $value',
          failure: (f) => 'Failed: ${f.message}',
        );

        // Assert
        expect(output, equals('Got 42'));
      });
    });

    group('failure', () {
      test('should carry the failure', () {
        // Arrange
        const failure = DatabaseFailure(message: 'Write failed');

        // Act
        const result = Result<int>.failure(failure);

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.isFailure, isTrue);
        expect(result.valueOrNull, isNull);
        expect(result.failureOrNull, isA<DatabaseFailure>());
      });
    });
  });

  group('Failure equality', () {
    test('should be equal when message and code match', () {
      const a = DatabaseFailure(message: 'err', code: 'DB_01');
      const b = DatabaseFailure(message: 'err', code: 'DB_01');
      expect(a, equals(b));
    });

    test('should not be equal when code differs', () {
      const a = DatabaseFailure(message: 'err', code: 'DB_01');
      const b = DatabaseFailure(message: 'err', code: 'DB_02');
      expect(a, isNot(equals(b)));
    });
  });
}
```

---

## 10. Impact Analysis

### 10.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| Result<T> | New | Low | Pure data class, no side effects |
| Failure hierarchy | New | Low | Sealed class hierarchy |
| AppException hierarchy | New | Low | Data layer exceptions |
| ErrorCodes | New | Low | Constants class |
| ErrorMessages | New | Low | Pure mapping function |
| All repositories (future) | Consumer | Medium | Must follow the mapping pattern |
| BLoC ErrorState | Consumer | Low | Carries Failure objects |
| Sync engine | Consumer | Medium | Uses SyncFailure, ConflictFailure |
| Connectivity monitor | Consumer | Low | NetworkFailure on reachability check |

### 10.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Exception not caught at repository boundary | Medium | Medium | Enforce pattern in code review. Lint rule for unhandled exceptions. |
| Missing Failure subclass for a new error type | Low | Low | Sealed class forces handling. Add new subclass when needed. |
| Error message not user-friendly | Medium | Low | Centralized in ErrorMessages -- easy to review and localize. |
| Stack trace lost during mapping | Low | Medium | Always pass `stackTrace` parameter in catch clauses. |
| Equatable props incomplete | Low | Medium | Unit tests verify equality behavior for every Failure subclass. |

---

## 11. Implementation Recommendations

### 11.1 Suggested Approach

1. Implement `Result<T>` sealed class with `when()`, `map()`, extensions.
2. Write Result tests (EH-FT-001 through EH-FT-005, EH-FT-015, EH-FT-016).
3. Implement `Failure` sealed class hierarchy with all subclasses.
4. Write Failure equality tests (EH-FT-009, EH-FT-010, EH-FT-011, EH-FT-012).
5. Implement `AppException` hierarchy.
6. Implement `ErrorCodes` constants.
7. Implement `ErrorMessages` mapper.
8. Write error message tests (EH-FT-013, EH-FT-014).
9. Document the repository mapping pattern for feature developers.
10. Write mapping tests (EH-FT-006, EH-FT-007, EH-FT-008).

### 11.2 Estimated Effort

**T-shirt size: S** (1-2 days)

Mostly type definitions and simple mapping logic. The tests are straightforward.

---

## 12. Open Questions

- [ ] Should we use Dart 3 sealed classes for `Result<T>` (as specified) or adopt a package like `fpdart` for its `Either<L, R>` and broader functional programming support? Sealed classes are simpler and have no external dependency, but `fpdart` provides `TaskEither` for async composition.
- [ ] Should `ErrorMessages` support localization from day one (returning l10n keys instead of English strings), or is hardcoded English acceptable for Phase 1 with localization added later?
- [ ] Should `UnexpectedFailure` automatically log to Crashlytics when created, or should logging be a separate concern handled by a `BlocObserver` or error reporting service?

---

*Generated by Software Architect Analyst*
*Date: 2026-03-05*
