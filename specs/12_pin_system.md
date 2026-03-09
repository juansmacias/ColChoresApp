# Parental PIN System

## 1. Overview

### 1.1 Summary

This specification defines the parental PIN system -- the security gate that protects sensitive operations from unauthorized access by children. It covers PIN setup, PIN entry, PIN verification, brute-force protection, biometric bypass, PIN session management, and the PinGuard route integration. The PIN system uses SHA-256 hashing with a UUID v4 salt, stored per-member in the Drift database and synced to Firestore. PIN verification is entirely local -- no network call is required to verify a PIN.

### 1.2 Business Context

The app runs on shared devices. Alex (10) and Emma (3) have access to the same device as Marcus and Sofia. Without a PIN gate, a child could change task assignments, delete rewards, modify family settings, or impersonate a parent. The PIN system must be fast enough that parents do not feel burdened (sub-second verification), secure enough to prevent a determined 10-year-old from brute-forcing it (lockout escalation), and optional enough that families who do not need it can skip it (not enforced for child profiles).

### 1.3 Scope

**In scope:**
- PIN requirements (4-6 digits, SHA-256 + salt)
- PinRepository abstract interface and implementation
- PinCubit state management
- PinEntryWidget (number pad, dot indicator, shake animation)
- PinSetupScreen (new PIN + confirm)
- PinGuard integration with go_router
- PIN session management (in-memory, expires after 5 minutes)
- Brute-force protection (5 attempts, escalating lockout)
- Biometric bypass via `local_auth` (optional)
- PIN change flow
- PIN data storage (Drift member row, Firestore member document)

**Out of scope:**
- PIN recovery (if forgotten, parent must sign in with Firebase Auth and reset PIN)
- Remote PIN wipe
- PIN complexity rules beyond length (no sequential/repeated digit checks)
- Hardware security module (HSM) integration

### 1.4 References

- `specs/00_project_foundation.md` -- Section 4.10.2 (PIN hashing)
- `specs/02_isar_schemas.md` -- Section 5.2 (MembersTable: pinHash, pinSalt fields)
- `specs/08_phase2_foundations.md` -- PinGuard, route configuration
- `specs/11_member_profiles.md` -- Profile switching, parent detection
- `CLAUDE.md` -- PIN 4-6 digits, SHA-256 + salt, biometric bypass optional

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| PIN-001 | Set up a 4-6 digit PIN | High | Parent enters PIN, confirms, hash+salt stored in Drift member row |
| PIN-002 | Verify PIN on entry | High | Entered PIN hashed with stored salt matches stored hash |
| PIN-003 | PIN entry shows dot indicators | High | One dot per digit, filled as digits entered |
| PIN-004 | Wrong PIN shakes the dots | High | Shake animation on incorrect entry, dots clear |
| PIN-005 | PIN verification is local-only | High | No network call required, works offline |
| PIN-006 | Brute-force lockout after 5 attempts | High | 5th failure triggers 5-minute lockout. Escalating: 10 min, 30 min, 1 hour |
| PIN-007 | Lockout timer displayed | High | "Try again in X:XX" shown during lockout |
| PIN-008 | PIN session expires after 5 minutes | Medium | After 5 min of inactivity or app background, PIN re-entry required |
| PIN-009 | Biometric bypass (optional) | Medium | Parent can enable fingerprint/face unlock to skip PIN |
| PIN-010 | Change PIN flow | Medium | Verify old PIN -> enter new -> confirm new |
| PIN-011 | PinGuard redirects to /pin for protected routes | High | Parent profiles accessing settings/admin routes must verify PIN |
| PIN-012 | Children skip PIN entirely | High | Child profiles never see PIN entry |
| PIN-013 | Each parent has their own PIN | High | Marcus and Sofia can have different PINs |
| PIN-014 | PIN syncs to Firestore | Medium | pinHash and pinSalt fields sync via SyncEngine |
| PIN-015 | First-time parent prompted to set PIN | Medium | After family creation, parent guided to /pin-setup |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| PIN-NFR-001 | PIN verification time | Hash computation time | < 50ms on mid-range device |
| PIN-NFR-002 | PIN entry UX | Time from screen open to verified | < 3 seconds (4-digit PIN) |
| PIN-NFR-003 | Brute-force resistance | Attempts before lockout | 5 (then escalating lockout) |
| PIN-NFR-004 | PIN hash strength | Algorithm | SHA-256 with 128-bit salt (UUID v4) |

### 2.3 Assumptions

- The `crypto` Dart package provides SHA-256 hashing (from `dart:convert` via `crypto` package).
- `local_auth` Flutter plugin is available for biometric authentication on both iOS and Android.
- PIN session state is in-memory only -- not persisted to disk. App kill = session expired.
- The lockout state is persisted in SharedPreferences to survive app restarts.
- PIN is per-member, not per-device. If a parent uses multiple devices, the same PIN works on all (synced via Firestore).

### 2.4 Constraints

- PIN hash uses SHA-256, not bcrypt/scrypt. SHA-256 is fast but sufficient for a 4-6 digit PIN because brute-force is rate-limited by the lockout mechanism, not computational cost.
- The salt is a UUID v4 string (36 characters, 122 bits of entropy). Generated once on PIN setup, stored alongside the hash.
- PIN session is not encrypted in memory. If the device is rooted/jailbroken, the session state could be inspected. This is acceptable for the threat model (preventing children, not state-level adversaries).
- Biometric authentication requires the device to have biometric hardware. If not available, the biometric option is hidden.

---

## 3. Use Cases

### UC-001: First-Time PIN Setup

- **Actor**: Marcus (parent, no PIN set)
- **Preconditions**: Marcus is authenticated, family created, no PIN set
- **Main Flow**:
  1. After family creation, router navigates to `/pin-setup`
  2. PinSetupScreen shows "Create a PIN" heading
  3. Marcus enters 4 digits: 1-2-3-4
  4. Dots fill as digits entered
  5. Screen transitions to "Confirm your PIN"
  6. Marcus enters 1-2-3-4 again
  7. PinCubit generates UUID v4 salt
  8. PinCubit computes SHA-256(salt + "1234")
  9. PinRepositoryImpl stores pinHash and pinSalt in Drift MembersTable row
  10. SyncEngine queues update for Firestore
  11. Optional: biometric enrollment prompt
  12. Router navigates to `/profiles`
- **Alternative Flows**:
  - Confirmation does not match: shake animation, "PINs don't match. Try again.", reset to step 3
  - Marcus taps "Skip" (if allowed): no PIN set, parent features unprotected until set
- **Postconditions**: pinHash and pinSalt stored for Marcus. PIN session active.
- **Exceptions**: None expected -- all local operations.

### UC-002: PIN Entry for Profile Switch

- **Actor**: Marcus (parent, PIN set)
- **Preconditions**: Alex is active profile, Marcus taps his avatar on profile switcher
- **Main Flow**:
  1. ProfileSwitcherScreen detects parent avatar tap
  2. Router navigates to `/pin?redirect=/profiles`
  3. PinEntryScreen shows "Enter Marcus's PIN" with 4 empty dots
  4. Marcus enters 1-2-3-4
  5. PinCubit retrieves pinSalt and pinHash for Marcus from Drift
  6. PinCubit computes SHA-256(salt + "1234")
  7. Hash matches stored hash
  8. PinCubit emits PinVerified
  9. PIN session timer starts (5 minutes)
  10. ActiveProfileCubit switches to Marcus
  11. Router navigates back to profile switcher
- **Alternative Flows**:
  - Wrong PIN: shake animation, dots clear, attempt counter incremented
  - 5th wrong attempt: lockout screen shown, "Try again in 5:00"
- **Postconditions**: Active profile is Marcus. PIN session active for 5 minutes.

### UC-003: Biometric Bypass

- **Actor**: Sofia (parent, PIN set, biometric enabled)
- **Preconditions**: Sofia taps her avatar, PIN entry screen shown
- **Main Flow**:
  1. PinEntryScreen shows fingerprint/face icon button alongside number pad
  2. Sofia taps biometric button
  3. `local_auth` shows system biometric prompt
  4. Sofia authenticates with fingerprint
  5. PinCubit emits PinVerified (bypasses hash check)
  6. PIN session timer starts
  7. Profile switches to Sofia
- **Alternative Flows**:
  - Biometric fails: fall back to PIN entry
  - Biometric not enrolled on device: button not shown
- **Postconditions**: Active profile is Sofia. PIN session active.

---

## 4. Domain Layer

### 4.1 PinRepository Interface

```dart
// lib/features/pin/domain/repositories/pin_repository.dart
import '../../../../core/utils/result.dart';

/// Abstract interface for PIN operations.
/// Implementations handle hashing, storage, and biometric integration.
abstract class PinRepository {
  /// Sets a new PIN for a member.
  /// Generates salt, computes hash, stores in Drift.
  Future<Result<void>> setPin({
    required String memberId,
    required String pin,
  });

  /// Verifies a PIN against the stored hash.
  /// Returns true if correct, false if incorrect.
  Future<Result<bool>> verifyPin({
    required String memberId,
    required String pin,
  });

  /// Returns whether a member has a PIN set.
  Future<Result<bool>> hasPin(String memberId);

  /// Clears the PIN for a member (sets pinHash and pinSalt to null).
  Future<Result<void>> clearPin(String memberId);

  /// Returns whether biometric bypass is enabled for a member.
  Future<Result<bool>> getBiometricEnabled(String memberId);

  /// Enables or disables biometric bypass.
  Future<Result<void>> setBiometricEnabled({
    required String memberId,
    required bool enabled,
  });

  /// Checks if the device supports biometric authentication.
  Future<Result<bool>> isBiometricAvailable();

  /// Triggers biometric authentication.
  /// Returns true if successful, false if failed or cancelled.
  Future<Result<bool>> authenticateWithBiometric();
}
```

### 4.2 PIN Hashing Service

```dart
// lib/features/pin/domain/services/pin_hash_service.dart

/// Pure function service for PIN hashing.
/// Separated from repository for testability.
abstract class PinHashService {
  /// Generates a cryptographic salt for PIN hashing.
  String generateSalt();

  /// Computes SHA-256 hash of the PIN with the given salt.
  String computeHash(String pin, String salt);

  /// Verifies a PIN against a stored hash and salt.
  bool verify(String pin, String salt, String storedHash);
}
```

---

## 5. Data Layer

### 5.1 PinHashServiceImpl

```dart
// lib/features/pin/data/services/pin_hash_service_impl.dart
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../domain/services/pin_hash_service.dart';

@LazySingleton(as: PinHashService)
class PinHashServiceImpl implements PinHashService {
  PinHashServiceImpl(this._uuid);

  final Uuid _uuid;

  @override
  String generateSalt() {
    return _uuid.v4(); // 36-char UUID v4, 122 bits of entropy
  }

  @override
  String computeHash(String pin, String salt) {
    final bytes = utf8.encode('$salt$pin');
    final digest = sha256.convert(bytes);
    return digest.toString(); // 64-char hex string
  }

  @override
  bool verify(String pin, String salt, String storedHash) {
    final computedHash = computeHash(pin, salt);
    // Constant-time comparison to prevent timing attacks
    if (computedHash.length != storedHash.length) return false;
    var result = 0;
    for (var i = 0; i < computedHash.length; i++) {
      result |= computedHash.codeUnitAt(i) ^ storedHash.codeUnitAt(i);
    }
    return result == 0;
  }
}
```

### 5.2 PinRepositoryImpl

```dart
// lib/features/pin/data/repositories/pin_repository_impl.dart
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/pin_repository.dart';
import '../../domain/services/pin_hash_service.dart';

@LazySingleton(as: PinRepository)
class PinRepositoryImpl implements PinRepository {
  PinRepositoryImpl(
    this._db,
    this._hashService,
    this._localAuth,
    this._prefs,
  );

  final AppDatabase _db;
  final PinHashService _hashService;
  final LocalAuthentication _localAuth;
  final SharedPreferences _prefs;

  @override
  Future<Result<void>> setPin({
    required String memberId,
    required String pin,
  }) async {
    try {
      final salt = _hashService.generateSalt();
      final hash = _hashService.computeHash(pin, salt);

      await (_db.update(_db.membersTable)
            ..where((t) => t.id.equals(int.parse(memberId))))
          .write(
        MembersTableCompanion(
          pinHash: Value(hash),
          pinSalt: Value(salt),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(SyncStatus.pending),
        ),
      );

      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(
        DatabaseFailure(message: 'Failed to set PIN: $e', stackTrace: st),
      );
    }
  }

  @override
  Future<Result<bool>> verifyPin({
    required String memberId,
    required String pin,
  }) async {
    try {
      final member = await (_db.select(_db.membersTable)
            ..where((t) => t.id.equals(int.parse(memberId))))
          .getSingleOrNull();

      if (member == null) {
        return const Result.failure(
          DatabaseFailure(message: 'Member not found'),
        );
      }

      if (member.pinHash == null || member.pinSalt == null) {
        return const Result.failure(
          PermissionFailure(message: 'No PIN set for this member'),
        );
      }

      final isValid = _hashService.verify(
        pin,
        member.pinSalt!,
        member.pinHash!,
      );

      return Result.success(isValid);
    } catch (e, st) {
      return Result.failure(
        DatabaseFailure(message: 'Failed to verify PIN: $e', stackTrace: st),
      );
    }
  }

  @override
  Future<Result<bool>> hasPin(String memberId) async {
    try {
      final member = await (_db.select(_db.membersTable)
            ..where((t) => t.id.equals(int.parse(memberId))))
          .getSingleOrNull();

      return Result.success(
        member?.pinHash != null && member?.pinSalt != null,
      );
    } catch (e, st) {
      return Result.failure(
        DatabaseFailure(message: 'Failed to check PIN: $e', stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> clearPin(String memberId) async {
    try {
      await (_db.update(_db.membersTable)
            ..where((t) => t.id.equals(int.parse(memberId))))
          .write(
        MembersTableCompanion(
          pinHash: const Value(null),
          pinSalt: const Value(null),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(SyncStatus.pending),
        ),
      );
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(
        DatabaseFailure(message: 'Failed to clear PIN: $e', stackTrace: st),
      );
    }
  }

  @override
  Future<Result<bool>> getBiometricEnabled(String memberId) async {
    final key = 'biometric_enabled_$memberId';
    return Result.success(_prefs.getBool(key) ?? false);
  }

  @override
  Future<Result<void>> setBiometricEnabled({
    required String memberId,
    required bool enabled,
  }) async {
    final key = 'biometric_enabled_$memberId';
    await _prefs.setBool(key, enabled);
    return const Result.success(null);
  }

  @override
  Future<Result<bool>> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return Result.success(canCheck && isSupported);
    } catch (e, st) {
      return Result.failure(
        UnexpectedFailure(
          message: 'Failed to check biometric: $e',
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<bool>> authenticateWithBiometric() async {
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Verify your identity to continue',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      return Result.success(didAuthenticate);
    } catch (e, st) {
      return Result.failure(
        UnexpectedFailure(
          message: 'Biometric authentication failed: $e',
          stackTrace: st,
        ),
      );
    }
  }
}
```

---

## 6. Presentation Layer

### 6.1 PinCubit States

```dart
// lib/features/pin/presentation/bloc/pin_state.dart
import 'package:equatable/equatable.dart';

sealed class PinState extends Equatable {
  const PinState();

  @override
  List<Object?> get props => [];
}

/// Initial state, no PIN action taken.
final class PinInitial extends PinState {
  const PinInitial();
}

/// PIN operation in progress.
final class PinLoading extends PinState {
  const PinLoading();
}

/// PIN was verified successfully. Session is active.
final class PinVerified extends PinState {
  const PinVerified();
}

/// PIN verification failed.
final class PinFailed extends PinState {
  const PinFailed({
    required this.attemptsRemaining,
  });

  /// How many more attempts before lockout.
  final int attemptsRemaining;

  @override
  List<Object?> get props => [attemptsRemaining];
}

/// Account is locked due to too many failed attempts.
final class PinLocked extends PinState {
  const PinLocked({
    required this.lockedUntil,
  });

  /// When the lockout expires.
  final DateTime lockedUntil;

  /// Remaining lockout duration.
  Duration get remainingDuration {
    final now = DateTime.now();
    if (lockedUntil.isBefore(now)) return Duration.zero;
    return lockedUntil.difference(now);
  }

  @override
  List<Object?> get props => [lockedUntil];
}

/// PIN was set successfully (setup flow).
final class PinSet extends PinState {
  const PinSet();
}

/// PIN setup error (e.g., confirmation mismatch).
final class PinSetupError extends PinState {
  const PinSetupError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
```

### 6.2 PinCubit Implementation

```dart
// lib/features/pin/presentation/bloc/pin_cubit.dart
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/pin_repository.dart';
import 'pin_state.dart';

@injectable
class PinCubit extends Cubit<PinState> {
  PinCubit(this._pinRepository, this._prefs) : super(const PinInitial());

  final PinRepository _pinRepository;
  final SharedPreferences _prefs;

  /// In-memory PIN session. Not persisted to disk.
  DateTime? _sessionExpiresAt;
  Timer? _sessionTimer;

  /// Lockout tracking keys.
  static const _failedAttemptsKey = 'pin_failed_attempts';
  static const _lockoutUntilKey = 'pin_lockout_until';
  static const _lockoutLevelKey = 'pin_lockout_level';

  /// Maximum attempts before lockout.
  static const int maxAttempts = 5;

  /// Lockout durations by level.
  static const List<Duration> _lockoutDurations = [
    Duration(minutes: 5),   // Level 0: first lockout
    Duration(minutes: 10),  // Level 1
    Duration(minutes: 30),  // Level 2
    Duration(hours: 1),     // Level 3+
  ];

  /// PIN session duration.
  static const Duration sessionDuration = Duration(minutes: 5);

  /// Whether the PIN session is currently active (verified and not expired).
  bool get isSessionActive {
    if (_sessionExpiresAt == null) return false;
    return DateTime.now().isBefore(_sessionExpiresAt!);
  }

  /// Verifies a PIN for a member.
  Future<void> verifyPin({
    required String memberId,
    required String pin,
  }) async {
    // Check lockout first
    final lockoutUntil = _getLockoutUntil();
    if (lockoutUntil != null && DateTime.now().isBefore(lockoutUntil)) {
      emit(PinLocked(lockedUntil: lockoutUntil));
      return;
    }

    emit(const PinLoading());

    final result = await _pinRepository.verifyPin(
      memberId: memberId,
      pin: pin,
    );

    result.when(
      success: (isValid) {
        if (isValid) {
          _clearFailedAttempts();
          _startSession();
          emit(const PinVerified());
        } else {
          _recordFailedAttempt();
          final remaining = _getRemainingAttempts();
          if (remaining <= 0) {
            _triggerLockout();
            emit(PinLocked(lockedUntil: _getLockoutUntil()!));
          } else {
            emit(PinFailed(attemptsRemaining: remaining));
          }
        }
      },
      failure: (failure) {
        emit(const PinFailed(attemptsRemaining: -1)); // Unknown error
      },
    );
  }

  /// Sets a new PIN for a member.
  Future<void> setPin({
    required String memberId,
    required String pin,
    required String confirmPin,
  }) async {
    if (pin != confirmPin) {
      emit(const PinSetupError("PINs don't match. Please try again."));
      return;
    }

    if (pin.length < 4 || pin.length > 6) {
      emit(const PinSetupError('PIN must be 4 to 6 digits.'));
      return;
    }

    emit(const PinLoading());

    final result = await _pinRepository.setPin(
      memberId: memberId,
      pin: pin,
    );

    result.when(
      success: (_) {
        _startSession();
        emit(const PinSet());
      },
      failure: (failure) {
        emit(PinSetupError('Failed to set PIN: ${failure.message}'));
      },
    );
  }

  /// Authenticates with biometric.
  Future<void> authenticateWithBiometric() async {
    emit(const PinLoading());

    final result = await _pinRepository.authenticateWithBiometric();
    result.when(
      success: (didAuthenticate) {
        if (didAuthenticate) {
          _startSession();
          emit(const PinVerified());
        } else {
          emit(const PinInitial()); // User cancelled
        }
      },
      failure: (_) {
        emit(const PinInitial()); // Fall back to PIN
      },
    );
  }

  /// Starts the PIN session timer.
  void _startSession() {
    _sessionTimer?.cancel();
    _sessionExpiresAt = DateTime.now().add(sessionDuration);
    _sessionTimer = Timer(sessionDuration, _expireSession);
  }

  /// Called when the PIN session expires.
  void _expireSession() {
    _sessionExpiresAt = null;
    emit(const PinInitial());
  }

  /// Called when the app goes to background.
  void onAppBackground() {
    _sessionExpiresAt = null;
    _sessionTimer?.cancel();
    if (state is PinVerified) {
      emit(const PinInitial());
    }
  }

  // --- Lockout management ---

  int _getFailedAttempts() => _prefs.getInt(_failedAttemptsKey) ?? 0;

  int _getRemainingAttempts() => maxAttempts - _getFailedAttempts();

  void _recordFailedAttempt() {
    final current = _getFailedAttempts();
    _prefs.setInt(_failedAttemptsKey, current + 1);
  }

  void _clearFailedAttempts() {
    _prefs.remove(_failedAttemptsKey);
  }

  DateTime? _getLockoutUntil() {
    final ms = _prefs.getInt(_lockoutUntilKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  void _triggerLockout() {
    final level = _prefs.getInt(_lockoutLevelKey) ?? 0;
    final duration = _lockoutDurations[
        level.clamp(0, _lockoutDurations.length - 1)];
    final lockedUntil = DateTime.now().add(duration);
    _prefs.setInt(_lockoutUntilKey, lockedUntil.millisecondsSinceEpoch);
    _prefs.setInt(_lockoutLevelKey, level + 1);
    _prefs.remove(_failedAttemptsKey); // Reset attempts for next round
  }

  @override
  Future<void> close() {
    _sessionTimer?.cancel();
    return super.close();
  }
}
```

### 6.3 PinEntryWidget

```dart
// lib/features/pin/presentation/widgets/pin_entry_widget.dart
//
// A reusable PIN entry widget used by both PinEntryScreen and PinSetupScreen.
//
// Layout:
// - Row of 4-6 dot indicators (filled/empty based on entered digits)
//   - Empty: outlined circle (24px)
//   - Filled: solid circle with accent color
//   - Active: slightly larger (28px) to indicate current position
// - Number pad grid (3 columns x 4 rows):
//   - [1] [2] [3]
//   - [4] [5] [6]
//   - [7] [8] [9]
//   - [biometric] [0] [backspace]
//   - Each key: 72px diameter circle, ripple on tap
//   - Biometric key: fingerprint/face icon (only if enabled)
//   - Backspace key: delete icon
//
// Animations:
// - Shake animation on wrong PIN (300ms, 3 oscillations, 8px amplitude)
// - Dot fill animation (100ms scale-in per dot)
// - Success: dots briefly flash green before transitioning
// - Lockout: dots turn red, number pad fades to 50% opacity
//
// Props:
// - pinLength: int (4-6, default 4)
// - onCompleted: (String pin) callback
// - onBiometricPressed: () callback (optional)
// - showBiometric: bool
// - isLocked: bool
// - errorMessage: String? (shown below dots)
//
// Accessibility:
// - Number keys have semantics labels ("1", "2", etc.)
// - Backspace has semantics label "Delete last digit"
// - Biometric has semantics label "Use fingerprint"
// - Dots announce "Digit {n} of {total} entered"
```

### 6.4 PinEntryScreen

```dart
// lib/features/pin/presentation/screens/pin_entry_screen.dart
//
// Layout:
// - AppBar with back button (or close, depending on context)
// - Member avatar at top (circular, 80px)
// - "Enter {name}'s PIN" heading
// - PinEntryWidget (centered)
// - Error message area (below dots)
// - Lockout timer display (when locked)
//
// Behavior:
// - On completed PIN: dispatch verifyPin to PinCubit
// - On PinVerified: navigate to redirect route (from query param)
// - On PinFailed: shake animation, show "Wrong PIN. X attempts remaining."
// - On PinLocked: show lockout timer, disable number pad
// - Biometric button: dispatch authenticateWithBiometric
//
// Route: /pin?redirect=/settings (redirect param specifies where to go after)
```

### 6.5 PinSetupScreen

```dart
// lib/features/pin/presentation/screens/pin_setup_screen.dart
//
// Layout:
// - AppBar with "Set Up PIN" title
// - Step indicator: "Step 1 of 2" or "Step 2 of 2"
// - Step 1: "Create a PIN" heading, PinEntryWidget
// - Step 2: "Confirm your PIN" heading, PinEntryWidget
// - After confirmation: optional biometric enrollment card
//   - "Use fingerprint to unlock?" with Yes/No buttons
//   - Only shown if device supports biometrics
// - "Skip" TextButton (allows skipping PIN setup)
//
// Behavior:
// - Step 1 completed: store PIN temporarily, advance to step 2
// - Step 2 completed: compare with step 1
//   - Match: dispatch setPin to PinCubit
//   - Mismatch: shake, show "PINs don't match", reset both steps
// - Biometric enrollment: dispatch setBiometricEnabled
// - On PinSet state: navigate to /profiles
```

---

## 7. PIN Session Management

### 7.1 Session Lifecycle

```
PIN Verified
  |
  v
[Session Active] ---- 5 min timeout ---> [Session Expired]
  |                                         |
  | (app background)                        | (any protected route)
  v                                         v
[Session Expired]                        [Redirect to /pin]
  |
  | (app foreground)
  v
[Redirect to /pin]
```

### 7.2 Session Rules

1. **Session starts** when PIN is verified or biometric succeeds.
2. **Session expires** after 5 minutes of inactivity (timer-based) OR when the app goes to background.
3. **Session state** is in-memory only (`_sessionExpiresAt` in PinCubit). Not written to SharedPreferences or Drift.
4. **App background detection** uses `WidgetsBindingObserver.didChangeAppLifecycleState`. When `AppLifecycleState.paused`, session is invalidated.
5. **Session check** occurs in the PinGuard router redirect. If `PinCubit.isSessionActive` is false and the route is PIN-protected, redirect to `/pin`.
6. **User activity** does NOT reset the timer. The 5-minute window is absolute from the time of verification. This is simpler and more predictable than an inactivity-based timer.

### 7.3 App Lifecycle Integration

```dart
// In the app's root widget or a dedicated lifecycle observer:
class PinSessionObserver extends WidgetsBindingObserver {
  PinSessionObserver(this._pinCubit);

  final PinCubit _pinCubit;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pinCubit.onAppBackground();
    }
  }
}
```

---

## 8. Brute-Force Protection

### 8.1 Lockout Escalation

| Failed Attempts | Action | Lockout Duration |
|----------------|--------|------------------|
| 1-4 | Show "Wrong PIN. X attempts remaining." | None |
| 5 | Lock PIN entry | 5 minutes |
| 5 (after first lockout expires) | Lock PIN entry | 10 minutes |
| 5 (after second lockout) | Lock PIN entry | 30 minutes |
| 5 (after third+) | Lock PIN entry | 1 hour |

### 8.2 Lockout Persistence

Lockout state is persisted in SharedPreferences to prevent bypassing by killing and restarting the app:

- `pin_failed_attempts` (int): current attempt count within a lockout cycle
- `pin_lockout_until` (int): milliseconds since epoch when lockout expires
- `pin_lockout_level` (int): escalation level (0, 1, 2, 3+)

### 8.3 Lockout Reset

- Successful PIN verification resets `pin_failed_attempts` to 0.
- Lockout level is NOT reset on success -- it only resets after 24 hours without a lockout trigger. This prevents an attacker from trying 5 PINs, waiting for lockout, trying 5 more, etc.
- Signing out and back in does NOT reset lockout state (persisted in SharedPreferences, not tied to auth session).

---

## 9. Impact Analysis

### 9.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| `lib/features/pin/` (entire feature) | New | Medium | 10+ files across layers |
| `MembersTable` (Drift) | Dependency | Low | Uses existing pinHash, pinSalt columns |
| `SharedPreferences` | Dependency | Low | Lockout state and biometric preference |
| `local_auth` | New dependency | Medium | Platform-specific biometric integration |
| `app_router.dart` | Modified | Low | PinGuard integrated |
| `app.dart` | Modified | Low | WidgetsBindingObserver for lifecycle |
| DI container | Modified | Low | PinCubit, PinRepository, PinHashService registered |

### 9.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| SHA-256 is too fast for PIN brute-force | Low | Medium | Rate-limited by lockout (5 attempts). 4-digit PIN = 10k combinations. 5 attempts per cycle is sufficient. |
| Biometric fails on specific devices | Medium | Low | Graceful fallback to PIN. Biometric is optional. |
| Session timer drift on backgrounded app | Low | Low | App background = session killed immediately. Timer is secondary. |
| Lockout state cleared by app uninstall/reinstall | Medium | Low | Acceptable -- reinstall requires re-sign-in anyway. |
| Constant-time comparison implementation incorrect | Low | High | Unit test with timing measurement. Use XOR-based comparison (Section 5.1). |
| PIN set on device A not available on device B until sync | Medium | Medium | PIN syncs via SyncEngine. If offline, parent must wait for sync. |

---

## 10. Functional Tests

### 10.1 Unit Tests -- PinHashService

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| PIN-FT-001 | Generate salt is UUID v4 | -- | generateSalt called | Returns 36-char UUID string | High |
| PIN-FT-002 | Two salts are different | -- | generateSalt called twice | Two different strings returned | High |
| PIN-FT-003 | Hash is deterministic | Same pin + salt | computeHash called twice | Same hash both times | High |
| PIN-FT-004 | Different PINs produce different hashes | Same salt, different PINs | computeHash for "1234" and "5678" | Different hashes | High |
| PIN-FT-005 | Different salts produce different hashes | Same pin, different salts | computeHash with two salts | Different hashes | High |
| PIN-FT-006 | Verify returns true for correct PIN | PIN "1234" set | verify("1234", salt, hash) | Returns true | High |
| PIN-FT-007 | Verify returns false for wrong PIN | PIN "1234" set | verify("5678", salt, hash) | Returns false | High |
| PIN-FT-008 | Hash is 64-char hex string | Any PIN + salt | computeHash called | 64-character string, all hex chars | Medium |

### 10.2 Unit Tests -- PinCubit

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| PIN-FT-010 | Initial state | PinCubit created | -- | State is PinInitial | High |
| PIN-FT-011 | Correct PIN emits PinVerified | PIN "1234" stored | verifyPin("1234") | Emits PinLoading then PinVerified | High |
| PIN-FT-012 | Wrong PIN emits PinFailed | PIN "1234" stored | verifyPin("5678") | Emits PinLoading then PinFailed(attemptsRemaining: 4) | High |
| PIN-FT-013 | 5th wrong attempt triggers lockout | 4 failed attempts | verifyPin(wrong) | Emits PinLocked with duration | High |
| PIN-FT-014 | Lockout duration escalates | First lockout expired | 5 more wrong attempts | Lockout is 10 minutes, not 5 | High |
| PIN-FT-015 | Correct PIN clears failed attempts | 3 failed attempts | verifyPin(correct) | Failed attempts reset to 0 | High |
| PIN-FT-016 | Session is active after verify | PIN verified | isSessionActive checked | Returns true | High |
| PIN-FT-017 | Session expires after 5 minutes | PIN verified | Wait 5+ minutes | isSessionActive returns false | High |
| PIN-FT-018 | App background expires session | PIN verified | onAppBackground called | State changes to PinInitial | High |
| PIN-FT-019 | Set PIN with matching confirmation | PIN "1234" entered twice | setPin called | PinSet emitted, hash stored | High |
| PIN-FT-020 | Set PIN with mismatch | "1234" and "5678" | setPin called | PinSetupError emitted | High |
| PIN-FT-021 | Set PIN too short | "12" entered | setPin called | PinSetupError("PIN must be 4 to 6 digits") | Medium |
| PIN-FT-022 | Biometric success emits PinVerified | Biometric succeeds | authenticateWithBiometric | PinVerified emitted, session started | Medium |
| PIN-FT-023 | Biometric cancel emits PinInitial | User cancels biometric | authenticateWithBiometric | PinInitial emitted | Medium |
| PIN-FT-024 | Lockout state persists across restart | Lockout triggered | PinCubit recreated, verifyPin | PinLocked emitted | High |

### 10.3 Widget Tests

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| PIN-FT-030 | PIN entry renders number pad | Screen mounted | -- | Digits 0-9 visible, backspace visible | High |
| PIN-FT-031 | Dots fill on digit tap | Empty PIN | Tap "1" | First dot fills | High |
| PIN-FT-032 | Backspace removes last dot | 2 dots filled | Tap backspace | 1 dot filled | High |
| PIN-FT-033 | Shake animation on wrong PIN | PinFailed state | -- | Dots shake horizontally | Medium |
| PIN-FT-034 | Lockout message shown | PinLocked state | -- | "Try again in X:XX" visible, pad disabled | High |
| PIN-FT-035 | Biometric button visible when enabled | Biometric available | Screen mounted | Fingerprint icon visible | Medium |
| PIN-FT-036 | Biometric button hidden when unavailable | No biometric hardware | Screen mounted | Fingerprint icon not visible | Medium |
| PIN-FT-037 | PIN setup step indicator | Setup screen mounted | -- | "Step 1 of 2" visible | Medium |

### 10.4 Route Guard Tests

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| PIN-FT-040 | PinGuard redirects parent to /pin | Parent active, no session | Navigate to /settings | Redirected to /pin?redirect=/settings | High |
| PIN-FT-041 | PinGuard allows child through | Child active | Navigate to /settings | No redirect | High |
| PIN-FT-042 | PinGuard allows verified parent through | Parent, session active | Navigate to /settings | No redirect | High |
| PIN-FT-043 | PinGuard redirects after session expiry | Parent, session expired | Navigate to /settings | Redirected to /pin | High |

### 10.5 Edge Cases

- PIN "0000" -- should be accepted (no complexity rules beyond length).
- PIN "000000" (6 digits) -- should work with 6-dot indicator.
- Rapid digit entry (all 4 digits in <200ms) -- should register all digits.
- Biometric prompt cancelled by system (e.g., incoming call) -- should fall back gracefully.
- Two parents on same device with different PINs -- each PIN verified against their own hash.
- PIN hash synced from another device overrides local hash -- last sync wins (LWW).
- Device clock manipulation to bypass lockout -- lockout uses persisted end time, not duration. If clock moved forward, lockout bypassed. Acceptable for threat model.

---

## 11. Implementation Recommendations

### 11.1 Prototype Checklist

1. **What can a user do?** As Marcus, I can set up a 4-digit PIN, then when switching back to my parent profile from a child's, enter my PIN to verify. I can optionally enable fingerprint unlock.
2. **Screens delivered:** `/pin-setup`, `/pin`
3. **Minimum data flow:** Marcus enters 4 digits on setup -> PinCubit generates salt, computes SHA-256, writes to Drift MembersTable -> on next parent switch, Marcus enters PIN -> PinCubit hashes and compares -> match -> session starts -> profile switches.
4. **Offline behavior:** All PIN operations are local. Hash stored in Drift. Verification compares local hashes. No network required. Lockout state in SharedPreferences.
5. **Done looks like:** A tester can set a 4-digit PIN for a parent, switch to a child profile, switch back to parent, enter the correct PIN to verify, and see that wrong PINs trigger shake animation and eventually lockout.

### 11.2 Suggested Approach

1. Implement `PinHashService` and `PinHashServiceImpl`.
2. Implement `PinRepository` abstract interface.
3. Implement `PinRepositoryImpl`.
4. Implement `PinState` sealed class.
5. Implement `PinCubit` with verify, set, lockout, and session logic.
6. Implement `PinEntryWidget` (reusable number pad + dot indicator).
7. Implement `PinEntryScreen`.
8. Implement `PinSetupScreen`.
9. Integrate `PinSessionObserver` for app lifecycle.
10. Write unit tests for PinHashService (deterministic, easy).
11. Write unit tests for PinCubit (all states, lockout escalation).
12. Write widget tests for PinEntryWidget.
13. Write route guard tests for PinGuard.

### 11.3 Estimated Effort

**T-shirt size: M** (3-4 days)

The hashing logic is simple. The primary effort is in the PinEntryWidget UI (animations, number pad layout) and the lockout state machine (escalation logic, persistence).

---

## 12. Open Questions

- [ ] Should PIN setup be mandatory for parents, or optional? Current spec allows "Skip" -- is that acceptable for the security model?
- [ ] Should the lockout level reset after 24 hours, or should it persist indefinitely?
- [ ] Should wrong PIN attempts be logged for parent review (e.g., "Someone tried to enter your PIN 3 times at 4:15 PM")?
- [ ] Should the PIN session timer reset on user interaction (activity-based) or be absolute (time-based)? Current spec uses absolute.
- [ ] Should there be a "Forgot PIN?" recovery flow in Phase 2, or is re-sign-in + reset sufficient?

---

*Generated by Software Architect Analyst*
*Date: 2026-03-09*
