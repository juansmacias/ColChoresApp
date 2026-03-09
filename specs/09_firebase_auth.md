# Firebase Authentication

## 1. Overview

### 1.1 Summary

This specification defines the complete Firebase Authentication feature for the Family Chores App. It covers the domain entities, abstract repository interfaces, concrete implementations, BLoC state management, UI screens (Sign In, Sign Up), error handling, session persistence, and testing strategy. Authentication is the entry gate to the entire app -- no feature works without a valid Firebase Auth session.

### 1.2 Business Context

The authentication system enables parents to create accounts and securely access their family's data across devices. Only parents (Marcus and Sofia) have Firebase Auth accounts. Children (Alex and Emma) are managed as in-app profiles without their own accounts. The auth system must be simple enough that a non-technical parent can complete sign-up in under 60 seconds, support Google Sign-In for one-tap convenience, and handle error states gracefully with clear, non-technical error messages.

### 1.3 Scope

**In scope:**
- `AppUser` domain entity
- `AuthRepository` abstract interface (domain layer)
- `AuthRepositoryImpl` implementation (data layer, wraps FirebaseAuth)
- `AuthRemoteDatasource` (raw Firebase Auth calls)
- `AuthFailure` sealed class with typed error variants
- `AuthBloc` with complete state machine (events, states, transitions)
- `SignInScreen` (email/password + Google Sign-In button)
- `SignUpScreen` (name, email, password, confirm password)
- Error message mapping from `AuthFailure` to user-facing strings
- Token refresh and session persistence
- Sign-out flow

**Out of scope:**
- Family member profiles (see `specs/11_member_profiles.md`)
- PIN verification (see `specs/12_pin_system.md`)
- Firestore security rules (see `specs/13_firestore_security_rules.md`)
- Account deletion (deferred to Phase 8)
- Password reset flow (deferred to Phase 7)
- Apple Sign-In UI (deferred to Phase 7 -- required only for iOS App Store submission)

### 1.4 References

- `specs/00_project_foundation.md` -- Section 4.3 (Authentication), Section 4.6 (Multi-User Model)
- `specs/08_phase2_foundations.md` -- Firebase DI, AuthGuard, route configuration
- `specs/06_error_handling.md` -- Failure hierarchy, Result type
- `CLAUDE.md` -- Children don't have Firebase accounts, shared device model

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| AUTH-001 | Sign up with email and password | High | New Firebase Auth user created, `AppUser` entity returned |
| AUTH-002 | Sign in with email and password | High | Existing user authenticated, `AppUser` entity returned |
| AUTH-003 | Sign in with Google | High | Google OAuth flow completes, Firebase Auth user linked, `AppUser` returned |
| AUTH-004 | Sign out | High | Firebase session cleared, local auth state reset, redirected to sign-in |
| AUTH-005 | Persist auth session across app restarts | High | Opening the app with a valid token skips sign-in |
| AUTH-006 | Stream auth state changes | High | `currentUser` stream emits on sign-in, sign-out, and token refresh |
| AUTH-007 | Display user-friendly error messages | High | Each `AuthFailure` variant maps to a clear, non-technical message |
| AUTH-008 | Validate email format on sign-up | Medium | Invalid email shows inline validation error before submission |
| AUTH-009 | Validate password strength on sign-up | Medium | Password < 8 characters shows inline validation error |
| AUTH-010 | Confirm password match on sign-up | Medium | Mismatched passwords show inline error on confirm field |
| AUTH-011 | Display name captured on sign-up | Medium | Name field required, stored in Firebase Auth `displayName` |
| AUTH-012 | Loading state during auth operations | High | UI shows loading indicator, buttons disabled during auth call |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| AUTH-NFR-001 | Sign-in response time | Time from button tap to authenticated state | < 3 seconds on stable connection |
| AUTH-NFR-002 | Google Sign-In response time | Time from button tap to authenticated state | < 5 seconds (includes Google OAuth popup) |
| AUTH-NFR-003 | Error message clarity | Non-technical parent can understand | No technical jargon, no error codes shown |
| AUTH-NFR-004 | Offline error handling | No internet during sign-in | Clear "No internet connection" message, not a crash |

### 2.3 Assumptions

- Firebase Auth is configured with email/password and Google providers enabled in the Firebase Console.
- Google Sign-In native configuration (OAuth client IDs) has been completed for both iOS and Android.
- The app only needs to support one authenticated parent per device at a time (no multi-account support).
- Token refresh is handled automatically by the Firebase Auth SDK.

### 2.4 Constraints

- Sign-in and sign-up require internet connectivity -- there is no offline auth path.
- Firebase Auth errors are `FirebaseAuthException` instances with `code` strings -- these must be mapped to domain `AuthFailure` types.
- Google Sign-In on iOS requires a URL scheme in `Info.plist`. Android requires SHA-1 fingerprint in Firebase Console.
- Apple Sign-In is required by App Store guidelines if any social login is offered. Implementation deferred to Phase 7 but `sign_in_with_apple` dependency is added now.

---

## 3. Domain Layer

### 3.1 AppUser Entity

```dart
// lib/features/auth/domain/entities/app_user.dart
import 'package:equatable/equatable.dart';

/// Represents an authenticated Firebase user.
/// This is the domain entity -- it has no Firebase SDK dependencies.
class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.createdAt,
    this.lastSignInAt,
  });

  /// Firebase Auth UID. Globally unique, immutable.
  final String uid;

  /// Email address used for authentication.
  final String email;

  /// Display name (set during sign-up or from Google profile).
  final String? displayName;

  /// Profile photo URL (from Google profile or uploaded).
  final String? photoUrl;

  /// When the account was created.
  final DateTime? createdAt;

  /// Most recent sign-in timestamp.
  final DateTime? lastSignInAt;

  /// Whether this user has a display name set.
  bool get hasDisplayName =>
      displayName != null && displayName!.isNotEmpty;

  @override
  List<Object?> get props => [
        uid,
        email,
        displayName,
        photoUrl,
        createdAt,
        lastSignInAt,
      ];
}
```

### 3.2 AuthRepository Interface

```dart
// lib/features/auth/domain/repositories/auth_repository.dart
import '../../../../core/utils/result.dart';
import '../entities/app_user.dart';

/// Abstract interface for authentication operations.
/// Implementations must map all provider-specific exceptions
/// to domain AuthFailure types.
abstract class AuthRepository {
  /// Signs in with email and password.
  /// Returns [AppUser] on success, [AuthFailure] on failure.
  Future<Result<AppUser>> signInWithEmail({
    required String email,
    required String password,
  });

  /// Creates a new account with email and password.
  /// Sets displayName on the Firebase Auth profile.
  /// Returns [AppUser] on success, [AuthFailure] on failure.
  Future<Result<AppUser>> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  /// Signs in with Google OAuth.
  /// Returns [AppUser] on success, [AuthFailure] on failure.
  Future<Result<AppUser>> signInWithGoogle();

  /// Signs out the current user.
  /// Returns void on success, [AuthFailure] on failure.
  Future<Result<void>> signOut();

  /// Stream of the current authenticated user.
  /// Emits null when signed out, AppUser when signed in.
  /// Reacts to token refresh and auth state changes.
  Stream<AppUser?> get currentUser;

  /// Returns the currently signed-in user synchronously, or null.
  AppUser? get currentUserSync;

  /// Deletes the current user's account.
  /// Requires recent authentication (re-auth may be needed).
  Future<Result<void>> deleteAccount();
}
```

### 3.3 AuthFailure Types

The existing `AuthFailure` class in `lib/core/error/failures.dart` is a generic failure with a `message` and `code`. For Phase 2, we extend the auth error handling with a more specific sealed class in the auth feature domain:

```dart
// lib/features/auth/domain/failures/auth_failures.dart
import '../../../../core/error/failures.dart';

/// Typed authentication failure variants.
/// Each maps to a specific Firebase Auth error code.
sealed class AuthenticationFailure extends AuthFailure {
  const AuthenticationFailure({
    required super.message,
    super.code,
    super.stackTrace,
  });
}

/// Email/password combination is incorrect.
final class InvalidCredentialsFailure extends AuthenticationFailure {
  const InvalidCredentialsFailure({
    super.message = 'Invalid email or password.',
    super.code = 'invalid-credentials',
    super.stackTrace,
  });
}

/// Email is already registered with another account.
final class EmailAlreadyInUseFailure extends AuthenticationFailure {
  const EmailAlreadyInUseFailure({
    super.message = 'An account with this email already exists.',
    super.code = 'email-already-in-use',
    super.stackTrace,
  });
}

/// Password does not meet strength requirements.
final class WeakPasswordFailure extends AuthenticationFailure {
  const WeakPasswordFailure({
    super.message = 'Password must be at least 8 characters.',
    super.code = 'weak-password',
    super.stackTrace,
  });
}

/// Network error during authentication.
final class AuthNetworkFailure extends AuthenticationFailure {
  const AuthNetworkFailure({
    super.message = 'No internet connection. Please check your network.',
    super.code = 'network-error',
    super.stackTrace,
  });
}

/// No user found with the provided email.
final class UserNotFoundFailure extends AuthenticationFailure {
  const UserNotFoundFailure({
    super.message = 'No account found with this email.',
    super.code = 'user-not-found',
    super.stackTrace,
  });
}

/// Too many failed attempts. Account temporarily locked.
final class TooManyRequestsFailure extends AuthenticationFailure {
  const TooManyRequestsFailure({
    super.message = 'Too many attempts. Please try again later.',
    super.code = 'too-many-requests',
    super.stackTrace,
  });
}

/// User cancelled the Google Sign-In flow.
final class SignInCancelledFailure extends AuthenticationFailure {
  const SignInCancelledFailure({
    super.message = 'Sign-in was cancelled.',
    super.code = 'sign-in-cancelled',
    super.stackTrace,
  });
}

/// Unexpected authentication error.
final class UnknownAuthFailure extends AuthenticationFailure {
  const UnknownAuthFailure({
    super.message = 'An unexpected error occurred. Please try again.',
    super.code = 'unknown',
    super.stackTrace,
  });
}
```

---

## 4. Data Layer

### 4.1 AuthRemoteDatasource

```dart
// lib/features/auth/data/datasources/auth_remote_datasource.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';

/// Raw Firebase Auth operations.
/// Does NOT catch exceptions -- that is the repository's job.
@lazySingleton
class AuthRemoteDatasource {
  AuthRemoteDatasource(this._firebaseAuth, this._googleSignIn);

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  /// Signs in with email/password. Throws FirebaseAuthException.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Creates account with email/password. Throws FirebaseAuthException.
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(displayName);
    return credential;
  }

  /// Google OAuth sign-in. Returns null if user cancels.
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // User cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return _firebaseAuth.signInWithCredential(credential);
  }

  /// Signs out from Firebase and Google.
  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Stream of Firebase auth state changes.
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Current Firebase user, or null.
  User? get currentUser => _firebaseAuth.currentUser;

  /// Deletes the current user account.
  Future<void> deleteAccount() async {
    await _firebaseAuth.currentUser?.delete();
  }
}
```

### 4.2 AppUser Mapper

```dart
// lib/features/auth/data/mappers/app_user_mapper.dart
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/app_user.dart';

/// Maps between Firebase User and domain AppUser.
abstract class AppUserMapper {
  /// Converts a Firebase [User] to an [AppUser] domain entity.
  static AppUser fromFirebaseUser(User user) {
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      createdAt: user.metadata.creationTime,
      lastSignInAt: user.metadata.lastSignInTime,
    );
  }
}
```

### 4.3 AuthRepositoryImpl

```dart
// lib/features/auth/data/repositories/auth_repository_impl.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/failures/auth_failures.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../mappers/app_user_mapper.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remoteDatasource);

  final AuthRemoteDatasource _remoteDatasource;

  @override
  Future<Result<AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _remoteDatasource.signInWithEmail(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return const Result.failure(UnknownAuthFailure());
      }
      return Result.success(AppUserMapper.fromFirebaseUser(user));
    } on FirebaseAuthException catch (e, st) {
      return Result.failure(_mapFirebaseException(e, st));
    } catch (e, st) {
      return Result.failure(
        UnknownAuthFailure(stackTrace: st),
      );
    }
  }

  @override
  Future<Result<AppUser>> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _remoteDatasource.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      final user = credential.user;
      if (user == null) {
        return const Result.failure(UnknownAuthFailure());
      }
      return Result.success(AppUserMapper.fromFirebaseUser(user));
    } on FirebaseAuthException catch (e, st) {
      return Result.failure(_mapFirebaseException(e, st));
    } catch (e, st) {
      return Result.failure(
        UnknownAuthFailure(stackTrace: st),
      );
    }
  }

  @override
  Future<Result<AppUser>> signInWithGoogle() async {
    try {
      final credential = await _remoteDatasource.signInWithGoogle();
      if (credential == null) {
        return const Result.failure(SignInCancelledFailure());
      }
      final user = credential.user;
      if (user == null) {
        return const Result.failure(UnknownAuthFailure());
      }
      return Result.success(AppUserMapper.fromFirebaseUser(user));
    } on FirebaseAuthException catch (e, st) {
      return Result.failure(_mapFirebaseException(e, st));
    } catch (e, st) {
      return Result.failure(
        UnknownAuthFailure(stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _remoteDatasource.signOut();
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(
        UnknownAuthFailure(stackTrace: st),
      );
    }
  }

  @override
  Stream<AppUser?> get currentUser {
    return _remoteDatasource.authStateChanges.map(
      (user) => user != null
          ? AppUserMapper.fromFirebaseUser(user)
          : null,
    );
  }

  @override
  AppUser? get currentUserSync {
    final user = _remoteDatasource.currentUser;
    return user != null ? AppUserMapper.fromFirebaseUser(user) : null;
  }

  @override
  Future<Result<void>> deleteAccount() async {
    try {
      await _remoteDatasource.deleteAccount();
      return const Result.success(null);
    } on FirebaseAuthException catch (e, st) {
      return Result.failure(_mapFirebaseException(e, st));
    } catch (e, st) {
      return Result.failure(
        UnknownAuthFailure(stackTrace: st),
      );
    }
  }

  /// Maps Firebase Auth exception codes to domain failure types.
  AuthenticationFailure _mapFirebaseException(
    FirebaseAuthException e,
    StackTrace st,
  ) {
    return switch (e.code) {
      'invalid-email' ||
      'wrong-password' ||
      'invalid-credential' =>
        InvalidCredentialsFailure(stackTrace: st),
      'email-already-in-use' =>
        EmailAlreadyInUseFailure(stackTrace: st),
      'weak-password' =>
        WeakPasswordFailure(stackTrace: st),
      'user-not-found' =>
        UserNotFoundFailure(stackTrace: st),
      'too-many-requests' =>
        TooManyRequestsFailure(stackTrace: st),
      'network-request-failed' =>
        AuthNetworkFailure(stackTrace: st),
      _ => UnknownAuthFailure(stackTrace: st),
    };
  }
}
```

---

## 5. Presentation Layer

### 5.1 AuthBloc Events

```dart
// lib/features/auth/presentation/bloc/auth_event.dart
import 'package:equatable/equatable.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// App started -- check current auth state.
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

/// User requested email sign-in.
final class SignInWithEmailRequested extends AuthEvent {
  const SignInWithEmailRequested({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

/// User requested email sign-up.
final class SignUpWithEmailRequested extends AuthEvent {
  const SignUpWithEmailRequested({
    required this.email,
    required this.password,
    required this.displayName,
  });

  final String email;
  final String password;
  final String displayName;

  @override
  List<Object?> get props => [email, password, displayName];
}

/// User requested Google sign-in.
final class SignInWithGoogleRequested extends AuthEvent {
  const SignInWithGoogleRequested();
}

/// User requested sign-out.
final class SignOutRequested extends AuthEvent {
  const SignOutRequested();
}

/// Auth state changed externally (token refresh, sign-in from another tab).
final class AuthStateChanged extends AuthEvent {
  const AuthStateChanged(this.user);

  final AppUser? user;

  @override
  List<Object?> get props => [user];
}
```

### 5.2 AuthBloc States

```dart
// lib/features/auth/presentation/bloc/auth_state.dart
import 'package:equatable/equatable.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/failures/auth_failures.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state before auth check.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Auth operation in progress.
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// User is authenticated.
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user, {this.hasFamily = false});

  final AppUser user;

  /// Whether this user belongs to a family.
  /// Determines redirect: family setup vs home.
  final bool hasFamily;

  @override
  List<Object?> get props => [user, hasFamily];
}

/// User is not authenticated.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Authentication operation failed.
final class AuthError extends AuthState {
  const AuthError(this.failure);

  final AuthenticationFailure failure;

  @override
  List<Object?> get props => [failure];
}
```

### 5.3 AuthBloc Implementation

```dart
// lib/features/auth/presentation/bloc/auth_bloc.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../family/domain/repositories/family_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Manages authentication state for the entire app.
/// Extends ChangeNotifier for go_router refreshListenable.
@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> with ChangeNotifier {
  AuthBloc(this._authRepository, this._familyRepository)
      : super(const AuthInitial()) {
    on<AuthStarted>(_onAuthStarted);
    on<SignInWithEmailRequested>(_onSignInWithEmail);
    on<SignUpWithEmailRequested>(_onSignUpWithEmail);
    on<SignInWithGoogleRequested>(_onSignInWithGoogle);
    on<SignOutRequested>(_onSignOut);
    on<AuthStateChanged>(_onAuthStateChanged);
  }

  final AuthRepository _authRepository;
  final FamilyRepository _familyRepository;
  StreamSubscription<AppUser?>? _authSubscription;

  Future<void> _onAuthStarted(
    AuthStarted event,
    Emitter<AuthState> emit,
  ) async {
    _authSubscription = _authRepository.currentUser.listen(
      (user) => add(AuthStateChanged(user)),
    );
  }

  Future<void> _onAuthStateChanged(
    AuthStateChanged event,
    Emitter<AuthState> emit,
  ) async {
    if (event.user == null) {
      emit(const AuthUnauthenticated());
    } else {
      final hasFamily = await _checkHasFamily(event.user!.uid);
      emit(AuthAuthenticated(event.user!, hasFamily: hasFamily));
    }
    notifyListeners(); // Trigger go_router refresh
  }

  Future<void> _onSignInWithEmail(
    SignInWithEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _authRepository.signInWithEmail(
      email: event.email,
      password: event.password,
    );
    result.when(
      success: (user) async {
        final hasFamily = await _checkHasFamily(user.uid);
        emit(AuthAuthenticated(user, hasFamily: hasFamily));
        notifyListeners();
      },
      failure: (failure) => emit(AuthError(failure)),
    );
  }

  Future<void> _onSignUpWithEmail(
    SignUpWithEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _authRepository.signUpWithEmail(
      email: event.email,
      password: event.password,
      displayName: event.displayName,
    );
    result.when(
      success: (user) {
        emit(AuthAuthenticated(user, hasFamily: false));
        notifyListeners();
      },
      failure: (failure) => emit(AuthError(failure)),
    );
  }

  Future<void> _onSignInWithGoogle(
    SignInWithGoogleRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _authRepository.signInWithGoogle();
    result.when(
      success: (user) async {
        final hasFamily = await _checkHasFamily(user.uid);
        emit(AuthAuthenticated(user, hasFamily: hasFamily));
        notifyListeners();
      },
      failure: (failure) => emit(AuthError(failure)),
    );
  }

  Future<void> _onSignOut(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _authRepository.signOut();
    result.when(
      success: (_) {
        emit(const AuthUnauthenticated());
        notifyListeners();
      },
      failure: (failure) => emit(AuthError(failure)),
    );
  }

  /// Checks if the authenticated user belongs to a family.
  Future<bool> _checkHasFamily(String uid) async {
    final result = await _familyRepository.getFamilyForUser(uid);
    return result.when(
      success: (family) => family != null,
      failure: (_) => false,
    );
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
```

### 5.4 SignInScreen

```dart
// lib/features/auth/presentation/screens/sign_in_screen.dart
//
// Layout specification (implemented as a StatefulWidget):
//
// - App logo and title at top (centered)
// - Email TextFormField with email keyboard type
// - Password TextFormField with obscureText
// - "Forgot password?" text button (Phase 7 -- disabled with TODO)
// - "Sign In" primary ElevatedButton (full width)
// - Divider with "OR" text
// - "Sign in with Google" OutlinedButton with Google icon
// - "Don't have an account? Sign Up" text button at bottom
//
// Validation:
// - Email: required, valid email format (RegExp)
// - Password: required, minimum 1 character (Firebase handles strength)
//
// Loading state:
// - BlocBuilder wraps the form
// - When AuthLoading, buttons show CircularProgressIndicator, fields disabled
//
// Error state:
// - BlocListener shows SnackBar with failure message
// - SnackBar uses error color from theme
//
// Dimensions:
// - Max width 400px (for tablet)
// - Horizontal padding 24px
// - Vertical spacing 16px between fields, 24px before buttons
```

**Form validation rules:**

| Field | Validation | Error Message |
|-------|-----------|---------------|
| Email | Required | "Please enter your email" |
| Email | Valid format (RegExp) | "Please enter a valid email" |
| Password | Required | "Please enter your password" |

### 5.5 SignUpScreen

```dart
// lib/features/auth/presentation/screens/sign_up_screen.dart
//
// Layout specification (implemented as a StatefulWidget):
//
// - App logo and title at top (centered, smaller than sign-in)
// - Display name TextFormField
// - Email TextFormField with email keyboard type
// - Password TextFormField with obscureText, strength indicator below
// - Confirm password TextFormField with obscureText
// - "Create Account" primary ElevatedButton (full width)
// - "Already have an account? Sign In" text button at bottom
//
// Validation:
// - Name: required, min 2 characters, max 50 characters
// - Email: required, valid email format
// - Password: required, min 8 characters
// - Confirm password: required, must match password
//
// All validation runs on form submit (not on field change)
// to avoid premature error display.
```

**Form validation rules:**

| Field | Validation | Error Message |
|-------|-----------|---------------|
| Display name | Required | "Please enter your name" |
| Display name | Min 2 chars | "Name must be at least 2 characters" |
| Display name | Max 50 chars | "Name must be 50 characters or less" |
| Email | Required | "Please enter your email" |
| Email | Valid format | "Please enter a valid email" |
| Password | Required | "Please enter a password" |
| Password | Min 8 chars | "Password must be at least 8 characters" |
| Confirm password | Required | "Please confirm your password" |
| Confirm password | Matches password | "Passwords do not match" |

### 5.6 Error Message Mapping

```dart
// lib/features/auth/presentation/utils/auth_error_messages.dart

import '../../domain/failures/auth_failures.dart';

/// Maps AuthenticationFailure to user-facing strings.
/// These messages are shown in SnackBars and error UI.
abstract class AuthErrorMessages {
  static String fromFailure(AuthenticationFailure failure) {
    return switch (failure) {
      InvalidCredentialsFailure() =>
        'The email or password you entered is incorrect. Please try again.',
      EmailAlreadyInUseFailure() =>
        'An account with this email already exists. Try signing in instead.',
      WeakPasswordFailure() =>
        'Your password is too short. Please use at least 8 characters.',
      AuthNetworkFailure() =>
        'Unable to connect. Please check your internet connection and try again.',
      UserNotFoundFailure() =>
        'We could not find an account with this email. Would you like to sign up?',
      TooManyRequestsFailure() =>
        'Too many attempts. Please wait a few minutes and try again.',
      SignInCancelledFailure() =>
        'Sign-in was cancelled.',
      UnknownAuthFailure() =>
        'Something went wrong. Please try again later.',
    };
  }
}
```

---

## 6. Session Persistence

### 6.1 Firebase Auth Persistence

Firebase Auth for Flutter persists the auth token automatically using platform-specific secure storage (Keychain on iOS, encrypted SharedPreferences on Android). No additional configuration is needed.

### 6.2 Auth State Flow on App Restart

```
App opens
  |
  v
Firebase.initializeApp()
  |
  v
AuthBloc receives AuthStarted
  |
  v
AuthBloc subscribes to authStateChanges stream
  |
  v
[Firebase checks persisted token]
  |                        |
  | (valid token)          | (no token / expired)
  v                        v
AuthStateChanged(user)     AuthStateChanged(null)
  |                        |
  v                        v
AuthAuthenticated          AuthUnauthenticated
  |                        |
  v                        v
Router: go to /home        Router: go to /sign-in
  or /family-setup
```

### 6.3 Token Refresh

Firebase Auth SDK handles token refresh automatically every ~55 minutes. The `authStateChanges()` stream does NOT emit on token refresh (only `idTokenChanges()` does). For the app's purposes, `authStateChanges()` is sufficient -- we only care about sign-in and sign-out transitions.

---

## 7. Impact Analysis

### 7.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| `lib/features/auth/` (entire feature) | New | Medium | New feature with 8+ files |
| `lib/core/error/failures.dart` | Dependency | Low | AuthFailure already exists, extended with typed subclasses in feature |
| `app.dart` | Modified | Low | AuthBloc provider added |
| `app_router.dart` | Modified | Medium | Auth guard integration |
| DI container | Modified | Low | AuthBloc, AuthRepository, AuthRemoteDatasource registered |

### 7.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Google Sign-In fails on specific devices | Medium | Medium | Test on 3+ real devices. Fall back to email auth. |
| Firebase Auth exception codes change between SDK versions | Low | Medium | Pin Firebase SDK version. Map unknown codes to UnknownAuthFailure. |
| Auth state race condition with router | Medium | High | Use `refreshListenable` pattern. AuthBloc extends ChangeNotifier. |
| User cancels Google Sign-In -- treated as error | Low | Low | Handle null return from GoogleSignIn.signIn() as cancellation, not error. |
| Token expires during long background session | Low | Medium | Firebase SDK auto-refreshes. `authStateChanges` emits if session is truly invalid. |

---

## 8. Functional Tests

### 8.1 Unit Tests -- AuthBloc

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| AUTH-FT-001 | Initial state | AuthBloc created | No events | State is AuthInitial | High |
| AUTH-FT-002 | Auth started -- user exists | Persisted token valid | AuthStarted dispatched | Emits AuthAuthenticated with user | High |
| AUTH-FT-003 | Auth started -- no user | No persisted token | AuthStarted dispatched | Emits AuthUnauthenticated | High |
| AUTH-FT-004 | Sign in success | Valid email/password | SignInWithEmailRequested | Emits AuthLoading then AuthAuthenticated | High |
| AUTH-FT-005 | Sign in failure -- wrong password | Wrong password | SignInWithEmailRequested | Emits AuthLoading then AuthError(InvalidCredentials) | High |
| AUTH-FT-006 | Sign in failure -- network error | No internet | SignInWithEmailRequested | Emits AuthLoading then AuthError(NetworkError) | High |
| AUTH-FT-007 | Sign up success | Valid credentials | SignUpWithEmailRequested | Emits AuthLoading then AuthAuthenticated(hasFamily: false) | High |
| AUTH-FT-008 | Sign up failure -- email in use | Existing email | SignUpWithEmailRequested | Emits AuthLoading then AuthError(EmailAlreadyInUse) | High |
| AUTH-FT-009 | Sign up failure -- weak password | 3-char password | SignUpWithEmailRequested | Emits AuthLoading then AuthError(WeakPassword) | High |
| AUTH-FT-010 | Google sign-in success | User completes OAuth | SignInWithGoogleRequested | Emits AuthLoading then AuthAuthenticated | High |
| AUTH-FT-011 | Google sign-in cancelled | User cancels OAuth | SignInWithGoogleRequested | Emits AuthLoading then AuthError(SignInCancelled) | Medium |
| AUTH-FT-012 | Sign out success | User authenticated | SignOutRequested | Emits AuthLoading then AuthUnauthenticated | High |
| AUTH-FT-013 | Auth state changes externally | Token invalidated | AuthStateChanged(null) | Emits AuthUnauthenticated | Medium |

### 8.2 Unit Tests -- AuthRepositoryImpl

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| AUTH-FT-020 | Maps FirebaseUser to AppUser | Valid Firebase User | signInWithEmail succeeds | Returns Result.success with correct AppUser fields | High |
| AUTH-FT-021 | Maps invalid-email to InvalidCredentials | Firebase throws invalid-email | signInWithEmail called | Returns Result.failure(InvalidCredentialsFailure) | High |
| AUTH-FT-022 | Maps email-already-in-use | Firebase throws email-already-in-use | signUpWithEmail called | Returns Result.failure(EmailAlreadyInUseFailure) | High |
| AUTH-FT-023 | Maps network-request-failed | Firebase throws network error | Any auth method | Returns Result.failure(AuthNetworkFailure) | High |
| AUTH-FT-024 | Maps unknown code to UnknownAuthFailure | Firebase throws unrecognized code | Any auth method | Returns Result.failure(UnknownAuthFailure) | Medium |
| AUTH-FT-025 | Google sign-in returns null (cancelled) | GoogleSignIn.signIn() returns null | signInWithGoogle called | Returns Result.failure(SignInCancelledFailure) | Medium |

### 8.3 Widget Tests

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| AUTH-FT-030 | Sign-in screen renders all fields | Screen mounted | -- | Email field, password field, sign-in button, Google button visible | High |
| AUTH-FT-031 | Empty email shows validation error | Email field empty | Sign-in button tapped | "Please enter your email" shown | High |
| AUTH-FT-032 | Invalid email shows validation error | "notanemail" entered | Sign-in button tapped | "Please enter a valid email" shown | Medium |
| AUTH-FT-033 | Loading state disables buttons | AuthLoading state | -- | Sign-in button shows loading indicator, not tappable | High |
| AUTH-FT-034 | Error state shows SnackBar | AuthError emitted | -- | SnackBar with error message visible | High |
| AUTH-FT-035 | Sign-up screen renders all fields | Screen mounted | -- | Name, email, password, confirm fields visible | High |
| AUTH-FT-036 | Password mismatch shows error | Different passwords entered | Create Account tapped | "Passwords do not match" shown on confirm field | High |
| AUTH-FT-037 | Short password shows error | 5-char password entered | Create Account tapped | "Password must be at least 8 characters" shown | Medium |
| AUTH-FT-038 | Navigate to sign-up from sign-in | Sign-in screen mounted | "Sign Up" link tapped | Navigation to /sign-up | Medium |

### 8.4 Edge Cases

- Sign in with email that uses mixed case (`Marcus@Email.com`) -- Firebase normalizes email, should work.
- Sign in while already authenticated -- should be a no-op or re-authenticate.
- Rapid double-tap on sign-in button -- should not send two auth requests.
- Very long email (255+ characters) -- Firebase has a 256-char limit, test behavior.
- Password with special characters and Unicode -- should work without encoding issues.
- Google Sign-In when Google Play Services unavailable (Android) -- should show clear error.

---

## 9. Implementation Recommendations

### 9.1 Suggested Approach

1. Create `AppUser` entity in domain layer.
2. Create `AuthenticationFailure` sealed class hierarchy.
3. Create `AuthRepository` abstract interface.
4. Implement `AuthRemoteDatasource` with raw Firebase calls.
5. Implement `AppUserMapper`.
6. Implement `AuthRepositoryImpl` with Firebase exception mapping.
7. Create `AuthEvent` and `AuthState` classes.
8. Implement `AuthBloc` with all event handlers.
9. Implement `SignInScreen` with form validation.
10. Implement `SignUpScreen` with form validation.
11. Implement `AuthErrorMessages` mapping.
12. Write unit tests for AuthRepositoryImpl (mock AuthRemoteDatasource).
13. Write unit tests for AuthBloc (mock AuthRepository).
14. Write widget tests for SignInScreen and SignUpScreen.
15. Integration test against Firebase Auth emulator.

### 9.2 Estimated Effort

**T-shirt size: M** (3-4 days)

Core auth logic is straightforward. Primary effort is in UI polish, error handling coverage, and thorough testing.

---

## 10. Open Questions

- [ ] Should we support "Remember me" checkbox on sign-in? Firebase persists sessions by default, so this may be unnecessary.
- [ ] Should the app detect if the user's email is already associated with a Google account and suggest Google Sign-In?
- [ ] Should we add biometric authentication as a future sign-in method (face/fingerprint to unlock), separate from the PIN system?
- [ ] Should password reset be part of Phase 2 or deferred to Phase 7 as currently planned?

---

*Generated by Software Architect Analyst*
*Date: 2026-03-09*
