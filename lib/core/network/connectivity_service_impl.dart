import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:injectable/injectable.dart';

import 'connectivity_service.dart';

@LazySingleton(as: ConnectivityService)
class ConnectivityServiceImpl implements ConnectivityService {
  ConnectivityServiceImpl(this._connectivity);

  final Connectivity _connectivity;

  @override
  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map((results) => _isOnline(results));

  @override
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
