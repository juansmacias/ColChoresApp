import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:family_chores_app/core/network/connectivity_service_impl.dart';
import 'package:family_chores_app/core/network/connectivity_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectivity extends Mock implements Connectivity {}

void main() {
  late MockConnectivity mockConnectivity;
  late StreamController<List<ConnectivityResult>> connectivityController;

  setUp(() {
    mockConnectivity = MockConnectivity();
    connectivityController =
        StreamController<List<ConnectivityResult>>.broadcast();

    when(() => mockConnectivity.onConnectivityChanged)
        .thenAnswer((_) => connectivityController.stream);
  });

  tearDown(() async {
    await connectivityController.close();
  });

  test('initial check sets online when network and reachability are available',
      () async {
    when(() => mockConnectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);

    final service = ConnectivityServiceImpl(
      mockConnectivity,
      debounceDuration: const Duration(milliseconds: 20),
      reachabilityChecker: () async => true,
    );

    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(service.currentStatus, ConnectivityStatus.online);
    service.dispose();
  });

  test('initial check stays offline when no network is available', () async {
    when(() => mockConnectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.none]);

    final service = ConnectivityServiceImpl(
      mockConnectivity,
      debounceDuration: const Duration(milliseconds: 20),
      reachabilityChecker: () async => true,
    );

    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(service.currentStatus, ConnectivityStatus.offline);
    service.dispose();
  });

  test('debounce collapses rapid changes and emits only the final status',
      () async {
    when(() => mockConnectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.none]);

    final service = ConnectivityServiceImpl(
      mockConnectivity,
      debounceDuration: const Duration(milliseconds: 30),
      reachabilityChecker: () async => true,
    );

    final emissions = <ConnectivityStatus>[];
    final sub = service.statusStream.skip(1).listen(emissions.add);

    connectivityController.add([ConnectivityResult.none]);
    connectivityController.add([ConnectivityResult.wifi]);
    connectivityController.add([ConnectivityResult.none]);
    connectivityController.add([ConnectivityResult.wifi]);

    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(emissions, [ConnectivityStatus.online]);

    await sub.cancel();
    service.dispose();
  });

  test('reports offline when network exists but reachability fails', () async {
    when(() => mockConnectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);

    final service = ConnectivityServiceImpl(
      mockConnectivity,
      debounceDuration: const Duration(milliseconds: 20),
      reachabilityChecker: () async => false,
    );

    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(service.currentStatus, ConnectivityStatus.offline);
    service.dispose();
  });

  test('checkConnectivity refreshes state and returns latest status', () async {
    when(() => mockConnectivity.checkConnectivity()).thenAnswer(
      (_) async => [ConnectivityResult.none],
    );

    final service = ConnectivityServiceImpl(
      mockConnectivity,
      debounceDuration: const Duration(milliseconds: 20),
      reachabilityChecker: () async => true,
    );

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(service.currentStatus, ConnectivityStatus.offline);

    when(() => mockConnectivity.checkConnectivity()).thenAnswer(
      (_) async => [ConnectivityResult.mobile],
    );

    final refreshed = await service.checkConnectivity();
    expect(refreshed, ConnectivityStatus.online);
    expect(service.currentStatus, ConnectivityStatus.online);

    service.dispose();
  });

  test('dispose stops further status emissions', () async {
    when(() => mockConnectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.none]);

    final service = ConnectivityServiceImpl(
      mockConnectivity,
      debounceDuration: const Duration(milliseconds: 20),
      reachabilityChecker: () async => true,
    );

    final emissions = <ConnectivityStatus>[];
    final sub = service.statusStream.listen(emissions.add);

    await Future<void>.delayed(const Duration(milliseconds: 10));
    service.dispose();

    connectivityController.add([ConnectivityResult.wifi]);
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(emissions, [ConnectivityStatus.offline]);

    await sub.cancel();
  });
}
