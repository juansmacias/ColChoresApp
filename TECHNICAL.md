# Technical Reference — Family Chores App

Developer-focused guide for setup, running, testing, and contributing to the project.

---

## Requirements

| Tool | Version | Notes |
|------|---------|-------|
| Flutter SDK | >= 3.19 | [Install](https://docs.flutter.dev/get-started/install) |
| Dart SDK | >= 3.3 | Bundled with Flutter |
| Xcode | >= 15 | Required for iOS builds |
| Android Studio | Latest | Required for Android builds |
| Firebase CLI | Latest | `npm install -g firebase-tools` |
| FlutterFire CLI | Latest | `dart pub global activate flutterfire_cli` |
| Node.js | >= 18 | Required for Firebase CLI and Cloud Functions |

---

## Flutter Dependencies

### State Management

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_bloc` | ^8.1.6 | BLoC and Cubit patterns — strict UI/logic separation, stream-based reactivity |
| `equatable` | ^2.0.5 | Value equality for BLoC states and events |

### Local Database

| Package | Version | Purpose |
|---------|---------|---------|
| `isar` | ^3.1.0 | Embedded NoSQL database — offline-first local storage |
| `isar_flutter_libs` | ^3.1.0 | Isar native binaries for Flutter |
| `path_provider` | ^2.1.0 | Locate Isar DB file on device |

### Firebase

| Package | Version | Purpose |
|---------|---------|---------|
| `firebase_core` | ^3.0.0 | Firebase initialization |
| `firebase_auth` | ^5.0.0 | Authentication (email, Google, Apple) |
| `cloud_firestore` | ^5.0.0 | Remote database with real-time sync |
| `cloud_functions` | ^5.0.0 | Call server-authoritative Cloud Functions |
| `firebase_messaging` | ^15.0.0 | Push notifications (FCM) |
| `firebase_crashlytics` | ^4.0.0 | Crash reporting |
| `firebase_analytics` | ^11.0.0 | Usage analytics |

### Routing & DI

| Package | Version | Purpose |
|---------|---------|---------|
| `go_router` | ^14.0.0 | Declarative routing with auth and PIN guards |
| `get_it` | ^8.0.0 | Service locator for dependency injection |
| `injectable` | ^2.4.0 | Code-generated DI wiring (`@injectable`, `@singleton`) |

### UI & Design

| Package | Version | Purpose |
|---------|---------|---------|
| `google_fonts` | ^6.2.0 | Nunito font (Material Design 3 theme) |
| `lottie` | ^3.1.0 | Celebration animations |
| `fl_chart` | ^0.69.0 | Fairness dashboard contribution charts |
| `local_auth` | ^2.3.0 | Biometric PIN bypass (Face ID / fingerprint) |

### Code Generation & Utilities

| Package | Version | Purpose |
|---------|---------|---------|
| `freezed` | ^2.5.0 | Immutable data classes, union types |
| `json_serializable` | ^6.8.0 | JSON serialization for models |

### Dev Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `build_runner` | ^2.4.0 | Code generation runner |
| `freezed_annotation` | ^2.4.0 | Annotations for freezed |
| `json_annotation` | ^4.9.0 | Annotations for json_serializable |
| `isar_generator` | ^3.1.0 | Isar schema code generation |
| `injectable_generator` | ^2.4.0 | DI code generation |
| `mocktail` | ^1.0.4 | Mocking library for unit tests |
| `bloc_test` | ^9.1.7 | BLoC-specific test utilities |
| `flutter_lints` | ^6.0.0 | Recommended lint rules |

> **Note:** Exact versions will be locked in `pubspec.lock` after running `flutter pub get`. Versions above are targets — check `pubspec.yaml` for the source of truth.

---

## Setup

### 1. Clone and install

```bash
git clone <repo-url>
cd choresApp
flutter pub get
```

### 2. Generate code

Run after any change to Isar schemas, Freezed models, or DI registrations:

```bash
dart run build_runner build --delete-conflicting-outputs
```

To watch for changes during development:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

### 3. Configure Firebase

```bash
# Log in to Firebase
firebase login

# Link the Flutter app to your Firebase project
flutterfire configure
```

This generates `lib/firebase_options.dart`. Do not commit real Firebase configs — use separate projects for dev and prod.

### 4. Environment

Copy the environment template and fill in values:

```bash
cp .env.example .env
```

Environment variables are accessed via the `--dart-define` flag at build time. Firebase configuration is handled by `flutterfire configure`, not `.env`.

### 5. Start Firebase emulators (local development)

```bash
firebase emulators:start
```

Emulators run on default ports:

| Emulator | Port |
|----------|------|
| Auth | 9099 |
| Firestore | 8080 |
| Cloud Functions | 5001 |
| Pub/Sub (FCM) | 8085 |
| Emulator UI | 4000 |

---

## Running the App

```bash
# Run on connected device or simulator
flutter run

# Run on a specific device
flutter run -d <device-id>

# List available devices
flutter devices

# Run in release mode
flutter run --release

# Run with custom dart-define flags
flutter run --dart-define=ENV=development
```

---

## Testing

```bash
# Run all tests
flutter test

# Run with coverage report
flutter test --coverage

# Run a single test file
flutter test test/unit/core/sync/sync_engine_test.dart

# Run tests matching a name pattern
flutter test --name "should queue operation when offline"

# View coverage (requires lcov)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Test structure

```
test/
  unit/                     # Fast, no I/O — mirrors lib/ structure
    core/
      sync/
      connectivity/
    features/
      tasks/
      rewards/
  integration/              # Firebase emulator tests
  e2e/                      # Full user flow tests
  helpers/                  # Factories, fixtures, custom matchers
```

### Coverage target

80% minimum on business logic (domain layer services and use cases). Run `flutter test --coverage` and inspect `coverage/lcov.info`.

---

## Code Generation

The project uses `build_runner` for four generators. Re-run after modifying any annotated file:

| Generator | Annotation | Output file |
|-----------|-----------|------------|
| Isar | `@collection` | `*.isar.dart` |
| Freezed | `@freezed` | `*.freezed.dart` |
| json_serializable | `@JsonSerializable` | `*.g.dart` |
| injectable | `@injectable`, `@singleton` | `injection.config.dart` |

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Architecture

### Layer dependencies

```
Presentation  →  Domain  ←  Data
(BLoC/Cubit)     (pure Dart)   (Isar + Firestore)
                     ↑
               Sync Engine
```

**Rule:** Domain layer never imports Isar, Firestore, or any external SDK. It depends only on abstract repository interfaces.

### Feature structure

Each feature under `lib/features/` follows the same layout:

```
feature_name/
  data/
    datasources/        # local_datasource.dart, remote_datasource.dart
    models/             # Isar schemas, Firestore DTOs
    repositories/       # Repository implementations
  domain/
    entities/           # Pure Dart classes (Freezed)
    repositories/       # Abstract interfaces
    usecases/           # One use case per file
  presentation/
    bloc/               # BLoC or Cubit + states + events
    screens/            # Full-screen widgets
    widgets/            # Reusable feature-scoped widgets
```

### BLoC conventions

- Use **Cubit** for simple state (no complex event processing).
- Use **BLoC** for flows with multiple distinct event types.
- States are `Freezed` sealed classes: `initial`, `loading`, `loaded`, `error`.
- BLoCs depend on use cases, not repositories directly.

---

## Linting & Analysis

```bash
# Run static analysis
flutter analyze

# Format code
dart format lib/ test/

# Check formatting without writing
dart format --output=none --set-exit-if-changed lib/ test/
```

Analysis config is in `analysis_options.yaml`. The project targets strict Dart analysis — no `dynamic`, no implicit casts.

---

## Building

```bash
# Android APK (debug)
flutter build apk --debug

# Android APK (release)
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle

# iOS (release)
flutter build ios --release

# Run on physical iOS device
flutter build ios && open ios/Runner.xcworkspace
```

---

## Git Workflow

### Branch strategy

```
main          →  production-ready
develop       →  integration branch
feature/<name>  →  new features (branches off develop)
fix/<name>      →  bug fixes (branches off develop)
chore/<name>    →  tooling, config, refactors
```

### Commit format (Conventional Commits)

```
<type>(<scope>): <description>
```

| Type | When to use |
|------|------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code change with no behavior change |
| `test` | Adding or updating tests |
| `docs` | Documentation only |
| `chore` | Build, tooling, CI |

Examples:

```
feat(tasks): add recurring task support with RRULE
fix(sync): retry failed operations with exponential backoff
test(rewards): add unit tests for RewardService.redeem
```

- Imperative mood, lowercase, max 72 characters, no trailing period.
- No code without tests. No "I'll add tests later."

---

## CI/CD

Every pull request runs:

1. `flutter pub get`
2. `flutter analyze` — zero warnings policy
3. `dart format --output=none --set-exit-if-changed` — formatting check
4. `dart run build_runner build` — generated code is up to date
5. `flutter test --coverage` — unit and integration tests
6. `flutter build apk --debug` — build must succeed

Merge is blocked if any step fails.

---

## Troubleshooting

### `build_runner` conflicts

```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

### Flutter version mismatch

```bash
flutter upgrade
flutter pub upgrade
```

### Firebase emulator not connecting

Ensure the app is configured to point to emulators at startup. Check `lib/app/firebase_emulator_config.dart` (to be created in Phase 1). The Firestore emulator host must be `10.0.2.2` on Android emulator and `localhost` on iOS simulator.

### Isar schema not updating

Delete the Isar DB file on the device/simulator and relaunch. Schema migrations are not automatic in development.

---

## Key File Locations

| File | Purpose |
|------|---------|
| `pubspec.yaml` | Dependencies and app metadata |
| `analysis_options.yaml` | Dart linting rules |
| `lib/app/di/injection.dart` | DI container setup |
| `lib/app/router/app_router.dart` | go_router route definitions |
| `lib/core/sync/sync_engine.dart` | Offline sync orchestrator |
| `lib/firebase_options.dart` | Firebase config (generated by flutterfire) |
| `test/helpers/` | Shared test factories and matchers |

---

## Further Reading

| Document | Path |
|----------|------|
| Architecture Spec | `specs/00_project_foundation.md` |
| BLoC Foundation Spec | `specs/05_bloc_foundation.md` |
| Sync Engine Spec | `specs/03_sync_engine.md` |
| Development Rules | `docs/development-rules.md` |
| Design System | `docs/design-system.md` |
