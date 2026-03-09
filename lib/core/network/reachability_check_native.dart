import 'dart:async';
import 'dart:io';

Future<bool> checkInternetReachabilityImpl({
  required String host,
  required Duration timeout,
}) async {
  try {
    final results = await InternetAddress.lookup(host).timeout(timeout);
    return results.isNotEmpty && results.first.rawAddress.isNotEmpty;
  } on SocketException {
    return false;
  } on TimeoutException {
    return false;
  }
}
