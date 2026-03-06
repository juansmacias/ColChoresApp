# BLoC Foundation & Offline-Aware State Patterns

## 1. Overview

### 1.1 Summary

This specification defines the base BLoC/Cubit classes, state patterns, and mixins that establish the foundation for all presentation-layer state management in the Family Chores App. The key innovation is the offline-aware pattern: every BLoC/Cubit automatically knows whether the device is online or offline, reacts to sync engine events, and supports the optimistic UI update pattern required by the offline-first architecture.

### 1.2 Business Context

The offline-first design (see `specs/00_project_foundation.md` Section 4.8.3) requires that all write operations update the UI immediately from local state. The user never waits for a server round-trip. If a sync later fails or a conflict is resolved differently, the BLoC must reactively correct the UI. This pattern must be standardized so that every feature team implements it consistently, reducing bugs and cognitive load.

### 1.3 Scope

**In scope:**
- Base state sealed class hierarchy (Initial, Loading, Loaded, Error)
- `ConnectivityAwareMixin` for Cubit/BLoC
- `SyncAwareMixin` for reactive data refresh on sync events
- `OfflineAwareCubit<T>` base class combining both mixins
- Optimistic UI update pattern (codified)
- Error state handling with `Failure` types from `specs/06_error_handling.md`
- Connectivity-to-UI state mapping (banner, indicator logic)

**Out of scope:**
- Feature-specific BLoCs (TaskListBloc, DashboardCubit, etc.) -- implemented in later phases
- Widget-level state management (local ephemeral state in StatefulWidgets)
- Navigation/routing state (managed by go_router)

### 1.4 References

- `specs/00_project_foundation.md` -- Section 4.3 (Architecture Diagram), Section 4.8.3 (Optimistic UI Updates)
- `specs/03_sync_engine.md` -- SyncState, SyncEvent streams
- `specs/04_connectivity_monitor.md` -- ConnectivityService, ConnectivityStatus
- `specs/06_error_handling.md` -- Failure sealed class, Result type
- `docs/development-rules.md` -- TDD, SOLID, Clean Code
- `specs/01_project_scaffolding.md` -- Dependencies: flutter_bloc, equatable, rxdart

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| BF-001 | Base state hierarchy usable by all features | High | Every BLoC/Cubit can express initial, loading, loaded, and error states using the base classes |
| BF-002 | Connectivity awareness via mixin | High | Any Cubit/BLoC using `ConnectivityAwareMixin` automatically emits updated state when connectivity changes |
| BF-003 | Sync awareness via mixin | High | Any Cubit/BLoC using `SyncAwareMixin` re-fetches data when the sync engine completes a relevant sync |
| BF-004 | Optimistic updates codified | High | A documented, testable pattern for immediate local state update, sync enqueue, and conflict correction |
| BF-005 | Error states carry Failure objects | High | Error states include the typed `Failure` from domain layer, enabling feature-specific error UI |
| BF-006 | Loaded state includes offline flag | High | The UI can distinguish between "loaded from cache (offline)" and "loaded and synced (online)" |
| BF-007 | Mixins are composable | Medium | A Cubit can use ConnectivityAwareMixin, SyncAwareMixin, both, or neither |
| BF-008 | Base classes support equatable state comparison | High | State classes extend Equatable for BLoC deduplication (same state not re-emitted) |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| BF-NFR-001 | State emission latency | Time from data change to UI update | < 16ms (within a single frame) |
| BF-NFR-002 | Memory footprint | Subscriptions per mixin | Max 2 active subscriptions (connectivity + sync) |
| BF-NFR-003 | Testability | All state transitions testable | 100% of state transitions coverable with bloc_test |

### 2.3 Assumptions

- `flutter_bloc` v8.1.0+ is used, providing `Cubit<State>` and `Bloc<Event, State>`.
- `equatable` v2.0.0+ provides value equality for state comparison.
- The `ConnectivityService` from `specs/04_connectivity_monitor.md` is registered as a singleton in DI.
- The `SyncEngine` from `specs/03_sync_engine.md` is registered as a singleton in DI.

### 2.4 Constraints

- Mixins must not break the BLoC library's internal state management (no `emit()` calls outside the BLoC/Cubit lifecycle).
- Mixin subscriptions must be cancelled in `close()` to prevent memory leaks.
- Base state classes must be extensible for feature-specific states (e.g., `TaskListLoaded extends Loaded<List<Task>>`).

---

## 3. Base State Hierarchy

### 3.1 Design Rationale

The state hierarchy uses Dart 3 sealed classes rather than Equatable-based inheritance. Sealed classes enable exhaustive pattern matching, which means the compiler enforces that every state variant is handled in the UI layer. This eliminates an entire category of bugs where a new state is added but not rendered.

### 3.2 Core State Definition

```dart
// lib/core/presentation/base_state.dart

import 'package:equatable/equatable.dart';
import '../error/failures.dart';

/// Base state for all BLoC/Cubit state hierarchies.
/// Uses Equatable for value comparison (BLoC deduplication).
///
/// Feature-specific states extend these base types to add
/// domain-specific data and behavior.
sealed class BaseState extends Equatable {
  const BaseState();

  /// Whether the state represents an offline condition.
  /// Defaults to false; overridden by states that carry offline info.
  bool get isOffline => false;

  @override
  List<Object?> get props => [];
}

/// Initial state before any data has been loaded.
/// Used as the starting state for Cubits/BLoCs.
class InitialState extends BaseState {
  const InitialState();
}

/// Data is being loaded (first load or refresh).
/// Optionally carries previously loaded data for skeleton UIs.
class LoadingState<T> extends BaseState {
  /// Previously loaded data, if available (for optimistic UI).
  final T? previousData;

  const LoadingState({this.previousData});

  @override
  List<Object?> get props => [previousData];
}

/// Data has been loaded successfully.
/// Carries the loaded data and metadata about staleness.
class LoadedState<T> extends BaseState {
  /// The loaded data.
  final T data;

  /// Whether this data was served from local cache while offline.
  /// When true, the UI may show a "last synced" indicator.
  @override
  final bool isOffline;

  /// Timestamp of the last successful sync, if known.
  /// Used for "Showing data from last sync: X minutes ago" messages.
  final DateTime? lastSyncedAt;

  const LoadedState({
    required this.data,
    this.isOffline = false,
    this.lastSyncedAt,
  });

  /// Creates a copy with updated fields.
  LoadedState<T> copyWith({
    T? data,
    bool? isOffline,
    DateTime? lastSyncedAt,
  }) {
    return LoadedState<T>(
      data: data ?? this.data,
      isOffline: isOffline ?? this.isOffline,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  @override
  List<Object?> get props => [data, isOffline, lastSyncedAt];
}

/// An error occurred during data loading or processing.
/// Carries the typed Failure from the domain layer.
class ErrorState extends BaseState {
  /// The domain failure that caused the error.
  final Failure failure;

  /// Previously loaded data, if available (to show stale data with error banner).
  final Object? previousData;

  const ErrorState({
    required this.failure,
    this.previousData,
  });

  @override
  List<Object?> get props => [failure, previousData];
}
```

### 3.3 Feature-Specific State Extension Pattern

Features extend the base states to add domain-specific typing:

```dart
// Example: lib/features/tasks/presentation/bloc/task_list_state.dart

sealed class TaskListState extends BaseState {
  const TaskListState();
}

class TaskListInitial extends TaskListState {
  const TaskListInitial();
}

class TaskListLoading extends TaskListState {
  final List<Task>? previousTasks;
  const TaskListLoading({this.previousTasks});

  @override
  List<Object?> get props => [previousTasks];
}

class TaskListLoaded extends TaskListState {
  final List<Task> tasks;
  final String familyId;

  @override
  final bool isOffline;
  final DateTime? lastSyncedAt;

  const TaskListLoaded({
    required this.tasks,
    required this.familyId,
    this.isOffline = false,
    this.lastSyncedAt,
  });

  @override
  List<Object?> get props => [tasks, familyId, isOffline, lastSyncedAt];
}

class TaskListError extends TaskListState {
  final Failure failure;
  final List<Task>? previousTasks;

  const TaskListError({
    required this.failure,
    this.previousTasks,
  });

  @override
  List<Object?> get props => [failure, previousTasks];
}
```

---

## 4. ConnectivityAwareMixin

### 4.1 Purpose

Automatically subscribes to `ConnectivityService.statusStream` and provides a hook for subclasses to react to connectivity changes. When connectivity changes, the mixin calls `onConnectivityChanged()` which the Cubit can override to update its state (e.g., toggle the `isOffline` flag on the current state).

### 4.2 Implementation

```dart
// lib/core/presentation/connectivity_aware_mixin.dart

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../network/connectivity_service.dart';
import '../network/connectivity_status.dart';

/// Mixin for Cubit/BLoC that need to react to connectivity changes.
///
/// Usage:
/// ```dart
/// class MyCubit extends Cubit<MyState> with ConnectivityAwareMixin<MyState> {
///   MyCubit(ConnectivityService connectivityService) : super(MyInitial()) {
///     initConnectivityListener(connectivityService);
///   }
///
///   @override
///   void onConnectivityChanged(ConnectivityStatus status) {
///     // Update state based on connectivity
///   }
///
///   @override
///   Future<void> close() {
///     disposeConnectivityListener();
///     return super.close();
///   }
/// }
/// ```
mixin ConnectivityAwareMixin<State> on BlocBase<State> {
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;
  ConnectivityService? _connectivityService;

  /// Whether the device is currently online.
  bool get isOnline => _connectivityService?.isOnline ?? false;

  /// Whether the device is currently offline.
  bool get isOffline => _connectivityService?.isOffline ?? true;

  /// Call in the constructor to start listening.
  void initConnectivityListener(ConnectivityService connectivityService) {
    _connectivityService = connectivityService;
    _connectivitySubscription = connectivityService.statusStream.listen(
      onConnectivityChanged,
    );
  }

  /// Override to react to connectivity changes.
  /// Called whenever the device transitions between online and offline.
  void onConnectivityChanged(ConnectivityStatus status);

  /// Call in close() to clean up.
  void disposeConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
}
```

---

## 5. SyncAwareMixin

### 5.1 Purpose

Automatically subscribes to `SyncEngine.eventStream` and triggers a data refresh when a sync event relevant to this Cubit's entity type occurs. This ensures the UI always reflects the latest state after sync operations complete, especially after conflict resolution where the winning state might differ from the optimistic local state.

### 5.2 Implementation

```dart
// lib/core/presentation/sync_aware_mixin.dart

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../sync/sync_engine.dart';
import '../sync/sync_event.dart';

/// Mixin for Cubit/BLoC that need to refresh data after sync events.
///
/// Usage:
/// ```dart
/// class TaskListCubit extends Cubit<TaskListState>
///     with SyncAwareMixin<TaskListState> {
///
///   TaskListCubit(SyncEngine syncEngine) : super(TaskListInitial()) {
///     initSyncListener(
///       syncEngine: syncEngine,
///       relevantEntityTypes: {'task'},
///     );
///   }
///
///   @override
///   void onSyncCompleted(SyncEvent event) {
///     // Re-fetch task list from local DB to get updated data
///     loadTasks();
///   }
///
///   @override
///   Future<void> close() {
///     disposeSyncListener();
///     return super.close();
///   }
/// }
/// ```
mixin SyncAwareMixin<State> on BlocBase<State> {
  StreamSubscription<SyncEvent>? _syncSubscription;

  /// Call in the constructor to start listening.
  ///
  /// [relevantEntityTypes] filters events to only those affecting
  /// entity types this Cubit cares about (e.g., {'task'} for TaskListCubit).
  /// If null, all events are forwarded.
  void initSyncListener({
    required SyncEngine syncEngine,
    Set<String>? relevantEntityTypes,
  }) {
    _syncSubscription = syncEngine.eventStream
        .where((event) {
          if (relevantEntityTypes == null) return true;
          return switch (event) {
            SyncOperationCompleted(:final entityType) =>
              relevantEntityTypes.contains(entityType),
            SyncConflictResolved(:final entityType) =>
              relevantEntityTypes.contains(entityType),
            SyncOperationFailed(:final entityType) =>
              relevantEntityTypes.contains(entityType),
            SyncPullError(:final entityType) =>
              relevantEntityTypes.contains(entityType),
            _ => true, // Queue events are always relevant
          };
        })
        .listen(onSyncCompleted);
  }

  /// Override to react to sync events.
  /// Typically re-fetches data from local DB.
  void onSyncCompleted(SyncEvent event);

  /// Call in close() to clean up.
  void disposeSyncListener() {
    _syncSubscription?.cancel();
    _syncSubscription = null;
  }
}
```

---

## 6. OfflineAwareCubit

### 6.1 Purpose

A convenience base class that combines both mixins and provides the standard lifecycle management. Feature Cubits that need both connectivity and sync awareness can extend this instead of manually applying both mixins.

### 6.2 Implementation

```dart
// lib/core/presentation/offline_aware_cubit.dart

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../network/connectivity_service.dart';
import '../network/connectivity_status.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_event.dart';
import 'base_state.dart';
import 'connectivity_aware_mixin.dart';
import 'sync_aware_mixin.dart';

/// Base Cubit for features that need offline-aware state management.
///
/// Provides:
/// - Automatic connectivity status tracking
/// - Automatic data refresh on relevant sync events
/// - Standard lifecycle management (subscription cleanup)
///
/// Subclasses must:
/// 1. Call [initialize] in their constructor or init method.
/// 2. Override [onConnectivityChanged] to update state's isOffline flag.
/// 3. Override [onSyncCompleted] to re-fetch data after sync.
/// 4. Override [relevantEntityTypes] to filter sync events.
abstract class OfflineAwareCubit<State extends BaseState>
    extends Cubit<State>
    with ConnectivityAwareMixin<State>, SyncAwareMixin<State> {

  OfflineAwareCubit(super.initialState);

  /// Entity types this Cubit cares about for sync events.
  /// Override in subclasses. Return null to receive all events.
  Set<String>? get relevantEntityTypes;

  /// Call after construction to wire up listeners.
  void initialize({
    required ConnectivityService connectivityService,
    required SyncEngine syncEngine,
  }) {
    initConnectivityListener(connectivityService);
    initSyncListener(
      syncEngine: syncEngine,
      relevantEntityTypes: relevantEntityTypes,
    );
  }

  @override
  Future<void> close() {
    disposeConnectivityListener();
    disposeSyncListener();
    return super.close();
  }
}
```

### 6.3 Usage Example

```dart
// Example: TaskListCubit using OfflineAwareCubit

class TaskListCubit extends OfflineAwareCubit<TaskListState> {
  final GetTasksForMember _getTasksForMember;

  TaskListCubit({
    required GetTasksForMember getTasksForMember,
    required ConnectivityService connectivityService,
    required SyncEngine syncEngine,
  })  : _getTasksForMember = getTasksForMember,
        super(const TaskListInitial()) {
    initialize(
      connectivityService: connectivityService,
      syncEngine: syncEngine,
    );
  }

  @override
  Set<String>? get relevantEntityTypes => {'task'};

  @override
  void onConnectivityChanged(ConnectivityStatus status) {
    final currentState = state;
    if (currentState is TaskListLoaded) {
      emit(currentState.copyWith(
        isOffline: status == ConnectivityStatus.offline,
      ));
    }
  }

  @override
  void onSyncCompleted(SyncEvent event) {
    // Re-fetch from local DB to pick up synced changes
    _refreshTasks();
  }

  Future<void> loadTasks(String memberId) async {
    emit(TaskListLoading(
      previousTasks: state is TaskListLoaded
          ? (state as TaskListLoaded).tasks
          : null,
    ));

    final result = await _getTasksForMember(memberId);

    result.when(
      success: (tasks) => emit(TaskListLoaded(
        tasks: tasks,
        familyId: tasks.isNotEmpty ? tasks.first.familyId : '',
        isOffline: isOffline,
      )),
      failure: (failure) => emit(TaskListError(
        failure: failure,
        previousTasks: state is TaskListLoaded
            ? (state as TaskListLoaded).tasks
            : null,
      )),
    );
  }

  void _refreshTasks() {
    final currentState = state;
    if (currentState is TaskListLoaded) {
      loadTasks(currentState.familyId);
    }
  }
}
```

---

## 7. Optimistic UI Update Pattern

### 7.1 The Pattern

From `specs/00_project_foundation.md` Section 4.8.3, codified as a standard approach:

```
1. User Action
       |
       v
2. Update Local DB (Isar)
       |
       v
3. Emit New State (immediate UI update)
       |
       v
4. Enqueue Sync Operation
       |
       v
5. [If online] Push to Firestore
       |
       +-- Success: Update syncStatus silently
       |
       +-- Conflict: ConflictResolver determines winner
                |
                +-- Local wins: No UI change needed
                |
                +-- Remote wins: Emit corrected state
                                 Show brief notification
```

### 7.2 Code Example: Optimistic Task Completion

```dart
// Inside TaskListCubit:

/// Completes a task optimistically.
/// The UI updates immediately; sync happens in the background.
Future<void> completeTask(String taskId) async {
  final currentState = state;
  if (currentState is! TaskListLoaded) return;

  // Step 1-2: Update local DB and get the updated task
  final result = await _completeTask(taskId);

  result.when(
    success: (updatedTask) {
      // Step 3: Emit new state with the task marked completed
      final updatedTasks = currentState.tasks.map((task) {
        return task.id == taskId ? updatedTask : task;
      }).toList();

      emit(TaskListLoaded(
        tasks: updatedTasks,
        familyId: currentState.familyId,
        isOffline: isOffline,
      ));

      // Step 4: Sync operation was already enqueued by the repository
      // Step 5: SyncEngine handles push. If conflict occurs,
      // SyncAwareMixin.onSyncCompleted() triggers a refresh.
    },
    failure: (failure) {
      // Local write failed (should be rare)
      emit(TaskListError(
        failure: failure,
        previousTasks: currentState.tasks,
      ));
    },
  );
}
```

### 7.3 Conflict Correction Flow

When a sync conflict is resolved and the remote version wins:

1. `SyncEngine` resolves the conflict (remote wins).
2. `SyncEngine` updates the local Isar entity with the remote state.
3. `SyncEngine` emits `SyncEvent.conflictResolved(entityType: 'task', ...)`.
4. `SyncAwareMixin` in `TaskListCubit` receives the event.
5. `onSyncCompleted()` triggers `_refreshTasks()`.
6. Cubit re-reads from Isar (which now has the remote-winning state).
7. New state is emitted with the corrected data.
8. UI updates to show the corrected version.
9. Optionally, a brief SnackBar: "A task was updated by another device."

---

## 8. Connectivity Banner State Mapping

The presentation layer combines `ConnectivityStatus` and `SyncState` to determine the UI indicator:

```dart
// lib/shared/widgets/connectivity_banner_controller.dart

/// Determines what connectivity UI to show based on connectivity + sync state.
///
/// See specs/00_project_foundation.md Section 4.8.1 for the full state table.
class ConnectivityBannerState {
  final ConnectivityBannerType type;
  final String? message;

  const ConnectivityBannerState({
    required this.type,
    this.message,
  });

  factory ConnectivityBannerState.fromStates({
    required ConnectivityStatus connectivity,
    required SyncState syncState,
  }) {
    if (connectivity == ConnectivityStatus.offline) {
      return const ConnectivityBannerState(
        type: ConnectivityBannerType.offline,
        message: "You're offline. Changes will sync when you reconnect.",
      );
    }

    return switch (syncState) {
      SyncIdle() => const ConnectivityBannerState(
          type: ConnectivityBannerType.hidden,
        ),
      SyncSyncing() => const ConnectivityBannerState(
          type: ConnectivityBannerType.syncing,
        ),
      SyncSyncingWithErrors(:final pendingCount) =>
        ConnectivityBannerState(
          type: ConnectivityBannerType.syncError,
          message: '$pendingCount items pending',
        ),
      SyncError(:final message) => ConnectivityBannerState(
          type: ConnectivityBannerType.syncError,
          message: message,
        ),
      SyncStopped() => const ConnectivityBannerState(
          type: ConnectivityBannerType.hidden,
        ),
    };
  }
}

enum ConnectivityBannerType {
  /// No indicator shown (online, synced).
  hidden,

  /// Yellow banner: offline.
  offline,

  /// Animated sync icon: syncing.
  syncing,

  /// Orange dot: sync error with pending items.
  syncError,
}
```

---

## 9. Testing

### 9.1 Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| BF-FT-001 | LoadedState includes isOffline flag | Cubit has loaded data | Connectivity changes to offline | State emitted with isOffline=true | High |
| BF-FT-002 | LoadedState updates on reconnection | Cubit in offline loaded state | Connectivity changes to online | State emitted with isOffline=false | High |
| BF-FT-003 | SyncAwareMixin triggers refresh | Cubit loaded with tasks | SyncEvent.operationCompleted for type "task" emitted | Cubit re-fetches data from local DB | High |
| BF-FT-004 | SyncAwareMixin ignores irrelevant events | Cubit loaded with tasks, relevantEntityTypes={"task"} | SyncEvent for type "reward" emitted | Cubit does NOT re-fetch | Medium |
| BF-FT-005 | Optimistic update shows immediately | User completes a task | completeTask() called | State updates with task completed BEFORE sync | High |
| BF-FT-006 | Conflict correction updates state | Task completed optimistically, sync conflict resolves with remote version | SyncEvent.conflictResolved received | State refreshed with remote-winning data | High |
| BF-FT-007 | ErrorState carries Failure and previous data | Data loaded, then refresh fails | Error occurs during refresh | ErrorState has failure AND previousTasks for stale display | Medium |
| BF-FT-008 | InitialState is default | Cubit created | No actions taken | state == InitialState | High |
| BF-FT-009 | LoadingState carries previous data | Data loaded, then refresh starts | Refresh triggered | LoadingState has previousData for skeleton UI | Medium |
| BF-FT-010 | Mixin cleanup on close | Cubit with both mixins active | cubit.close() called | No further emissions, no memory leaks, subscriptions cancelled | High |
| BF-FT-011 | OfflineAwareCubit integrates both mixins | Cubit extends OfflineAwareCubit | Connectivity changes AND sync event fires | Both handlers execute correctly | High |
| BF-FT-012 | ConnectivityBannerState mapping offline | ConnectivityStatus.offline | Banner state computed | type=offline, message set | Medium |
| BF-FT-013 | ConnectivityBannerState mapping syncing | ConnectivityStatus.online, SyncState.syncing | Banner state computed | type=syncing | Medium |
| BF-FT-014 | ConnectivityBannerState mapping idle | ConnectivityStatus.online, SyncState.idle | Banner state computed | type=hidden | Medium |

### 9.2 Testing Approach

```dart
// Example test using bloc_test:

import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockConnectivityService extends Mock implements ConnectivityService {}
class MockSyncEngine extends Mock implements SyncEngine {}
class MockGetTasksForMember extends Mock implements GetTasksForMember {}

void main() {
  group('TaskListCubit', () {
    late MockConnectivityService connectivityService;
    late MockSyncEngine syncEngine;
    late MockGetTasksForMember getTasksForMember;

    setUp(() {
      connectivityService = MockConnectivityService();
      syncEngine = MockSyncEngine();
      getTasksForMember = MockGetTasksForMember();

      // Default stubs
      when(() => connectivityService.statusStream)
          .thenAnswer((_) => const Stream.empty());
      when(() => connectivityService.isOnline).thenReturn(true);
      when(() => syncEngine.eventStream)
          .thenAnswer((_) => const Stream.empty());
    });

    group('onConnectivityChanged', () {
      blocTest<TaskListCubit, TaskListState>(
        'emits loaded state with isOffline=true when going offline',
        build: () => TaskListCubit(
          getTasksForMember: getTasksForMember,
          connectivityService: connectivityService,
          syncEngine: syncEngine,
        ),
        seed: () => TaskListLoaded(
          tasks: [testTask],
          familyId: 'family1',
        ),
        act: (cubit) => cubit.onConnectivityChanged(
          ConnectivityStatus.offline,
        ),
        expect: () => [
          TaskListLoaded(
            tasks: [testTask],
            familyId: 'family1',
            isOffline: true,
          ),
        ],
      );
    });
  });
}
```

---

## 10. Impact Analysis

### 10.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| BaseState hierarchy | New | Low | Foundation for all feature states |
| ConnectivityAwareMixin | New | Medium | Must correctly manage subscriptions |
| SyncAwareMixin | New | Medium | Must correctly filter events |
| OfflineAwareCubit | New | Low | Convenience composition of mixins |
| ConnectivityBannerState | New | Low | Pure mapping function |
| All feature Cubits (future) | Consumer | Medium | Must correctly extend/use base classes |
| ConnectivityService | Dependency | Low | Already defined in specs/04 |
| SyncEngine | Dependency | Low | Already defined in specs/03 |

### 10.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Mixin subscriptions leak memory | Medium | Medium | `close()` override enforced by lint rule + tests that verify disposal |
| State emission after close() | Medium | Medium | Guard `emit()` calls with `!isClosed` check in mixins |
| Sync event storm causes excessive re-fetches | Low | Medium | Debounce sync event handling with 100ms throttle |
| Feature teams skip mixins | Medium | Low | Document in development rules. Code review checklist. |
| Equatable props mismatch causes missed state updates | Medium | Medium | Unit tests verify state equality semantics for every state class |

---

## 11. Implementation Recommendations

### 11.1 Suggested Approach

1. Define `BaseState` sealed class hierarchy.
2. Write unit tests for state equality (props behavior).
3. Implement `ConnectivityAwareMixin`.
4. Write mixin tests using a simple test Cubit.
5. Implement `SyncAwareMixin`.
6. Write mixin tests with event filtering.
7. Implement `OfflineAwareCubit` composing both mixins.
8. Write integration test combining connectivity + sync + state.
9. Implement `ConnectivityBannerState` mapping.
10. Write mapping tests for all state combinations.

### 11.2 Estimated Effort

**T-shirt size: M** (2-3 days)

The patterns are well-defined. The main effort is in writing comprehensive tests for all state transitions and edge cases.

---

## 12. Open Questions

- [ ] Should the `SyncAwareMixin` debounce rapid sync events (e.g., 10 task operations completing in quick succession) to avoid 10 consecutive re-fetches? Recommendation: yes, throttle at 100ms to batch rapid events.
- [ ] Should the `ErrorState` include a `retryAction` callback so the UI can offer a generic "Retry" button? Or should retry logic be feature-specific?
- [ ] Should we provide a `BlocObserver` subclass that logs all state transitions for debugging? This would be helpful during development but should be disabled in production.

---

*Generated by Software Architect Analyst*
*Date: 2026-03-05*
