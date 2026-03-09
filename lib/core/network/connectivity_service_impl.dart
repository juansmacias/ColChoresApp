import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:injectable/injectable.dart';
import 'package:rxdart/rxdart.dart';

import 'connectivity_service.dart';
import 'connectivity_status.dart';
import 'reachability_check.dart';

@LazySingleton(as: ConnectivityService)
class ConnectivityServiceImpl implements ConnectivityService {
  ConnectivityServiceImpl(
    this._connectivity, {
    Duration debounceDuration = const Duration(seconds: 2),
    Duration reachabilityTimeout = const Duration(seconds: 3),
    String reachabilityHost = 'dns.google',
    Future<bool> Function()? reachabilityChecker,
  })  : _debounceDuration = debounceDuration,
        _reachabilityTimeout = reachabilityTimeout,
        _reachabilityHost = reachabilityHost,
        _reachabilityChecker = reachabilityChecker {
    _initialize();
  }

  final Connectivity _connectivity;
  final Duration _debounceDuration;
  final Duration _reachabilityTimeout;
  final String _reachabilityHost;
  final Future<bool> Function()? _reachabilityChecker;

  final BehaviorSubject<ConnectivityStatus> _statusSubject =
      BehaviorSubject<ConnectivityStatus>.seeded(ConnectivityStatus.offline);
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isDisposed = false;

  @override
  Stream<ConnectivityStatus> get statusStream => _statusSubject.stream;

  @override
  ConnectivityStatus get currentStatus => _statusSubject.value;

  @override
  bool get isOnline => currentStatus == ConnectivityStatus.online;

  @override
  bool get isOffline => currentStatus == ConnectivityStatus.offline;

  @override
  Future<ConnectivityStatus> checkConnectivity() async {
    await _performCheck();
    return currentStatus;
  }

  void _initialize() {
    unawaited(_performCheck());
    _subscription = _connectivity.onConnectivityChanged
        .debounceTime(_debounceDuration)
        .listen(
          (results) => unawaited(_handleConnectivityChange(results)),
        );
  }

  Future<void> _performCheck() async {
    if (_isDisposed) return;
    final results = await _connectivity.checkConnectivity();
    await _handleConnectivityChange(results);
  }

  Future<void> _handleConnectivityChange(
    List<ConnectivityResult> results,
  ) async {
    if (_isDisposed) return;

    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    if (!hasConnection) {
      _emitStatus(ConnectivityStatus.offline);
      return;
    }

    final reachable = await _checkInternetReachability();
    _emitStatus(
      reachable ? ConnectivityStatus.online : ConnectivityStatus.offline,
    );
  }

  Future<bool> _checkInternetReachability() async {
    if (_reachabilityChecker != null) {
      return _reachabilityChecker();
    }

    return checkInternetReachability(
      host: _reachabilityHost,
      timeout: _reachabilityTimeout,
    );
  }

  void _emitStatus(ConnectivityStatus status) {
    if (_isDisposed) return;
    if (_statusSubject.value != status) {
      _statusSubject.add(status);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_statusSubject.close());
  }
}
