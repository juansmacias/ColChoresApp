import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:family_chores_app/core/presentation/base_state.dart';
import 'package:family_chores_app/core/presentation/sync_aware_mixin.dart';
import 'package:family_chores_app/core/sync/sync_engine.dart';
import 'package:family_chores_app/core/sync/sync_event.dart';
import 'package:family_chores_app/core/sync/models/conflict_result.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

class TestSyncCubit extends Cubit<BaseState> with SyncAwareMixin<BaseState> {
  TestSyncCubit({
    required SyncEngine syncEngine,
  }) : super(const LoadedState<int>(data: 0)) {
    initSyncListener(
      syncEngine: syncEngine,
      relevantEntityTypes: relevantEntityTypes,
    );
  }

  int refreshCount = 0;

  Set<String>? get relevantEntityTypes => {'task'};

  @override
  void onSyncCompleted(SyncEvent event) {
    refreshCount++;
    emit(LoadedState<int>(data: refreshCount));
  }

  @override
  Future<void> close() async {
    await disposeSyncListener();
    return super.close();
  }
}

void main() {
  group('SyncAwareMixin', () {
    late MockSyncEngine syncEngine;
    late StreamController<SyncEvent> syncEvents;

    setUp(() {
      syncEngine = MockSyncEngine();
      syncEvents = StreamController<SyncEvent>.broadcast();
      when(() => syncEngine.eventStream).thenAnswer((_) => syncEvents.stream);
    });

    tearDown(() async {
      await syncEvents.close();
    });

    blocTest<TestSyncCubit, BaseState>(
      'refreshes for relevant task events',
      build: () => TestSyncCubit(syncEngine: syncEngine),
      act: (cubit) async {
        syncEvents.add(
          const SyncEvent.operationCompleted(
            entityType: 'task',
            entityId: 'task-1',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 120));
      },
      expect: () => [
        const LoadedState<int>(data: 1),
      ],
    );

    blocTest<TestSyncCubit, BaseState>(
      'ignores irrelevant entity events',
      build: () => TestSyncCubit(syncEngine: syncEngine),
      act: (cubit) async {
        syncEvents.add(
          const SyncEvent.operationCompleted(
            entityType: 'reward',
            entityId: 'reward-1',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 120));
      },
      expect: () => <BaseState>[],
    );

    test('throttles rapid relevant events into one refresh', () async {
      final cubit = TestSyncCubit(syncEngine: syncEngine);

      syncEvents.add(
        const SyncEvent.operationCompleted(
          entityType: 'task',
          entityId: 'task-1',
        ),
      );
      syncEvents.add(
        const SyncEvent.conflictResolved(
          entityType: 'task',
          entityId: 'task-1',
          winner: ConflictWinner.remote,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(cubit.state, const LoadedState<int>(data: 1));
      expect(cubit.refreshCount, 1);

      await cubit.close();
    });
  });
}
