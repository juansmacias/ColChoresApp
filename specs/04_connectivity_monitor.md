# Connectivity Monitor Service

## 1. Overview

### 1.1 Summary

This specification defines the Connectivity Monitor service, which wraps the `connectivity_plus` Flutter plugin and provides a clean, testable, stream-based API for the rest of the application to observe network connectivity state. It serves two consumers: the sync engine (which uses it to trigger sync operations) and the presentation layer (which uses it to display connectivity banners).

### 1.2 Business Context

The offline-first design requires the app to know its connectivity state at all times. Users must never be surprised by a failed operation due to missing internet. The connectivity indicator defined in `specs/00_project_foundation.md` Section 4.8.1 provides gentle, non-intrusive communication about network state. The sync engine depends on connectivity transitions to trigger push/pull operations.

### 1.3 Scope

**In scope:**
- Abstract `ConnectivityService` interface (domain layer)
- Concrete `ConnectivityServiceImpl` (data layer, wraps `connectivity_plus`)
- `ConnectivityStatus` enum (online, offline)
- Stream-based API for connectivity state changes
- Debounce strategy for flaky connections
- Initial connectivity check on service creation
- Internet reachability validation (beyond connection-type detection)
- Platform-specific permissions and configuration

**Out of scope:**
- UI components (connectivity banner widget) -- defined in `specs/05_bloc_foundation.md`
- Sync engine trigger logic -- defined in `specs/03_sync_engine.md`
- Firestore real-time listener management

### 1.4 References

- `specs/00_project_foundation.md` -- Section 4.4.3 (Sync Triggers), Section 4.8.1 (Connectivity States)
- `specs/03_sync_engine.md` -- Consumer of connectivity state for sync triggers
- `specs/05_bloc_foundation.md` -- ConnectivityAwareMixin consumes the connectivity stream
- `specs/01_project_scaffolding.md` -- DI registration, dependency on `connectivity_plus: ^5.0.0`

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| CM-001 | Expose a stream of connectivity status changes | High | Consumers receive `ConnectivityStatus.online` or `ConnectivityStatus.offline` when state changes |
| CM-002 | Provide current connectivity status synchronously | High | `isOnline` getter returns the latest known state without awaiting |
| CM-003 | Debounce rapid connectivity changes | High | Rapid on/off/on transitions within 2 seconds emit only the final state |
| CM-004 | Check connectivity on initialization | High | When service is created, it immediately determines and exposes the current state |
| CM-005 | Validate actual internet reachability | Medium | Beyond detecting a Wi-Fi/cellular connection, validate that the internet is actually reachable |
| CM-006 | Clean up resources on disposal | Medium | Stream subscriptions and timers are cancelled when the service is disposed |
| CM-007 | Abstract interface in domain layer | High | Domain and use case code depends on `ConnectivityService` abstraction, not the concrete implementation |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| CM-NFR-001 | State change latency | Time from actual connectivity change to stream emission | < 3 seconds (2s debounce + detection) |
| CM-NFR-002 | Battery impact | Background monitoring frequency | Zero background monitoring -- only active when app is foregrounded |
| CM-NFR-003 | False positive rate | Incorrectly reporting online when offline | < 5% (mitigated by reachability check) |

### 2.3 Assumptions

- The `connectivity_plus` plugin correctly detects connection type (Wi-Fi, cellular, none) on both iOS and Android.
- `connectivity_plus` only detects whether a network interface is available, not whether the internet is reachable. A separate reachability check is needed for accuracy.
- The app is in the foreground when connectivity monitoring is active. Background monitoring is not required (per NFR-005 of the foundation spec).

### 2.4 Constraints

- The domain layer must not import `connectivity_plus` directly. The abstract interface lives in `lib/core/network/` and the implementation depends on the plugin.
- The stream must be a broadcast stream (multiple listeners: sync engine + UI).
- Debounce must not delay the initial state emission.

---

## 3. Detailed Design

### 3.1 ConnectivityStatus Enum

```dart
// lib/core/network/connectivity_status.dart

/// Represents the app-level connectivity state.
/// Simplified from connectivity_plus's detailed connection types
/// to what the app actually needs to know.
enum ConnectivityStatus {
  /// Device has internet access (Wi-Fi, cellular, or ethernet).
  online,

  /// Device has no internet access.
  offline,
}
```

### 3.2 Abstract Interface (Domain Layer)

```dart
// lib/core/network/connectivity_service.dart

/// Abstract interface for monitoring network connectivity.
/// Domain and presentation layers depend on this abstraction.
/// Concrete implementation wraps connectivity_plus.
///
/// Registered as a singleton in DI (see specs/01_project_scaffolding.md).
abstract class ConnectivityService {
  /// Stream of connectivity state changes.
  /// Emits only when the state actually changes (deduplicated).
  /// Debounced by 2 seconds to avoid rapid oscillation.
  /// This is a broadcast stream (supports multiple listeners).
  Stream<ConnectivityStatus> get statusStream;

  /// Current connectivity status.
  /// Returns the latest known state synchronously.
  /// Before initialization completes, defaults to [ConnectivityStatus.offline]
  /// (fail-safe: assume offline until proven otherwise).
  ConnectivityStatus get currentStatus;

  /// Convenience getter.
  bool get isOnline => currentStatus == ConnectivityStatus.online;

  /// Convenience getter.
  bool get isOffline => currentStatus == ConnectivityStatus.offline;

  /// Performs an on-demand connectivity check.
  /// Useful when the cached status might be stale.
  Future<ConnectivityStatus> checkConnectivity();

  /// Releases resources (stream controllers, subscriptions, timers).
  void dispose();
}
```

### 3.3 Concrete Implementation (Data Layer)

```dart
// lib/core/network/connectivity_service_impl.dart

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:injectable/injectable.dart';
import 'package:rxdart/rxdart.dart';

import 'connectivity_service.dart';
import 'connectivity_status.dart';

/// Concrete implementation of [ConnectivityService].
/// Wraps [connectivity_plus] with debounce and reachability validation.
@LazySingleton(as: ConnectivityService)
class ConnectivityServiceImpl implements ConnectivityService {
  final Connectivity _connectivity;

  /// Debounce duration for rapid connectivity changes.
  static const _debounceDuration = Duration(seconds: 2);

  /// Host used for internet reachability check.
  /// Google's DNS is reliable and fast to resolve.
  static const _reachabilityHost = 'dns.google';

  /// Timeout for the reachability check.
  static const _reachabilityTimeout = Duration(seconds: 3);

  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  final BehaviorSubject<ConnectivityStatus> _statusSubject =
      BehaviorSubject<ConnectivityStatus>.seeded(ConnectivityStatus.offline);

  ConnectivityServiceImpl({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _initialize();
  }

  void _initialize() {
    // Perform initial check
    _performCheck();

    // Listen to connectivity changes with debounce
    _subscription = _connectivity.onConnectivityChanged
        .debounceTime(_debounceDuration)
        .listen(_handleConnectivityChange);
  }

  Future<void> _handleConnectivityChange(
    List<ConnectivityResult> results,
  ) async {
    final hasConnection = results.any(
      (r) => r != ConnectivityResult.none,
    );

    if (hasConnection) {
      // Connectivity detected, but verify reachability
      final isReachable = await _checkInternetReachability();
      _emitStatus(
        isReachable
            ? ConnectivityStatus.online
            : ConnectivityStatus.offline,
      );
    } else {
      _emitStatus(ConnectivityStatus.offline);
    }
  }

  /// Validates actual internet reachability by performing a DNS lookup.
  /// connectivity_plus only checks if a network interface is available,
  /// not if the internet is reachable (e.g., captive portal, DNS failure).
  Future<bool> _checkInternetReachability() async {
    try {
      final result = await InternetAddress.lookup(_reachabilityHost)
          .timeout(_reachabilityTimeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  void _emitStatus(ConnectivityStatus status) {
    // Only emit if status actually changed (deduplicate)
    if (_statusSubject.value != status) {
      _statusSubject.add(status);
    }
  }

  Future<void> _performCheck() async {
    final results = await _connectivity.checkConnectivity();
    await _handleConnectivityChange(results);
  }

  @override
  Stream<ConnectivityStatus> get statusStream => _statusSubject.stream;

  @override
  ConnectivityStatus get currentStatus => _statusSubject.value;

  @override
  Future<ConnectivityStatus> checkConnectivity() async {
    await _performCheck();
    return currentStatus;
  }

  @override
  void dispose() {
    _subscription.cancel();
    _statusSubject.close();
  }
}
```

### 3.4 State Transitions

```
                    App Start
                       |
                       v
              [Check Connectivity]
                 /           \
                v             v
         [Online]          [Offline]
            |                  |
            v                  v
    +-- Emit online     Emit offline --+
    |       |                  |        |
    |       v                  v        |
    |   [Monitoring]     [Monitoring]   |
    |       |                  |        |
    |   [Connection         [Connection |
    |    lost]               restored]  |
    |       |                  |        |
    |       v                  v        |
    |   [Debounce 2s]    [Debounce 2s]  |
    |       |                  |        |
    |       v                  v        |
    |   [Check                [Check    |
    |    reachability]         reach.]  |
    |       |                  |        |
    |       v                  v        |
    +-- Emit offline     Emit online --+
```

### 3.5 Debounce Behavior

The 2-second debounce prevents rapid oscillation when a device is on the edge of Wi-Fi range or transitioning between cellular and Wi-Fi:

| Time | Raw Event | Debounced Output |
|------|-----------|-----------------|
| T+0s | offline | (wait) |
| T+0.5s | online | (wait) |
| T+1s | offline | (wait) |
| T+1.5s | online | (wait) |
| T+3.5s | (2s since last change) | **Emit: online** |

The first emission after app start is NOT debounced -- it fires immediately from `_performCheck()`.

---

## 4. Platform Configuration

### 4.1 Android

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.INTERNET" />
```

Both permissions are already required by Firestore and Flutter, so no additional manifest changes should be needed.

### 4.2 iOS

No special permissions required for `connectivity_plus` on iOS. The `NSAppTransportSecurity` key in `Info.plist` may need configuration if the reachability check uses a non-HTTPS endpoint (our DNS lookup approach avoids this).

### 4.3 Platform-Specific Behavior Notes

| Behavior | Android | iOS |
|----------|---------|-----|
| Wi-Fi detection | Immediate | Immediate |
| Cellular detection | Immediate | May have slight delay |
| Airplane mode | Reports `none` immediately | Reports `none` immediately |
| Captive portal (hotel Wi-Fi) | Reports `wifi` (connected) | Reports `wifi` (connected) |
| VPN connected | Reports underlying connection type | Reports underlying connection type |

The captive portal case is why the reachability check (DNS lookup) is critical -- `connectivity_plus` will report "connected" even when internet is not actually reachable.

---

## 5. UI Notification Contract

The ConnectivityService produces raw `ConnectivityStatus` values. The mapping to UI states from `specs/00_project_foundation.md` Section 4.8.1 is handled by the presentation layer (specifically `ConnectivityAwareMixin` in `specs/05_bloc_foundation.md`):

| ConnectivityStatus | SyncState | UI State | Visual Indicator | User Message |
|-------------------|-----------|----------|-----------------|--------------|
| online | idle | Online, synced | No indicator | None |
| online | syncing | Online, syncing | Animated sync icon | None |
| online | syncingWithErrors | Online, sync error | Orange dot on sync icon | "Some changes pending" |
| offline | * | Offline | Yellow banner | "You're offline. Changes will sync when you reconnect." |
| online (transition from offline) | syncing | Returning online | Banner transitions to sync animation | "Reconnected. Syncing..." |

The ConnectivityService is responsible only for `online`/`offline`. The richer UI states combine connectivity with sync engine state.

---

## 6. Integration with Sync Engine

The sync engine (from `specs/03_sync_engine.md`) subscribes to the connectivity stream for two trigger conditions:

### 6.1 Trigger: Connectivity Restored

```dart
// Inside SyncEngine initialization:
_connectivitySubscription = _connectivityService.statusStream
    .where((status) => status == ConnectivityStatus.online)
    .listen((_) async {
  // Connectivity restored -- push pending operations, then pull
  await fullSync();
});
```

### 6.2 Guard: Check Before Sync

```dart
// Inside SyncEngine.fullSync():
if (!_connectivityService.isOnline) {
  // Skip sync, remain in current state
  return;
}
```

### 6.3 Mid-Sync Connectivity Loss

```dart
// Inside push loop (specs/03_sync_engine.md Section 4.3.2):
if (!_connectivityService.isOnline) {
  _statusManager.emitEvent(
    SyncEvent.syncPausedOffline(
      remainingOperations: await _operationQueue.pendingCount,
    ),
  );
  break;  // Exit push loop, remaining ops stay queued
}
```

---

## 7. Testing

### 7.1 Test Doubles

```dart
// test/helpers/mock_connectivity.dart
import 'package:mocktail/mocktail.dart';

class MockConnectivity extends Mock implements Connectivity {}

/// A fake ConnectivityService for testing that allows manual control.
class FakeConnectivityService implements ConnectivityService {
  final _statusController = BehaviorSubject<ConnectivityStatus>.seeded(
    ConnectivityStatus.online,
  );

  @override
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  @override
  ConnectivityStatus get currentStatus => _statusController.value;

  @override
  bool get isOnline => currentStatus == ConnectivityStatus.online;

  @override
  bool get isOffline => currentStatus == ConnectivityStatus.offline;

  @override
  Future<ConnectivityStatus> checkConnectivity() async => currentStatus;

  /// Test helper: simulate going online.
  void goOnline() => _statusController.add(ConnectivityStatus.online);

  /// Test helper: simulate going offline.
  void goOffline() => _statusController.add(ConnectivityStatus.offline);

  @override
  void dispose() => _statusController.close();
}
```

### 7.2 Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| CM-FT-001 | Initial state is determined on creation | Service created with Wi-Fi available | Service initializes | `currentStatus == online` | High |
| CM-FT-002 | Initial state offline when no connection | Service created with no network | Service initializes | `currentStatus == offline` | High |
| CM-FT-003 | Stream emits offline on disconnect | Service online | Network disconnects (after debounce) | Stream emits `ConnectivityStatus.offline` | High |
| CM-FT-004 | Stream emits online on reconnect | Service offline | Network reconnects (after debounce) | Stream emits `ConnectivityStatus.online` | High |
| CM-FT-005 | Debounce collapses rapid changes | Service online | offline -> online -> offline -> online within 2s | Only final state emitted (online) | High |
| CM-FT-006 | No duplicate emissions | Service online | Same "online" result received twice | Stream does not emit second time | Medium |
| CM-FT-007 | Reachability check fails = offline | Wi-Fi connected but DNS lookup fails | Connectivity change detected | Status = offline despite Wi-Fi | Medium |
| CM-FT-008 | Reachability check succeeds = online | Wi-Fi connected and DNS lookup succeeds | Connectivity change detected | Status = online | Medium |
| CM-FT-009 | checkConnectivity() returns fresh result | Status was offline (stale) | `checkConnectivity()` called, network now available | Returns online, stream updated | Medium |
| CM-FT-010 | dispose() cleans up resources | Service is active | `dispose()` called | No further emissions, no memory leaks | Medium |
| CM-FT-011 | Multiple listeners receive same events | Two consumers subscribed to statusStream | Network changes | Both receive the same status change | Medium |
| CM-FT-012 | Reachability timeout treated as offline | DNS lookup takes > 3 seconds | Connectivity change detected | Status = offline | Low |

### 7.3 Edge Cases

- **Airplane mode toggle:** Rapid airplane mode on/off should debounce correctly.
- **Wi-Fi to cellular handoff:** Should detect as a brief offline then online (if debounce collapses, single online).
- **Captive portal:** Wi-Fi is "connected" but internet is unreachable. Reachability check must catch this.
- **VPN connection/disconnection:** Should not cause false offline reports.
- **Service disposed while check in progress:** The pending reachability check should not emit after disposal.

---

## 8. Impact Analysis

### 8.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| ConnectivityService (abstract) | New | Low | Simple interface with stream + getter |
| ConnectivityServiceImpl | New | Medium | Wraps connectivity_plus, adds debounce and reachability |
| SyncEngine | Consumer | Medium | Uses connectivity to trigger syncs and guard operations |
| BLoC ConnectivityAwareMixin | Consumer | Low | Subscribes to status stream for UI state |
| Connectivity banner widget | Consumer | Low | Observes status for display |
| DI network_module | Modified | Low | Registers ConnectivityService singleton |

### 8.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| connectivity_plus reports wrong state | Medium | Medium | Reachability check (DNS lookup) as secondary validation |
| DNS lookup delays connectivity detection | Medium | Low | 3-second timeout prevents blocking. Worst case: 5s total detection time. |
| Debounce hides real connectivity changes | Low | Medium | 2s debounce is a balance. Adjustable if needed. |
| BehaviorSubject memory leak | Low | Low | dispose() closes the subject. DI lifecycle manages disposal. |
| connectivity_plus API changes in future versions | Low | Medium | Plugin is wrapped behind abstract interface. Only impl changes needed. |

---

## 9. Implementation Recommendations

### 9.1 Suggested Approach

1. Define `ConnectivityStatus` enum.
2. Define `ConnectivityService` abstract interface.
3. Implement `ConnectivityServiceImpl` with connectivity_plus, debounce, and reachability.
4. Register in DI as `@LazySingleton(as: ConnectivityService)`.
5. Create `FakeConnectivityService` test double.
6. Write all unit tests (CM-FT-001 through CM-FT-012).
7. Verify integration with sync engine trigger in an integration test.

### 9.2 Estimated Effort

**T-shirt size: S** (1-2 days)

The connectivity service is straightforward. The main complexity is in the reachability check and debounce testing.

### 9.3 Dependencies

| Dependency | Version | Purpose |
|-----------|---------|---------|
| `connectivity_plus` | ^5.0.0 | Network connection type detection |
| `rxdart` | ^0.28.0 | BehaviorSubject, debounceTime |

---

## 10. Open Questions

- [ ] Should the reachability check use a DNS lookup (`InternetAddress.lookup`) or an HTTP HEAD request to a known endpoint? DNS is faster but HTTP is more reliable for captive portal detection. Current recommendation: DNS lookup for speed, with HTTP fallback in a future iteration if captive portals are a real problem.
- [ ] Should the debounce duration be configurable (e.g., via DI parameter) or hardcoded? Current recommendation: hardcoded at 2 seconds, adjustable only if testing reveals the need.
- [ ] Should we track the _type_ of connection (Wi-Fi vs cellular) for analytics or sync behavior (e.g., defer large photo uploads to Wi-Fi)? Current recommendation: Not in Phase 1. Add `connectionType` getter if needed in Phase 4 (photo uploads).

---

*Generated by Software Architect Analyst*
*Date: 2026-03-05*
