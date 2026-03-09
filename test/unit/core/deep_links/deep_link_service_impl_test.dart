import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:family_chores_app/core/deep_links/deep_link_service_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppLinks extends Mock implements AppLinks {}

void main() {
  group('DeepLinkServiceImpl', () {
    late MockAppLinks appLinks;
    late DeepLinkServiceImpl service;
    late StreamController<Uri> uriController;

    setUp(() {
      appLinks = MockAppLinks();
      uriController = StreamController<Uri>.broadcast();
      service = DeepLinkServiceImpl(appLinks);

      when(() => appLinks.uriLinkStream)
          .thenAnswer((_) => uriController.stream);
    });

    tearDown(() async {
      await uriController.close();
    });

    test('getInitialUri should delegate to AppLinks', () async {
      final uri = Uri.parse('https://familychores.app/join?code=ABC123');
      when(() => appLinks.getInitialLink()).thenAnswer((_) async => uri);

      final result = await service.getInitialUri();

      expect(result, uri);
    });

    test('incomingUris should expose the AppLinks stream', () async {
      final expectedUri = Uri.parse('familychores://join?code=ABC123');

      final expectation = expectLater(service.incomingUris, emits(expectedUri));
      uriController.add(expectedUri);
      await expectation;
    });
  });
}
