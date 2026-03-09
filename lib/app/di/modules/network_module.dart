import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:injectable/injectable.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/network/connectivity_service_impl.dart';

@module
abstract class NetworkModule {
  @singleton
  Connectivity get connectivity => Connectivity();

  @lazySingleton
  ConnectivityService connectivityService(Connectivity connectivity) =>
      ConnectivityServiceImpl(connectivity);
}
