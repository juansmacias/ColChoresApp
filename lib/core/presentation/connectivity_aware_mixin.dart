import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../network/connectivity_service.dart';
import '../network/connectivity_status.dart';

mixin ConnectivityAwareMixin<State> on BlocBase<State> {
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;
  ConnectivityService? _connectivityService;

  bool get isOnline => _connectivityService?.isOnline ?? false;

  bool get isOffline => _connectivityService?.isOffline ?? true;

  void initConnectivityListener(ConnectivityService connectivityService) {
    _connectivityService = connectivityService;
    _connectivitySubscription = connectivityService.statusStream.listen(
      (status) {
        if (!isClosed) {
          onConnectivityChanged(status);
        }
      },
    );
  }

  void onConnectivityChanged(ConnectivityStatus status);

  Future<void> disposeConnectivityListener() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
}
