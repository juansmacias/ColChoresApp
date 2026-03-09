abstract class DeepLinkService {
  Future<Uri?> getInitialUri();

  Stream<Uri> get incomingUris;
}
