# Phase 2 Test Plan

## 1. Overview

### 1.1 Summary

This specification defines the complete test plan for Phase 2: Auth & Family Onboarding. It consolidates all test scenarios from the individual Phase 2 specs (08 through 14) into a unified plan, adds integration tests, E2E tests, test infrastructure (fixtures, mocks, helpers), and defines coverage targets. Every test traces back to a requirement in the corresponding component spec. Phase 2 introduces the first user-facing features, making thorough testing critical -- these are the flows real users will encounter on their first interaction with the app.

### 1.2 Business Context

Phase 2 delivers the onboarding experience: sign-up, family creation, member management, profile switching, and PIN security. A bug in any of these flows means a user cannot get started -- the highest-friction failure mode. The test plan ensures that all happy paths work flawlessly, error states are handled gracefully, offline scenarios degrade predictably, and security rules prevent unauthorized access. The development rules mandate 80% minimum coverage on business logic, and this test plan is designed to exceed that target.

### 1.3 Scope

**In scope:**
- Unit tests for all BLoCs, Cubits, and Repositories
- Widget tests for all Phase 2 screens
- Integration tests for auth flow, family creation, and member management
- Route guard tests (AuthGuard, PinGuard)
- Firestore security rules tests
- Cloud Function unit tests
- E2E test for complete onboarding flow
- Test fixtures, mock factories, and helpers
- Coverage targets and enforcement

**Out of scope:**
- Performance testing (Phase 8)
- Accessibility testing beyond basic semantics (Phase 7)
- Visual regression testing (Phase 8)
- Load testing on Cloud Functions (Phase 8)

### 1.4 References

- `specs/07_phase1_test_plan.md` -- Phase 1 test infrastructure and conventions
- `specs/09_firebase_auth.md` -- Section 8 (Auth tests)
- `specs/10_family_onboarding.md` -- Section 9 (Family tests)
- `specs/11_member_profiles.md` -- Section 11 (Member tests)
- `specs/12_pin_system.md` -- Section 10 (PIN tests)
- `specs/13_firestore_security_rules.md` -- Section 6 (Rules tests)
- `specs/14_cloud_functions_invite.md` -- Section 9 (Function tests)
- `docs/development-rules.md` -- TDD, Arrange-Act-Assert, test naming

---

## 2. Test Infrastructure

### 2.1 Test Directory Structure

```
test/
  unit/
    features/
      auth/
        data/
          repositories/
            auth_repository_impl_test.dart
          datasources/
            auth_remote_datasource_test.dart
        domain/
          entities/
            app_user_test.dart
          failures/
            auth_failures_test.dart
        presentation/
          bloc/
            auth_bloc_test.dart
            onboarding_cubit_test.dart
      family/
        data/
          repositories/
            family_repository_impl_test.dart
            member_repository_impl_test.dart
          datasources/
            family_local_datasource_test.dart
            member_local_datasource_test.dart
        domain/
          entities/
            family_test.dart
            member_test.dart
        presentation/
          bloc/
            family_bloc_test.dart
            active_profile_cubit_test.dart
      pin/
        data/
          services/
            pin_hash_service_impl_test.dart
          repositories/
            pin_repository_impl_test.dart
        presentation/
          bloc/
            pin_cubit_test.dart
    core/
      deep_links/
        deep_link_service_impl_test.dart
        deep_link_redirect_cubit_test.dart
    app/
      router/
        guards/
          auth_guard_test.dart
          pin_guard_test.dart
  widget/
    features/
      auth/
        presentation/
          screens/
            sign_in_screen_test.dart
            sign_up_screen_test.dart
            onboarding_screen_test.dart
      family/
        presentation/
          screens/
            family_setup_screen_test.dart
            create_family_screen_test.dart
            join_family_screen_test.dart
            join_family_screen_deep_link_test.dart
            add_member_screen_test.dart
            profile_switcher_screen_test.dart
            settings_screen_test.dart
      pin/
        presentation/
          screens/
            pin_entry_screen_test.dart
            pin_setup_screen_test.dart
          widgets/
            pin_entry_widget_test.dart
  integration/
    auth/
      firebase_auth_integration_test.dart
    family/
      family_creation_integration_test.dart
      member_management_integration_test.dart
    deep_links/
      deep_link_navigation_test.dart
    flow/
      onboarding_flow_integration_test.dart
  e2e/
    onboarding_e2e_test.dart
  fixtures/
    auth_fixtures.dart
    family_fixtures.dart
    member_fixtures.dart
    pin_fixtures.dart
  helpers/
    test_helpers.dart
    mock_factories.dart
    pump_app.dart
    fake_auth_repository.dart
    fake_family_repository.dart
    fake_member_repository.dart
    fake_pin_repository.dart
```

### 2.2 Test Naming Convention

Following `docs/development-rules.md` Section 5.2, adapted to Dart:

```dart
group('AuthBloc', () {
  group('SignInWithEmailRequested', () {
    test('should emit AuthLoading then AuthAuthenticated on valid credentials', () {
      // Arrange-Act-Assert
    });
    test('should emit AuthLoading then AuthError on invalid credentials', () {
      // Arrange-Act-Assert
    });
  });
});
```

Pattern: `group('ClassName') > group('methodOrEvent') > test('should behavior')`.

### 2.3 Arrange-Act-Assert Convention

```dart
test('should emit AuthAuthenticated when sign-in succeeds', () {
  // Arrange
  final email = 'marcus@family.com';
  final password = 'securePass123';
  when(() => mockAuthRepo.signInWithEmail(
    email: email,
    password: password,
  )).thenAnswer((_) async => Result.success(authFixtures.marcus));

  // Act
  authBloc.add(SignInWithEmailRequested(email: email, password: password));

  // Assert
  expect(
    authBloc.stream,
    emitsInOrder([
      const AuthLoading(),
      AuthAuthenticated(authFixtures.marcus, hasFamily: true),
    ]),
  );
});
```

---

## 3. Test Fixtures

### 3.1 Auth Fixtures

```dart
// test/fixtures/auth_fixtures.dart
import 'package:family_chores_app/features/auth/domain/entities/app_user.dart';

abstract class AuthFixtures {
  static const marcus = AppUser(
    uid: 'uid-marcus-001',
    email: 'marcus@family.com',
    displayName: 'Marcus Johnson',
    photoUrl: null,
    createdAt: null,
    lastSignInAt: null,
  );

  static const sofia = AppUser(
    uid: 'uid-sofia-002',
    email: 'sofia@family.com',
    displayName: 'Sofia Johnson',
    photoUrl: null,
    createdAt: null,
    lastSignInAt: null,
  );

  static const validEmail = 'test@example.com';
  static const validPassword = 'securePass123';
  static const weakPassword = 'abc';
  static const invalidEmail = 'notanemail';
}
```

### 3.2 Family Fixtures

```dart
// test/fixtures/family_fixtures.dart
import 'package:family_chores_app/features/family/domain/entities/family.dart';

abstract class FamilyFixtures {
  static final johnsons = Family(
    id: '1',
    remoteId: 'remote-family-001',
    name: 'The Johnsons',
    createdBy: 'uid-marcus-001',
    createdAt: DateTime(2026, 3, 1),
    inviteCode: 'ABC123',
    inviteCodeExpiresAt: DateTime(2026, 3, 3),
    memberIds: ['uid-marcus-001', 'uid-sofia-002', 'uuid-alex', 'uuid-emma'],
  );

  static const familyName = 'The Johnsons';
  static const validInviteCode = 'ABC123';
  static const invalidInviteCode = 'XXXXXX';
  static const expiredInviteCode = 'EXPIR3';
}
```

### 3.3 Member Fixtures

```dart
// test/fixtures/member_fixtures.dart
import 'package:family_chores_app/core/enums/member_role.dart';
import 'package:family_chores_app/features/family/domain/entities/member.dart';

abstract class MemberFixtures {
  static final marcus = Member(
    id: '1',
    remoteId: 'uid-marcus-001',
    familyId: 'remote-family-001',
    name: 'Marcus',
    role: MemberRole.parent,
    age: 38,
    avatarSeed: 'avatar_bear',
    accentColor: '#A8D8EA',
    userId: 'uid-marcus-001',
    points: 120,
    currentStreak: 5,
    longestStreak: 14,
    hasPin: true,
    createdAt: DateTime(2026, 3, 1),
  );

  static final sofia = Member(
    id: '2',
    remoteId: 'uid-sofia-002',
    familyId: 'remote-family-001',
    name: 'Sofia',
    role: MemberRole.parent,
    age: 36,
    avatarSeed: 'avatar_owl',
    accentColor: '#F4A9A8',
    userId: 'uid-sofia-002',
    points: 95,
    currentStreak: 3,
    longestStreak: 10,
    hasPin: true,
    createdAt: DateTime(2026, 3, 1),
  );

  static final alex = Member(
    id: '3',
    remoteId: 'uuid-alex-003',
    familyId: 'remote-family-001',
    name: 'Alex',
    role: MemberRole.child,
    age: 10,
    avatarSeed: 'avatar_fox',
    accentColor: '#B8E6D0',
    userId: null,
    points: 75,
    currentStreak: 7,
    longestStreak: 7,
    hasPin: false,
    createdAt: DateTime(2026, 3, 1),
  );

  static final emma = Member(
    id: '4',
    remoteId: 'uuid-emma-004',
    familyId: 'remote-family-001',
    name: 'Emma',
    role: MemberRole.child,
    age: 3,
    avatarSeed: 'avatar_bunny',
    accentColor: '#C5B3E6',
    userId: null,
    points: 10,
    currentStreak: 1,
    longestStreak: 2,
    hasPin: false,
    createdAt: DateTime(2026, 3, 1),
  );

  static final allMembers = [marcus, sofia, alex, emma];
  static final parents = [marcus, sofia];
  static final children = [alex, emma];
}
```

### 3.4 PIN Fixtures

```dart
// test/fixtures/pin_fixtures.dart
abstract class PinFixtures {
  static const validPin = '1234';
  static const wrongPin = '5678';
  static const shortPin = '12';
  static const longPin = '1234567';
  static const sixDigitPin = '123456';

  static const salt = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
  // SHA-256 of "a1b2c3d4-e5f6-7890-abcd-ef12345678901234"
  static const validPinHash =
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
}
```

---

## 4. Mock Factories

### 4.1 Repository Mocks

```dart
// test/helpers/mock_factories.dart
import 'package:mocktail/mocktail.dart';

// Auth
class MockAuthRepository extends Mock implements AuthRepository {}
class MockAuthRemoteDatasource extends Mock implements AuthRemoteDatasource {}

// Family
class MockFamilyRepository extends Mock implements FamilyRepository {}
class MockFamilyLocalDatasource extends Mock implements FamilyLocalDatasource {}
class MockFamilyRemoteDatasource extends Mock implements FamilyRemoteDatasource {}

// Member
class MockMemberRepository extends Mock implements MemberRepository {}
class MockMemberLocalDatasource extends Mock implements MemberLocalDatasource {}
class MockMemberRemoteDatasource extends Mock implements MemberRemoteDatasource {}

// PIN
class MockPinRepository extends Mock implements PinRepository {}
class MockPinHashService extends Mock implements PinHashService {}
class MockLocalAuthentication extends Mock implements LocalAuthentication {}

// Infrastructure
class MockSyncEngine extends Mock implements SyncEngine {}
class MockIdGenerator extends Mock implements IdGenerator {}
class MockSharedPreferences extends Mock implements SharedPreferences {}
class MockAppDatabase extends Mock implements AppDatabase {}

// Firebase (for integration tests)
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockGoogleSignIn extends Mock implements GoogleSignIn {}
class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}
```

### 4.2 Fake Implementations

```dart
// test/helpers/fake_auth_repository.dart
import 'dart:async';
import 'package:family_chores_app/core/utils/result.dart';
import 'package:family_chores_app/features/auth/domain/entities/app_user.dart';
import 'package:family_chores_app/features/auth/domain/repositories/auth_repository.dart';

/// In-memory fake for testing AuthBloc without mocking.
class FakeAuthRepository implements AuthRepository {
  AppUser? _currentUser;
  final _controller = StreamController<AppUser?>.broadcast();

  void setCurrentUser(AppUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  @override
  Stream<AppUser?> get currentUser => _controller.stream;

  @override
  AppUser? get currentUserSync => _currentUser;

  @override
  Future<Result<AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    // Simulates sign-in with deterministic behavior
    if (email == 'marcus@family.com' && password == 'password123') {
      final user = AuthFixtures.marcus;
      setCurrentUser(user);
      return Result.success(user);
    }
    return const Result.failure(InvalidCredentialsFailure());
  }

  // ... other methods with similar fake behavior
}
```

### 4.3 Widget Test Helper

```dart
// test/helpers/pump_app.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Pumps a widget with all required providers for testing.
extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    Widget widget, {
    AuthBloc? authBloc,
    FamilyBloc? familyBloc,
    ActiveProfileCubit? activeProfileCubit,
    PinCubit? pinCubit,
    GoRouter? router,
  }) async {
    await pumpWidget(
      MultiBlocProvider(
        providers: [
          if (authBloc != null)
            BlocProvider<AuthBloc>.value(value: authBloc),
          if (familyBloc != null)
            BlocProvider<FamilyBloc>.value(value: familyBloc),
          if (activeProfileCubit != null)
            BlocProvider<ActiveProfileCubit>.value(value: activeProfileCubit),
          if (pinCubit != null)
            BlocProvider<PinCubit>.value(value: pinCubit),
        ],
        child: MaterialApp(
          home: widget,
        ),
      ),
    );
  }
}
```

---

## 5. Unit Test Inventory

### 5.1 Auth Unit Tests

Source: `specs/09_firebase_auth.md` Section 8

| Test File | Test Count | Component | Coverage Target |
|-----------|-----------|-----------|----------------|
| `auth_bloc_test.dart` | 13 | AuthBloc | 95% |
| `auth_repository_impl_test.dart` | 6 | AuthRepositoryImpl | 90% |
| `app_user_test.dart` | 3 | AppUser entity | 100% |
| `auth_failures_test.dart` | 3 | AuthenticationFailure types | 100% |

**Key test scenarios:**

| ID | Test | States Verified |
|----|------|----------------|
| AUTH-FT-001 | Initial state | AuthInitial |
| AUTH-FT-002 | Auth started with persisted user | AuthAuthenticated |
| AUTH-FT-003 | Auth started without user | AuthUnauthenticated |
| AUTH-FT-004 | Sign in success | AuthLoading -> AuthAuthenticated |
| AUTH-FT-005 | Sign in wrong password | AuthLoading -> AuthError(InvalidCredentials) |
| AUTH-FT-006 | Sign in network error | AuthLoading -> AuthError(NetworkError) |
| AUTH-FT-007 | Sign up success | AuthLoading -> AuthAuthenticated(hasFamily: false) |
| AUTH-FT-008 | Sign up email in use | AuthLoading -> AuthError(EmailAlreadyInUse) |
| AUTH-FT-009 | Sign up weak password | AuthLoading -> AuthError(WeakPassword) |
| AUTH-FT-010 | Google sign-in success | AuthLoading -> AuthAuthenticated |
| AUTH-FT-011 | Google sign-in cancelled | AuthLoading -> AuthError(Cancelled) |
| AUTH-FT-012 | Sign out | AuthLoading -> AuthUnauthenticated |
| AUTH-FT-013 | External auth state change | AuthUnauthenticated (when token invalidated) |

### 5.2 Family Unit Tests

Source: `specs/10_family_onboarding.md` Section 9

| Test File | Test Count | Component | Coverage Target |
|-----------|-----------|-----------|----------------|
| `family_bloc_test.dart` | 8 | FamilyBloc | 90% |
| `family_repository_impl_test.dart` | 6 | FamilyRepositoryImpl | 90% |
| `family_local_datasource_test.dart` | 5 | FamilyLocalDatasource | 85% |
| `family_test.dart` | 3 | Family entity | 100% |
| `onboarding_cubit_test.dart` | 3 | OnboardingCubit | 100% |

**Key test scenarios:**

| ID | Test | States Verified |
|----|------|----------------|
| FAM-FT-001 | Create family success | FamilyCreated |
| FAM-FT-002 | Create family writes to Drift | Drift row with syncStatus=pending |
| FAM-FT-003 | Create family queues sync | SyncOperationsTable entry |
| FAM-FT-004 | Create family creates parent member | MembersTable row |
| FAM-FT-005 | Join family success | FamilyJoined |
| FAM-FT-006 | Join with invalid code | FamilyError |
| FAM-FT-007 | Join with expired code | FamilyError |
| FAM-FT-008 | Get family found | FamilyLoaded |
| FAM-FT-009 | Get family not found | FamilyNotFound |
| FAM-FT-010 | Onboarding marks as seen | SharedPrefs updated |
| FAM-FT-011 | Onboarding not shown again | hasSeenOnboarding check |

### 5.3 Member Unit Tests

Source: `specs/11_member_profiles.md` Section 11

| Test File | Test Count | Component | Coverage Target |
|-----------|-----------|-----------|----------------|
| `active_profile_cubit_test.dart` | 6 | ActiveProfileCubit | 95% |
| `member_repository_impl_test.dart` | 8 | MemberRepositoryImpl | 90% |
| `member_local_datasource_test.dart` | 5 | MemberLocalDatasource | 85% |
| `member_test.dart` | 6 | Member entity | 100% |

**Key test scenarios:**

| ID | Test | States Verified |
|----|------|----------------|
| MEM-FT-001 | Create child member | Drift row, sync queued |
| MEM-FT-005 | Switch to child profile | ActiveProfileCubit emits child |
| MEM-FT-007 | Profile persists across restart | SharedPrefs -> loadActiveProfile |
| MEM-FT-008 | Profile cleared on sign-out | emit(null) |
| MEM-FT-011 | Cannot delete creator | Result.failure |
| MEM-FT-012 | Age group: 3 = toddler | AgeGroup.toddler |
| MEM-FT-013 | Age group: 10 = child | AgeGroup.child |

### 5.4 PIN Unit Tests

Source: `specs/12_pin_system.md` Section 10

| Test File | Test Count | Component | Coverage Target |
|-----------|-----------|-----------|----------------|
| `pin_hash_service_impl_test.dart` | 8 | PinHashServiceImpl | 100% |
| `pin_cubit_test.dart` | 15 | PinCubit | 95% |
| `pin_repository_impl_test.dart` | 8 | PinRepositoryImpl | 90% |

**Key test scenarios:**

| ID | Test | States Verified |
|----|------|----------------|
| PIN-FT-001 | Generate salt UUID | 36-char string |
| PIN-FT-003 | Hash deterministic | Same output for same input |
| PIN-FT-006 | Verify correct PIN | true |
| PIN-FT-007 | Verify wrong PIN | false |
| PIN-FT-011 | Correct PIN -> PinVerified | PinLoading -> PinVerified |
| PIN-FT-012 | Wrong PIN -> PinFailed | PinLoading -> PinFailed(4) |
| PIN-FT-013 | 5th wrong -> PinLocked | PinLocked(5 min) |
| PIN-FT-014 | Lockout escalation | 10 min on second lockout |
| PIN-FT-017 | Session expires | isSessionActive = false after 5 min |
| PIN-FT-018 | App background kills session | PinInitial |
| PIN-FT-020 | PIN mismatch on setup | PinSetupError |

### 5.5 Route Guard Unit Tests

| Test File | Test Count | Component | Coverage Target |
|-----------|-----------|-----------|----------------|
| `auth_guard_test.dart` | 5 | AuthGuard | 100% |
| `pin_guard_test.dart` | 4 | PinGuard | 100% |

**Key test scenarios:**

| ID | Test |
|----|------|
| P2F-FT-005 | AuthGuard redirects unauthenticated to /sign-in |
| P2F-FT-006 | AuthGuard allows authenticated through |
| P2F-FT-007 | AuthGuard redirects authenticated from auth screens |
| PIN-FT-040 | PinGuard redirects parent to /pin |
| PIN-FT-041 | PinGuard allows child through |
| PIN-FT-042 | PinGuard allows verified parent through |
| PIN-FT-043 | PinGuard redirects after session expiry |

---

## 6. Widget Test Inventory

### 6.1 Screen Widget Tests

| Test File | Test Count | Screen | Coverage Target |
|-----------|-----------|--------|----------------|
| `sign_in_screen_test.dart` | 9 | SignInScreen | 85% |
| `sign_up_screen_test.dart` | 7 | SignUpScreen | 85% |
| `onboarding_screen_test.dart` | 4 | OnboardingScreen | 80% |
| `family_setup_screen_test.dart` | 3 | FamilySetupScreen | 80% |
| `create_family_screen_test.dart` | 4 | CreateFamilyScreen | 80% |
| `join_family_screen_test.dart` | 4 | JoinFamilyScreen | 80% |
| `add_member_screen_test.dart` | 6 | AddMemberScreen | 80% |
| `profile_switcher_screen_test.dart` | 7 | ProfileSwitcherScreen | 85% |
| `settings_screen_test.dart` | 3 | SettingsScreen | 75% |
| `pin_entry_screen_test.dart` | 5 | PinEntryScreen | 80% |
| `pin_setup_screen_test.dart` | 4 | PinSetupScreen | 80% |
| `pin_entry_widget_test.dart` | 7 | PinEntryWidget | 85% |

### 6.2 Widget Test Strategy

Widget tests verify:
1. **Rendering:** All expected elements are visible on initial load.
2. **Validation:** Form fields show appropriate error messages.
3. **State reflection:** Loading, error, and success states are displayed correctly.
4. **Navigation:** Tapping buttons triggers correct navigation.
5. **Interaction:** Buttons, inputs, and selections respond correctly.

Widget tests do NOT verify:
- Network calls (mocked at the BLoC level)
- Database writes (mocked at the repository level)
- Platform-specific behavior (biometric prompts, keyboard behavior)

### 6.3 Key Widget Test Scenarios

**SignInScreen:**

| Test | Action | Expected |
|------|--------|----------|
| Renders all elements | Mount screen | Email, password, sign-in button, Google button, sign-up link visible |
| Empty email validation | Tap sign-in with empty email | "Please enter your email" shown |
| Invalid email validation | Enter "notanemail", tap sign-in | "Please enter a valid email" shown |
| Loading state | AuthLoading emitted | Button shows loading indicator, inputs disabled |
| Error SnackBar | AuthError emitted | SnackBar with error message visible |

**ProfileSwitcherScreen:**

| Test | Action | Expected |
|------|--------|----------|
| Shows all members | Mount with 4 members | 4 avatars with names visible |
| Active indicator | Marcus active | Marcus avatar has colored ring |
| Tap child switches | Tap Alex avatar | ActiveProfileCubit.switchProfile called |
| Tap parent routes to PIN | Tap Sofia avatar | Navigation to /pin triggered |
| Add member card | Parent active | "+ Add Member" card visible |

**PinEntryWidget:**

| Test | Action | Expected |
|------|--------|----------|
| Number pad renders | Mount widget | Digits 0-9, backspace visible |
| Dots fill | Tap 1, 2, 3, 4 | 4 dots filled |
| Backspace removes | 3 dots filled, tap backspace | 2 dots filled |
| Completed callback | Enter 4th digit | onCompleted called with "1234" |
| Shake on error | PinFailed state | Dots animate horizontally |
| Lockout disables pad | PinLocked state | Number buttons disabled |

---

## 7. Integration Tests

### 7.1 Firebase Auth Integration Test

```dart
// test/integration/auth/firebase_auth_integration_test.dart
//
// Tests against Firebase Auth emulator (port 9099).
// Verifies actual Firebase Auth behavior, not mocked.
//
// Setup:
// 1. Start emulators: firebase emulators:start --only auth
// 2. Configure test to connect to emulator
//
// Tests:
// - Create account with email/password -> verify user exists
// - Sign in with created account -> returns correct user data
// - Sign in with wrong password -> throws expected error code
// - Sign out -> auth state changes to null
// - Delete account -> user no longer exists
// - Create duplicate account -> throws email-already-in-use
```

### 7.2 Family Creation Integration Test

```dart
// test/integration/family/family_creation_integration_test.dart
//
// Tests the full family creation flow with real Drift database.
// Does NOT use Firebase (mocked at remote datasource level).
//
// Tests:
// - Create family -> Drift row exists with correct fields
// - Create family -> sync operation queued in SyncOperationsTable
// - Create family -> creator member row exists with role=parent
// - Get family for user -> returns created family
// - Create family offline -> Drift write succeeds, sync status=pending
// - Watch family -> stream emits on update
```

### 7.3 Member Management Integration Test

```dart
// test/integration/family/member_management_integration_test.dart
//
// Tests member CRUD with real Drift database.
//
// Tests:
// - Add 4 members -> all exist in MembersTable
// - Get members for family -> returns all 4
// - Watch members -> stream emits on add/update/delete
// - Update member age -> Drift row updated, sync queued
// - Delete member -> Drift row removed, sync queued
// - Active profile persists across cubit recreation
```

### 7.4 Onboarding Flow Integration Test

```dart
// test/integration/flow/onboarding_flow_integration_test.dart
//
// Tests the complete onboarding flow with real Drift and mocked Firebase.
//
// Flow under test:
// 1. App starts -> splash screen
// 2. No auth -> redirect to onboarding (first time)
// 3. Complete onboarding -> redirect to sign-in
// 4. Sign up -> authenticated
// 5. No family -> redirect to family setup
// 6. Create family -> family created in Drift
// 7. Add 3 members -> members created in Drift
// 8. Set PIN -> PIN hash stored
// 9. Profile switcher -> all 4 members visible
// 10. Switch profile -> active profile updates
//
// Assertions:
// - Each redirect happens at the correct point
// - Drift contains expected data at each step
// - SharedPreferences updated correctly (onboarding seen, active profile)
```

---

## 8. Security Rules Tests

Source: `specs/13_firestore_security_rules.md` Section 6

| Test File | Test Count | Coverage |
|-----------|-----------|----------|
| `family_rules_test.ts` | 8 | Family document CRUD |
| `member_rules_test.ts` | 11 | Member document CRUD + field-level |
| `placeholder_rules_test.ts` | 3 | Phase 3+ deny-all |

**Testing approach:** Uses `@firebase/rules-unit-testing` against the Firestore emulator. Each test creates authenticated and unauthenticated contexts and asserts `assertSucceeds` or `assertFails`.

**Full scenario list from spec 13:**

| ID | Scenario | Expected |
|----|----------|----------|
| SEC-FT-001 | Unauthenticated read family | DENIED |
| SEC-FT-002 | Authenticated read family | ALLOWED |
| SEC-FT-003 | Create family with matching UID | ALLOWED |
| SEC-FT-004 | Create family with mismatched UID | DENIED |
| SEC-FT-005 | Parent updates family name | ALLOWED |
| SEC-FT-006 | Non-member updates family | DENIED |
| SEC-FT-007 | Client writes inviteCode | DENIED |
| SEC-FT-008 | Delete family | DENIED |
| SEC-FT-009 | Family member reads members | ALLOWED |
| SEC-FT-010 | Non-member reads members | DENIED |
| SEC-FT-011 | Parent creates member | ALLOWED |
| SEC-FT-012 | Child creates member | DENIED |
| SEC-FT-013 | Parent updates any member | ALLOWED |
| SEC-FT-014 | Member updates own avatar | ALLOWED |
| SEC-FT-015 | Member updates own role | DENIED |
| SEC-FT-016 | Member updates own pinHash | ALLOWED |
| SEC-FT-017 | Non-parent updates other's pinHash | DENIED |
| SEC-FT-018 | Parent deletes child member | ALLOWED |
| SEC-FT-019 | Parent deletes self | DENIED |
| SEC-FT-020 | Read tasks (placeholder) | DENIED |
| SEC-FT-021 | Write rewards (placeholder) | DENIED |
| SEC-FT-022 | Create family missing required fields | DENIED |

---

## 9. Cloud Function Tests

Source: `specs/14_cloud_functions_invite.md` Section 9

| Test File | Test Count | Function |
|-----------|-----------|----------|
| `generate-invite-code.test.ts` | 5 | generateInviteCode |
| `validate-and-join.test.ts` | 6 | validateAndJoinFamily |
| `cleanup-expired.test.ts` | 3 | cleanupExpiredInviteCodes |

**Testing approach:** Uses `firebase-functions-test` SDK with the Firestore emulator. Functions are tested with both authenticated and unauthenticated contexts.

---

## 9.5 Deep Link Tests

Source: `specs/16_deep_links.md` Section 10

### 9.5.1 Unit Tests

| Test File | Test Count | Component | Coverage Target |
|-----------|-----------|-----------|----------------|
| `deep_link_service_impl_test.dart` | 5 | DeepLinkServiceImpl | 90% |
| `deep_link_redirect_cubit_test.dart` | 5 | DeepLinkRedirectCubit | 100% |

**DeepLinkServiceImpl scenarios:**

| ID | Test | States Verified |
|----|------|----------------|
| DL-UT-001 | getInitialLink returns URI when app launched via deep link | Returns URI |
| DL-UT-002 | getInitialLink returns null when app launched normally | Returns null |
| DL-UT-003 | incomingLinks emits URI on warm start deep link | URI emitted on stream |
| DL-UT-004 | getInitialLink handles platform error gracefully | Returns null |
| DL-UT-005 | incomingLinks emits multiple URIs in order | Both URIs emitted |

**DeepLinkRedirectCubit scenarios:**

| ID | Test | States Verified |
|----|------|----------------|
| DL-UT-006 | Initial state is DeepLinkRedirectInitial | DeepLinkRedirectInitial |
| DL-UT-007 | setPendingDeepLink emits DeepLinkRedirectPending | DeepLinkRedirectPending(uri) |
| DL-UT-008 | consumePendingDeepLink returns URI and emits Consumed | Returns URI, DeepLinkRedirectConsumed |
| DL-UT-009 | consumePendingDeepLink returns null when no pending link | Returns null, state unchanged |
| DL-UT-010 | clear resets state to DeepLinkRedirectInitial | DeepLinkRedirectInitial |

### 9.5.2 Widget Tests

| Test File | Test Count | Screen | Coverage Target |
|-----------|-----------|--------|----------------|
| `join_family_screen_deep_link_test.dart` | 3 | JoinFamilyScreen (deep link) | 80% |

**JoinFamilyScreen deep link scenarios:**

| ID | Test | Action | Expected |
|----|------|--------|----------|
| DL-WT-001 | Code pre-filled from deep link | Render with `initialCode: 'ABC123'` | Code input shows "ABC123" |
| DL-WT-002 | Invalid code format shows inline error | Render with `initialCode: 'XY'` | Error message displayed |
| DL-WT-003 | No initial code renders empty input | Render with `initialCode: null` | Code input empty |

### 9.5.3 Integration Tests

| Test File | Test Count | Scenario |
|-----------|-----------|----------|
| `deep_link_navigation_test.dart` | 4 | Deep link navigation flows |

**Deep link integration scenarios:**

| ID | Test | Given | When | Then |
|----|------|-------|------|------|
| DL-IT-001 | Cold start with valid deep link | App not running | Deep link tapped | App launches, navigates to JoinFamilyScreen with code pre-filled |
| DL-IT-002 | Cold start with expired code | App not running | Deep link with expired code tapped | JoinFamilyScreen shows, submit returns error |
| DL-IT-003 | Warm start with valid deep link (authenticated) | App in background, user authenticated | Deep link tapped | Navigates to JoinFamilyScreen with code pre-filled |
| DL-IT-004 | Warm start unauthenticated with deep link | App in background, not authenticated | Deep link tapped | Redirects to sign-in, preserves URI, redirects to join after auth |

### 9.5.4 Test File Locations

```
test/
  unit/
    core/
      deep_links/
        deep_link_service_impl_test.dart
        deep_link_redirect_cubit_test.dart
  widget/
    features/
      family/
        presentation/
          screens/
            join_family_screen_deep_link_test.dart
  integration/
    deep_links/
      deep_link_navigation_test.dart
```

---

## 10. E2E Test

### 10.1 Complete Onboarding E2E

```dart
// test/e2e/onboarding_e2e_test.dart
//
// Full end-to-end test of the onboarding experience.
// Runs against Firebase emulators (auth + firestore + functions).
//
// Prerequisites:
// - firebase emulators:start --only auth,firestore,functions
// - Flutter integration test driver
//
// Scenario: Marcus installs app and sets up family
//
// Steps:
// 1. Launch app -> see splash screen
// 2. Wait for splash -> navigate to onboarding carousel
// 3. Swipe through 3 slides -> tap "Get Started"
// 4. See sign-up screen -> enter name "Marcus", email, password
// 5. Tap "Create Account" -> authenticated
// 6. See family setup screen -> tap "Create a family"
// 7. Enter "The Johnsons" -> tap "Create Family"
// 8. See add member screen -> add "Sofia" (parent, age 36)
// 9. Add "Alex" (child, age 10) -> add "Emma" (child, age 3)
// 10. Tap "Done" -> navigate to PIN setup
// 11. Enter PIN 1-2-3-4 -> confirm 1-2-3-4
// 12. See profile switcher -> 4 avatars visible
// 13. Tap Alex -> profile switches to Alex
// 14. Tap Marcus -> PIN entry appears
// 15. Enter 1-2-3-4 -> profile switches to Marcus
// 16. See home screen (stub) -> "The Johnsons" in app bar
//
// Assertions at each step:
// - Correct screen visible
// - Correct data in Drift
// - Correct UI state
// - Correct routing
//
// Duration target: < 60 seconds
```

### 10.2 E2E Test Infrastructure

```dart
// Run with:
// flutter test integration_test/onboarding_e2e_test.dart \
//   --dart-define=USE_FIREBASE_EMULATOR=true

// Or using flutter drive:
// flutter drive --target=test/e2e/onboarding_e2e_test.dart \
//   --driver=test_driver/integration_test_driver.dart
```

---

## 11. Coverage Targets

### 11.1 Per-Component Targets

| Component | Type | Target | Rationale |
|-----------|------|--------|-----------|
| AuthBloc | BLoC | 95% | Critical path, all states must be tested |
| AuthRepositoryImpl | Repository | 90% | Firebase exception mapping must be comprehensive |
| FamilyBloc | BLoC | 90% | Core business logic |
| FamilyRepositoryImpl | Repository | 90% | Drift + sync integration |
| MemberRepositoryImpl | Repository | 90% | CRUD with sync |
| ActiveProfileCubit | Cubit | 95% | Simple but critical for profile switching |
| PinCubit | Cubit | 95% | Security-critical, lockout logic |
| PinHashServiceImpl | Service | 100% | Security-critical, must be perfectly tested |
| PinRepositoryImpl | Repository | 90% | Hash storage and verification |
| AuthGuard | Guard | 100% | Routing logic, all paths covered |
| PinGuard | Guard | 100% | Routing logic, all paths covered |
| DeepLinkServiceImpl | Service | 90% | Platform bridge, error handling |
| DeepLinkRedirectCubit | Cubit | 100% | Simple state machine, all paths covered |
| Domain entities | Entity | 100% | Value objects, simple but must be correct |
| Screen widgets | UI | 80% | Rendering and state reflection |

### 11.2 Overall Phase 2 Target

**Minimum: 80% line coverage on business logic** (per `docs/development-rules.md`).
**Goal: 90%+ on domain and data layers, 80%+ on presentation layer.**

### 11.3 Coverage Enforcement

```bash
# Generate coverage
flutter test --coverage

# Check coverage threshold (using lcov or custom script)
# Fail CI if business logic coverage < 80%
```

---

## 12. Test Execution Order

### 12.1 Local Development

```bash
# 1. Unit tests (fast, no dependencies)
flutter test test/unit/

# 2. Widget tests (needs Flutter framework, no Firebase)
flutter test test/widget/

# 3. Integration tests (needs Drift, may need emulators)
flutter test test/integration/

# 4. Security rules tests (needs emulators)
cd functions && npm test
firebase emulators:exec --only firestore "npx jest test/security-rules/"

# 5. E2E tests (needs all emulators running)
firebase emulators:start &
flutter test test/e2e/
```

### 12.2 CI Pipeline

```yaml
# .github/workflows/test.yml
jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter test test/unit/ test/widget/ --coverage
      - run: |
          COVERAGE=$(lcov --summary coverage/lcov.info | grep "lines" | awk '{print $2}' | sed 's/%//')
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "Coverage $COVERAGE% is below 80% threshold"
            exit 1
          fi

  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter test test/integration/

  security-rules-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm install -g firebase-tools
      - run: cd functions && npm install
      - run: |
          firebase emulators:exec --only firestore \
            "npx jest test/security-rules/ --forceExit"

  cloud-function-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: cd functions && npm install
      - run: cd functions && npm test
```

---

## 13. Test Data Management

### 13.1 Drift Test Database

```dart
// For integration tests that need a real Drift database:
import 'package:drift/native.dart';

AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

// Teardown:
// await db.close();
```

### 13.2 Firebase Emulator Data

```bash
# Seed emulator with test data
firebase emulators:start --import=./test/emulator-data

# Export data after manual setup
firebase emulators:export ./test/emulator-data
```

### 13.3 Test Isolation

- Each unit test creates fresh mocks. No shared state between tests.
- Each integration test creates a new in-memory Drift database. Closed after test.
- Firebase emulator data is cleared between test suites using `testEnv.clearFirestore()`.
- SharedPreferences are mocked with a fresh `MockSharedPreferences` per test.

---

## 14. Impact Analysis

### 14.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| `test/` directory | New/Modified | Low | 40+ new test files |
| `test/fixtures/` | New | Low | 4 fixture files |
| `test/helpers/` | Modified | Low | New mock factories and helpers |
| `functions/test/` | New | Low | 3 Jest test files |
| `test/security-rules/` | New | Low | 3 TypeScript test files |
| CI pipeline | Modified | Medium | New test jobs added |

### 14.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Test suite too slow (> 5 min for unit+widget) | Medium | Medium | Keep unit tests fast (no I/O). Parallelize in CI. |
| Emulator tests flaky due to port conflicts | Medium | Low | Use unique ports per CI job. Add retry logic. |
| Drift in-memory DB behavior differs from file-based | Low | Medium | Run critical paths against file-based DB in integration tests. |
| Mock setup diverges from real implementation | Medium | Medium | Prefer fakes over mocks for repositories. Keep mocks minimal. |
| Coverage metric misleading (trivial lines counted) | Low | Low | Focus on branch coverage for complex logic, not just line coverage. |

---

## 15. Implementation Recommendations

### 15.1 Suggested Approach

1. Set up test fixtures and mock factories first -- they are used by all tests.
2. Write unit tests for domain entities and hash service (simplest, fastest feedback).
3. Write unit tests for BLoCs and Cubits (most business logic lives here).
4. Write unit tests for repositories (verify Drift interactions with mock DB).
5. Write widget tests in parallel with screen implementation (TDD).
6. Write route guard tests.
7. Write integration tests after all components are implemented.
8. Write security rules tests after rules are deployed to emulator.
9. Write Cloud Function tests after functions are implemented.
10. Write E2E test as the final validation.

### 15.2 Estimated Effort

**T-shirt size: L** (5-7 days)

Testing is the largest single effort in Phase 2. It is also the most valuable -- Phase 2 components are the foundation for all subsequent phases. Investing here prevents exponential debugging costs later.

---

## 16. Test Summary

### 16.1 Test Count by Type

| Test Type | File Count | Estimated Test Count |
|-----------|-----------|---------------------|
| Unit tests (Dart) | 22 | ~130 |
| Widget tests (Dart) | 13 | ~66 |
| Integration tests (Dart) | 5 | ~29 |
| Security rules tests (TypeScript) | 3 | ~22 |
| Cloud Function tests (TypeScript) | 3 | ~14 |
| E2E tests (Dart) | 1 | ~1 (multi-step) |
| **Total** | **47** | **~262** |

### 16.2 Traceability Matrix

Every test traces back to a functional requirement:

| Spec | Requirement IDs | Test IDs |
|------|----------------|----------|
| 08 (Foundation) | P2F-001 through P2F-013 | P2F-FT-001 through P2F-FT-012 |
| 09 (Auth) | AUTH-001 through AUTH-012 | AUTH-FT-001 through AUTH-FT-038 |
| 10 (Family) | FAM-001 through FAM-011 | FAM-FT-001 through FAM-FT-014 |
| 11 (Members) | MEM-001 through MEM-015 | MEM-FT-001 through MEM-FT-027 |
| 12 (PIN) | PIN-001 through PIN-015 | PIN-FT-001 through PIN-FT-043 |
| 13 (Security) | SEC-001 through SEC-013 | SEC-FT-001 through SEC-FT-022 |
| 14 (Functions) | CF-001 through CF-011 | CF-FT-001 through CF-FT-016 |
| 16 (Deep Links) | DL-001 through DL-011 | DL-UT-001 through DL-UT-010, DL-WT-001 through DL-WT-003, DL-IT-001 through DL-IT-004 |

---

## 17. Open Questions

- [ ] Should integration tests run against Firebase emulators in CI, or only locally? Emulator setup in CI adds complexity but increases confidence.
- [ ] Should widget tests use golden image testing (screenshot comparison) for visual regression?
- [ ] Should test coverage be enforced per-file or per-package? Per-package is more practical but allows individual files to fall below threshold.
- [ ] Should we add mutation testing (e.g., `stryker-mutator`) to catch tests that pass trivially?
- [ ] Should E2E tests run on real devices via Firebase Test Lab, or only on emulators/simulators?

---

*Generated by Software Architect Analyst*
*Date: 2026-03-09*
