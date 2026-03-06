/// Abstract connectivity interface (Domain layer — no SDK imports).
abstract class ConnectivityService {
  /// Stream that emits true when online, false when offline.
  Stream<bool> get onConnectivityChanged;

  /// Current connectivity state.
  Future<bool> get isConnected;
}
