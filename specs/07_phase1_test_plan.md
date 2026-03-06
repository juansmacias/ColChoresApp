# Phase 1 Test Plan

## 1. Overview

### 1.1 Summary

This specification defines the complete test plan for Phase 1: Foundation of the Family Chores App. It covers unit tests for every component built in Phase 1 (sync engine, connectivity monitor, BLoC foundation, error handling, Isar schemas), integration test strategy, test infrastructure (fixtures, mocks, helpers), and quality targets. Every test scenario traces back to a requirement in the corresponding component spec.

### 1.2 Business Context

The development rules (`docs/development-rules.md`) mandate TDD with 80% minimum line coverage on business logic. Phase 1 components are the foundation the entire app is built on -- the sync engine, error handling, and state management patterns. Defects in these components cascade to every feature. Investing heavily in Phase 1 testing prevents exponential debugging costs in later phases.

### 1.3 Scope

**In scope:**
- Unit tests for: OperationQueue, ConflictResolver, SyncEngine, ConnectivityService, BLoC mixins, Result type, Failure hierarchy, ErrorMessages
- Integration tests for: Isar schema roundtrips, Isar index queries, multi-isolate Isar access
- Test infrastructure: fixtures, mock factories, test helpers
- Coverage targets and enforcement strategy

**Out of scope:**
- E2E tests (Phase 7)
- Firebase emulator tests (Phase 2, when Firestore integration is built)
- UI widget tests (feature-specific, not in Phase 1)
- Cloud Function tests (Phase 2+)

### 1.4 References

- `specs/01_project_scaffolding.md` -- Test directory structure, dev dependencies
- `specs/02_isar_schemas.md` -- Section 12 (Isar test scenarios)
- `specs/03_sync_engine.md` -- Section 8 (Sync engine test scenarios)
- `specs/04_connectivity_monitor.md` -- Section 7 (Connectivity test scenarios)
- `specs/05_bloc_foundation.md` -- Section 9 (BLoC test scenarios)
- `specs/06_error_handling.md` -- Section 9 (Error handling test scenarios)
- `docs/development-rules.md` -- Section 3 (TDD workflow, test types, coverage)

---

## 2. Test Strategy

### 2.1 TDD Workflow

Per `docs/development-rules.md` Section 3.1:

1. **Red:** Write a failing test that defines expected behavior.
2. **Green:** Write the minimum code to make the test pass.
3. **Refactor:** Clean up without changing behavior. Tests stay green.

No code is merged without corresponding tests.

### 2.2 Test Types for Phase 1

| Type | Scope | Runner | Phase 1 Count |
|------|-------|--------|---------------|
| **Unit** | Single class, all dependencies mocked | `flutter test test/unit/` | ~80 tests |
| **Integration** | Isar with real database (in-memory) | `flutter test test/integration/` | ~15 tests |
| **Widget** | N/A for Phase 1 (no UI) | -- | 0 |
| **E2E** | N/A for Phase 1 | -- | 0 |

### 2.3 Test Naming Convention

Adapted from `docs/development-rules.md` Section 3.3 to Dart's `test` package:

```dart
group('ClassName', () {
  group('methodName', () {
    test('should [expected behavior] when [condition]', () {
      // Arrange
      // Act
      // Assert
    });
  });
});
```

### 2.4 Coverage Targets

| Component | Target | Rationale |
|-----------|--------|-----------|
| `lib/core/sync/` | >= 90% | Highest-risk component, every path must be tested |
| `lib/core/error/` | >= 95% | Pure logic, no external dependencies, easy to cover |
| `lib/core/network/` | >= 85% | Some platform-specific behavior is hard to unit test |
| `lib/core/presentation/` | >= 85% | Mixin behavior needs thorough testing |
| `lib/core/utils/` | >= 95% | Pure functions, should be fully testable |
| **Overall Phase 1** | >= 80% | Per NFR-010 of foundation spec |

### 2.5 Coverage Enforcement

```bash
# Run tests with coverage
flutter test --coverage

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Check coverage threshold (CI script)
lcov --summary coverage/lcov.info | grep "lines" | awk '{print $2}' | \
  awk -F'%' '{ if ($1 < 80) exit 1; }'
```

---

## 3. Test Infrastructure

### 3.1 Test Directory Structure

```
test/
+-- unit/
|   +-- core/
|   |   +-- sync/
|   |   |   +-- sync_engine_test.dart
|   |   |   +-- conflict_resolver_test.dart
|   |   |   +-- operation_queue_test.dart
|   |   |   +-- sync_config_test.dart
|   |   +-- network/
|   |   |   +-- connectivity_service_impl_test.dart
|   |   +-- error/
|   |   |   +-- failures_test.dart
|   |   |   +-- error_messages_test.dart
|   |   +-- presentation/
|   |   |   +-- base_state_test.dart
|   |   |   +-- connectivity_aware_mixin_test.dart
|   |   |   +-- sync_aware_mixin_test.dart
|   |   |   +-- offline_aware_cubit_test.dart
|   |   +-- utils/
|   |       +-- result_test.dart
|   |       +-- result_extensions_test.dart
|   +-- features/
|       (empty in Phase 1)
+-- integration/
|   +-- database/
|       +-- isar_schema_test.dart
|       +-- isar_index_test.dart
|       +-- isar_multi_isolate_test.dart
+-- fixtures/
|   +-- task_fixtures.dart
|   +-- member_fixtures.dart
|   +-- family_fixtures.dart
|   +-- sync_operation_fixtures.dart
|   +-- reward_fixtures.dart
+-- helpers/
    +-- test_helpers.dart
    +-- mock_factories.dart
    +-- isar_test_helper.dart
```

### 3.2 Mock Factories

```dart
// test/helpers/mock_factories.dart

import 'package:mocktail/mocktail.dart';

// --- Sync Engine Mocks ---
class MockOperationQueue extends Mock implements OperationQueue {}
class MockConflictResolver extends Mock implements ConflictResolver {}
class MockSyncEngine extends Mock implements SyncEngine {}
class MockEntitySyncAdapter extends Mock implements EntitySyncAdapter {}

// --- Connectivity Mocks ---
class MockConnectivity extends Mock implements Connectivity {}
class MockConnectivityService extends Mock implements ConnectivityService {}

// --- Database Mocks ---
class MockIsar extends Mock implements Isar {}
class MockIsarCollection<T> extends Mock implements IsarCollection<T> {}

// --- Fallback values (required by mocktail for value types) ---
void registerFallbackValues() {
  registerFallbackValue(OperationType.create);
  registerFallbackValue(SyncStatus.pending);
  registerFallbackValue(ConnectivityStatus.online);
  registerFallbackValue(DateTime(2026));
  registerFallbackValue(const SyncState.idle());
}
```

### 3.3 Test Fixtures

```dart
// test/fixtures/task_fixtures.dart

import 'package:family_chores_app/features/tasks/data/models/task_entity.dart';

/// Factory functions for creating test TaskEntity instances.
/// Each factory produces a valid, fully-populated entity.
class TaskFixtures {
  TaskFixtures._();

  static TaskEntity pendingTask({
    String? remoteId,
    String familyId = 'family-1',
    String title = 'Unload dishwasher',
    String assigneeId = 'alex-1',
  }) {
    return TaskEntity()
      ..remoteId = remoteId ?? 'remote-task-1'
      ..familyId = familyId
      ..title = title
      ..description = 'Empty the top and bottom racks'
      ..category = 'Kitchen'
      ..assigneeIds = [assigneeId]
      ..createdBy = 'sofia-1'
      ..dueDate = DateTime(2026, 3, 5, 17, 0)
      ..dueTime = '17:00'
      ..recurrenceRule = null
      ..points = 10
      ..ageGroup = AgeGroup.child
      ..status = TaskStatus.pending
      ..requiresVerification = false
      ..requiresPhoto = false
      ..subtasks = []
      ..completedAt = null
      ..completedBy = null
      ..verifiedAt = null
      ..verifiedBy = null
      ..localPhotoPath = null
      ..photoUrl = null
      ..createdAt = DateTime(2026, 3, 1)
      ..updatedAt = DateTime(2026, 3, 1)
      ..syncStatus = SyncStatus.synced
      ..lastSyncedAt = DateTime(2026, 3, 1);
  }

  static TaskEntity completedTask({
    String? remoteId,
    String familyId = 'family-1',
    DateTime? completedAt,
  }) {
    return pendingTask(remoteId: remoteId, familyId: familyId)
      ..status = TaskStatus.completed
      ..completedAt = completedAt ?? DateTime(2026, 3, 5, 16, 30)
      ..completedBy = 'alex-1';
  }

  static TaskEntity taskWithSubtasks() {
    return pendingTask()
      ..subtasks = [
        SubtaskEmbedded()
          ..title = 'Top rack'
          ..completed = true,
        SubtaskEmbedded()
          ..title = 'Bottom rack'
          ..completed = false,
        SubtaskEmbedded()
          ..title = 'Silverware'
          ..completed = false,
      ];
  }
}
```

```dart
// test/fixtures/sync_operation_fixtures.dart

class SyncOperationFixtures {
  SyncOperationFixtures._();

  static SyncOperationEntity pendingCreate({
    String entityType = 'task',
    String entityId = 'task-1',
    DateTime? createdAt,
  }) {
    return SyncOperationEntity()
      ..entityType = entityType
      ..entityId = entityId
      ..operationType = OperationType.create
      ..payload = '{"title":"Test task","points":10}'
      ..timestamp = createdAt ?? DateTime(2026, 3, 5, 10, 0)
      ..status = 'pending'
      ..retryCount = 0
      ..errorMessage = null
      ..createdAt = createdAt ?? DateTime(2026, 3, 5, 10, 0);
  }

  static SyncOperationEntity failedOperation({
    int retryCount = 3,
    String errorMessage = 'Firestore write failed',
  }) {
    return pendingCreate()
      ..status = 'failed'
      ..retryCount = retryCount
      ..errorMessage = errorMessage;
  }

  static SyncOperationEntity inProgressOperation() {
    return pendingCreate()..status = 'inProgress';
  }
}
```

```dart
// test/fixtures/member_fixtures.dart

class MemberFixtures {
  MemberFixtures._();

  static MemberEntity parentMember({
    String name = 'Sofia',
    String familyId = 'family-1',
  }) {
    return MemberEntity()
      ..remoteId = 'sofia-1'
      ..familyId = familyId
      ..name = name
      ..role = MemberRole.parent
      ..age = 36
      ..avatarUrl = null
      ..accentColor = '#D5C8E6'
      ..userId = 'firebase-uid-sofia'
      ..pinHash = 'sha256-hash'
      ..pinSalt = 'device-salt'
      ..deviceIds = ['device-1']
      ..points = 0
      ..currentStreak = 0
      ..longestStreak = 0
      ..createdAt = DateTime(2026, 3, 1)
      ..updatedAt = DateTime(2026, 3, 1)
      ..syncStatus = SyncStatus.synced
      ..lastSyncedAt = DateTime(2026, 3, 1);
  }

  static MemberEntity childMember({
    String name = 'Alex',
    int age = 10,
    String familyId = 'family-1',
  }) {
    return MemberEntity()
      ..remoteId = 'alex-1'
      ..familyId = familyId
      ..name = name
      ..role = MemberRole.child
      ..age = age
      ..avatarUrl = null
      ..accentColor = '#B5E6C5'
      ..userId = null  // Children don't have Firebase accounts
      ..pinHash = null
      ..pinSalt = null
      ..deviceIds = []
      ..points = 45
      ..currentStreak = 3
      ..longestStreak = 7
      ..createdAt = DateTime(2026, 3, 1)
      ..updatedAt = DateTime(2026, 3, 1)
      ..syncStatus = SyncStatus.synced
      ..lastSyncedAt = DateTime(2026, 3, 1);
  }
}
```

### 3.4 Isar Test Helper

```dart
// test/helpers/isar_test_helper.dart

import 'package:isar/isar.dart';

/// Provides an in-memory Isar instance for integration tests.
/// Each test gets a fresh database.
class IsarTestHelper {
  static int _dbCounter = 0;

  /// Creates a fresh Isar instance for testing.
  /// Uses a unique name per test to prevent interference.
  static Future<Isar> createTestDatabase() async {
    await Isar.initializeIsarCore(download: true);

    final name = 'test_db_${_dbCounter++}';
    return Isar.open(
      [
        FamilyEntitySchema,
        MemberEntitySchema,
        TaskEntitySchema,
        RewardEntitySchema,
        RedemptionEntitySchema,
        CategoryEntitySchema,
        SyncOperationEntitySchema,
      ],
      directory: '',  // In-memory for tests
      name: name,
    );
  }

  /// Closes and cleans up a test database.
  static Future<void> closeTestDatabase(Isar isar) async {
    await isar.close(deleteFromDisk: true);
  }
}
```

---

## 4. Unit Test Specifications

### 4.1 Operation Queue Tests

**File:** `test/unit/core/sync/operation_queue_test.dart`

```dart
void main() {
  group('OperationQueue', () {
    late OperationQueue queue;
    late Isar isar;

    setUp(() async {
      isar = await IsarTestHelper.createTestDatabase();
      queue = OperationQueueImpl(isar);
    });

    tearDown(() async {
      await IsarTestHelper.closeTestDatabase(isar);
    });

    group('enqueue', () {
      test('should create operation with status pending', () async {
        // Arrange
        final op = SyncOperationFixtures.pendingCreate();

        // Act
        await queue.enqueue(op);

        // Assert
        final count = await queue.pendingCount;
        expect(count, equals(1));
      });

      test('should set retryCount to 0', () async {
        final op = SyncOperationFixtures.pendingCreate();
        await queue.enqueue(op);

        final dequeued = await queue.dequeueNext();
        expect(dequeued?.retryCount, equals(0));
      });
    });

    group('dequeueNext', () {
      test('should return oldest pending operation (FIFO)', () async {
        // Arrange
        final op1 = SyncOperationFixtures.pendingCreate(
          entityId: 'task-1',
          createdAt: DateTime(2026, 3, 5, 10, 0),
        );
        final op2 = SyncOperationFixtures.pendingCreate(
          entityId: 'task-2',
          createdAt: DateTime(2026, 3, 5, 10, 5),
        );
        final op3 = SyncOperationFixtures.pendingCreate(
          entityId: 'task-3',
          createdAt: DateTime(2026, 3, 5, 10, 10),
        );

        await queue.enqueue(op1);
        await queue.enqueue(op2);
        await queue.enqueue(op3);

        // Act
        final first = await queue.dequeueNext();

        // Assert
        expect(first?.entityId, equals('task-1'));
      });

      test('should return null when queue is empty', () async {
        final result = await queue.dequeueNext();
        expect(result, isNull);
      });

      test('should skip failed operations', () async {
        final pending = SyncOperationFixtures.pendingCreate(entityId: 'task-2');
        final failed = SyncOperationFixtures.failedOperation();

        await queue.enqueue(failed);
        await queue.enqueue(pending);

        final result = await queue.dequeueNext();
        expect(result?.entityId, equals('task-2'));
      });
    });

    group('markCompleted', () {
      test('should remove operation from pending query', () async {
        final op = SyncOperationFixtures.pendingCreate();
        await queue.enqueue(op);

        final dequeued = await queue.dequeueNext();
        await queue.markCompleted(dequeued!.id);

        expect(await queue.pendingCount, equals(0));
      });
    });

    group('markRetry', () {
      test('should increment retryCount', () async {
        final op = SyncOperationFixtures.pendingCreate();
        await queue.enqueue(op);

        final dequeued = await queue.dequeueNext();
        await queue.markInProgress(dequeued!.id);
        await queue.markRetry(dequeued.id, 'Network error');

        // Re-fetch
        final retried = await queue.dequeueNext();
        expect(retried?.retryCount, equals(1));
        expect(retried?.errorMessage, equals('Network error'));
      });

      test('should mark as failed after max retries', () async {
        final op = SyncOperationFixtures.pendingCreate();
        await queue.enqueue(op);

        // Retry 3 times
        for (int i = 0; i < 3; i++) {
          final dequeued = await queue.dequeueNext();
          if (dequeued == null) break;
          await queue.markInProgress(dequeued.id);
          await queue.markRetry(dequeued.id, 'Error attempt $i');
        }

        // Should now be in failed state
        final failed = await queue.getFailedOperations();
        expect(failed.length, equals(1));
        expect(failed.first.retryCount, equals(3));
      });
    });

    group('capacity', () {
      test('should report at capacity when queue reaches limit', () async {
        // This is a conceptual test -- in practice, use a lower limit for testing
        // or mock SyncConfig.maxQueueSize
        for (int i = 0; i < SyncConfig.maxQueueSize; i++) {
          await queue.enqueue(
            SyncOperationFixtures.pendingCreate(entityId: 'task-$i'),
          );
        }

        expect(await queue.isAtCapacity, isTrue);
      });
    });

    group('purgeCompleted', () {
      test('should remove only completed operations', () async {
        final op1 = SyncOperationFixtures.pendingCreate(entityId: 'task-1');
        final op2 = SyncOperationFixtures.pendingCreate(entityId: 'task-2');

        await queue.enqueue(op1);
        await queue.enqueue(op2);

        // Complete first
        final dequeued = await queue.dequeueNext();
        await queue.markCompleted(dequeued!.id);

        await queue.purgeCompleted();

        expect(await queue.pendingCount, equals(1));
      });
    });
  });
}
```

### 4.2 Conflict Resolver Tests

**File:** `test/unit/core/sync/conflict_resolver_test.dart`

```dart
void main() {
  group('ConflictResolver', () {
    late ConflictResolver resolver;

    setUp(() {
      resolver = ConflictResolverImpl();
    });

    final localState = {'title': 'Local Title', 'points': 10};
    final remoteState = {'title': 'Remote Title', 'points': 15};

    group('timestamp comparison', () {
      test('should select remote when remote timestamp is newer', () {
        final result = resolver.resolve(
          localState: localState,
          remoteState: remoteState,
          localUpdatedAt: DateTime(2026, 3, 5, 10, 0),
          remoteUpdatedAt: DateTime(2026, 3, 5, 10, 5),
          localIsDelete: false,
          remoteIsDelete: false,
        );

        expect(result.winner, equals(ConflictWinner.remote));
        expect(result.winnerState, equals(remoteState));
        expect(result.loserState, equals(localState));
      });

      test('should select local when local timestamp is newer', () {
        final result = resolver.resolve(
          localState: localState,
          remoteState: remoteState,
          localUpdatedAt: DateTime(2026, 3, 5, 10, 5),
          remoteUpdatedAt: DateTime(2026, 3, 5, 10, 0),
          localIsDelete: false,
          remoteIsDelete: false,
        );

        expect(result.winner, equals(ConflictWinner.local));
        expect(result.winnerState, equals(localState));
        expect(result.loserState, equals(remoteState));
      });

      test('should select remote on timestamp tie (server authoritative)', () {
        final timestamp = DateTime(2026, 3, 5, 10, 0);

        final result = resolver.resolve(
          localState: localState,
          remoteState: remoteState,
          localUpdatedAt: timestamp,
          remoteUpdatedAt: timestamp,
          localIsDelete: false,
          remoteIsDelete: false,
        );

        expect(result.winner, equals(ConflictWinner.remote));
        expect(result.reason, contains('server is authoritative'));
      });
    });

    group('delete conflicts', () {
      test('should select local delete over remote edit', () {
        final result = resolver.resolve(
          localState: localState,
          remoteState: remoteState,
          localUpdatedAt: DateTime(2026, 3, 5, 10, 0),
          remoteUpdatedAt: DateTime(2026, 3, 5, 10, 5),
          localIsDelete: true,
          remoteIsDelete: false,
        );

        expect(result.winner, equals(ConflictWinner.local));
        expect(result.winnerState, isNull); // Delete = no state
        expect(result.loserState, equals(remoteState));
      });

      test('should select remote delete over local edit', () {
        final result = resolver.resolve(
          localState: localState,
          remoteState: remoteState,
          localUpdatedAt: DateTime(2026, 3, 5, 10, 5),
          remoteUpdatedAt: DateTime(2026, 3, 5, 10, 0),
          localIsDelete: false,
          remoteIsDelete: true,
        );

        expect(result.winner, equals(ConflictWinner.remote));
        expect(result.winnerState, isNull);
        expect(result.loserState, equals(localState));
      });

      test('should handle both deletes as no conflict', () {
        final result = resolver.resolve(
          localState: localState,
          remoteState: remoteState,
          localUpdatedAt: DateTime(2026, 3, 5, 10, 0),
          remoteUpdatedAt: DateTime(2026, 3, 5, 10, 5),
          localIsDelete: true,
          remoteIsDelete: true,
        );

        expect(result.winner, equals(ConflictWinner.remote));
        expect(result.loserState, isNull);
      });

      test('should delete win regardless of timestamps', () {
        // Local deletes at T1, remote edits at T2 (T2 > T1)
        // Delete should still win
        final result = resolver.resolve(
          localState: localState,
          remoteState: remoteState,
          localUpdatedAt: DateTime(2026, 3, 5, 10, 0), // Earlier
          remoteUpdatedAt: DateTime(2026, 3, 5, 10, 5), // Later
          localIsDelete: true,
          remoteIsDelete: false,
        );

        expect(result.winner, equals(ConflictWinner.local));
      });
    });
  });
}
```

### 4.3 Sync Engine Orchestrator Tests

**File:** `test/unit/core/sync/sync_engine_test.dart`

Key test scenarios (abbreviated, using `blocTest`-style expectations):

```dart
void main() {
  group('SyncEngine', () {
    late MockOperationQueue operationQueue;
    late MockConflictResolver conflictResolver;
    late FakeConnectivityService connectivityService;
    late SyncEngine engine;

    setUp(() {
      operationQueue = MockOperationQueue();
      conflictResolver = MockConflictResolver();
      connectivityService = FakeConnectivityService();
      // ... engine initialization
    });

    group('syncNow', () {
      test('should process all pending operations in order', () async {
        // Arrange: 3 pending operations
        when(() => operationQueue.dequeueNext())
            .thenAnswer((_) async => op1) // first call
            .thenAnswer((_) async => op2) // second call
            .thenAnswer((_) async => op3) // third call
            .thenAnswer((_) async => null); // empty

        // Act
        await engine.syncNow();

        // Assert: all 3 marked completed
        verify(() => operationQueue.markCompleted(op1.id)).called(1);
        verify(() => operationQueue.markCompleted(op2.id)).called(1);
        verify(() => operationQueue.markCompleted(op3.id)).called(1);
      });

      test('should skip sync when offline', () async {
        connectivityService.goOffline();

        await engine.syncNow();

        verifyNever(() => operationQueue.dequeueNext());
      });

      test('should skip sync when engine is stopped', () async {
        await engine.stop();

        await engine.syncNow();

        verifyNever(() => operationQueue.dequeueNext());
      });
    });

    group('partial failure', () {
      test('should mark successful ops completed and failed ops as retry',
          () async {
        // Arrange: op1 succeeds, op2 fails, op3 succeeds
        when(() => operationQueue.dequeueNext())
            .thenAnswer((_) async => op1)
            .thenAnswer((_) async => op2)
            .thenAnswer((_) async => op3)
            .thenAnswer((_) async => null);

        // op2 adapter throws
        when(() => adapter.pushToRemote(
              entityId: op2.entityId,
              operationType: any(named: 'operationType'),
              payload: any(named: 'payload'),
            )).thenThrow(SyncException(message: 'Firestore write failed'));

        // Act
        await engine.syncNow();

        // Assert
        verify(() => operationQueue.markCompleted(op1.id)).called(1);
        verify(() => operationQueue.markRetry(op2.id, any())).called(1);
        verify(() => operationQueue.markCompleted(op3.id)).called(1);
      });
    });

    group('connectivity loss mid-sync', () {
      test('should stop processing when connectivity drops', () async {
        when(() => operationQueue.dequeueNext())
            .thenAnswer((_) async => op1)
            .thenAnswer((_) async => op2)
            .thenAnswer((_) async => op3)
            .thenAnswer((_) async => null);

        // Go offline after first operation completes
        var callCount = 0;
        when(() => operationQueue.markCompleted(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) connectivityService.goOffline();
        });

        await engine.syncNow();

        // Only first op should be completed
        verify(() => operationQueue.markCompleted(op1.id)).called(1);
        verifyNever(() => operationQueue.markCompleted(op2.id));
      });
    });

    group('recovery', () {
      test('should reset inProgress operations to pending on start',
          () async {
        when(() => operationQueue.dequeueNext())
            .thenAnswer((_) async => null);

        // Simulate interrupted operation
        // Engine start should recover it
        await engine.start();

        // Verify recovery logic ran
        // (Implementation-specific verification)
      });
    });

    group('state stream', () {
      test('should emit syncing then idle on successful sync', () async {
        when(() => operationQueue.dequeueNext())
            .thenAnswer((_) async => op1)
            .thenAnswer((_) async => null);

        // Act & Assert via stream
        expectLater(
          engine.stateStream,
          emitsInOrder([
            isA<SyncSyncing>(),
            isA<SyncIdle>(),
          ]),
        );

        await engine.syncNow();
      });

      test('should emit syncingWithErrors on partial failure', () async {
        // ... setup with partial failure ...

        expectLater(
          engine.stateStream,
          emitsInOrder([
            isA<SyncSyncing>(),
            isA<SyncSyncingWithErrors>(),
          ]),
        );

        await engine.syncNow();
      });
    });
  });
}
```

### 4.4 Connectivity Service Tests

**File:** `test/unit/core/network/connectivity_service_impl_test.dart`

```dart
void main() {
  group('ConnectivityServiceImpl', () {
    late MockConnectivity mockConnectivity;
    late ConnectivityServiceImpl service;
    late StreamController<List<ConnectivityResult>> connectivityController;

    setUp(() {
      mockConnectivity = MockConnectivity();
      connectivityController =
          StreamController<List<ConnectivityResult>>.broadcast();

      when(() => mockConnectivity.onConnectivityChanged)
          .thenAnswer((_) => connectivityController.stream);
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);

      service = ConnectivityServiceImpl(connectivity: mockConnectivity);
    });

    tearDown(() {
      service.dispose();
      connectivityController.close();
    });

    test('should start with initial connectivity check', () async {
      // Allow initial check to complete
      await Future<void>.delayed(Duration.zero);

      // Note: reachability check may make this async
      // In test, DNS lookup is not available -- mock or skip reachability
    });

    test('should emit offline when connection is lost', () async {
      expectLater(
        service.statusStream,
        emitsInOrder([
          ConnectivityStatus.online,   // Initial
          ConnectivityStatus.offline,  // After disconnect
        ]),
      );

      connectivityController.add([ConnectivityResult.none]);

      // Wait for debounce
      await Future<void>.delayed(const Duration(seconds: 3));
    });

    test('should debounce rapid changes', () async {
      final emissions = <ConnectivityStatus>[];
      service.statusStream.listen(emissions.add);

      // Rapid changes within 2 seconds
      connectivityController.add([ConnectivityResult.none]);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      connectivityController.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      connectivityController.add([ConnectivityResult.none]);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      connectivityController.add([ConnectivityResult.wifi]);

      // Wait for debounce to settle
      await Future<void>.delayed(const Duration(seconds: 3));

      // Should have limited emissions due to debounce
      // Exact count depends on timing, but should be < 4
    });

    test('should not emit duplicate states', () async {
      final emissions = <ConnectivityStatus>[];
      service.statusStream.listen(emissions.add);

      // Two wifi results in a row
      connectivityController.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(seconds: 3));
      connectivityController.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(seconds: 3));

      // Should only emit once (deduplication)
    });
  });
}
```

### 4.5 BLoC Foundation Tests

**File:** `test/unit/core/presentation/connectivity_aware_mixin_test.dart`

```dart
// Test cubit that uses the mixin
class TestCubit extends Cubit<BaseState> with ConnectivityAwareMixin {
  TestCubit(ConnectivityService connectivityService)
      : super(const InitialState()) {
    initConnectivityListener(connectivityService);
  }

  @override
  void onConnectivityChanged(ConnectivityStatus status) {
    if (state is LoadedState<String>) {
      emit(LoadedState<String>(
        data: (state as LoadedState<String>).data,
        isOffline: status == ConnectivityStatus.offline,
      ));
    }
  }

  void loadData() {
    emit(const LoadedState<String>(data: 'test data'));
  }

  @override
  Future<void> close() {
    disposeConnectivityListener();
    return super.close();
  }
}

void main() {
  group('ConnectivityAwareMixin', () {
    late FakeConnectivityService connectivityService;

    setUp(() {
      connectivityService = FakeConnectivityService();
    });

    tearDown(() {
      connectivityService.dispose();
    });

    blocTest<TestCubit, BaseState>(
      'should update isOffline when going offline',
      build: () => TestCubit(connectivityService),
      seed: () => const LoadedState<String>(data: 'test data'),
      act: (cubit) => connectivityService.goOffline(),
      expect: () => [
        const LoadedState<String>(data: 'test data', isOffline: true),
      ],
    );

    blocTest<TestCubit, BaseState>(
      'should update isOffline when coming online',
      build: () => TestCubit(connectivityService),
      seed: () => const LoadedState<String>(data: 'test data', isOffline: true),
      act: (cubit) => connectivityService.goOnline(),
      expect: () => [
        const LoadedState<String>(data: 'test data', isOffline: false),
      ],
    );

    test('should report isOnline correctly', () {
      final cubit = TestCubit(connectivityService);
      expect(cubit.isOnline, isTrue);

      connectivityService.goOffline();
      expect(cubit.isOffline, isTrue);

      cubit.close();
    });
  });
}
```

### 4.6 Result and Failure Tests

**File:** `test/unit/core/utils/result_test.dart`

```dart
void main() {
  group('Result', () {
    group('success', () {
      test('should carry value', () {
        const result = Result<int>.success(42);
        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
        expect(result.valueOrNull, equals(42));
        expect(result.failureOrNull, isNull);
      });

      test('should execute success branch in when()', () {
        const result = Result<int>.success(42);
        final output = result.when(
          success: (v) => 'value: $v',
          failure: (f) => 'error: ${f.message}',
        );
        expect(output, equals('value: 42'));
      });
    });

    group('failure', () {
      test('should carry failure', () {
        const failure = DatabaseFailure(message: 'write error');
        const result = Result<int>.failure(failure);
        expect(result.isSuccess, isFalse);
        expect(result.isFailure, isTrue);
        expect(result.valueOrNull, isNull);
        expect(result.failureOrNull, isA<DatabaseFailure>());
      });

      test('should execute failure branch in when()', () {
        const failure = DatabaseFailure(message: 'write error');
        const result = Result<int>.failure(failure);
        final output = result.when(
          success: (v) => 'value: $v',
          failure: (f) => 'error: ${f.message}',
        );
        expect(output, equals('error: write error'));
      });
    });

    group('map', () {
      test('should transform success value', () {
        const result = Result<int>.success(21);
        final mapped = result.map((v) => v * 2);
        expect(mapped.valueOrNull, equals(42));
      });

      test('should pass through failure', () {
        const failure = DatabaseFailure(message: 'err');
        const result = Result<int>.failure(failure);
        final mapped = result.map((v) => v * 2);
        expect(mapped.isFailure, isTrue);
        expect(mapped.failureOrNull?.message, equals('err'));
      });
    });

    group('getOrElse', () {
      test('should return value on success', () {
        const result = Result<int>.success(42);
        expect(result.getOrElse(() => 0), equals(42));
      });

      test('should return default on failure', () {
        const failure = DatabaseFailure(message: 'err');
        const result = Result<int>.failure(failure);
        expect(result.getOrElse(() => 0), equals(0));
      });
    });

    group('getOrThrow', () {
      test('should return value on success', () {
        const result = Result<int>.success(42);
        expect(result.getOrThrow(), equals(42));
      });

      test('should throw StateError on failure', () {
        const failure = DatabaseFailure(message: 'err');
        const result = Result<int>.failure(failure);
        expect(() => result.getOrThrow(), throwsA(isA<StateError>()));
      });
    });
  });
}
```

---

## 5. Integration Tests

### 5.1 Isar Schema Integration Tests

**File:** `test/integration/database/isar_schema_test.dart`

```dart
void main() {
  group('Isar Schema Integration', () {
    late Isar isar;

    setUp(() async {
      isar = await IsarTestHelper.createTestDatabase();
    });

    tearDown(() async {
      await IsarTestHelper.closeTestDatabase(isar);
    });

    test('should open database with all 7 collections', () {
      expect(isar.isOpen, isTrue);
      expect(isar.taskEntitys, isNotNull);
      expect(isar.memberEntitys, isNotNull);
      expect(isar.familyEntitys, isNotNull);
      expect(isar.rewardEntitys, isNotNull);
      expect(isar.redemptionEntitys, isNotNull);
      expect(isar.categoryEntitys, isNotNull);
      expect(isar.syncOperationEntitys, isNotNull);
    });

    group('TaskEntity', () {
      test('should write and read with all fields', () async {
        final task = TaskFixtures.pendingTask();

        await isar.writeTxn(() async {
          await isar.taskEntitys.put(task);
        });

        final read = await isar.taskEntitys.get(task.id);
        expect(read, isNotNull);
        expect(read!.title, equals('Unload dishwasher'));
        expect(read.status, equals(TaskStatus.pending));
        expect(read.syncStatus, equals(SyncStatus.synced));
        expect(read.assigneeIds, contains('alex-1'));
      });

      test('should roundtrip embedded subtasks', () async {
        final task = TaskFixtures.taskWithSubtasks();

        await isar.writeTxn(() async {
          await isar.taskEntitys.put(task);
        });

        final read = await isar.taskEntitys.get(task.id);
        expect(read!.subtasks.length, equals(3));
        expect(read.subtasks[0].title, equals('Top rack'));
        expect(read.subtasks[0].completed, isTrue);
        expect(read.subtasks[1].title, equals('Bottom rack'));
        expect(read.subtasks[1].completed, isFalse);
      });

      test('should enforce unique remoteId', () async {
        final task1 = TaskFixtures.pendingTask(remoteId: 'same-id');
        final task2 = TaskFixtures.pendingTask(remoteId: 'same-id');

        await isar.writeTxn(() async {
          await isar.taskEntitys.put(task1);
        });

        expect(
          () => isar.writeTxn(() async {
            await isar.taskEntitys.put(task2);
          }),
          throwsA(isA<IsarError>()),
        );
      });
    });

    group('SyncOperationEntity', () {
      test('should query pending operations in FIFO order', () async {
        final op1 = SyncOperationFixtures.pendingCreate(
          entityId: 'task-1',
          createdAt: DateTime(2026, 3, 5, 10, 0),
        );
        final op2 = SyncOperationFixtures.pendingCreate(
          entityId: 'task-2',
          createdAt: DateTime(2026, 3, 5, 10, 5),
        );
        final op3 = SyncOperationFixtures.pendingCreate(
          entityId: 'task-3',
          createdAt: DateTime(2026, 3, 5, 10, 10),
        );

        await isar.writeTxn(() async {
          await isar.syncOperationEntitys.putAll([op3, op1, op2]);
        });

        final pending = await isar.syncOperationEntitys
            .where()
            .statusCreatedAtEqualTo('pending')
            .sortByCreatedAt()
            .findAll();

        expect(pending.length, equals(3));
        expect(pending[0].entityId, equals('task-1'));
        expect(pending[1].entityId, equals('task-2'));
        expect(pending[2].entityId, equals('task-3'));
      });
    });

    // Additional index query tests for all composite indexes...
  });
}
```

### 5.2 Isar Index Query Tests

**File:** `test/integration/database/isar_index_test.dart`

```dart
void main() {
  group('Isar Index Queries', () {
    late Isar isar;

    setUp(() async {
      isar = await IsarTestHelper.createTestDatabase();
      await _seedTestData(isar);
    });

    tearDown(() async {
      await IsarTestHelper.closeTestDatabase(isar);
    });

    test('familyId_status_dueDate index: pending tasks by due date', () async {
      final results = await isar.taskEntitys
          .where()
          .familyIdStatusDueDateEqualTo('family-1', TaskStatus.pending.name)
          .sortByDueDate()
          .findAll();

      expect(results, isNotEmpty);
      expect(results.every((t) => t.familyId == 'family-1'), isTrue);
      expect(results.every((t) => t.status == TaskStatus.pending), isTrue);
      // Verify sorted by dueDate
      for (int i = 1; i < results.length; i++) {
        expect(
          results[i].dueDate!.isAfter(results[i - 1].dueDate!) ||
              results[i].dueDate == results[i - 1].dueDate,
          isTrue,
        );
      }
    });

    test('familyId_completedAt index: completed tasks in date range', () async {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final results = await isar.taskEntitys
          .where()
          .familyIdCompletedAtBetween('family-1', weekAgo, DateTime.now())
          .findAll();

      expect(results, isNotEmpty);
      expect(results.every((t) => t.familyId == 'family-1'), isTrue);
      expect(
        results.every(
          (t) => t.completedAt != null && t.completedAt!.isAfter(weekAgo),
        ),
        isTrue,
      );
    });

    test('assigneeIds index: tasks containing specific member', () async {
      final results = await isar.taskEntitys
          .where()
          .assigneeIdsElementEqualTo('alex-1')
          .findAll();

      expect(results, isNotEmpty);
      expect(
        results.every((t) => t.assigneeIds.contains('alex-1')),
        isTrue,
      );
    });

    test('memberId_redeemedAt index: member redemption history', () async {
      final results = await isar.redemptionEntitys
          .where()
          .memberIdRedeemedAtEqualTo('alex-1')
          .sortByRedeemedAtDesc()
          .findAll();

      expect(results, isNotEmpty);
      expect(results.every((r) => r.memberId == 'alex-1'), isTrue);
    });
  });
}

Future<void> _seedTestData(Isar isar) async {
  await isar.writeTxn(() async {
    // Seed 20 tasks across 2 families, various statuses and dates
    // Seed 5 members
    // Seed 10 redemptions
    // ... (comprehensive seed data)
  });
}
```

---

## 6. Test Execution Plan

### 6.1 Execution Order

Tests should be written and executed in this order, matching the implementation order:

| Order | Component | Test File | Dependency |
|-------|-----------|-----------|------------|
| 1 | Result<T> | `result_test.dart` | None |
| 2 | Failure hierarchy | `failures_test.dart` | None |
| 3 | ErrorMessages | `error_messages_test.dart` | Failures |
| 4 | Isar schemas | `isar_schema_test.dart` | None (integration, real Isar) |
| 5 | Isar indexes | `isar_index_test.dart` | Schemas, fixtures |
| 6 | OperationQueue | `operation_queue_test.dart` | Isar schemas |
| 7 | ConflictResolver | `conflict_resolver_test.dart` | None (pure logic) |
| 8 | SyncConfig | `sync_config_test.dart` | None |
| 9 | SyncEngine | `sync_engine_test.dart` | Queue, Resolver, Connectivity |
| 10 | ConnectivityService | `connectivity_service_impl_test.dart` | connectivity_plus mock |
| 11 | ConnectivityAwareMixin | `connectivity_aware_mixin_test.dart` | FakeConnectivityService |
| 12 | SyncAwareMixin | `sync_aware_mixin_test.dart` | MockSyncEngine |
| 13 | OfflineAwareCubit | `offline_aware_cubit_test.dart` | Both mixin tests |
| 14 | BaseState | `base_state_test.dart` | Equatable |

### 6.2 CI Configuration

```yaml
# .github/workflows/test.yml (conceptual)
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: dart analyze --fatal-infos
      - run: dart format --set-exit-if-changed lib/ test/
      - run: flutter test --coverage
      - name: Check coverage threshold
        run: |
          COVERAGE=$(lcov --summary coverage/lcov.info 2>&1 | grep 'lines' | awk '{print $2}' | tr -d '%')
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "Coverage $COVERAGE% is below 80% threshold"
            exit 1
          fi
```

---

## 7. Test Summary Matrix

All test IDs from component specs, consolidated:

| Source Spec | Test ID Range | Count | Description |
|-------------|--------------|-------|-------------|
| 02_isar_schemas | IS-FT-001 to IS-FT-015 | 15 | Schema roundtrips, indexes, cleanup |
| 03_sync_engine | SE-FT-001 to SE-FT-028 | 28 | Queue, resolver, orchestrator, edge cases |
| 04_connectivity | CM-FT-001 to CM-FT-012 | 12 | Stream behavior, debounce, reachability |
| 05_bloc_foundation | BF-FT-001 to BF-FT-014 | 14 | Mixins, state hierarchy, banner mapping |
| 06_error_handling | EH-FT-001 to EH-FT-016 | 16 | Result, Failure, mapping, messages |
| **Total** | | **85** | |

---

## 8. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Isar in-memory mode behaves differently from file mode | Medium | Medium | Run a subset of tests with file-based Isar in CI |
| Async test timing issues (debounce, backoff) | High | Low | Use `fake_async` package for deterministic time control |
| Mock setup complexity hides real integration bugs | Medium | Medium | Supplement unit tests with integration tests using real Isar |
| Test fixtures drift from actual data patterns | Low | Medium | Validate fixtures against Firestore seed data in Phase 2 |
| Coverage target not met | Medium | Medium | Track coverage per-file, not just aggregate. Fix gaps before merging. |

---

## 9. Open Questions

- [ ] Should we use `fake_async` for all time-dependent tests (debounce, retry backoff), or use real `Future.delayed` with generous timeouts? Recommendation: `fake_async` for determinism.
- [ ] Should integration tests use the Isar in-memory mode or write to a temporary directory? In-memory is faster but may miss file I/O issues.
- [ ] Should we set up a test coverage badge in the README during Phase 1?

---

*Generated by Software Architect Analyst*
*Date: 2026-03-05*
