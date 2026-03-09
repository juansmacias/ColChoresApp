Future<bool> checkInternetReachabilityImpl({
  required String host,
  required Duration timeout,
}) {
  throw UnsupportedError(
    'No reachability implementation is available for this platform.',
  );
}
