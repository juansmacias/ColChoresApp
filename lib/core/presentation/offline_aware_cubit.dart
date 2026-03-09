import 'package:flutter_bloc/flutter_bloc.dart';

import '../network/connectivity_service.dart';
import '../sync/sync_engine.dart';
import 'base_state.dart';
import 'connectivity_aware_mixin.dart';
import 'sync_aware_mixin.dart';

abstract class OfflineAwareCubit<State extends BaseState> extends Cubit<State>
    with ConnectivityAwareMixin<State>, SyncAwareMixin<State> {
  OfflineAwareCubit(super.initialState);

  Set<String>? get relevantEntityTypes;

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
  Future<void> close() async {
    await disposeConnectivityListener();
    await disposeSyncListener();
    return super.close();
  }
}
