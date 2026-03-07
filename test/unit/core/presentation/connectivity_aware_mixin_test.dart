import 'package:bloc_test/bloc_test.dart';
import 'package:family_chores_app/core/network/connectivity_status.dart';
import 'package:family_chores_app/core/presentation/base_state.dart';
import 'package:family_chores_app/core/presentation/connectivity_aware_mixin.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/mock_connectivity.dart';

class TestConnectivityCubit extends Cubit<BaseState>
    with ConnectivityAwareMixin<BaseState> {
  TestConnectivityCubit(FakeConnectivityService connectivityService)
      : super(const InitialState()) {
    initConnectivityListener(connectivityService);
  }

  @override
  void onConnectivityChanged(ConnectivityStatus status) {
    final current = state;
    if (current is LoadedState<String>) {
      emit(
        current.copyWith(
          isOffline: status == ConnectivityStatus.offline,
        ),
      );
    }
  }

  void loadData() {
    emit(const LoadedState<String>(data: 'test data'));
  }

  @override
  Future<void> close() async {
    await disposeConnectivityListener();
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

    blocTest<TestConnectivityCubit, BaseState>(
      'updates isOffline when going offline',
      build: () => TestConnectivityCubit(connectivityService),
      seed: () => const LoadedState<String>(data: 'test data'),
      act: (cubit) => connectivityService.goOffline(),
      expect: () => [
        const LoadedState<String>(data: 'test data', isOffline: true),
      ],
    );

    blocTest<TestConnectivityCubit, BaseState>(
      'updates isOffline when returning online',
      build: () => TestConnectivityCubit(connectivityService),
      seed: () => const LoadedState<String>(data: 'test data', isOffline: true),
      act: (cubit) => connectivityService.goOnline(),
      expect: () => [
        const LoadedState<String>(data: 'test data', isOffline: false),
      ],
    );

    test('exposes isOnline and isOffline based on service state', () async {
      final cubit = TestConnectivityCubit(connectivityService);

      expect(cubit.isOnline, isTrue);
      connectivityService.goOffline();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.isOffline, isTrue);

      await cubit.close();
    });
  });
}
