import 'package:app_links/app_links.dart';
import 'package:injectable/injectable.dart';

import 'deep_link_service.dart';

@LazySingleton(as: DeepLinkService)
class DeepLinkServiceImpl implements DeepLinkService {
  DeepLinkServiceImpl(this._appLinks);

  final AppLinks _appLinks;

  @override
  Future<Uri?> getInitialUri() => _appLinks.getInitialLink();

  @override
  Stream<Uri> get incomingUris => _appLinks.uriLinkStream;
}
