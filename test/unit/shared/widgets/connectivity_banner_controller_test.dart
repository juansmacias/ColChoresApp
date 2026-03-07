import 'package:family_chores_app/core/network/connectivity_status.dart';
import 'package:family_chores_app/core/sync/sync_state.dart';
import 'package:family_chores_app/shared/widgets/connectivity_banner_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectivityBannerState', () {
    test('maps offline connectivity to offline banner', () {
      final state = ConnectivityBannerState.fromStates(
        connectivity: ConnectivityStatus.offline,
        syncState: const SyncState.idle(),
      );

      expect(state.type, ConnectivityBannerType.offline);
      expect(
        state.message,
        "You're offline. Changes will sync when you reconnect.",
      );
    });

    test('maps online syncing state to syncing indicator', () {
      final state = ConnectivityBannerState.fromStates(
        connectivity: ConnectivityStatus.online,
        syncState: const SyncState.syncing(),
      );

      expect(state.type, ConnectivityBannerType.syncing);
      expect(state.message, isNull);
    });

    test('maps online idle state to hidden indicator', () {
      final state = ConnectivityBannerState.fromStates(
        connectivity: ConnectivityStatus.online,
        syncState: const SyncState.idle(),
      );

      expect(state.type, ConnectivityBannerType.hidden);
    });

    test('maps syncing with errors to sync error banner', () {
      final state = ConnectivityBannerState.fromStates(
        connectivity: ConnectivityStatus.online,
        syncState: const SyncState.syncingWithErrors(pendingCount: 3),
      );

      expect(state.type, ConnectivityBannerType.syncError);
      expect(state.message, '3 items pending');
    });
  });
}
