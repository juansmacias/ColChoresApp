import 'connectivity_status.dart';

/// Abstract connectivity interface (Domain layer — no SDK imports).
abstract class ConnectivityService {
  /// Stream of connectivity state changes.
  Stream<ConnectivityStatus> get statusStream;

  /// Current connectivity status.
  ConnectivityStatus get currentStatus;

  /// Convenience getter.
  bool get isOnline => currentStatus == ConnectivityStatus.online;

  /// Convenience getter.
  bool get isOffline => currentStatus == ConnectivityStatus.offline;

  /// Performs an on-demand connectivity check and returns fresh status.
  Future<ConnectivityStatus> checkConnectivity();

  /// Releases stream resources and subscriptions.
  void dispose();
}
