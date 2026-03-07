# Project Scaffolding & Configuration

## 1. Overview

### 1.1 Summary

This specification defines the Flutter project scaffolding, folder structure, dependency management, dependency injection configuration, static analysis rules, build tooling, and development environment setup for the Family Chores App. It is the first deliverable of Phase 1: Foundation and establishes the structural conventions that all subsequent code must follow.

### 1.2 Business Context

A well-structured project foundation reduces onboarding friction, prevents architectural drift, and enforces the SOLID, Clean Code, and TDD standards mandated by `docs/development-rules.md`. Every file created after this scaffold must have an unambiguous home. Every dependency must be justified. Every convention must be documented once and enforced automatically.

### 1.3 Scope

**In scope:**
- Flutter project creation and initial configuration
- Complete folder structure for `lib/`, `test/`, and project root
- Full dependency list with pinned versions (runtime and dev)
- Dependency injection setup with get_it + injectable
- `analysis_options.yaml` with strict Dart rules
- `build.yaml` for build_runner configuration
- Pre-commit hook setup for Flutter/Dart
- `.gitignore`, `.env.example`, and asset directory structure
- Barrel export conventions
- Dart naming conventions adapted from `docs/development-rules.md`

**Out of scope:**
- Firebase configuration (Phase 2)
- Drift table definitions (see `specs/02_isar_schemas.md`)
- Sync engine implementation (see `specs/03_sync_engine.md`)
- Any UI implementation

### 1.4 References

- `specs/00_project_foundation.md` -- Section 7.4 (Project Structure), Section 7.5 (Dependencies)
- `docs/development-rules.md` -- Naming, file rules, pre-commit hooks, project structure
- `CLAUDE.md` -- Tech stack, architecture summary, resolved decisions

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| SC-001 | Flutter project compiles and runs on iOS and Android | High | `flutter run` succeeds on both platforms with a blank MaterialApp |
| SC-002 | Folder structure matches the architecture specification | High | All directories from Section 7.4 of the foundation spec exist with placeholder files |
| SC-003 | All dependencies are declared with pinned versions | High | `flutter pub get` resolves without conflicts. No version ranges wider than caret (^) |
| SC-004 | Dependency injection resolves all registered services | High | `getIt<T>()` resolves for every registered singleton and factory |
| SC-005 | Static analysis passes with zero warnings | High | `dart analyze` reports no issues with the configured ruleset |
| SC-006 | Code generation runs without errors | High | `dart run build_runner build --delete-conflicting-outputs` completes cleanly |
| SC-007 | Pre-commit hooks enforce format, analysis, and tests | Medium | Committing unformatted code or code with analysis errors is blocked |
| SC-008 | Test infrastructure runs an example test | High | `flutter test` executes at least one passing test |
| SC-009 | Git repository initialized with correct branching | Medium | `main` and `develop` branches exist. `.gitignore` excludes generated files and secrets |
| SC-010 | Minimum platform versions configured | High | iOS deployment target is 15.0, Android minSdk is 26 |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| SC-NFR-001 | Build time for clean project | Time for `flutter build` on empty scaffold | < 60 seconds |
| SC-NFR-002 | Dependency count | Total direct dependencies | <= 25 runtime, <= 15 dev |
| SC-NFR-003 | Analysis strictness | Equivalent to TypeScript strict | No `dynamic`, no implicit casts, explicit types on public API |

### 2.3 Assumptions

- Flutter SDK >= 3.19 and Dart >= 3.3 are installed on the development machine.
- The Drift maintenance status decision gate has been resolved (Drift is used unless explicitly switched to Drift).
- Firebase CLI is installed but Firebase project configuration is deferred to Phase 2.
- Development occurs on macOS (Xcode available for iOS builds).

### 2.4 Constraints

- All conventions from `docs/development-rules.md` apply, adapted from TypeScript/Node.js to Dart/Flutter.
- No native platform code except through established Flutter plugins.
- All user-facing strings must be externalized from day one (i18n readiness per NFR-012 of foundation spec).

---

## 3. Flutter Project Creation

### 3.1 Creation Command

```bash
flutter create --org com.familychores --project-name family_chores_app .
```

### 3.2 Platform Configuration

**`android/app/build.gradle`:**
```groovy
android {
    compileSdk 34

    defaultConfig {
        applicationId "com.familychores.app"
        minSdk 26        // Android 8.0 (per NFR-011)
        targetSdk 34
        versionCode 1
        versionName "1.0.0"
    }
}
```

**`ios/Runner.xcodeproj` (via Xcode or `ios/Podfile`):**
```ruby
platform :ios, '15.0'   # Per NFR-011
```

### 3.3 pubspec.yaml

```yaml
name: family_chores_app
description: Family Chores App - coordinate household chores, build responsibility, make invisible work visible.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'
  flutter: '>=3.19.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # State Management
  flutter_bloc: ^8.1.0
  equatable: ^2.0.0

  # Local Database
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.6.0

  # Firebase
  firebase_core: ^2.25.0
  firebase_auth: ^4.17.0
  cloud_firestore: ^4.15.0
  firebase_messaging: ^14.7.0
  firebase_crashlytics: ^3.4.0
  firebase_analytics: ^10.8.0

  # Dependency Injection
  get_it: ^7.6.0
  injectable: ^2.3.0

  # Routing
  go_router: ^13.2.0

  # Networking & Connectivity
  connectivity_plus: ^5.0.0

  # Data Classes & Serialization
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0

  # Authentication
  local_auth: ^2.1.0

  # UI & Design
  google_fonts: ^6.1.0
  lottie: ^3.0.0
  fl_chart: ^0.66.0

  # Media
  image_picker: ^1.0.0

  # Utilities
  uuid: ^4.2.0
  intl: ^0.19.0
  shared_preferences: ^2.2.0
  path_provider: ^2.1.0
  rxdart: ^0.28.0

dev_dependencies:
  flutter_test:
    sdk: flutter

  # Code Generation
  build_runner: ^2.4.0
  injectable_generator: ^2.4.0
  drift_dev: ^2.18.0
  freezed: ^2.4.0
  json_serializable: ^6.7.0

  # Testing
  mocktail: ^1.0.0
  bloc_test: ^9.1.0
  fake_async: ^1.3.0

  # Linting
  flutter_lints: ^3.0.0
  very_good_analysis: ^5.1.0

flutter:
  uses-material-design: true

  assets:
    - assets/animations/
    - assets/images/
    - assets/icons/
```

---

## 4. Folder Structure

The complete folder structure, adapted from `specs/00_project_foundation.md` Section 7.4 to Dart/Flutter conventions.

```
family_chores_app/
|
+-- lib/
|   +-- app/
|   |   +-- app.dart                        # MaterialApp.router setup, theme, locale
|   |   +-- di/
|   |   |   +-- injection.dart              # configureDependencies() entry point
|   |   |   +-- injection.config.dart       # Generated by injectable
|   |   |   +-- modules/
|   |   |       +-- database_module.dart     # Drift instance provider
|   |   |       +-- network_module.dart      # Connectivity, Firestore, Auth providers
|   |   |       +-- external_module.dart     # SharedPreferences, UUID, etc.
|   |   +-- router/
|   |       +-- app_router.dart             # GoRouter configuration
|   |       +-- route_names.dart            # Route path constants
|   |       +-- guards/
|   |           +-- auth_guard.dart         # Firebase Auth redirect
|   |           +-- pin_guard.dart          # PIN verification redirect
|   |
|   +-- core/
|   |   +-- error/
|   |   |   +-- failures.dart              # Failure sealed class hierarchy
|   |   |   +-- exceptions.dart            # Exception classes (data layer)
|   |   |   +-- error_codes.dart           # Error code registry
|   |   +-- network/
|   |   |   +-- connectivity_service.dart   # Abstract connectivity interface
|   |   |   +-- connectivity_service_impl.dart
|   |   +-- sync/
|   |   |   +-- sync_engine.dart           # SyncEngine orchestrator
|   |   |   +-- operation_queue.dart       # Queue management
|   |   |   +-- conflict_resolver.dart     # LWW conflict resolution
|   |   |   +-- sync_status.dart           # SyncStatus enum and events
|   |   |   +-- sync_config.dart           # Retry constants, queue limits
|   |   +-- utils/
|   |   |   +-- result.dart                # Result<T> sealed class
|   |   |   +-- date_utils.dart            # Date helpers
|   |   |   +-- id_generator.dart          # UUID wrapper (injectable)
|   |   +-- constants/
|   |       +-- app_constants.dart         # App-wide constants
|   |       +-- sync_constants.dart        # Sync-specific constants
|   |       +-- storage_constants.dart     # DB names, collection names
|   |
|   +-- features/
|   |   +-- auth/
|   |   |   +-- data/
|   |   |   |   +-- datasources/
|   |   |   |   |   +-- auth_remote_datasource.dart
|   |   |   |   +-- repositories/
|   |   |   |       +-- auth_repository_impl.dart
|   |   |   +-- domain/
|   |   |   |   +-- entities/
|   |   |   |   |   +-- app_user.dart
|   |   |   |   +-- repositories/
|   |   |   |   |   +-- auth_repository.dart
|   |   |   |   +-- usecases/
|   |   |   |       +-- sign_in.dart
|   |   |   |       +-- sign_up.dart
|   |   |   |       +-- sign_out.dart
|   |   |   +-- presentation/
|   |   |       +-- bloc/
|   |   |       |   +-- auth_bloc.dart
|   |   |       +-- screens/
|   |   |       |   +-- sign_in_screen.dart
|   |   |       +-- widgets/
|   |   |
|   |   +-- family/
|   |   |   +-- data/
|   |   |   |   +-- datasources/
|   |   |   |   |   +-- family_local_datasource.dart
|   |   |   |   |   +-- family_remote_datasource.dart
|   |   |   |   +-- models/
|   |   |   |   |   +-- family_model.dart
|   |   |   |   |   +-- member_model.dart
|   |   |   |   +-- repositories/
|   |   |   |       +-- family_repository_impl.dart
|   |   |   +-- domain/
|   |   |   |   +-- entities/
|   |   |   |   |   +-- family.dart
|   |   |   |   |   +-- member.dart
|   |   |   |   +-- repositories/
|   |   |   |   |   +-- family_repository.dart
|   |   |   |   +-- usecases/
|   |   |   |       +-- create_family.dart
|   |   |   |       +-- join_family.dart
|   |   |   |       +-- switch_profile.dart
|   |   |   +-- presentation/
|   |   |       +-- bloc/
|   |   |       |   +-- family_bloc.dart
|   |   |       |   +-- profile_cubit.dart
|   |   |       +-- screens/
|   |   |       |   +-- family_setup_screen.dart
|   |   |       |   +-- profile_switcher.dart
|   |   |       +-- widgets/
|   |   |
|   |   +-- tasks/
|   |   |   +-- data/
|   |   |   |   +-- datasources/
|   |   |   |   |   +-- task_local_datasource.dart
|   |   |   |   |   +-- task_remote_datasource.dart
|   |   |   |   +-- models/
|   |   |   |   |   +-- task_model.dart
|   |   |   |   |   +-- subtask_model.dart
|   |   |   |   +-- repositories/
|   |   |   |       +-- task_repository_impl.dart
|   |   |   +-- domain/
|   |   |   |   +-- entities/
|   |   |   |   |   +-- task.dart
|   |   |   |   |   +-- subtask.dart
|   |   |   |   +-- repositories/
|   |   |   |   |   +-- task_repository.dart
|   |   |   |   +-- usecases/
|   |   |   |       +-- create_task.dart
|   |   |   |       +-- complete_task.dart
|   |   |   |       +-- get_tasks_for_member.dart
|   |   |   +-- presentation/
|   |   |       +-- bloc/
|   |   |       |   +-- task_list_bloc.dart
|   |   |       |   +-- task_creation_cubit.dart
|   |   |       +-- screens/
|   |   |       |   +-- task_list_screen.dart
|   |   |       |   +-- task_detail_screen.dart
|   |   |       +-- widgets/
|   |   |           +-- task_card.dart
|   |   |           +-- task_form.dart
|   |   |
|   |   +-- rewards/
|   |   |   +-- data/
|   |   |   |   +-- datasources/
|   |   |   |   +-- models/
|   |   |   |   +-- repositories/
|   |   |   +-- domain/
|   |   |   |   +-- entities/
|   |   |   |   +-- repositories/
|   |   |   |   +-- usecases/
|   |   |   +-- presentation/
|   |   |       +-- bloc/
|   |   |       +-- screens/
|   |   |       +-- widgets/
|   |   |
|   |   +-- dashboard/
|   |   |   +-- data/
|   |   |   +-- domain/
|   |   |   +-- presentation/
|   |   |
|   |   +-- pin/
|   |   |   +-- data/
|   |   |   |   +-- repositories/
|   |   |   |       +-- pin_repository_impl.dart
|   |   |   +-- domain/
|   |   |   |   +-- repositories/
|   |   |   |   |   +-- pin_repository.dart
|   |   |   |   +-- usecases/
|   |   |   |       +-- verify_pin.dart
|   |   |   |       +-- set_pin.dart
|   |   |   +-- presentation/
|   |   |       +-- bloc/
|   |   |       |   +-- pin_cubit.dart
|   |   |       +-- widgets/
|   |   |           +-- pin_entry_widget.dart
|   |   |
|   |   +-- notifications/
|   |       +-- data/
|   |       +-- domain/
|   |       +-- presentation/
|   |
|   +-- shared/
|       +-- theme/
|       |   +-- app_theme.dart              # ThemeData configuration
|       |   +-- color_tokens.dart           # Pastel palette constants
|       |   +-- text_styles.dart            # Nunito-based TextTheme
|       |   +-- spacing.dart                # 8px grid spacing constants
|       +-- widgets/
|       |   +-- celebration_overlay.dart
|       |   +-- connectivity_banner.dart
|       |   +-- progress_ring.dart
|       |   +-- member_avatar.dart
|       |   +-- empty_state.dart
|       |   +-- loading_indicator.dart
|       +-- extensions/
|       |   +-- context_extensions.dart     # Theme, MediaQuery shortcuts
|       |   +-- date_extensions.dart
|       +-- l10n/
|           +-- app_en.arb                  # English strings (i18n ready)
|
+-- test/
|   +-- unit/
|   |   +-- core/
|   |   |   +-- sync/
|   |   |   |   +-- sync_engine_test.dart
|   |   |   |   +-- conflict_resolver_test.dart
|   |   |   |   +-- operation_queue_test.dart
|   |   |   +-- network/
|   |   |   |   +-- connectivity_service_test.dart
|   |   |   +-- error/
|   |   |       +-- failures_test.dart
|   |   +-- features/
|   |       +-- tasks/
|   |       |   +-- domain/
|   |       |   |   +-- usecases/
|   |       |   +-- data/
|   |       |       +-- repositories/
|   |       +-- (mirrors lib/features/ structure)
|   +-- integration/
|   |   +-- sync/
|   |   +-- database/
|   +-- e2e/
|   |   +-- onboarding_test.dart
|   |   +-- task_lifecycle_test.dart
|   +-- fixtures/
|   |   +-- task_fixtures.dart
|   |   +-- member_fixtures.dart
|   |   +-- family_fixtures.dart
|   +-- helpers/
|       +-- test_helpers.dart
|       +-- mock_factories.dart
|       +-- pump_app.dart                   # Widget test helper
|
+-- assets/
|   +-- animations/                         # Lottie JSON files
|   +-- images/                             # Static images
|   +-- icons/                              # Custom icons if needed
|
+-- android/
+-- ios/
+-- .gitignore
+-- .env.example
+-- analysis_options.yaml
+-- build.yaml
+-- pubspec.yaml
+-- README.md
+-- CLAUDE.md
```

### 4.1 Placeholder Files

Each directory must contain at least one file to establish the convention and prevent empty directories from being lost in Git. For directories that will not have Phase 1 implementation, create a `.gitkeep` file. For directories with Phase 1 content, create the actual interface or placeholder file with a `// TODO(phase-N): Implement` comment referencing the phase where it will be built.

### 4.2 Barrel Exports

Each feature module and core module exposes a barrel file that re-exports only the public API. This follows the pattern from `docs/development-rules.md` Section 6.

```dart
// lib/core/sync/sync.dart (barrel export)
export 'sync_engine.dart';
export 'sync_status.dart';
// Do NOT export operation_queue.dart or conflict_resolver.dart
// -- they are internal to the sync package.
```

**Rule:** Only export types that other modules need to depend on. Internal implementation details stay private to the package.

---

## 5. Dependency Injection Configuration

### 5.1 Setup Entry Point

```dart
// lib/app/di/injection.dart
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
)
Future<void> configureDependencies(String environment) async {
  getIt.init(environment: environment);
}

// Environment constants for injectable
abstract class Env {
  static const dev = 'dev';
  static const staging = 'staging';
  static const prod = 'prod';
  static const test = 'test';
}
```

### 5.2 Module Registration Pattern

External dependencies that cannot be annotated directly use `@module` classes:

```dart
// lib/app/di/modules/database_module.dart
import 'package:injectable/injectable.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

@module
abstract class DatabaseModule {
  @preResolve
  @singleton
  Future<AppDatabase> get database async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'family_chores.db'));
    return AppDatabase(NativeDatabase(file));
    /* Tables registered in @DriftDatabase -- see specs/02_isar_schemas.md
        TasksTable,
        MembersTable,
        FamilyEntitySchema,
        RewardEntitySchema,
        RedemptionEntitySchema,
        CategoryEntitySchema,
        SyncOperationEntitySchema,
      ],
      directory: dir.path,
      name: 'family_chores',
      maxSizeMiB: 64,
    );
  }
}
```

```dart
// lib/app/di/modules/external_module.dart
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

@module
abstract class ExternalModule {
  @preResolve
  @singleton
  Future<SharedPreferences> get sharedPreferences =>
      SharedPreferences.getInstance();

  @singleton
  Uuid get uuid => const Uuid();
}
```

### 5.3 Service Registration Convention

All services, repositories, and data sources use injectable annotations:

```dart
// Domain layer: abstract interface
abstract class TaskRepository {
  Future<Result<List<Task>>> getTasksForMember(String memberId);
}

// Data layer: concrete implementation
@LazySingleton(as: TaskRepository)
class TaskRepositoryImpl implements TaskRepository {
  final TaskLocalDatasource _localDatasource;
  final SyncEngine _syncEngine;

  TaskRepositoryImpl(this._localDatasource, this._syncEngine);

  @override
  Future<Result<List<Task>>> getTasksForMember(String memberId) {
    // Implementation reads from local Drift only
  }
}
```

### 5.4 Test Environment Override

For tests, register mock implementations:

```dart
// test/helpers/test_helpers.dart
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

final getIt = GetIt.instance;

class MockTaskRepository extends Mock implements TaskRepository {}

void setupTestDependencies() {
  getIt.reset();
  getIt.registerSingleton<TaskRepository>(MockTaskRepository());
  // Register other mocks...
}
```

### 5.5 App Initialization

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'app/di/injection.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize DI container
  await configureDependencies(Env.prod);

  runApp(const FamilyChoresApp());
}
```

```dart
// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../shared/theme/app_theme.dart';
import 'router/app_router.dart';

class FamilyChoresApp extends StatelessWidget {
  const FamilyChoresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Family Chores',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        // i18n delegates will be added here
      ],
    );
  }
}
```

---

## 6. Static Analysis Configuration

### 6.1 analysis_options.yaml

```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    invalid_annotation_target: ignore  # For freezed/injectable
    missing_required_param: error
    missing_return: error
    todo: info
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/*.config.dart"
    - "lib/generated/**"
    - "test/.test_coverage.dart"

linter:
  rules:
    # Enforced beyond very_good_analysis defaults
    avoid_dynamic_calls: true
    avoid_type_to_string: true
    cancel_subscriptions: true
    close_sinks: true
    literal_only_boolean_expressions: true
    no_adjacent_strings_in_list: true
    prefer_single_quotes: true
    require_trailing_commas: true
    sort_constructors_first: true
    sort_unnamed_constructors_first: true
    unawaited_futures: true
    unnecessary_await_in_return: true
    unnecessary_statements: true
    use_if_null_to_convert_nulls: true

    # Relaxed for Flutter widgets (which often exceed 200 lines)
    # But enforced for non-widget code via code review
    lines_longer_than_80_chars: false
```

### 6.2 Rationale for Key Rules

| Rule | Rationale |
|------|-----------|
| `strict-casts: true` | Equivalent to TypeScript `strict`. No implicit downcasts. |
| `strict-inference: true` | Forces explicit types where Dart cannot infer. Prevents `dynamic`. |
| `strict-raw-types: true` | No raw generic types like `List` without type parameter. |
| `avoid_dynamic_calls: true` | Direct enforcement of "no `dynamic`" from development rules. |
| `require_trailing_commas: true` | Consistent formatting, cleaner diffs. |
| `unawaited_futures: true` | Prevents accidentally dropping futures -- critical for sync operations. |
| `cancel_subscriptions: true` | Prevents memory leaks from stream subscriptions in BLoCs. |

---

## 7. Build Runner Configuration

### 7.1 build.yaml

```yaml
targets:
  $default:
    builders:
      injectable_generator|injectable_builder:
        generate_for:
          - lib/**
      drift_dev:
        generate_for:
          - lib/features/**/models/**
          - lib/core/sync/**
      freezed|freezed:
        generate_for:
          - lib/features/**/entities/**
          - lib/features/**/models/**
          - lib/core/**
      json_serializable:
        generate_for:
          - lib/features/**/models/**
```

### 7.2 Code Generation Commands

```bash
# Full build (clean)
dart run build_runner build --delete-conflicting-outputs

# Watch mode during development
dart run build_runner watch --delete-conflicting-outputs

# Clean generated files
dart run build_runner clean
```

---

## 8. Dart Naming Conventions

Adapted from `docs/development-rules.md` Section 4.1 to Dart conventions:

| Element | Convention | Example |
|---------|-----------|---------|
| Files | `snake_case` | `task_repository.dart`, `sync_engine.dart` |
| Classes / Enums | `PascalCase` | `TaskRepository`, `SyncStatus` |
| Abstract classes (interfaces) | `PascalCase` (no `I` prefix) | `TaskRepository` (not `ITaskRepository`) |
| Implementations | `PascalCase` with `Impl` suffix | `TaskRepositoryImpl` |
| Functions / Methods | `camelCase`, verb-first | `getTasksForMember()`, `resolveConflict()` |
| Variables | `camelCase`, descriptive noun | `assignedMember`, `overdueCount` |
| Constants (top-level) | `camelCase` | `maxRetryCount`, `syncIntervalSeconds` |
| Private fields | `_camelCase` (underscore prefix) | `_repository`, `_syncEngine` |
| Boolean variables | `is/has/should/can` prefix | `isCompleted`, `hasReward`, `canSync` |
| Enum values | `camelCase` | `SyncStatus.pending`, `TaskStatus.inProgress` |
| Type parameters | Single uppercase letter or `PascalCase` | `T`, `State`, `Event` |
| Extensions | `PascalCase` + `Extension` | `DateTimeExtension` |
| Mixins | `PascalCase` + `Mixin` | `ConnectivityAwareMixin` |
| Test files | `snake_case_test.dart` | `sync_engine_test.dart` |
| Test groups | `group('ClassName')` > `group('methodName')` > `test('should behavior')` | See testing spec |

### 8.1 File Organization Rules

Adapted from development-rules.md Section 6.1:

- One class per file (excepting small, tightly-coupled helper classes).
- File name matches the primary class: `sync_engine.dart` exports `SyncEngine`.
- Test files mirror the source path: `test/unit/core/sync/sync_engine_test.dart` tests `lib/core/sync/sync_engine.dart`.
- No circular imports. Extract shared dependencies into a separate file if two modules need each other.
- Maximum ~200 lines per file. If exceeded, split following SRP.

---

## 9. Pre-Commit Hooks

### 9.1 Setup

The project uses a shell-based pre-commit hook (no external hook manager to minimize dependencies):

```bash
#!/bin/sh
# .git/hooks/pre-commit

echo "Running pre-commit checks..."

# 1. Format check
echo "Checking formatting..."
dart format --set-exit-if-changed lib/ test/
if [ $? -ne 0 ]; then
  echo "ERROR: Code is not formatted. Run 'dart format lib/ test/' to fix."
  exit 1
fi

# 2. Static analysis
echo "Running analysis..."
dart analyze --fatal-infos
if [ $? -ne 0 ]; then
  echo "ERROR: Static analysis found issues. Fix them before committing."
  exit 1
fi

# 3. Run unit tests
echo "Running unit tests..."
flutter test test/unit/ --no-pub
if [ $? -ne 0 ]; then
  echo "ERROR: Unit tests failed. Fix them before committing."
  exit 1
fi

echo "All pre-commit checks passed."
```

### 9.2 Hook Installation

A setup script installs the hook:

```bash
#!/bin/sh
# scripts/setup_hooks.sh
cp scripts/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
echo "Pre-commit hook installed."
```

---

## 10. Environment & Configuration

### 10.1 .gitignore (additions to Flutter default)

```gitignore
# Environment
.env
.env.local
.env.staging
.env.production

# Firebase
google-services.json
GoogleService-Info.plist
firebase_options.dart
firebase_app_id_file.json

# Generated files
*.g.dart
*.freezed.dart
*.config.dart
# *.isar.dart  # no longer applicable — Drift uses *.g.dart

# Coverage
coverage/
*.lcov

# IDE
.idea/
.vscode/settings.json
*.iml

# OS
.DS_Store
Thumbs.db
```

### 10.2 .env.example

```bash
# Firebase configuration is managed by flutterfire configure
# No manual API keys needed for Firebase

# Feature flags (for development)
ENABLE_SYNC_LOGGING=false
ENABLE_PERFORMANCE_OVERLAY=false

# Firebase Emulator (for local development)
USE_FIREBASE_EMULATOR=true
EMULATOR_HOST=localhost
FIRESTORE_EMULATOR_PORT=8080
AUTH_EMULATOR_PORT=9099
```

---

## 11. Git Repository Setup

### 11.1 Branch Initialization

```bash
git init
git checkout -b main
git add .
git commit -m "chore: initial project scaffolding"
git checkout -b develop
```

### 11.2 Conventional Commits

Per `docs/development-rules.md` Section 7.2:

| Type | Usage |
|------|-------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code change, no new feature or fix |
| `test` | Adding or updating tests |
| `docs` | Documentation only |
| `chore` | Build, tooling, CI changes |
| `style` | Formatting, no logic change |

Format: `<type>(<scope>): <description>` -- imperative mood, lowercase, max 72 characters, no period.

---

## 12. Impact Analysis

### 12.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| Flutter project root | New | Low | Standard Flutter create output |
| Folder structure | New | Low | Creates directories only, no logic |
| pubspec.yaml | New | Medium | Dependency resolution conflicts possible |
| DI configuration | New | Medium | Must handle async initialization (Drift, SharedPreferences) |
| analysis_options.yaml | New | Low | Stricter than default, may surface issues in generated code |
| build.yaml | New | Low | Code generation targets |
| Pre-commit hooks | New | Low | Shell script, platform-specific |

### 12.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Drift package incompatibility with latest Flutter | Medium | High | Decision gate: verify Drift compatibility at Phase 1 start. Have Drift migration plan ready. |
| Dependency version conflicts between Firebase packages | Medium | Medium | Use BoM-compatible versions. Pin exact versions. Test `flutter pub get` early. |
| injectable + freezed code generation conflicts | Low | Medium | Configure `build.yaml` to scope generators to specific directories. |
| Pre-commit hooks too slow (running all unit tests) | Medium | Low | Scope pre-commit to `test/unit/` only. Run full suite in CI. |
| Very_good_analysis rules conflict with project conventions | Low | Low | Override specific rules in `analysis_options.yaml` with documented rationale. |

---

## 13. Functional Tests

### 13.1 Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| SC-FT-001 | Project compiles | Scaffold is created with all dependencies | `flutter build apk --debug` runs | Build succeeds with zero errors | High |
| SC-FT-002 | DI container resolves | All modules registered | `configureDependencies('test')` called | No resolution errors thrown | High |
| SC-FT-003 | Analysis passes | All scaffold files exist | `dart analyze` runs | Zero errors, zero warnings | High |
| SC-FT-004 | Code generation works | Annotated classes exist | `build_runner build` runs | All `.g.dart` and `.config.dart` files generated | High |
| SC-FT-005 | Example test passes | Test infrastructure set up | `flutter test` runs | At least one test passes | High |
| SC-FT-006 | Pre-commit blocks bad format | Unformatted file staged | `git commit` attempted | Commit rejected with format error | Medium |
| SC-FT-007 | Pre-commit blocks analysis errors | File with `dynamic` usage staged | `git commit` attempted | Commit rejected with analysis error | Medium |

### 13.2 Verification Checklist

After scaffolding is complete, run the following commands. All must succeed:

```bash
flutter pub get                                          # Dependencies resolve
dart run build_runner build --delete-conflicting-outputs  # Code generation
dart analyze                                             # Zero issues
dart format --set-exit-if-changed lib/ test/              # Already formatted
flutter test                                             # Tests pass
flutter build apk --debug                                # Android builds
flutter build ios --debug --no-codesign                  # iOS builds
```

---

## 14. Implementation Recommendations

### 14.1 Suggested Approach

1. Run `flutter create` with the specified org and project name.
2. Replace the generated `pubspec.yaml` with the version specified in Section 3.3.
3. Create the full folder structure from Section 4 with `.gitkeep` files.
4. Add `analysis_options.yaml` and `build.yaml`.
5. Implement `injection.dart` and the DI modules.
6. Implement `main.dart` and `app.dart` with a blank MaterialApp.
7. Set up the pre-commit hook via the setup script.
8. Run `flutter pub get` and resolve any dependency issues.
9. Run `build_runner build` to verify code generation pipeline.
10. Write and run one example test to verify the test infrastructure.
11. Run `dart analyze` to verify static analysis passes.
12. Commit with `chore: initial project scaffolding`.

### 14.2 Estimated Effort

**T-shirt size: S** (1-2 days)

The scaffolding is primarily file creation and configuration. The main complexity is in dependency resolution and DI setup.

### 14.3 Database Decision (Resolved)

**Drift is the chosen local database.** Isar 3.x requires Dart <3.0.0 and is incompatible with this project's Dart 3.11.1 SDK. Drift with SQLite provides equivalent query power, type-safe generated DAOs, and full Dart 3.x compatibility.

Key packages: `drift`, `sqlite3_flutter_libs`, `drift_dev` (code generation).
See `specs/02_isar_schemas.md` for the Drift table definitions.

---

## 15. Open Questions

- [ ] Should `very_good_analysis` be the base lint package, or should we use `flutter_lints` with custom additions? `very_good_analysis` is stricter but well-maintained.
- [ ] Should the pre-commit hook run integration tests or only unit tests? Current recommendation: unit tests only (speed), integration tests in CI.
- [ ] Should we add a Makefile or use `dart run` scripts in `pubspec.yaml` for common commands?

---

*Generated by Software Architect Analyst*
*Date: 2026-03-05*
