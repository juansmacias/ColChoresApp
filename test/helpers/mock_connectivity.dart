import 'package:family_chores_app/core/network/connectivity_service.dart';
import 'package:family_chores_app/core/network/connectivity_status.dart';
import 'package:rxdart/rxdart.dart';

/// ConnectivityService fake that can be controlled in tests.
class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({
    ConnectivityStatus initialStatus = ConnectivityStatus.online,
  }) : _statusController = BehaviorSubject<ConnectivityStatus>.seeded(
          initialStatus,
        );

  final BehaviorSubject<ConnectivityStatus> _statusController;

  @override
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  @override
  ConnectivityStatus get currentStatus => _statusController.value;

  @override
  bool get isOnline => currentStatus == ConnectivityStatus.online;

  @override
  bool get isOffline => currentStatus == ConnectivityStatus.offline;

  @override
  Future<ConnectivityStatus> checkConnectivity() async => currentStatus;

  void goOnline() => _statusController.add(ConnectivityStatus.online);

  void goOffline() => _statusController.add(ConnectivityStatus.offline);

  @override
  void dispose() {
    _statusController.close();
  }
}
