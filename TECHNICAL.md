# Technical Reference — Family Chores App

Developer-focused guide for setup, running, testing, and contributing to the project.

---

## Platform Support

| Platform | Support | Notes |
|----------|---------|-------|
| **Android** | Required | Primary target. Min SDK 26 (Android 8.0) |
| **iOS** | Required | Primary target. Min deployment target iOS 15.0 |
| **Web** | Required | Core target. Firebase works natively on web |
| **macOS** | Optional | Best-effort. Requires Xcode and macOS entitlements |
| **Linux** | Optional | Best-effort. No biometric support (`local_auth`) |
| **Windows** | Optional | Best-effort. No biometric support (`local_auth`) |

> **Note:** All features must work on Android, iOS, and Web. Desktop platforms (macOS, Linux, Windows) may have degraded functionality for features that rely on mobile-only plugins (e.g. biometric PIN, image picker, FCM push notifications).

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
| `flutter_bloc` | ^9.1.1 | BLoC and Cubit patterns — strict UI/logic separation, stream-based reactivity |
| `equatable` | ^2.0.5 | Value equality for BLoC states and events |

### Local Database

| Package | Version | Purpose |
|---------|---------|---------|
| `drift` | ^2.18.0 | Type-safe SQLite ORM — offline-first local storage |
| `sqlite3_flutter_libs` | ^0.6.0 | SQLite native binaries for Flutter |
| `path_provider` | ^2.1.0 | Locate Drift DB file on device |

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
| `drift_dev` | ^2.18.0 | Drift schema code generation |
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

Run after any change to Drift table definitions, Freezed models, or DI registrations:

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

| Generator | Annotation / Trigger | Output file |
|-----------|---------------------|------------|
| Drift | `@DriftDatabase`, `Table` subclasses | `*.g.dart` |
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
(BLoC/Cubit)     (pure Dart)   (Drift + Firestore)
                     ↑
               Sync Engine
```

**Rule:** Domain layer never imports Drift, Firestore, or any external SDK. It depends only on abstract repository interfaces.

### Feature structure

Each feature under `lib/features/` follows the same layout:

```
feature_name/
  data/
    datasources/        # local_datasource.dart, remote_datasource.dart
    models/             # Drift table definitions, Firestore DTOs
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

### Drift schema not updating

Delete the Drift DB file (`family_chores.db`) on the device/simulator and relaunch, or increment `schemaVersion` in `AppDatabase` and add a migration in `MigrationStrategy`. Re-run `build_runner` after any table definition change.

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

## Implementation Phases

Each phase after Phase 1 ships a **fully working prototype**: real screens, real data, real sync. A family can install and use the app at the end of every phase.

### Phase Overview

| Phase | Name | Shippable Output | Status |
|-------|------|-----------------|--------|
| **1** | Foundation | Infrastructure only (no UI) | **Complete** |
| **2** | Auth & Family Onboarding | Sign up → create family → manage profiles → switch profiles | Planned |
| **3** | Task Management Core | Create → assign → complete tasks (offline + sync) | Planned |
| **4** | Rewards & Gamification | Earn points → browse catalog → redeem rewards | Planned |
| **5** | Fairness Dashboard | View contribution charts, streaks, time periods | Planned |
| **6** | Age-Appropriate Experiences | Emma's picture view + Alex's gamified view | Planned |
| **7** | Notifications & Polish | Push notifications, dark mode, biometric PIN | Planned |
| **8** | Production Hardening | E2E tests, Crashlytics, App Store submission | Planned |

---

### Phase 1 — Foundation ✅

**No user-facing screens. Pure infrastructure.**

Completed work:
- Flutter scaffold: app shell, DI container (`get_it` + `injectable`), route skeleton (`go_router`), theme
- Drift schema: all tables (`tasks`, `members`, `families`, `rewards`, `redemptions`, `categories`, `sync_operations`), TypeConverters, DAOs
- Sync engine: FIFO operation queue, LWW conflict resolver, retry with exponential backoff (1s → 4s → 16s), isolate-based processing
- Connectivity monitor: `connectivity_plus` stream, `ConnectivityStatus` enum, reconnection events
- BLoC base classes: `SyncAwareMixin`, `ConnectivityAwareMixin`, sealed state hierarchy
- Error handling: domain `AppException` hierarchy, `Result<T>` type, global `AppErrorBoundary`

Specs: `specs/01_project_scaffolding.md`, `specs/03_sync_engine.md`, `specs/04_connectivity_monitor.md`, `specs/05_bloc_foundation.md`, `specs/06_error_handling.md`

---

### Phase 2 — Auth & Family Onboarding

**Goal:** A parent goes from app install to a fully configured family in under 5 minutes.

#### Screens

| Screen | Route | Notes |
|--------|-------|-------|
| Splash | `/splash` | Initializes Firebase, checks auth state |
| Onboarding Carousel | `/onboarding` | First-run only, 3 slides |
| Sign In | `/sign-in` | Email + Google Sign-In |
| Sign Up | `/sign-up` | Email + display name |
| Family Setup | `/family-setup` | Create or join via invite code |
| Add Member | `/family-setup/add-member` | Name, age, avatar, role |
| Profile Switcher | `/profiles` | Avatar grid, active profile ring |
| PIN Setup | `/pin/setup` | 4-6 digits, confirm, biometric opt-in |
| PIN Entry | `/pin/verify` | Gate for parent-only actions |
| Settings (stub) | `/settings` | Family management entry point |

#### Backend

- Firebase Auth: email/password + Google Sign-In
- Firestore security rules v1: families scoped per `familyId`, parents only write
- Cloud Function: `generateInviteCode` (6-char code, 48h TTL) + `validateInviteCode`
- Sync: family document + members subcollection fully synced via Drift

#### Spec file: `specs/08_auth_family.md`

---

### Phase 3 — Task Management Core

**Goal:** The core chore loop works end-to-end — online and offline.

#### Screens

| Screen | Route | Notes |
|--------|-------|-------|
| Task List (Parent) | `/tasks` | All tasks, grouped by assignee |
| Task List (Child) | `/tasks` | My tasks only, filtered by active profile |
| Task Creation | `/tasks/new` | Full metadata form |
| Task Edit | `/tasks/:id/edit` | Same form, pre-filled |
| Task Detail | `/tasks/:id` | Subtask checklist, history |
| Task Completion | — | Inline: checkbox animation + confetti |
| Category List | `/categories` | Manage categories (PIN-gated) |
| Sync Status Banner | — | Global: offline / syncing / up-to-date |

#### Backend

- Task CRUD fully synced (Drift → Firestore)
- Recurrence engine: RRULE parsing, automatic next-instance generation
- Sync queue: operations displayed to user as "pending" badge on task card
- Offline first: all operations available without internet

#### Spec file: `specs/09_task_management.md`

---

### Phase 4 — Rewards & Gamification

**Goal:** Points make chores motivating. Kids can spend what they earn.

#### Screens

| Screen | Route | Notes |
|--------|-------|-------|
| Points Balance | — | Displayed on profile header and task list |
| Reward Catalog | `/rewards` | Card grid, sorted by point cost |
| Reward Detail | `/rewards/:id` | Description, cost, redeem button |
| Redemption Confirmation | — | Bottom sheet, deducts points |
| Redemption History | `/rewards/history` | Per-member log |
| Lottie Celebration | — | Overlay: task complete + redemption |

#### Backend

- Points: auto-credited on task completion, stored per member in Drift + Firestore
- Reward CRUD: PIN-protected create/edit/delete for parents
- Redemption: auto-approved when points ≥ cost; recorded in Drift + Firestore

#### Spec file: `specs/10_rewards_gamification.md`

---

### Phase 5 — Fairness Dashboard

**Goal:** Parents see who is contributing. Conversations are fact-based.

#### Screens

| Screen | Route | Notes |
|--------|-------|-------|
| Dashboard | `/dashboard` | PIN-gated (configurable) |
| Contribution Rings | — | fl_chart donut per member |
| Daily Bar Chart | — | Tasks completed per day per member |
| Time Period Selector | — | Today / This Week / This Month |
| Streak Cards | — | Consecutive full-completion days |
| Member Detail Stats | `/dashboard/:memberId` | Tasks, points, rate |

#### Data

- All aggregations run on local Drift DB (no Firestore reads for dashboard)
- Emma excluded from comparative views
- Streak: consecutive days where all assigned tasks were completed before midnight
- Offline: serves last-synced data with timestamp banner

#### Spec file: `specs/11_fairness_dashboard.md`

---

### Phase 6 — Age-Appropriate Experiences

**Goal:** Emma can use the app. Alex's view feels like a game.

#### Emma's View

- Picture-based task cards (no text required — illustrated icons per task type)
- 56px minimum touch targets throughout
- 2.5s confetti + chime celebration on completion
- Pink/warm tinted background
- "Complete on behalf of Emma" quick action in parent view

#### Alex's View (child mode enhancements)

- Streak flame counter on home screen header
- Points balance with level badge ("Level 3 Helper")
- Task card XP bar showing progress toward next reward
- "Nice work!" micro-celebration on every completion (1.5s)
- No access to management actions (task creation, rewards editing)

#### Spec file: `specs/12_child_experiences.md`

---

### Phase 7 — Notifications & Polish

**Goal:** The app feels production-ready. Families are reminded, informed, and delighted.

#### Delivered

- FCM push notifications:
  - Task reminder (configurable lead time: 30 min / 1 hr / day before)
  - Completion alert to parents when child finishes a chore
  - Overdue task alert
- Notification preferences screen (per member, per notification type)
- Dark mode: full Material Design 3 dark theme using the same pastel token system
- Biometric PIN bypass: Face ID / Touch ID / fingerprint via `local_auth`
- i18n audit: all user-facing strings in ARB files; English-only for v1 but structure is ready
- Accessibility pass: WCAG 2.1 AA, semantic labels, focus order, color contrast check
- Animation polish: consistent easing curves, `prefers-reduced-motion` support

#### Spec file: `specs/13_notifications_polish.md`

---

### Phase 8 — Production Hardening

**Goal:** Real family, real data, App Store.

#### Delivered

- Integration tests: all repositories tested against Firebase emulators
- E2E tests: primary flows (onboarding → task creation → completion → reward redemption → dashboard)
- Performance profiling: cold start < 2s, sync < 5s, scroll 60fps on mid-range device
- Crashlytics: production config, custom keys (familyId, memberId, syncStatus)
- Firebase Analytics: events for all key actions (task_created, task_completed, reward_redeemed, dashboard_viewed)
- App Store: screenshots (6.7", 6.1", iPad), app description, privacy policy URL, age rating
- Play Store: listing assets, content rating questionnaire
- Beta release: TestFlight (iOS) + Firebase App Distribution (Android)

#### Spec file: `specs/14_production_hardening.md`

---

## Further Reading

| Document | Path |
|----------|------|
| Architecture Spec | `specs/00_project_foundation.md` |
| BLoC Foundation Spec | `specs/05_bloc_foundation.md` |
| Sync Engine Spec | `specs/03_sync_engine.md` |
| Development Rules | `docs/development-rules.md` |
| Design System | `docs/design-system.md` |
