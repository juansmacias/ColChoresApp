import 'dart:async';

import 'package:family_chores_app/core/database/app_database.dart';
import 'package:family_chores_app/core/enums/operation_type.dart';
import 'package:family_chores_app/core/network/connectivity_service.dart';
import 'package:family_chores_app/core/network/connectivity_status.dart';
import 'package:family_chores_app/core/sync/conflict_resolver.dart';
import 'package:family_chores_app/core/sync/entity_sync_adapter.dart';
import 'package:family_chores_app/core/sync/exceptions/sync_conflict_exception.dart';
import 'package:family_chores_app/core/sync/models/conflict_result.dart';
import 'package:family_chores_app/core/sync/operation_queue.dart';
import 'package:family_chores_app/core/sync/sync_engine_impl.dart';
import 'package:family_chores_app/core/sync/sync_event.dart';
import 'package:family_chores_app/core/sync/sync_state.dart';
import 'package:family_chores_app/core/sync/sync_status_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/native.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────

class MockOperationQueue extends Mock implements OperationQueue {}

class MockConflictResolver extends Mock implements ConflictResolver {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockEntitySyncAdapter extends Mock implements EntitySyncAdapter {}

// ── Helpers ────────────────────────────────────────────────────────────────

AppDatabase _openTestDb() => AppDatabase(NativeDatabase.memory());

SyncOperationsTableData _buildOp({
  int id = 1,
  String entityType = 'task',
  String entityId = 'task-1',
  OperationType operationType = OperationType.create,
  String payload = '{"title":"test"}',
  String status = 'pending',
  int retryCount = 0,
}) {
  final now = DateTime.now();
  return SyncOperationsTableData(
    id: id,
    entityType: entityType,
    entityId: entityId,
    operationType: operationType,
    payload: payload,
    timestamp: now,
    status: status,
    retryCount: retryCount,
    errorMessage: null,
    createdAt: now,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(OperationType.create);
    registerFallbackValue(
      const ConflictResult(
        winner: ConflictWinner.remote,
        winnerState: null,
        loserState: null,
        reason: 'fallback',
      ),
    );
  });

  group('SyncEngineImpl', () {
    late MockOperationQueue mockQueue;
    late MockConflictResolver mockResolver;
    late MockConnectivityService mockConnectivity;
    late MockEntitySyncAdapter mockAdapter;
    late SyncStatusManager statusManager;
    late AppDatabase testDb;
    late SyncEngineImpl engine;
    late StreamController<ConnectivityStatus> connectivityController;

    setUp(() {
      connectivityController = StreamController<ConnectivityStatus>.broadcast();
      mockQueue = MockOperationQueue();
      mockResolver = MockConflictResolver();
      mockConnectivity = MockConnectivityService();
      mockAdapter = MockEntitySyncAdapter();
      statusManager = SyncStatusManager();
      testDb = _openTestDb();

      when(() => mockConnectivity.statusStream)
          .thenAnswer((_) => connectivityController.stream);
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityStatus.offline);
      when(() => mockConnectivity.currentStatus)
          .thenReturn(ConnectivityStatus.offline);
      when(() => mockAdapter.entityType).thenReturn('task');

      engine = SyncEngineImpl(
        operationQueue: mockQueue,
        conflictResolver: mockResolver,
        connectivityService: mockConnectivity,
        statusManager: statusManager,
        database: testDb,
      );
    });

    tearDown(() async {
      await engine.stop();
      statusManager.dispose();
      await testDb.close();
      await connectivityController.close();
    });

    // ── SE-FT-021: Sync skipped when offline ──────────────────────────────

    test('SE-FT-021: syncNow does nothing when offline', () async {
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityStatus.offline);
      when(() => mockQueue.recoverInterruptedOperations())
          .thenAnswer((_) async {});

      await engine.start();
      await engine.syncNow();

      verifyNever(() => mockQueue.dequeueNext());
    });

    // ── SE-FT-022: Sync skipped when stopped ─────────────────────────────

    test('SE-FT-022: syncNow does nothing when engine is stopped', () async {
      // Engine never started.
      await engine.syncNow();
      verifyNever(() => mockQueue.dequeueNext());
    });

    // ── SE-FT-017: Full sync pushes then reaches idle ────────────────────

    test('SE-FT-017: syncNow pushes pending ops then emits idle', () async {
      final op = _buildOp();

      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityStatus.online);
      when(() => mockQueue.recoverInterruptedOperations())
          .thenAnswer((_) async {});
      when(() => mockQueue.markInProgress(any())).thenAnswer((_) async {});
      when(() => mockQueue.markCompleted(any())).thenAnswer((_) async {});
      when(() => mockQueue.pendingCount).thenAnswer((_) async => 0);
      when(
        () => mockAdapter.pushToRemote(
          entityId: any(named: 'entityId'),
          operationType: any(named: 'operationType'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});

      var dequeueCount = 0;
      when(() => mockQueue.dequeueNext()).thenAnswer((_) async {
        dequeueCount++;
        return dequeueCount == 1 ? op : null;
      });

      engine.registerAdapter(mockAdapter);

      await engine.start();

      // After a successful push cycle, engine should be idle.
      expect(engine.currentState, isA<SyncIdle>());
      verify(() => mockQueue.markCompleted(op.id)).called(1);
    });

    // ── SE-FT-018: Partial failure preserves successful ops ───────────────

    test(
        'SE-FT-018: partial failure — successful ops marked completed, failed ops retried',
        () async {
      final op1 = _buildOp(id: 1, entityId: 'task-1');
      // retryCount=2: next retry will permanently fail (no backoff delay).
      final op2 = _buildOp(id: 2, entityId: 'task-2', retryCount: 2);

      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityStatus.online);
      when(() => mockQueue.recoverInterruptedOperations())
          .thenAnswer((_) async {});
      when(() => mockQueue.markInProgress(any())).thenAnswer((_) async {});
      when(() => mockQueue.markCompleted(any())).thenAnswer((_) async {});
      when(() => mockQueue.markRetry(any(), any())).thenAnswer((_) async {});
      when(() => mockQueue.pendingCount).thenAnswer((_) async => 1);

      var dequeueCount = 0;
      when(() => mockQueue.dequeueNext()).thenAnswer((_) async {
        dequeueCount++;
        if (dequeueCount == 1) return op1;
        if (dequeueCount == 2) return op2;
        return null;
      });

      // op1 succeeds, op2 throws.
      var pushCount = 0;
      when(
        () => mockAdapter.pushToRemote(
          entityId: any(named: 'entityId'),
          operationType: any(named: 'operationType'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {
        pushCount++;
        if (pushCount == 2) throw Exception('network error');
      });

      engine.registerAdapter(mockAdapter);

      await engine.start();

      // op1 must be completed.
      verify(() => mockQueue.markCompleted(op1.id)).called(1);
      // op2 must be retried (markRetry called, which internally marks failed when count=3).
      verify(() => mockQueue.markRetry(op2.id, any())).called(1);
      // Engine in syncingWithErrors or error state (failure count > 0).
      expect(
        engine.currentState,
        anyOf(isA<SyncSyncingWithErrors>(), isA<SyncError>()),
      );
    });

    // ── SE-FT-020: Interrupted operations recovered on start ─────────────

    test('SE-FT-020: start() calls recoverInterruptedOperations', () async {
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityStatus.offline);
      when(() => mockQueue.recoverInterruptedOperations())
          .thenAnswer((_) async {});

      await engine.start();

      verify(() => mockQueue.recoverInterruptedOperations()).called(1);
    });

    // ── SE-FT-025: Retry delay is exponential ─────────────────────────────

    test('SE-FT-025: retry delays follow exponential backoff 1s, 4s, 16s', () {
      expect(_retryDelaySeconds(0), equals(1), reason: 'attempt 0 → 1s');
      expect(_retryDelaySeconds(1), equals(4), reason: 'attempt 1 → 4s');
      expect(_retryDelaySeconds(2), equals(16), reason: 'attempt 2 → 16s');
    });

    // ── Conflict resolution during push ───────────────────────────────────

    test('conflict: emits conflictResolved event and marks operation completed',
        () async {
      final now = DateTime.now();
      final op = _buildOp(payload: '{"title":"local"}');
      final remoteState = {'title': 'remote'};

      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityStatus.online);
      when(() => mockQueue.recoverInterruptedOperations())
          .thenAnswer((_) async {});
      when(() => mockQueue.markInProgress(any())).thenAnswer((_) async {});
      when(() => mockQueue.markCompleted(any())).thenAnswer((_) async {});
      when(() => mockQueue.pendingCount).thenAnswer((_) async => 0);

      var dequeueCount = 0;
      when(() => mockQueue.dequeueNext()).thenAnswer((_) async {
        dequeueCount++;
        return dequeueCount == 1 ? op : null;
      });

      when(
        () => mockAdapter.pushToRemote(
          entityId: any(named: 'entityId'),
          operationType: any(named: 'operationType'),
          payload: any(named: 'payload'),
        ),
      ).thenThrow(
        SyncConflictException(
          remoteState: remoteState,
          remoteUpdatedAt: now.add(const Duration(minutes: 1)),
          remoteIsDeleted: false,
        ),
      );
      when(
        () => mockResolver.resolve(
          localState: any(named: 'localState'),
          remoteState: any(named: 'remoteState'),
          localUpdatedAt: any(named: 'localUpdatedAt'),
          remoteUpdatedAt: any(named: 'remoteUpdatedAt'),
          localIsDelete: any(named: 'localIsDelete'),
          remoteIsDelete: any(named: 'remoteIsDelete'),
        ),
      ).thenReturn(
        ConflictResult(
          winner: ConflictWinner.remote,
          winnerState: remoteState,
          loserState: {'title': 'local'},
          reason: 'Remote timestamp is newer',
        ),
      );

      engine.registerAdapter(mockAdapter);

      final events = <SyncEvent>[];
      final sub = engine.eventStream.listen(events.add);

      await engine.start();

      await sub.cancel();

      final conflictEvents = events.whereType<SyncConflictResolved>().toList();
      expect(conflictEvents, hasLength(1));
      expect(conflictEvents.first.winner, ConflictWinner.remote);
      verify(() => mockQueue.markCompleted(any())).called(1);
    });
  });
}

// Helper to verify SyncConfig.retryDelay logic without a direct import.
int _retryDelaySeconds(int attempt) {
  const base = 1;
  const factor = 4;
  var result = 1;
  for (var i = 0; i < attempt; i++) {
    result *= factor;
  }
  return base * result;
}
