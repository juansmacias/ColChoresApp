import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:family_chores_app/core/network/connectivity_service.dart';
import 'package:family_chores_app/core/network/connectivity_status.dart';
import 'package:family_chores_app/core/presentation/base_state.dart';
import 'package:family_chores_app/core/presentation/offline_aware_cubit.dart';
import 'package:family_chores_app/core/sync/sync_engine.dart';
import 'package:family_chores_app/core/sync/sync_event.dart';
import 'package:family_chores_app/core/sync/sync_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockSyncEngine extends Mock implements SyncEngine {}

class TestOfflineAwareCubit extends OfflineAwareCubit<BaseState> {
  TestOfflineAwareCubit({
    required ConnectivityService connectivityService,
    required SyncEngine syncEngine,
  }) : super(
          const LoadedState<List<String>>(
            data: ['task-1'],
          ),
        ) {
    initialize(
      connectivityService: connectivityService,
      syncEngine: syncEngine,
    );
  }

  int refreshCount = 0;

  @override
  Set<String>? get relevantEntityTypes => {'task'};

  @override
  void onConnectivityChanged(ConnectivityStatus status) {
    final current = state;
    if (current is LoadedState<List<String>>) {
      emit(
        current.copyWith(
          isOffline: status == ConnectivityStatus.offline,
        ),
      );
    }
  }

  @override
  void onSyncCompleted(SyncEvent event) {
    refreshCount++;
    final current = state;
    if (current is LoadedState<List<String>>) {
      emit(
        current.copyWith(
          data: [...current.data, 'refresh-$refreshCount'],
        ),
      );
    }
  }
}

void main() {
  group('OfflineAwareCubit', () {
    late MockConnectivityService connectivityService;
    late MockSyncEngine syncEngine;
    late StreamController<ConnectivityStatus> connectivityController;
    late StreamController<SyncEvent> syncEventController;

    setUp(() {
      connectivityService = MockConnectivityService();
      syncEngine = MockSyncEngine();
      connectivityController = StreamController<ConnectivityStatus>.broadcast();
      syncEventController = StreamController<SyncEvent>.broadcast();

      when(() => connectivityService.statusStream)
          .thenAnswer((_) => connectivityController.stream);
      when(() => connectivityService.currentStatus)
          .thenReturn(ConnectivityStatus.online);
      when(() => connectivityService.isOnline).thenReturn(true);
      when(() => connectivityService.isOffline).thenReturn(false);
      when(() => syncEngine.eventStream)
          .thenAnswer((_) => syncEventController.stream);
      when(() => syncEngine.stateStream)
          .thenAnswer((_) => const Stream<SyncState>.empty());
      when(() => syncEngine.currentState).thenReturn(const SyncState.idle());
      when(() => syncEngine.pendingOperationCount).thenAnswer((_) async => 0);
    });

    tearDown(() async {
      await connectivityController.close();
      await syncEventController.close();
    });

    blocTest<TestOfflineAwareCubit, BaseState>(
      'emits loaded state with isOffline=true when connectivity goes offline',
      build: () => TestOfflineAwareCubit(
        connectivityService: connectivityService,
        syncEngine: syncEngine,
      ),
      act: (cubit) async {
        connectivityController.add(ConnectivityStatus.offline);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        const LoadedState<List<String>>(
          data: ['task-1'],
          isOffline: true,
        ),
      ],
    );

    blocTest<TestOfflineAwareCubit, BaseState>(
      'ignores sync events for unrelated entity types',
      build: () => TestOfflineAwareCubit(
        connectivityService: connectivityService,
        syncEngine: syncEngine,
      ),
      act: (cubit) async {
        syncEventController.add(
          const SyncEvent.operationCompleted(
            entityType: 'reward',
            entityId: 'reward-1',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 120));
      },
      expect: () => <BaseState>[],
      verify: (cubit) {
        expect(cubit.refreshCount, 0);
      },
    );

    blocTest<TestOfflineAwareCubit, BaseState>(
      'refreshes once for relevant sync events',
      build: () => TestOfflineAwareCubit(
        connectivityService: connectivityService,
        syncEngine: syncEngine,
      ),
      act: (cubit) async {
        syncEventController.add(
          const SyncEvent.operationCompleted(
            entityType: 'task',
            entityId: 'task-1',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 120));
      },
      expect: () => [
        const LoadedState<List<String>>(
          data: ['task-1', 'refresh-1'],
        ),
      ],
      verify: (cubit) {
        expect(cubit.refreshCount, 1);
      },
    );

    test('close cancels listeners and prevents further emissions', () async {
      final cubit = TestOfflineAwareCubit(
        connectivityService: connectivityService,
        syncEngine: syncEngine,
      );

      final emittedStates = <BaseState>[];
      final subscription = cubit.stream.listen(emittedStates.add);

      await cubit.close();

      connectivityController.add(ConnectivityStatus.offline);
      syncEventController.add(
        const SyncEvent.operationCompleted(
          entityType: 'task',
          entityId: 'task-1',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(emittedStates, isEmpty);

      await subscription.cancel();
    });
  });
}
