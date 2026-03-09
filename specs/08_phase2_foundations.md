# Phase 2 Foundation -- Auth & Family Onboarding

## 1. Overview

### 1.1 Summary

This specification defines the foundation work required for Phase 2: Auth & Family Onboarding. It covers Firebase project configuration, Firebase initialization in the Flutter app, emulator setup for local development, new DI modules for Firebase services, updated go_router configuration with auth and PIN route guards, all Phase 2 route definitions, and pubspec.yaml dependency additions. This is the umbrella spec that establishes the infrastructure on which all other Phase 2 features are built.

### 1.2 Business Context

Phase 2 delivers the first user-facing experience: **"A parent can go from app install to a configured family in under 5 minutes."** Before any auth screen, profile switcher, or family setup can be implemented, the Firebase SDK must be initialized, the routing system must enforce authentication, and the DI container must provide Firebase service instances. This spec ensures that all Phase 2 feature specs (09 through 14) have a stable, testable platform to build on.

### 1.3 Scope

**In scope:**
- Firebase project creation and `flutterfire configure` integration
- `firebase_options.dart` generation and `main.dart` initialization
- Firebase emulator configuration for local development (Auth port 9099, Firestore port 8080, Functions port 5001)
- New DI module: `FirebaseModule` (FirebaseAuth, FirebaseFirestore, GoogleSignIn providers)
- Updated `app_router.dart` with all Phase 2 routes and redirect guards
- Updated `route_names.dart` with new route constants
- `AuthGuard` redirect logic (unauthenticated users to `/sign-in`)
- `PinGuard` redirect logic (parent profiles to `/pin-entry` for protected routes)
- New pubspec.yaml dependencies: `google_sign_in`, `sign_in_with_apple`, `crypto`
- Feature flag: `USE_FIREBASE_EMULATOR` for local development
- Environment-aware Firebase initialization (dev uses emulators, prod uses real Firebase)

**Out of scope:**
- Auth feature implementation (see `specs/09_firebase_auth.md`)
- Family setup screens (see `specs/10_family_onboarding.md`)
- Member profile management (see `specs/11_member_profiles.md`)
- PIN system (see `specs/12_pin_system.md`)
- Firestore security rules (see `specs/13_firestore_security_rules.md`)
- Cloud Functions (see `specs/14_cloud_functions_invite.md`)

### 1.4 References

- `specs/00_project_foundation.md` -- Section 4.7 (Security), Section 7.4 (Project Structure), Section 7.5 (Dependencies)
- `specs/01_project_scaffolding.md` -- DI modules, router setup, folder structure
- `CLAUDE.md` -- Tech stack, architecture summary, resolved decisions
- `docs/development-rules.md` -- Naming, file rules, conventions

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| P2F-001 | Firebase Core initializes on app start | High | `Firebase.initializeApp()` completes without error on both iOS and Android |
| P2F-002 | Firebase Auth instance is available via DI | High | `getIt<FirebaseAuth>()` resolves a valid instance |
| P2F-003 | Firestore instance is available via DI | High | `getIt<FirebaseFirestore>()` resolves a valid instance |
| P2F-004 | GoogleSignIn instance is available via DI | High | `getIt<GoogleSignIn>()` resolves a valid instance |
| P2F-005 | Firebase emulators connect in dev environment | High | Auth and Firestore calls route to local emulators when `USE_FIREBASE_EMULATOR=true` |
| P2F-006 | AuthGuard redirects unauthenticated users to sign-in | High | Navigating to any protected route without auth redirects to `/sign-in` |
| P2F-007 | AuthGuard allows authenticated users through | High | Authenticated users can access protected routes without redirect |
| P2F-008 | PinGuard redirects parent profiles to PIN entry | High | Parent profile accessing PIN-protected route without verified session redirects to `/pin-entry` |
| P2F-009 | PinGuard allows child profiles through without PIN | High | Child profiles skip PIN verification for routes that only gate parents |
| P2F-010 | All Phase 2 routes are registered in go_router | High | Every screen listed in Phase 2 has a corresponding route |
| P2F-011 | Crashlytics captures errors in release builds | Medium | Uncaught Flutter errors are reported to Firebase Crashlytics |
| P2F-012 | Analytics tracks screen views | Medium | Screen transitions are logged to Firebase Analytics |
| P2F-013 | New dependencies resolve without conflicts | High | `flutter pub get` succeeds with all new dependencies |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| P2F-NFR-001 | Firebase initialization time | Time from app start to Firebase ready | < 2 seconds on mid-range device |
| P2F-NFR-002 | Emulator connection time | Time to connect to local emulators | < 1 second |
| P2F-NFR-003 | Route redirect latency | Time from navigation to redirect | < 100ms (imperceptible) |

### 2.3 Assumptions

- A Firebase project has been created in the Firebase Console for this app.
- `flutterfire configure` has been run and `firebase_options.dart` generated for both iOS and Android.
- The Firebase CLI is installed and the developer is logged in.
- The `firebase.json` and `.firebaserc` configuration files exist at the project root.
- iOS and Android build configurations are compatible with the Firebase SDK versions.

### 2.4 Constraints

- Firebase initialization must happen before `runApp()` -- it is a blocking async operation in `main()`.
- The emulator feature flag must not accidentally route production builds through emulators. Environment checks must be compile-time safe.
- `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are in `.gitignore` and must not be committed.
- `firebase_options.dart` is generated code and should also be in `.gitignore`.

---

## 3. Firebase Project Configuration

### 3.1 Firebase Console Setup

Create a Firebase project with the following services enabled:

| Service | Purpose | Phase |
|---------|---------|-------|
| Authentication | Email/password + Google Sign-In + Apple Sign-In | Phase 2 |
| Cloud Firestore | Primary remote database | Phase 2 |
| Cloud Functions | Invite code generation/validation | Phase 2 |
| Cloud Messaging (FCM) | Push notifications | Phase 7 |
| Crashlytics | Crash reporting | Phase 2 |
| Analytics | Usage analytics | Phase 2 |

### 3.2 FlutterFire Configuration

```bash
# Install FlutterFire CLI (if not already installed)
dart pub global activate flutterfire_cli

# Configure Firebase for this project
flutterfire configure \
  --project=family-chores-app \
  --platforms=android,ios \
  --android-package-name=com.familychores.app \
  --ios-bundle-id=com.familychores.app
```

This generates:
- `lib/firebase_options.dart` -- Platform-specific Firebase configuration
- `android/app/google-services.json` -- Android Firebase config
- `ios/Runner/GoogleService-Info.plist` -- iOS Firebase config
- `ios/firebase_app_id_file.json` -- iOS app ID mapping

### 3.3 Firebase Emulator Configuration

```json
// firebase.json (project root)
{
  "emulators": {
    "auth": {
      "port": 9099,
      "host": "0.0.0.0"
    },
    "firestore": {
      "port": 8080,
      "host": "0.0.0.0"
    },
    "functions": {
      "port": 5001,
      "host": "0.0.0.0"
    },
    "ui": {
      "enabled": true,
      "port": 4000
    }
  },
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "functions": {
    "source": "functions"
  }
}
```

```bash
# Start emulators for local development
firebase emulators:start

# Start with data import/export for persistence between sessions
firebase emulators:start --import=./emulator-data --export-on-exit=./emulator-data
```

---

## 4. App Initialization

### 4.1 Updated main.dart

```dart
// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/di/injection.dart';
import 'core/config/firebase_config.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Connect to emulators in dev
  if (FirebaseConfig.useEmulator) {
    await FirebaseConfig.connectToEmulators();
  }

  // 3. Configure Crashlytics
  if (!kDebugMode) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // 4. Initialize DI container
  await configureDependencies(
    kDebugMode ? Env.dev : Env.prod,
  );

  runApp(const FamilyChoresApp());
}
```

### 4.2 Firebase Configuration Helper

```dart
// lib/core/config/firebase_config.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Manages Firebase environment configuration.
/// Emulators are used in debug builds only.
abstract class FirebaseConfig {
  /// Whether to connect to Firebase emulators.
  /// True in debug mode, false in release.
  static bool get useEmulator => kDebugMode;

  static const String _emulatorHost = 'localhost';
  static const int _authEmulatorPort = 9099;
  static const int _firestoreEmulatorPort = 8080;

  /// Connects Firebase services to local emulators.
  /// Must be called after Firebase.initializeApp().
  static Future<void> connectToEmulators() async {
    await FirebaseAuth.instance.useAuthEmulator(
      _emulatorHost,
      _authEmulatorPort,
    );
    FirebaseFirestore.instance.useFirestoreEmulator(
      _emulatorHost,
      _firestoreEmulatorPort,
    );
  }
}
```

### 4.3 Updated app.dart

```dart
// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../shared/theme/app_theme.dart';
import 'di/injection.dart';
import 'router/app_router.dart';

class FamilyChoresApp extends StatelessWidget {
  const FamilyChoresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => getIt<AuthBloc>()..add(const AuthStarted()),
        ),
      ],
      child: MaterialApp.router(
        title: 'Family Chores',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
```

---

## 5. Dependency Injection Updates

### 5.1 Firebase Module

```dart
// lib/app/di/modules/firebase_module.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';

@module
abstract class FirebaseModule {
  @singleton
  FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  @singleton
  FirebaseFirestore get firebaseFirestore => FirebaseFirestore.instance;

  @singleton
  GoogleSignIn get googleSignIn => GoogleSignIn(
        scopes: ['email', 'profile'],
      );
}
```

### 5.2 Updated Network Module

The existing `network_module.dart` is extended with Firebase-aware providers:

```dart
// lib/app/di/modules/network_module.dart (additions)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

// Existing ConnectivityService registration remains unchanged.
// Firebase module handles FirebaseFirestore registration.
```

No changes needed -- Firebase-specific providers live in `FirebaseModule`. The existing `NetworkModule` continues to provide `ConnectivityService`.

---

## 6. Router Updates

### 6.1 Updated Route Names

```dart
// lib/app/router/route_names.dart
abstract class RouteNames {
  // -- Onboarding & Auth --
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';

  // -- Family Setup --
  static const familySetup = '/family-setup';
  static const createFamily = '/family-setup/create';
  static const joinFamily = '/family-setup/join';
  static const addMember = '/family-setup/add-member';

  // -- Profiles --
  static const profileSwitcher = '/profiles';

  // -- PIN --
  static const pinEntry = '/pin';
  static const pinSetup = '/pin-setup';

  // -- Main App --
  static const home = '/';
  static const taskList = '/tasks';
  static const taskDetail = '/tasks/:taskId';
  static const rewards = '/rewards';
  static const dashboard = '/dashboard';

  // -- Settings --
  static const settings = '/settings';

  // -- Age-appropriate --
  static const emmaView = '/emma';
}
```

### 6.2 Updated Router Configuration

```dart
// lib/app/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import 'guards/auth_guard.dart';
import 'guards/pin_guard.dart';
import 'route_names.dart';

/// Creates the app router with auth-aware redirects.
/// Deep link handling: go_router natively handles incoming deep links.
/// The `/join` route maps external deep links to internal `/family-setup/join`.
/// See `specs/16_deep_links.md` Section 7.3 for deep link route configuration.
GoRouter createAppRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: true,
    refreshListenable: authBloc,
    redirect: (context, state) {
      return AuthGuard.redirect(authBloc, state);
    },
    routes: [
      // -- Unauthenticated routes --
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RouteNames.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: RouteNames.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),

      // -- Family setup routes (authenticated, no PIN required) --
      GoRoute(
        path: RouteNames.familySetup,
        builder: (context, state) => const FamilySetupScreen(),
      ),
      GoRoute(
        path: RouteNames.createFamily,
        builder: (context, state) => const CreateFamilyScreen(),
      ),
      GoRoute(
        path: RouteNames.joinFamily,
        builder: (context, state) {
          final code = state.uri.queryParameters['code'];
          return JoinFamilyScreen(initialCode: code);
        },
      ),

      // Deep link entry point: /join?code=ABC123
      // Maps external deep link path to internal route.
      // See specs/16_deep_links.md Section 7.3.
      GoRoute(
        path: '/join',
        redirect: (context, state) {
          final code = state.uri.queryParameters['code'];
          if (code != null) {
            return '${RouteNames.joinFamily}?code=$code';
          }
          return RouteNames.joinFamily;
        },
      ),
      GoRoute(
        path: RouteNames.addMember,
        builder: (context, state) => const AddMemberScreen(),
      ),

      // -- Profile routes --
      GoRoute(
        path: RouteNames.profileSwitcher,
        builder: (context, state) => const ProfileSwitcherScreen(),
      ),

      // -- PIN routes --
      GoRoute(
        path: RouteNames.pinEntry,
        builder: (context, state) => const PinEntryScreen(),
      ),
      GoRoute(
        path: RouteNames.pinSetup,
        builder: (context, state) => const PinSetupScreen(),
      ),

      // -- Main app routes (authenticated + profile selected) --
      GoRoute(
        path: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: RouteNames.taskList,
        builder: (context, state) => const TaskListScreen(),
      ),
      GoRoute(
        path: RouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}
```

### 6.3 Auth Guard

```dart
// lib/app/router/guards/auth_guard.dart
import 'package:go_router/go_router.dart';

import '../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../route_names.dart';

/// Redirects unauthenticated users to the sign-in screen.
/// Redirects authenticated users away from auth screens.
abstract class AuthGuard {
  /// Routes that do not require authentication.
  static const _publicRoutes = [
    RouteNames.splash,
    RouteNames.onboarding,
    RouteNames.signIn,
    RouteNames.signUp,
  ];

  /// Returns a redirect path, or null if no redirect is needed.
  static String? redirect(AuthBloc authBloc, GoRouterState state) {
    final isAuthenticated = authBloc.state is AuthAuthenticated;
    final isOnPublicRoute = _publicRoutes.contains(state.matchedLocation);

    // Unauthenticated user trying to access protected route
    if (!isAuthenticated && !isOnPublicRoute) {
      return RouteNames.signIn;
    }

    // Authenticated user on auth screen -- redirect to home or family setup
    if (isAuthenticated && isOnPublicRoute) {
      final hasFamily = (authBloc.state as AuthAuthenticated).hasFamily;
      return hasFamily ? RouteNames.home : RouteNames.familySetup;
    }

    return null; // No redirect needed
  }
}
```

### 6.4 PIN Guard

```dart
// lib/app/router/guards/pin_guard.dart
import 'package:go_router/go_router.dart';

import '../../../features/pin/presentation/bloc/pin_cubit.dart';
import '../route_names.dart';

/// Redirects parent profiles to PIN entry for protected routes.
abstract class PinGuard {
  /// Routes that require PIN verification for parent profiles.
  static const _pinProtectedRoutes = [
    RouteNames.settings,
    RouteNames.addMember,
  ];

  /// Returns a redirect path, or null if no redirect is needed.
  static String? redirect({
    required PinCubit pinCubit,
    required GoRouterState state,
    required bool isParentProfile,
  }) {
    if (!isParentProfile) return null; // Children skip PIN
    if (!_pinProtectedRoutes.contains(state.matchedLocation)) return null;

    final isPinVerified = pinCubit.state is PinVerified;
    if (!isPinVerified) {
      return '${RouteNames.pinEntry}?redirect=${state.matchedLocation}';
    }

    return null;
  }
}
```

---

## 7. New Dependencies

### 7.1 pubspec.yaml Additions

The following dependencies are added to the existing `pubspec.yaml` for Phase 2:

```yaml
dependencies:
  # Authentication (additions to existing firebase_auth)
  google_sign_in: ^6.2.0
  sign_in_with_apple: ^6.1.0

  # Cryptography (for PIN hashing)
  crypto: ^3.0.0

  # Firebase Functions (for invite code callable functions)
  cloud_functions: ^5.2.0

  # Smooth page indicators (for onboarding carousel)
  smooth_page_indicator: ^1.1.0

  # Cached network images (for avatars/family photos)
  cached_network_image: ^3.3.0

  # Deep link handling (replaces deprecated uni_links)
  app_links: ^6.0.0

  # System share sheet (for sharing invite links)
  share_plus: ^10.0.0
```

### 7.2 Dependency Justification

| Package | Purpose | Alternative Considered | Rationale |
|---------|---------|----------------------|-----------|
| `google_sign_in` | Google OAuth sign-in | Manual OAuth flow | Official Flutter plugin, maintained by Google |
| `sign_in_with_apple` | Apple Sign-In (required for iOS apps with social login) | None | Apple App Store requirement |
| `crypto` | SHA-256 PIN hashing | `pointycastle` | Simpler API, maintained by Dart team, sufficient for SHA-256 |
| `cloud_functions` | Call Firebase Cloud Functions from Flutter | Raw HTTP calls | Type-safe, handles auth tokens automatically |
| `smooth_page_indicator` | Onboarding carousel page dots | Custom implementation | Well-maintained, saves time on non-core UI |
| `cached_network_image` | Cached image loading for avatars | `image_network` | Industry standard, disk + memory caching |
| `app_links` | Deep link handling for Universal Links and App Links | `uni_links` (deprecated) | Actively maintained replacement for uni_links, supports iOS + Android |
| `share_plus` | System share sheet for invite link sharing | `flutter_share` | Official Flutter Community plugin, supports all platforms |

---

## 8. Feature Flag Configuration

### 8.1 Firebase Emulator Flag

```dart
// lib/core/config/app_config.dart
import 'package:flutter/foundation.dart';

/// Application-wide configuration flags.
abstract class AppConfig {
  /// Whether to use Firebase emulators for local development.
  /// Determined by build mode: debug = emulators, release = production.
  static bool get useFirebaseEmulator => kDebugMode;

  /// Duration of PIN session validity before requiring re-entry.
  static const Duration pinSessionDuration = Duration(minutes: 5);

  /// Maximum number of failed PIN attempts before lockout.
  static const int maxPinAttempts = 5;

  /// Initial lockout duration after max failed PIN attempts.
  static const Duration initialLockoutDuration = Duration(minutes: 5);
}
```

---

## 9. Phase 2 Route Flow

### 9.1 Navigation State Machine

```
App Launch
  |
  v
[Splash Screen] -- check auth state -->
  |                                    |
  | (no auth)                          | (authenticated)
  v                                    v
[First launch?] -- yes --> [Onboarding] --> [Sign In]
  |                                           |
  | (no, returning)                           | (sign up link)
  v                                           v
[Sign In] <------------------------------> [Sign Up]
  |
  | (authenticated)
  v
[Has family?] -- no --> [Family Setup]
  |                       |           |
  | (yes)         [Create Family]  [Join Family]
  v                       |           |
[Profile Switcher]        v           v
  |                    [Add Members]
  | (select profile)      |
  v                       v
[Is parent?] -- yes --> [PIN Entry] --> [Home]
  |
  | (child)
  v
[Home]
```

### 9.2 Screen Inventory

| Screen | Route | Auth Required | PIN Required | Phase 2 |
|--------|-------|---------------|-------------|---------|
| Splash | `/splash` | No | No | Yes |
| Onboarding Carousel | `/onboarding` | No | No | Yes |
| Sign In | `/sign-in` | No | No | Yes |
| Sign Up | `/sign-up` | No | No | Yes |
| Family Setup | `/family-setup` | Yes | No | Yes |
| Create Family | `/family-setup/create` | Yes | No | Yes |
| Join Family | `/family-setup/join` | Yes | No | Yes |
| Join Family (deep link) | `/join` (redirects to `/family-setup/join`) | Yes | No | Yes |
| Add Member | `/family-setup/add-member` | Yes | No (during setup) | Yes |
| Profile Switcher | `/profiles` | Yes | No | Yes |
| PIN Entry | `/pin` | Yes | No (it IS the PIN gate) | Yes |
| PIN Setup | `/pin-setup` | Yes | No (first-time setup) | Yes |
| Settings (stub) | `/settings` | Yes | Yes | Yes |
| Home | `/` | Yes | No | Stub |

---

## 10. File Structure (New Files)

```
lib/
  core/
    config/
      firebase_config.dart          # Firebase emulator connection
      app_config.dart               # Feature flags and app constants
  app/
    di/
      modules/
        firebase_module.dart        # NEW: Firebase DI registrations
    router/
      app_router.dart               # MODIFIED: Full Phase 2 routes
      route_names.dart              # MODIFIED: All route constants
      guards/
        auth_guard.dart             # NEW: Auth redirect logic
        pin_guard.dart              # NEW: PIN redirect logic
  features/
    auth/                           # NEW: Auth feature (see spec 09)
    family/                         # MODIFIED: Family feature (see spec 10)
    pin/                            # NEW: PIN feature (see spec 12)
```

---

## 11. Impact Analysis

### 11.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| `main.dart` | Modified | Medium | Firebase init added before DI. Order matters. |
| `app.dart` | Modified | Low | BlocProvider wrapper added for AuthBloc |
| `app_router.dart` | Modified | Medium | Complete rewrite with guards and Phase 2 routes |
| `route_names.dart` | Modified | Low | New constants added, existing ones preserved |
| `pubspec.yaml` | Modified | Medium | New dependencies may cause version conflicts |
| DI container | Modified | Medium | New FirebaseModule must not conflict with existing modules |
| `.gitignore` | Modified | Low | Firebase config files added to ignore list |

### 11.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Firebase SDK version conflicts with existing deps | Medium | High | Run `flutter pub get` early. Pin exact compatible versions. |
| Google Sign-In native setup fails on iOS/Android | Medium | Medium | Follow official setup guides. Test on real devices early. |
| Emulator connection fails on physical devices | Medium | Low | Use `10.0.2.2` for Android emulator, `localhost` for iOS simulator |
| AuthGuard redirect loops | Low | High | Explicit public route whitelist. Integration test for redirect logic. |
| Firebase init blocks app startup too long | Low | Medium | Show splash screen during init. Measure init time on real devices. |
| PinGuard conflicts with AuthGuard | Medium | Medium | Guards execute in order. Auth check first, then PIN check. Clear separation. |

---

## 12. Functional Tests

### 12.1 Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| P2F-FT-001 | Firebase initializes | App launches | `Firebase.initializeApp()` called | No error thrown, services available | High |
| P2F-FT-002 | FirebaseAuth registered in DI | DI configured | `getIt<FirebaseAuth>()` called | Returns valid FirebaseAuth instance | High |
| P2F-FT-003 | Firestore registered in DI | DI configured | `getIt<FirebaseFirestore>()` called | Returns valid FirebaseFirestore instance | High |
| P2F-FT-004 | GoogleSignIn registered in DI | DI configured | `getIt<GoogleSignIn>()` called | Returns GoogleSignIn with email+profile scopes | High |
| P2F-FT-005 | AuthGuard redirects unauthenticated to /sign-in | User not authenticated | Navigate to /home | Redirected to /sign-in | High |
| P2F-FT-006 | AuthGuard allows authenticated through | User authenticated with family | Navigate to /home | Reaches /home without redirect | High |
| P2F-FT-007 | AuthGuard redirects authenticated from auth screens | User authenticated | Navigate to /sign-in | Redirected to /home or /family-setup | High |
| P2F-FT-008 | PinGuard redirects parent to PIN entry | Parent profile, PIN not verified | Navigate to /settings | Redirected to /pin?redirect=/settings | High |
| P2F-FT-009 | PinGuard skips for child profiles | Child profile active | Navigate to /settings | No PIN redirect | High |
| P2F-FT-010 | All Phase 2 routes resolve | Routes configured | Navigate to each route | No route not found errors | Medium |
| P2F-FT-011 | Emulator connects in debug mode | Debug build | App starts | Auth and Firestore use emulators | Medium |
| P2F-FT-012 | Emulator does not connect in release | Release build | App starts | Auth and Firestore use production | High |

### 12.2 Edge Cases

- App launch with no internet -- Firebase.initializeApp() should still succeed (uses cached config).
- Auth state changes during navigation -- redirect should update reactively via `refreshListenable`.
- Deep link to a protected route while unauthenticated -- should redirect to sign-in, then redirect back after auth.
- Multiple rapid route changes -- guards should not cause redirect loops.

---

## 13. Implementation Recommendations

### 13.1 Prototype Checklist

1. **What can a user do at the end of this phase that they could not do before?** As Marcus, I can install the app, see a splash screen, view an onboarding carousel, sign up with my email, create a family called "The Johnsons", add Sofia/Alex/Emma as family members, set up my parent PIN, and switch between family profiles.

2. **Which screens are delivered?** See Section 9.2 -- 13 screens/routes total.

3. **What is the minimum data flow?** User taps "Sign Up" -> AuthBloc dispatches SignUpRequested -> AuthRepositoryImpl creates Firebase Auth user -> Drift writes member row with `syncStatus=pending` -> SyncEngine pushes to Firestore -> Firestore listener confirms sync -> `syncStatus=synced`.

4. **What is the offline behavior?** Sign-up and sign-in require internet (Firebase Auth is cloud-only). Family creation and member addition work offline (write to Drift, queue for sync). Profile switching works offline. PIN verification works offline (hash comparison is local).

5. **What does "done" look like?** A QA tester can: install the app -> see onboarding -> sign up -> create family -> add 3 members -> set PIN -> switch profiles -> see empty home screen. All data persists after app restart. If the tester signs out and signs back in, data reloads from Firestore.

### 13.2 Suggested Approach

1. Create Firebase project in Console and run `flutterfire configure`.
2. Add all new dependencies to `pubspec.yaml` and run `flutter pub get`.
3. Implement `FirebaseConfig` and update `main.dart` with Firebase init.
4. Implement `FirebaseModule` for DI.
5. Update `route_names.dart` with all Phase 2 routes.
6. Implement `AuthGuard` and `PinGuard`.
7. Update `app_router.dart` with all routes and guards.
8. Update `app.dart` with AuthBloc provider.
9. Run `dart run build_runner build` for DI code generation.
10. Write guard unit tests.
11. Verify Firebase emulator connectivity on iOS simulator and Android emulator.

### 13.3 Suggested Order of Implementation (across Phase 2 specs)

1. **Phase 2 Foundation** (this spec) -- Firebase setup, DI, routing
2. **Firebase Auth** (spec 09) -- Auth feature, sign-in/sign-up screens
3. **Family Onboarding** (spec 10) -- Family setup, onboarding carousel
4. **Member Profiles** (spec 11) -- Add members, profile switcher
5. **PIN System** (spec 12) -- PIN setup, entry, verification
6. **Firestore Security Rules** (spec 13) -- Deploy rules
7. **Cloud Functions** (spec 14) -- Invite code system
8. **Test Plan** (spec 15) -- Integration and E2E tests

### 13.4 Estimated Effort

**T-shirt size: S** (1-2 days)

Firebase configuration and DI setup are primarily configuration work. The guard implementations are small but require careful testing.

---

## 14. Open Questions

- [X] Should the app support Android emulator connecting to Firebase emulators on host machine (requires `10.0.2.2` instead of `localhost`)? this should depend on the environment config env dev should connect to firebase emultaor
- [X] Should `firebase_options.dart` be committed to the repo or remain in `.gitignore`? It does not contain secrets but is generated code. keet gitignore
- [x] Should the splash screen show a loading indicator during Firebase init, or should it be a static branded screen? loadng indicator
- [x] Should we implement deep link handling in Phase 2 or defer to Phase 7? Resolved: implement in Phase 2. Full specification in `specs/16_deep_links.md`.

---

*Generated by Software Architect Analyst*
*Date: 2026-03-09*
