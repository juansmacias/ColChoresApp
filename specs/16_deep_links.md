# Deep Link Support

## 1. Overview

### 1.1 Summary

This specification defines deep link support for the Family Chores App in Phase 2. Deep links enable shareable invite URLs that open the app directly to the Join Family screen with the invite code pre-filled. Firebase Auth email actions (email verification, password reset) are handled natively by the Firebase Auth SDK and require no custom deep link handling -- they are documented here for completeness. Phase 7 will add notification-triggered deep links.

### 1.2 Business Context

The family invite flow is the critical secondary onboarding path. When Marcus texts an invite link to Sofia via iMessage or WhatsApp, Sofia should be able to tap the link and land directly on the Join Family screen with the code already filled in. Without deep links, Sofia must manually open the app, navigate to the join screen, and type a 6-character code -- a friction point that reduces conversion. Deep links eliminate this friction by making the join flow a single tap.

### 1.3 Scope

**In scope:**
- Universal Links (iOS) and App Links (Android) for `https://familychores.app/join?code=...`
- Custom URL scheme (`familychores://join?code=...`) as fallback
- Firebase Hosting configuration to serve AASA and assetlinks.json verification files
- `app_links` package integration in Flutter
- DeepLinkService abstraction and implementation
- go_router deep link route configuration
- DeepLinkRedirectCubit for preserving pending deep links across auth redirects
- JoinFamilyScreen deep link pre-fill
- Cloud Function `generateShareableLink` returning a shareable URL
- Share sheet integration via `share_plus` package
- Cold start and warm start deep link handling

**Out of scope:**
- Notification deep links (Phase 7)
- QR code generation wrapping deep links (Phase 7)
- Firebase Dynamic Links (deprecated -- using native Universal Links / App Links instead)
- App-not-installed fallback page on Firebase Hosting (documented as future enhancement)

### 1.4 References

- `specs/08_phase2_foundations.md` -- Section 6 (Router), Section 7 (Dependencies)
- `specs/10_family_onboarding.md` -- Section 3 UC-003 (Join Family), Section 7.5 (JoinFamilyScreen)
- `specs/14_cloud_functions_invite.md` -- Section 4.2 (generateInviteCode)
- `CLAUDE.md` -- Tech stack, go_router routing

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| DL-001 | Tapping a join link opens the app to JoinFamilyScreen | High | `https://familychores.app/join?code=ABC123` opens JoinFamilyScreen with code pre-filled |
| DL-002 | Deep link works on cold start (app not running) | High | App launches, initializes, then navigates to `/family/join?code=ABC123` |
| DL-003 | Deep link works on warm start (app in background) | High | App resumes and navigates to `/family/join?code=ABC123` |
| DL-004 | Custom scheme fallback works | Medium | `familychores://join?code=ABC123` opens JoinFamilyScreen with code pre-filled |
| DL-005 | Invalid or expired code shows error on JoinFamilyScreen | High | User sees inline error message, can manually enter a different code |
| DL-006 | Unauthenticated user with deep link is redirected to sign-in first | High | Deep link URI preserved, user redirected to sign-in, then to join screen after auth |
| DL-007 | Authenticated user with no family navigates directly to join screen | High | No extra redirects, code pre-filled |
| DL-008 | Authenticated user already in a family sees error dialog | Medium | "You are already part of a family." message shown |
| DL-009 | Share button on FamilySetupScreen opens system share sheet | High | Calls `generateShareableLink`, displays share sheet with HTTPS URL |
| DL-010 | Firebase Auth email actions handled natively by SDK | Low | No custom handling needed, documented for reference |
| DL-011 | Firebase Auth password reset handled natively by SDK | Low | No custom handling needed, documented for reference |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| DL-NFR-001 | Link format is human-readable | URL length | < 60 characters |
| DL-NFR-002 | Deep link works on iOS and Android | Platform coverage | Both platforms verified |
| DL-NFR-003 | Cold start deep link navigation time | Time from tap to join screen | < 4 seconds (includes app init) |
| DL-NFR-004 | Warm start deep link navigation time | Time from tap to join screen | < 1 second |

### 2.3 Assumptions

- The domain `familychores.app` is owned and configured for the project.
- Firebase Hosting is set up and deployed for the project.
- The app is published to the App Store and Google Play (required for Universal Links / App Links verification in production). During development, links work via custom scheme.
- iOS Team ID and Android SHA-256 signing certificate fingerprint are available.

### 2.4 Constraints

- Universal Links (iOS) require an HTTPS domain with a valid AASA file. Cannot be tested on the iOS Simulator without a workaround (custom scheme works on simulator).
- App Links (Android) with `autoVerify=true` require the assetlinks.json file to be served at `https://familychores.app/.well-known/assetlinks.json`. Verification happens at app install time.
- Firebase Dynamic Links is deprecated and should not be used. Native Universal Links and App Links are the replacement.
- The `app_links` package replaces the deprecated `uni_links` package.

---

## 3. URL Scheme Design

### 3.1 Phase 2 Deep Link URLs

| Path | Purpose | Format | Example |
|------|---------|--------|---------|
| `/join` | Join family via invite code | `https://familychores.app/join?code={6-char-code}` | `https://familychores.app/join?code=ABC123` |
| `/join` (custom scheme) | Fallback join link | `familychores://join?code={6-char-code}` | `familychores://join?code=ABC123` |

### 3.2 Firebase Auth Action URLs (Reference Only)

Firebase Auth handles these URLs internally via the Firebase SDK. No custom deep link handling is required in the app. They are documented here for awareness.

| Action | URL Pattern |
|--------|------------|
| Email verification | `https://familychores.app/__/auth/action?mode=verifyEmail&oobCode=...` |
| Password reset | `https://familychores.app/__/auth/action?mode=resetPassword&oobCode=...` |

These URLs are served by Firebase Hosting's built-in `__/auth/` rewrite rule. The Firebase SDK processes the `oobCode` parameter automatically.

### 3.3 go_router Path Mapping

| Deep Link Path | go_router Route | Screen |
|----------------|-----------------|--------|
| `/join?code={code}` | `/family/join?code={code}` | JoinFamilyScreen |

Note: The external deep link path (`/join`) is mapped to the internal go_router path (`/family/join`) in the router configuration. This keeps external URLs short while maintaining the app's internal route hierarchy.

---

## 4. Firebase Hosting Configuration

### 4.1 firebase.json Updates

Add a `hosting` section to the existing `firebase.json`:

```json
{
  "hosting": {
    "public": "public",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "/__/auth/**",
        "function": "ext-firebase-auth-emulator"
      }
    ],
    "headers": [
      {
        "source": "/apple-app-site-association",
        "headers": [
          {
            "key": "Content-Type",
            "value": "application/json"
          }
        ]
      },
      {
        "source": "/.well-known/assetlinks.json",
        "headers": [
          {
            "key": "Content-Type",
            "value": "application/json"
          }
        ]
      }
    ]
  }
}
```

### 4.2 Apple App Site Association (AASA) File

```json
// public/apple-app-site-association
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "<TEAM_ID>.com.familychores.app",
        "paths": [
          "/join",
          "/join?*"
        ]
      }
    ]
  }
}
```

Replace `<TEAM_ID>` with the Apple Developer Team ID from the Apple Developer Console.

### 4.3 Android Asset Links File

```json
// public/.well-known/assetlinks.json
[
  {
    "relation": [
      "delegate_permission/common.handle_all_urls"
    ],
    "target": {
      "namespace": "android_app",
      "package_name": "com.familychores.app",
      "sha256_cert_fingerprints": [
        "<SHA256_FINGERPRINT>"
      ]
    }
  }
]
```

Replace `<SHA256_FINGERPRINT>` with the SHA-256 certificate fingerprint from the Play Console (App signing > App signing key certificate > SHA-256 certificate fingerprint). For debug builds, use the debug keystore fingerprint:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA256
```

### 4.4 Hosting Deployment

```bash
# Deploy hosting files (AASA + assetlinks.json)
firebase deploy --only hosting

# Verify AASA is served correctly
curl -I https://familychores.app/apple-app-site-association

# Verify assetlinks.json is served correctly
curl -I https://familychores.app/.well-known/assetlinks.json
```

---

## 5. iOS Configuration

### 5.1 Associated Domains Entitlement

```xml
<!-- ios/Runner/Runner.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:familychores.app</string>
    </array>
</dict>
</plist>
```

### 5.2 Custom URL Scheme Registration

```xml
<!-- ios/Runner/Info.plist (add inside the top-level <dict>) -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.familychores.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>familychores</string>
        </array>
    </dict>
</array>
```

### 5.3 Xcode Setup

In Xcode, navigate to the Runner target > Signing & Capabilities > + Capability > Associated Domains. Add `applinks:familychores.app`. This generates the entitlements file above if it does not already exist.

---

## 6. Android Configuration

### 6.1 AndroidManifest.xml Intent Filters

Add the following intent filters inside the `<activity>` tag for `MainActivity` in `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- App Links (HTTPS Universal Links for Android) -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="https"
        android:host="familychores.app"
        android:pathPrefix="/join" />
</intent-filter>

<!-- Custom Scheme (fallback) -->
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="familychores" />
</intent-filter>
```

Note: `android:autoVerify="true"` on the HTTPS intent filter tells Android to verify the app's ownership of the domain by fetching `https://familychores.app/.well-known/assetlinks.json` at install time.

---

## 7. Flutter Implementation

### 7.1 Package Setup

Add to `pubspec.yaml`:

```yaml
dependencies:
  app_links: ^6.0.0
  share_plus: ^10.0.0
```

### 7.2 DeepLinkService

#### Abstract Interface

```dart
// lib/core/deep_links/deep_link_service.dart

/// Provides incoming deep link URIs to the app.
/// Abstracts the platform-specific deep link handling.
abstract class DeepLinkService {
  /// Stream of incoming deep link URIs.
  /// Emits when the app receives a deep link while running (warm start).
  Stream<Uri> get incomingLinks;

  /// Returns the URI that launched the app, or null if the app
  /// was not launched via a deep link (cold start check).
  Future<Uri?> getInitialLink();
}
```

#### Implementation

```dart
// lib/core/deep_links/deep_link_service_impl.dart
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:injectable/injectable.dart';

import 'deep_link_service.dart';

@LazySingleton(as: DeepLinkService)
class DeepLinkServiceImpl implements DeepLinkService {
  DeepLinkServiceImpl() : _appLinks = AppLinks();

  final AppLinks _appLinks;

  @override
  Stream<Uri> get incomingLinks => _appLinks.uriLinkStream;

  @override
  Future<Uri?> getInitialLink() async {
    try {
      return await _appLinks.getInitialLink();
    } catch (_) {
      // No initial link or platform error
      return null;
    }
  }
}
```

### 7.3 go_router Integration

Update `app_router.dart` to handle the `/join` deep link path and map it to the internal `/family/join` route:

```dart
// In app_router.dart -- add to routes list:

// Deep link entry point: /join?code=ABC123
// Maps external /join path to internal /family-setup/join route
GoRoute(
  path: '/join',
  redirect: (context, state) {
    final code = state.uri.queryParameters['code'];
    if (code != null) {
      return '${RouteNames.joinFamily}?code=$code';
    }
    return RouteNames.joinFamily;
  },
),
```

Update the existing `/family-setup/join` route to accept a `code` query parameter:

```dart
GoRoute(
  path: RouteNames.joinFamily,
  builder: (context, state) {
    final code = state.uri.queryParameters['code'];
    return JoinFamilyScreen(initialCode: code);
  },
),
```

go_router natively handles incoming deep links in Flutter. When a deep link arrives, go_router matches the path against defined routes and navigates accordingly. No additional `GoRouter.setPathUrlStrategy()` call is needed for mobile -- that is for web only.

### 7.4 Deep Link Handling on App Startup

#### Cold Start

On cold start, the initial deep link is captured before the router initializes. The deep link URI is checked in `main.dart` and stored in the DI container for the router to consume:

```dart
// In main.dart, after DI initialization:
final deepLinkService = getIt<DeepLinkService>();
final initialUri = await deepLinkService.getInitialLink();

if (initialUri != null) {
  getIt<DeepLinkRedirectCubit>().setPendingDeepLink(initialUri);
}
```

The `DeepLinkRedirectCubit` holds the pending URI. The router checks for a pending deep link after auth is resolved and navigates to it.

#### Warm Start

On warm start, the deep link arrives via the `incomingLinks` stream. The app listens to this stream in the root `FamilyChoresApp` widget or in a global listener:

```dart
// In app.dart or a dedicated DeepLinkListener widget:
class _DeepLinkListener extends StatefulWidget {
  const _DeepLinkListener({required this.child});
  final Widget child;

  @override
  State<_DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends State<_DeepLinkListener> {
  late final StreamSubscription<Uri> _subscription;

  @override
  void initState() {
    super.initState();
    final deepLinkService = getIt<DeepLinkService>();
    _subscription = deepLinkService.incomingLinks.listen(_handleDeepLink);
  }

  void _handleDeepLink(Uri uri) {
    final router = GoRouter.of(context);
    // Map external /join path to internal route
    if (uri.path == '/join') {
      final code = uri.queryParameters['code'];
      router.go('${RouteNames.joinFamily}?code=${code ?? ''}');
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
```

### 7.5 AuthGuard Deep Link Awareness

When an unauthenticated user opens a deep link, the AuthGuard must:
1. Save the intended deep link URI.
2. Redirect to sign-in.
3. After successful auth, redirect to the saved deep link.

#### DeepLinkRedirectCubit

```dart
// lib/core/deep_links/deep_link_redirect_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

// -- States --

sealed class DeepLinkRedirectState extends Equatable {
  const DeepLinkRedirectState();

  @override
  List<Object?> get props => [];
}

final class DeepLinkRedirectInitial extends DeepLinkRedirectState {
  const DeepLinkRedirectInitial();
}

final class DeepLinkRedirectPending extends DeepLinkRedirectState {
  const DeepLinkRedirectPending(this.uri);
  final Uri uri;

  @override
  List<Object?> get props => [uri];
}

final class DeepLinkRedirectConsumed extends DeepLinkRedirectState {
  const DeepLinkRedirectConsumed();
}

// -- Cubit --

@lazySingleton
class DeepLinkRedirectCubit extends Cubit<DeepLinkRedirectState> {
  DeepLinkRedirectCubit() : super(const DeepLinkRedirectInitial());

  /// Stores a pending deep link URI to be consumed after auth.
  void setPendingDeepLink(Uri uri) {
    emit(DeepLinkRedirectPending(uri));
  }

  /// Returns the pending URI and marks it as consumed.
  /// Returns null if no pending deep link.
  Uri? consumePendingDeepLink() {
    final currentState = state;
    if (currentState is DeepLinkRedirectPending) {
      emit(const DeepLinkRedirectConsumed());
      return currentState.uri;
    }
    return null;
  }

  /// Clears any pending deep link.
  void clear() {
    emit(const DeepLinkRedirectInitial());
  }
}
```

#### AuthGuard Update

Update `AuthGuard.redirect` to save the deep link before redirecting to sign-in:

```dart
// In auth_guard.dart -- updated redirect method:
static String? redirect(AuthBloc authBloc, GoRouterState state) {
  final isAuthenticated = authBloc.state is AuthAuthenticated;
  final isOnPublicRoute = _publicRoutes.contains(state.matchedLocation);

  // Unauthenticated user trying to access protected route
  if (!isAuthenticated && !isOnPublicRoute) {
    // Preserve deep link for post-auth redirect
    final deepLinkCubit = getIt<DeepLinkRedirectCubit>();
    if (state.matchedLocation.startsWith('/family-setup/join') ||
        state.matchedLocation == '/join') {
      deepLinkCubit.setPendingDeepLink(state.uri);
    }
    return RouteNames.signIn;
  }

  // Authenticated user on auth screen -- check for pending deep link
  if (isAuthenticated && isOnPublicRoute) {
    final deepLinkCubit = getIt<DeepLinkRedirectCubit>();
    final pendingUri = deepLinkCubit.consumePendingDeepLink();
    if (pendingUri != null) {
      final code = pendingUri.queryParameters['code'];
      if (code != null) {
        return '${RouteNames.joinFamily}?code=$code';
      }
    }

    final hasFamily = (authBloc.state as AuthAuthenticated).hasFamily;
    return hasFamily ? RouteNames.home : RouteNames.familySetup;
  }

  return null; // No redirect needed
}
```

### 7.6 JoinFamilyScreen Deep Link Pre-fill

The `JoinFamilyScreen` accepts an optional `initialCode` parameter from the route's query parameters:

```dart
// In JoinFamilyScreen:
class JoinFamilyScreen extends StatefulWidget {
  const JoinFamilyScreen({super.key, this.initialCode});

  /// Pre-filled invite code from a deep link.
  /// Null if the user navigated to this screen manually.
  final String? initialCode;

  // ...
}

class _JoinFamilyScreenState extends State<JoinFamilyScreen> {
  late final TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode);

    // If code is pre-filled from deep link, validate format
    if (widget.initialCode != null) {
      _validateCodeFormat(widget.initialCode!);
    }
  }

  void _validateCodeFormat(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized.length != 6 || !RegExp(r'^[A-Z0-9]+$').hasMatch(normalized)) {
      // Show inline error, allow manual correction
      setState(() {
        _codeError = 'This invite code looks invalid. Please check and try again.';
      });
    }
  }

  // ...
}
```

---

## 8. Cloud Function: generateShareableLink

### 8.1 Updated generateInviteCode Response

The existing `generateInviteCode` Cloud Function (see `specs/14_cloud_functions_invite.md` Section 4.2) is updated to return the shareable URL alongside the code:

```typescript
// Updated return value in generate-invite-code.ts:
return {
  code: inviteCode,
  shareableUrl: `https://familychores.app/join?code=${inviteCode}`,
  expiresAt: expiresAt.toDate().toISOString(),
};
```

This avoids creating a separate Cloud Function -- the existing `generateInviteCode` function already handles code generation and now also returns the pre-formatted shareable URL.

### 8.2 Flutter Share Integration

Add a "Share Invite Link" button to FamilySetupScreen (shown after family creation) and to the Settings screen:

```dart
// In FamilySetupScreen or SettingsScreen:
import 'package:share_plus/share_plus.dart';

Future<void> _shareInviteLink(String familyId) async {
  // 1. Call Cloud Function to generate code + URL
  final result = await familyRepository.generateInviteCode(familyId);

  result.when(
    success: (data) async {
      final shareableUrl = data.shareableUrl;
      // 2. Open system share sheet
      await Share.share(
        'Join our family on Family Chores! $shareableUrl',
        subject: 'Join our family',
      );
    },
    failure: (failure) {
      // Show error SnackBar
    },
  );
}
```

### 8.3 Updated FamilyRemoteDatasource

```dart
// In FamilyRemoteDatasource -- updated generateInviteCode method:
Future<InviteCodeResult> generateInviteCode(String familyId) async {
  final callable = _functions.httpsCallable('generateInviteCode');
  final result = await callable.call<Map<String, dynamic>>(
    {'familyId': familyId},
  );
  return InviteCodeResult(
    code: result.data['code'] as String,
    shareableUrl: result.data['shareableUrl'] as String,
    expiresAt: DateTime.parse(result.data['expiresAt'] as String),
  );
}
```

```dart
// lib/features/family/data/models/invite_code_result.dart
class InviteCodeResult {
  const InviteCodeResult({
    required this.code,
    required this.shareableUrl,
    required this.expiresAt,
  });

  final String code;
  final String shareableUrl;
  final DateTime expiresAt;
}
```

---

## 9. Error Handling

### 9.1 Error Scenarios

| Scenario | Detection | User-Facing Message | Action |
|----------|-----------|---------------------|--------|
| Invalid code format (not 6 alphanumeric chars) | Client-side regex | "This invite code looks invalid. Please check and try again." | Allow manual edit |
| Expired invite code | Cloud Function returns `failed-precondition` | "This invite link has expired. Ask a family member for a new one." | Show retry button |
| Code not found | Cloud Function returns `not-found` | "We could not find a family with this code. Please check and try again." | Allow manual edit |
| Already a member | Cloud Function returns `already-exists` | "You are already part of this family." | Navigate to home |
| User not authenticated | AuthGuard redirect | N/A (user sees sign-in screen) | Preserve deep link URI |
| App not installed | N/A (browser opens) | Browser shows `familychores.app/join` page | Future: add App Store / Play Store links to hosted page |
| Network error | `SocketException` or timeout | "Unable to connect. Please check your internet and try again." | Show retry button |

### 9.2 App Not Installed Fallback

When the app is not installed and a user taps the deep link, the browser opens `https://familychores.app/join?code=ABC123`. For Phase 2, this will show the default Firebase Hosting page. As a future enhancement (Phase 7 or Phase 8), add a hosted HTML page at `/join` that detects the platform and redirects to the App Store or Play Store:

```
public/join/index.html  (future enhancement -- not in Phase 2 scope)
```

---

## 10. Testing

### 10.1 Unit Tests

#### DeepLinkServiceImpl Tests

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| DL-UT-001 | getInitialLink returns URI | App launched via deep link | `getInitialLink()` called | Returns the launch URI | High |
| DL-UT-002 | getInitialLink returns null when no link | App launched normally | `getInitialLink()` called | Returns null | High |
| DL-UT-003 | incomingLinks emits URI | App receives deep link while running | Stream listened | URI emitted on stream | High |
| DL-UT-004 | getInitialLink handles platform error | Platform throws exception | `getInitialLink()` called | Returns null (error caught) | Medium |
| DL-UT-005 | incomingLinks emits multiple URIs | Two deep links received | Stream listened | Both URIs emitted in order | Medium |

#### DeepLinkRedirectCubit Tests

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| DL-UT-006 | Initial state is DeepLinkRedirectInitial | Cubit created | Check state | DeepLinkRedirectInitial | High |
| DL-UT-007 | setPendingDeepLink emits Pending | No pending link | `setPendingDeepLink(uri)` called | DeepLinkRedirectPending(uri) emitted | High |
| DL-UT-008 | consumePendingDeepLink returns URI and emits Consumed | Pending link exists | `consumePendingDeepLink()` called | Returns URI, emits DeepLinkRedirectConsumed | High |
| DL-UT-009 | consumePendingDeepLink returns null when no pending | No pending link | `consumePendingDeepLink()` called | Returns null, state unchanged | High |
| DL-UT-010 | clear resets to Initial | Pending link exists | `clear()` called | DeepLinkRedirectInitial emitted | Medium |

### 10.2 Widget Tests

#### JoinFamilyScreen Deep Link Tests

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| DL-WT-001 | Code pre-filled from deep link | `initialCode: 'ABC123'` | Screen renders | Code input shows "ABC123" | High |
| DL-WT-002 | Invalid code from deep link shows error | `initialCode: 'XY'` | Screen renders | Inline error message shown | Medium |
| DL-WT-003 | No initial code shows empty input | `initialCode: null` | Screen renders | Code input is empty | Medium |

### 10.3 Integration Tests

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| DL-IT-001 | Cold start with valid deep link | App not running | Deep link tapped | App launches, navigates to JoinFamilyScreen with code | High |
| DL-IT-002 | Cold start with expired code | App not running | Deep link with expired code tapped | App launches, JoinFamilyScreen shows, submit shows error | Medium |
| DL-IT-003 | Warm start with valid deep link | App in background, user authenticated | Deep link tapped | App resumes, navigates to JoinFamilyScreen with code | High |
| DL-IT-004 | Warm start unauthenticated with deep link | App in background, user not authenticated | Deep link tapped | Redirects to sign-in, then to join screen after auth | Medium |

### 10.4 Test File Locations

```
test/
  unit/
    core/
      deep_links/
        deep_link_service_impl_test.dart     # DL-UT-001 through DL-UT-005
        deep_link_redirect_cubit_test.dart   # DL-UT-006 through DL-UT-010
  widget/
    features/
      family/
        presentation/
          screens/
            join_family_screen_deep_link_test.dart  # DL-WT-001 through DL-WT-003
  integration/
    deep_links/
      deep_link_navigation_test.dart         # DL-IT-001 through DL-IT-004
```

---

## 11. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| AASA file not served correctly by Firebase Hosting | Medium | High | Verify with `curl` after deploy. Test on real device. Add Content-Type header explicitly. |
| Universal Links fail on first install (caching) | Medium | Medium | Custom scheme fallback works without verification. Document that Universal Links may take up to 24h to propagate. |
| Android App Links autoVerify fails due to wrong SHA-256 | Medium | High | Double-check fingerprint from Play Console. Test with `adb shell am start -W -a android.intent.action.VIEW -d "https://familychores.app/join?code=TEST"`. |
| Deep link lost during auth redirect | Low | High | DeepLinkRedirectCubit persists the URI in memory. Covered by integration test DL-IT-004. |
| Cold start deep link missed due to race condition with Firebase init | Medium | Medium | Check initial link after Firebase and DI initialization completes. Await all init before checking. |
| `app_links` package breaking change in future version | Low | Low | Pin version in pubspec.yaml. Abstract behind DeepLinkService interface. |
| Share sheet not working on all devices | Low | Low | `share_plus` is well-maintained. Fallback: copy link to clipboard with SnackBar. |

---

## 12. Implementation Recommendations

### 12.1 Prototype Checklist

1. **What can a user do at the end of this phase that they could not do before?** As Marcus, I can tap "Share Invite Link" after creating my family, send the link to Sofia via iMessage, and Sofia can tap the link to open the app directly on the Join Family screen with the code pre-filled.

2. **Which screens are delivered?** No new screens. The JoinFamilyScreen (already in spec 10) is enhanced with deep link pre-fill. The FamilySetupScreen gets a "Share Invite Link" button.

3. **What is the minimum data flow?** Marcus taps "Share" -> Flutter calls `generateInviteCode` Cloud Function -> Function returns code + shareableUrl -> Share sheet shows URL -> Sofia taps URL -> OS opens app via Universal Link / App Link -> go_router matches `/join` -> Redirects to `/family-setup/join?code=ABC123` -> JoinFamilyScreen renders with code pre-filled.

4. **What is the offline behavior?** Generating the shareable link requires internet (Cloud Function call). Tapping a deep link opens the app regardless of connectivity, but joining requires internet. If offline, JoinFamilyScreen shows the pre-filled code but the "Join" button is disabled with "Requires internet" tooltip.

5. **What does "done" look like?** A tester on Device A creates a family, taps "Share Invite Link", sends the link via messaging app. A tester on Device B taps the link, the app opens to the Join Family screen with the code pre-filled. The tester taps "Join" and is added to the family.

### 12.2 Suggested Order of Implementation

1. Add `app_links` and `share_plus` dependencies to `pubspec.yaml`.
2. Create `DeepLinkService` interface and `DeepLinkServiceImpl`.
3. Create `DeepLinkRedirectCubit`.
4. Register both in DI via injectable.
5. Create Firebase Hosting `public/` directory with AASA and assetlinks.json files.
6. Update `firebase.json` with hosting configuration.
7. Deploy hosting: `firebase deploy --only hosting`.
8. Add iOS entitlements and Info.plist URL scheme.
9. Add Android intent filters to AndroidManifest.xml.
10. Update `app_router.dart` with `/join` route and `JoinFamilyScreen` code parameter.
11. Update AuthGuard with deep link awareness.
12. Add deep link listener in `app.dart`.
13. Update `main.dart` cold start handling.
14. Update `generateInviteCode` Cloud Function to return `shareableUrl`.
15. Add share button to FamilySetupScreen / SettingsScreen.
16. Write unit tests for DeepLinkServiceImpl and DeepLinkRedirectCubit.
17. Write widget tests for JoinFamilyScreen with pre-filled code.
18. Write integration tests for cold start and warm start deep link scenarios.
19. Test on real iOS and Android devices.

### 12.3 Estimated Effort

**T-shirt size: M** (3-4 days)

Platform configuration (AASA, assetlinks, entitlements, manifests) takes the most time due to manual verification on real devices. The Flutter code is straightforward. Testing deep links requires real devices or emulators with specific configurations.

---

## 13. Open Questions

- [ ] Is the domain `familychores.app` registered and configured for Firebase Hosting?
- [ ] What is the Apple Developer Team ID for the AASA file?
- [ ] What is the Android signing key SHA-256 fingerprint for the assetlinks.json file?
- [ ] Should the share message be customizable, or is a fixed message ("Join our family on Family Chores! {url}") sufficient for Phase 2?
- [ ] Should tapping a deep link when the user already has a family offer to leave the current family, or just show an error? (Phase 2: error only, since multi-family is not supported.)

---

## 14. References

- `specs/08_phase2_foundations.md` -- Phase 2 router and dependencies
- `specs/10_family_onboarding.md` -- JoinFamilyScreen, FamilyBloc
- `specs/14_cloud_functions_invite.md` -- generateInviteCode Cloud Function
- `specs/15_phase2_test_plan.md` -- Test infrastructure and conventions
- [app_links package](https://pub.dev/packages/app_links) -- Flutter deep link handling
- [share_plus package](https://pub.dev/packages/share_plus) -- System share sheet
- [Apple Universal Links](https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content) -- Apple documentation
- [Android App Links](https://developer.android.com/training/app-links) -- Android documentation

---

*Generated by Software Architect Analyst*
*Date: 2026-03-09*
