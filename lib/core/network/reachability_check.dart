import 'reachability_check_stub.dart'
    if (dart.library.io) 'reachability_check_native.dart'
    if (dart.library.js_interop) 'reachability_check_web.dart';

Future<bool> checkInternetReachability({
  required String host,
  required Duration timeout,
}) {
  return checkInternetReachabilityImpl(
    host: host,
    timeout: timeout,
  );
}
