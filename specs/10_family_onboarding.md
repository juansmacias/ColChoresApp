# Family Setup & Onboarding Flow

## 1. Overview

### 1.1 Summary

This specification defines the family onboarding flow -- the critical path from a freshly authenticated user to a fully configured family. It covers the onboarding carousel, family creation, family join (via invite code), the Family domain entity, FamilyRepository interface and implementation, FamilyBloc state management, Firestore sync for family data, and the routing logic that ensures every authenticated user either has a family or is guided to create/join one.

### 1.2 Business Context

The onboarding experience is the first impression. If Marcus installs the app and cannot set up his family within 5 minutes, the app is abandoned. The flow must be linear, minimal, and forgiving -- no dead ends, no confusing choices, no data loss if interrupted. Two paths exist: creating a new family (primary flow) and joining an existing family via invite code (secondary flow, for when Sofia installs the app after Marcus has already set things up).

### 1.3 Scope

**In scope:**
- Onboarding carousel (3 slides, skip button, page indicator)
- FamilySetupScreen (create vs join decision)
- CreateFamilyFlow (family name, optional photo, confirmation)
- JoinFamilyFlow (invite code input, validation, family preview)
- Family domain entity
- FamilyRepository abstract interface and implementation
- FamilyLocalDatasource (Drift DAO operations on FamiliesTable)
- FamilyRemoteDatasource (Firestore reads/writes)
- FamilyBloc (states, events, transitions)
- Onboarding routing logic (after auth, check family membership)
- Invite code overview (generation/validation delegated to Cloud Functions -- see spec 14)

**Out of scope:**
- Adding family members (see `specs/11_member_profiles.md`)
- Invite code Cloud Functions implementation (see `specs/14_cloud_functions_invite.md`)
- Firestore security rules (see `specs/13_firestore_security_rules.md`)
- Family settings and management (Phase 7)
- Family photo upload to Firebase Storage (Phase 7)

### 1.4 References

- `specs/00_project_foundation.md` -- Section 4.5 (Data Model), Section 4.6 (Multi-User Model)
- `specs/02_isar_schemas.md` -- Section 5.1 (FamiliesTable)
- `specs/03_sync_engine.md` -- SyncEngine API, operation queue
- `specs/08_phase2_foundations.md` -- Router flow, AuthGuard, route names
- `specs/09_firebase_auth.md` -- AuthBloc, AuthAuthenticated state
- `CLAUDE.md` -- Multi-family not supported, one family per account

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| FAM-001 | Onboarding carousel displays 3 slides | Medium | Three pages with illustrations, titles, and descriptions. Skip button on each page. |
| FAM-002 | First-time users see onboarding before sign-in | Medium | Onboarding carousel shown once (persisted in SharedPreferences). Skip goes to sign-in. |
| FAM-003 | Create a new family with a name | High | User enters family name (2-50 chars), family created in Drift, queued for Firestore sync |
| FAM-004 | Family creator is automatically added as parent member | High | Creating a family also creates a member record for the creator with role=parent |
| FAM-005 | Join an existing family with invite code | High | User enters 6-char code, code validated via Cloud Function, user added to family |
| FAM-006 | Family data syncs to Firestore | High | Family document created in `families/{familyId}` on sync |
| FAM-007 | Authenticated user without family redirected to family setup | High | AuthGuard + router checks family membership and redirects accordingly |
| FAM-008 | Family name displayed in app after creation | Medium | Home screen (stub) shows family name in app bar |
| FAM-009 | Family creation works offline | High | Family created in Drift immediately, synced when connectivity restored |
| FAM-010 | Join family requires internet | Medium | Invite code validation requires Cloud Function call -- show offline message if no internet |
| FAM-011 | Onboarding seen flag persisted | Medium | SharedPreferences stores `hasSeenOnboarding=true` after first view |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| FAM-NFR-001 | Family creation time | Tap "Create" to family confirmed | < 1 second (local write) |
| FAM-NFR-002 | Invite code validation time | Enter code to family preview shown | < 3 seconds |
| FAM-NFR-003 | Onboarding carousel smoothness | Frame rate during page transitions | 60 fps |
| FAM-NFR-004 | Onboarding completion rate | Users who complete onboarding | No abandonment-causing friction |

### 2.3 Assumptions

- Lottie animation files for onboarding slides are provided as assets in `assets/animations/`.
- The onboarding carousel is shown only once per device. Clearing app data resets it.
- Multi-family support is explicitly not supported -- one family per parent account.
- The "optional family photo" feature stores only a local path in Phase 2. Upload to Firebase Storage is deferred.

### 2.4 Constraints

- Family creation must write to Drift first, then queue for Firestore sync (offline-first).
- Join family cannot work offline because invite code validation requires a server-side Cloud Function.
- The `familyId` is generated client-side as a UUID. Firestore uses this as the document ID.
- Once a parent joins a family, they cannot join a second family (enforced by app logic, not a Firestore constraint).

---

## 3. Use Cases

### UC-001: First-Time Onboarding

- **Actor**: Marcus (first-time user)
- **Preconditions**: App freshly installed, no stored auth token, `hasSeenOnboarding` is false
- **Main Flow**:
  1. App launches, shows splash screen
  2. No auth token found, `hasSeenOnboarding` is false
  3. Router navigates to `/onboarding`
  4. Marcus swipes through 3 carousel slides
  5. On last slide, Marcus taps "Get Started"
  6. `hasSeenOnboarding` set to true in SharedPreferences
  7. Router navigates to `/sign-up`
- **Alternative Flows**:
  - Marcus taps "Skip" on any slide -- jumps to `/sign-in` directly
  - Marcus has seen onboarding before -- router skips to `/sign-in`
- **Postconditions**: `hasSeenOnboarding` is true in SharedPreferences
- **Exceptions**: None -- onboarding is purely informational

### UC-002: Create a Family

- **Actor**: Marcus (authenticated, no family)
- **Preconditions**: Marcus is signed in, has no family membership
- **Main Flow**:
  1. Router detects no family, navigates to `/family-setup`
  2. Marcus taps "Create a family"
  3. Router navigates to `/family-setup/create`
  4. Marcus enters family name "The Johnsons"
  5. Marcus taps "Create Family"
  6. FamilyBloc dispatches CreateFamilyRequested
  7. FamilyRepositoryImpl generates UUID for familyId
  8. FamilyRepositoryImpl writes Family row to Drift with `syncStatus=pending`
  9. FamilyRepositoryImpl creates Member row for Marcus (role=parent) in Drift
  10. SyncEngine queues both writes for Firestore
  11. FamilyBloc emits FamilyCreated state
  12. Router navigates to `/family-setup/add-member` for adding other family members
- **Alternative Flows**:
  - Marcus is offline: Steps 1-11 work identically. Step 10 queues but does not execute sync until online.
- **Postconditions**: Family and creator member exist in Drift. Sync pending.
- **Exceptions**:
  - Empty family name -- validation error shown inline
  - Drift write fails -- FamilyError state emitted, retry offered

### UC-003: Join a Family via Invite Code

- **Actor**: Sofia (authenticated, no family)
- **Preconditions**: Sofia signed in, Marcus has created a family and generated an invite code
- **Main Flow**:
  1. Sofia sees `/family-setup` screen
  2. Sofia taps "Join with invite code"
  3. Router navigates to `/family-setup/join`
  4. Sofia enters 6-character invite code (e.g., "ABC123")
  5. Sofia taps "Join"
  6. FamilyBloc dispatches JoinFamilyRequested(code)
  7. FamilyRepositoryImpl calls Cloud Function `validateAndJoinFamily`
  8. Cloud Function validates code, adds Sofia to family, returns familyId
  9. FamilyRepositoryImpl pulls family data from Firestore to Drift
  10. FamilyBloc emits FamilyJoined state
  11. Router navigates to `/profiles`
- **Alternative Flows**:
  - Invalid code: Cloud Function returns error, SnackBar shows "Invalid or expired code"
  - Sofia is offline: "Join with invite code" shows disabled state with "Requires internet" tooltip
- **Postconditions**: Sofia's account is linked to the family. Family and member data in Drift.
- **Exceptions**:
  - Expired invite code -- "This invite code has expired. Ask a family member for a new one."
  - Already a member -- "You are already a member of this family."
  - Network error -- "Unable to connect. Please check your internet and try again."

### UC-004: Join a Family via Deep Link

- **Actor**: Sofia (may or may not be authenticated)
- **Preconditions**: Marcus has created a family and shared an invite link (e.g., `https://familychores.app/join?code=ABC123`) via iMessage, WhatsApp, or another messaging app.
- **Main Flow**:
  1. Sofia taps the shared link on her device
  2. OS opens the Family Chores app via Universal Link (iOS) or App Link (Android)
  3. `DeepLinkService` provides the incoming URI to the app
  4. **If Sofia is authenticated and has no family:**
     - go_router matches `/join`, redirects to `/family-setup/join?code=ABC123`
     - JoinFamilyScreen renders with the code pre-filled in the input field
     - Sofia taps "Join" (or code auto-submits)
     - Flow continues from UC-003 Step 6
  5. **If Sofia is not authenticated:**
     - AuthGuard intercepts the navigation, saves the deep link URI in `DeepLinkRedirectCubit`
     - Router navigates to `/sign-in`
     - Sofia signs in (or signs up)
     - After auth, AuthGuard consumes the pending deep link from `DeepLinkRedirectCubit`
     - Router navigates to `/family-setup/join?code=ABC123`
     - JoinFamilyScreen renders with code pre-filled
  6. **If Sofia is authenticated and already has a family:**
     - App shows error dialog: "You are already part of a family. Each account can only belong to one family."
     - Sofia is redirected to home screen
- **Alternative Flows**:
  - Cold start (app not running): App launches, completes Firebase and DI initialization, then processes the deep link via `DeepLinkService.getInitialLink()`
  - Warm start (app in background): `DeepLinkService.incomingLinks` stream emits the URI, deep link listener navigates to the join screen
  - Custom scheme (`familychores://join?code=ABC123`): Same flow, used as fallback when Universal Links / App Links are not available
  - Invalid code format: JoinFamilyScreen shows inline error "This invite code looks invalid. Please check and try again." and allows manual correction
- **Postconditions**: Same as UC-003 -- Sofia's account is linked to the family.
- **Exceptions**:
  - App not installed: Browser opens `https://familychores.app/join?code=ABC123` (Phase 2: shows default Firebase Hosting page; future: redirect to App Store / Play Store)
  - Deep link URI lost during redirect: `DeepLinkRedirectCubit` preserves the URI in memory across auth redirects

See `specs/16_deep_links.md` for complete deep link implementation details.

---

## 4. Onboarding Carousel

### 4.1 Slide Content

| Slide | Title | Description | Animation |
|-------|-------|-------------|-----------|
| 1 | "Coordinate Without Conflict" | "Share the household workload fairly. Everyone knows what needs doing." | `onboarding_coordinate.json` |
| 2 | "Build Responsibility" | "Teach kids that contributing to the family is normal -- and rewarding." | `onboarding_responsibility.json` |
| 3 | "Make the Invisible Visible" | "See who's doing what. Have fact-based conversations, not arguments." | `onboarding_visibility.json` |

### 4.2 OnboardingScreen Specification

```dart
// lib/features/auth/presentation/screens/onboarding_screen.dart
//
// Layout:
// - Full-screen PageView with 3 pages
// - Each page: Lottie animation (top 50%), title + description (bottom 50%)
// - SmoothPageIndicator at bottom (dot style, active color = primary)
// - "Skip" TextButton in top-right corner (all pages)
// - "Get Started" ElevatedButton on last page (replaces "Next" arrow)
//
// Behavior:
// - Swipe horizontally between pages
// - Auto-advance disabled (user controls pace)
// - On "Get Started" or "Skip": set hasSeenOnboarding=true, navigate to /sign-in
//
// Accessibility:
// - Each slide has semantics label
// - Skip button has tooltip "Skip onboarding"
// - Page indicator announces current page
```

### 4.3 OnboardingCubit

```dart
// lib/features/auth/presentation/bloc/onboarding_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@injectable
class OnboardingCubit extends Cubit<bool> {
  OnboardingCubit(this._prefs) : super(false);

  final SharedPreferences _prefs;
  static const _key = 'hasSeenOnboarding';

  /// Returns true if onboarding has been seen before.
  bool get hasSeenOnboarding => _prefs.getBool(_key) ?? false;

  /// Marks onboarding as completed.
  Future<void> completeOnboarding() async {
    await _prefs.setBool(_key, true);
    emit(true);
  }
}
```

---

## 5. Domain Layer

### 5.1 Family Entity

```dart
// lib/features/family/domain/entities/family.dart
import 'package:equatable/equatable.dart';

/// Represents a family unit in the domain layer.
/// Has no dependencies on Drift, Firestore, or any data layer.
class Family extends Equatable {
  const Family({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    this.remoteId,
    this.photoUrl,
    this.inviteCode,
    this.inviteCodeExpiresAt,
    this.memberIds = const [],
  });

  /// Local UUID identifier. Generated client-side.
  final String id;

  /// Firestore document ID. Null until synced.
  final String? remoteId;

  /// Family display name (e.g., "The Johnsons").
  final String name;

  /// Firebase Auth UID of the creating parent.
  final String createdBy;

  /// Optional family photo URL or local path.
  final String? photoUrl;

  /// Active invite code for joining. Null if none generated.
  final String? inviteCode;

  /// When the invite code expires. Null if no code.
  final DateTime? inviteCodeExpiresAt;

  /// List of member IDs (local UUIDs).
  final List<String> memberIds;

  /// When the family was created.
  final DateTime createdAt;

  /// Whether the invite code is currently valid.
  bool get hasValidInviteCode =>
      inviteCode != null &&
      inviteCodeExpiresAt != null &&
      inviteCodeExpiresAt!.isAfter(DateTime.now());

  @override
  List<Object?> get props => [
        id,
        remoteId,
        name,
        createdBy,
        photoUrl,
        inviteCode,
        inviteCodeExpiresAt,
        memberIds,
        createdAt,
      ];
}
```

### 5.2 FamilyRepository Interface

```dart
// lib/features/family/domain/repositories/family_repository.dart
import '../../../../core/utils/result.dart';
import '../entities/family.dart';

/// Abstract interface for family CRUD operations.
/// Implementations write to Drift first, then queue Firestore sync.
abstract class FamilyRepository {
  /// Creates a new family with the given name.
  /// Also creates a parent member record for the creator.
  /// Returns the created [Family] entity.
  Future<Result<Family>> createFamily({
    required String name,
    required String createdByUid,
    required String createdByName,
    String? photoUrl,
  });

  /// Joins an existing family using an invite code.
  /// Requires internet (Cloud Function call).
  /// Returns the joined [Family] entity.
  Future<Result<Family>> joinFamily({
    required String inviteCode,
    required String userId,
    required String userName,
  });

  /// Returns the family for a given user UID, or null if none.
  Future<Result<Family?>> getFamilyForUser(String uid);

  /// Stream of the current family. Emits on any change.
  Stream<Family?> watchFamily(String familyId);

  /// Updates family metadata (name, photo).
  Future<Result<Family>> updateFamily({
    required String familyId,
    String? name,
    String? photoUrl,
  });

  /// Generates a new invite code for the family.
  /// Requires internet (Cloud Function call).
  Future<Result<String>> generateInviteCode(String familyId);

  /// Removes the current user from the family.
  /// If the user is the last parent, this fails.
  Future<Result<void>> leaveFamily({
    required String familyId,
    required String userId,
  });
}
```

---

## 6. Data Layer

### 6.1 FamilyModel (Data Layer Mapping)

```dart
// lib/features/family/data/models/family_model.dart
import '../../domain/entities/family.dart';
import '../../../../core/sync/sync_status.dart';

/// Maps between Drift FamiliesTable row and domain Family entity.
/// Also handles Firestore document mapping.
class FamilyModel {
  const FamilyModel({
    required this.localId,
    required this.remoteId,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
    this.inviteCode,
    this.inviteCodeExpiresAt,
    this.lastSyncedAt,
  });

  final int localId;
  final String? remoteId;
  final String name;
  final String createdBy;
  final String? inviteCode;
  final DateTime? inviteCodeExpiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;
  final DateTime? lastSyncedAt;

  /// Converts to domain entity.
  Family toDomain() {
    return Family(
      id: localId.toString(),
      remoteId: remoteId,
      name: name,
      createdBy: createdBy,
      inviteCode: inviteCode,
      inviteCodeExpiresAt: inviteCodeExpiresAt,
      createdAt: createdAt,
    );
  }

  /// Creates from Firestore document.
  factory FamilyModel.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    return FamilyModel(
      localId: 0, // Will be assigned by Drift on insert
      remoteId: docId,
      name: data['name'] as String,
      createdBy: data['createdBy'] as String,
      inviteCode: data['inviteCode'] as String?,
      inviteCodeExpiresAt: data['inviteCodeExpiresAt'] != null
          ? (data['inviteCodeExpiresAt'] as Timestamp).toDate()
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      syncStatus: SyncStatus.synced,
      lastSyncedAt: DateTime.now(),
    );
  }

  /// Converts to Firestore document map.
  /// Excludes sync metadata fields (local only).
  Map<String, dynamic> toFirestoreMap() {
    return {
      'name': name,
      'createdBy': createdBy,
      'inviteCode': inviteCode,
      'inviteCodeExpiresAt': inviteCodeExpiresAt,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
```

### 6.2 FamilyLocalDatasource

```dart
// lib/features/family/data/datasources/family_local_datasource.dart
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_status.dart';

/// Drift DAO operations for the FamiliesTable.
@lazySingleton
class FamilyLocalDatasource {
  FamilyLocalDatasource(this._db);

  final AppDatabase _db;

  /// Inserts a new family row. Returns the auto-incremented ID.
  Future<int> insertFamily(FamiliesTableCompanion family) {
    return _db.into(_db.familiesTable).insert(family);
  }

  /// Returns the family row by remote ID, or null.
  Future<FamiliesTableData?> getFamilyByRemoteId(String remoteId) {
    return (_db.select(_db.familiesTable)
          ..where((t) => t.remoteId.equals(remoteId)))
        .getSingleOrNull();
  }

  /// Returns the family row for a user (by createdBy UID).
  Future<FamiliesTableData?> getFamilyForUser(String uid) {
    return (_db.select(_db.familiesTable)
          ..where((t) => t.createdBy.equals(uid)))
        .getSingleOrNull();
  }

  /// Watches a family by its local ID.
  Stream<FamiliesTableData?> watchFamily(int localId) {
    return (_db.select(_db.familiesTable)
          ..where((t) => t.id.equals(localId)))
        .watchSingleOrNull();
  }

  /// Updates a family row.
  Future<bool> updateFamily(
    int localId,
    FamiliesTableCompanion updates,
  ) {
    return (_db.update(_db.familiesTable)
          ..where((t) => t.id.equals(localId)))
        .write(updates)
        .then((_) => true);
  }

  /// Deletes a family row.
  Future<int> deleteFamily(int localId) {
    return (_db.delete(_db.familiesTable)
          ..where((t) => t.id.equals(localId)))
        .go();
  }
}
```

### 6.3 FamilyRemoteDatasource

```dart
// lib/features/family/data/datasources/family_remote_datasource.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:injectable/injectable.dart';

/// Firestore operations for families collection.
@lazySingleton
class FamilyRemoteDatasource {
  FamilyRemoteDatasource(
    this._firestore,
    this._functions,
  );

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _familiesRef =>
      _firestore.collection('families');

  /// Creates a family document in Firestore.
  Future<void> createFamily(
    String familyId,
    Map<String, dynamic> data,
  ) async {
    await _familiesRef.doc(familyId).set(data);
  }

  /// Gets a family document by ID.
  Future<DocumentSnapshot<Map<String, dynamic>>> getFamily(
    String familyId,
  ) async {
    return _familiesRef.doc(familyId).get();
  }

  /// Updates a family document.
  Future<void> updateFamily(
    String familyId,
    Map<String, dynamic> data,
  ) async {
    await _familiesRef.doc(familyId).update(data);
  }

  /// Watches a family document for real-time changes.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchFamily(
    String familyId,
  ) {
    return _familiesRef.doc(familyId).snapshots();
  }

  /// Calls the generateInviteCode Cloud Function.
  Future<String> generateInviteCode(String familyId) async {
    final callable = _functions.httpsCallable('generateInviteCode');
    final result = await callable.call<Map<String, dynamic>>(
      {'familyId': familyId},
    );
    return result.data['inviteCode'] as String;
  }

  /// Calls the validateAndJoinFamily Cloud Function.
  Future<String> validateAndJoinFamily({
    required String inviteCode,
    required String userId,
    required String userName,
  }) async {
    final callable = _functions.httpsCallable('validateAndJoinFamily');
    final result = await callable.call<Map<String, dynamic>>({
      'inviteCode': inviteCode,
      'userId': userId,
      'userName': userName,
    });
    return result.data['familyId'] as String;
  }
}
```

### 6.4 FamilyRepositoryImpl

```dart
// lib/features/family/data/repositories/family_repository_impl.dart
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/sync/sync_engine.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/family.dart';
import '../../domain/repositories/family_repository.dart';
import '../datasources/family_local_datasource.dart';
import '../datasources/family_remote_datasource.dart';

@LazySingleton(as: FamilyRepository)
class FamilyRepositoryImpl implements FamilyRepository {
  FamilyRepositoryImpl(
    this._localDatasource,
    this._remoteDatasource,
    this._syncEngine,
    this._idGenerator,
  );

  final FamilyLocalDatasource _localDatasource;
  final FamilyRemoteDatasource _remoteDatasource;
  final SyncEngine _syncEngine;
  final IdGenerator _idGenerator;

  @override
  Future<Result<Family>> createFamily({
    required String name,
    required String createdByUid,
    required String createdByName,
    String? photoUrl,
  }) async {
    try {
      final now = DateTime.now();
      final familyUuid = _idGenerator.generate();

      // 1. Write to Drift
      final localId = await _localDatasource.insertFamily(
        FamiliesTableCompanion.insert(
          remoteId: Value(familyUuid),
          name: name,
          createdBy: createdByUid,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 2. Queue sync operation
      await _syncEngine.enqueue(
        entityType: 'family',
        entityId: familyUuid,
        operationType: OperationType.create,
        payload: {
          'name': name,
          'createdBy': createdByUid,
        },
      );

      return Result.success(
        Family(
          id: localId.toString(),
          remoteId: familyUuid,
          name: name,
          createdBy: createdByUid,
          photoUrl: photoUrl,
          createdAt: now,
        ),
      );
    } catch (e, st) {
      return Result.failure(
        DatabaseFailure(message: 'Failed to create family: $e', stackTrace: st),
      );
    }
  }

  @override
  Future<Result<Family?>> getFamilyForUser(String uid) async {
    try {
      final row = await _localDatasource.getFamilyForUser(uid);
      if (row == null) return const Result.success(null);

      return Result.success(
        Family(
          id: row.id.toString(),
          remoteId: row.remoteId,
          name: row.name,
          createdBy: row.createdBy,
          inviteCode: row.inviteCode,
          inviteCodeExpiresAt: row.inviteCodeExpiresAt,
          createdAt: row.createdAt,
        ),
      );
    } catch (e, st) {
      return Result.failure(
        DatabaseFailure(message: 'Failed to get family: $e', stackTrace: st),
      );
    }
  }

  // ... remaining methods follow same pattern:
  // joinFamily: calls Cloud Function, pulls Firestore data to Drift
  // watchFamily: watches Drift row
  // updateFamily: writes to Drift, queues sync
  // generateInviteCode: calls Cloud Function, updates Drift row
  // leaveFamily: removes member from Drift, queues sync
}
```

---

## 7. Presentation Layer

### 7.1 FamilyBloc Events

```dart
// lib/features/family/presentation/bloc/family_event.dart
import 'package:equatable/equatable.dart';

sealed class FamilyEvent extends Equatable {
  const FamilyEvent();

  @override
  List<Object?> get props => [];
}

/// Check if current user has a family.
final class FamilyCheckRequested extends FamilyEvent {
  const FamilyCheckRequested(this.uid);
  final String uid;

  @override
  List<Object?> get props => [uid];
}

/// Create a new family.
final class CreateFamilyRequested extends FamilyEvent {
  const CreateFamilyRequested({
    required this.name,
    required this.createdByUid,
    required this.createdByName,
  });

  final String name;
  final String createdByUid;
  final String createdByName;

  @override
  List<Object?> get props => [name, createdByUid, createdByName];
}

/// Join a family with invite code.
final class JoinFamilyRequested extends FamilyEvent {
  const JoinFamilyRequested({
    required this.inviteCode,
    required this.userId,
    required this.userName,
  });

  final String inviteCode;
  final String userId;
  final String userName;

  @override
  List<Object?> get props => [inviteCode, userId, userName];
}

/// Generate a new invite code.
final class GenerateInviteCodeRequested extends FamilyEvent {
  const GenerateInviteCodeRequested(this.familyId);
  final String familyId;

  @override
  List<Object?> get props => [familyId];
}
```

### 7.2 FamilyBloc States

```dart
// lib/features/family/presentation/bloc/family_state.dart
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/family.dart';

sealed class FamilyState extends Equatable {
  const FamilyState();

  @override
  List<Object?> get props => [];
}

final class FamilyInitial extends FamilyState {
  const FamilyInitial();
}

final class FamilyLoading extends FamilyState {
  const FamilyLoading();
}

/// User has no family. Show family setup screen.
final class FamilyNotFound extends FamilyState {
  const FamilyNotFound();
}

/// Family exists and is loaded.
final class FamilyLoaded extends FamilyState {
  const FamilyLoaded(this.family);
  final Family family;

  @override
  List<Object?> get props => [family];
}

/// Family was just created. Navigate to add members.
final class FamilyCreated extends FamilyState {
  const FamilyCreated(this.family);
  final Family family;

  @override
  List<Object?> get props => [family];
}

/// Family was joined via invite code.
final class FamilyJoined extends FamilyState {
  const FamilyJoined(this.family);
  final Family family;

  @override
  List<Object?> get props => [family];
}

/// Invite code was generated.
final class InviteCodeGenerated extends FamilyState {
  const InviteCodeGenerated(this.inviteCode);
  final String inviteCode;

  @override
  List<Object?> get props => [inviteCode];
}

/// Family operation failed.
final class FamilyError extends FamilyState {
  const FamilyError(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
```

### 7.3 FamilySetupScreen

```dart
// lib/features/family/presentation/screens/family_setup_screen.dart
//
// Layout:
// - App logo centered at top
// - "Welcome to Family Chores!" heading
// - "Let's get your family set up." subheading
// - Two large cards (stacked vertically):
//   1. "Create a Family" card
//      - House icon, title, "Start fresh with a new family" description
//      - Tap navigates to /family-setup/create
//   2. "Join a Family" card
//      - People icon, title, "Someone already set things up? Join with a code." description
//      - Tap navigates to /family-setup/join
//      - Disabled with tooltip when offline
//
// Dimensions:
// - Card height: 120px
// - Horizontal padding: 24px
// - Card spacing: 16px
// - Cards have elevation: 2, borderRadius: 16
```

### 7.3.1 Share Invite Link (Post-Creation)

After a family is created, the FamilySetupScreen (or a post-creation confirmation step) displays a "Share Invite Link" button. This allows Marcus to immediately invite Sofia before moving on to add members.

```dart
// Added to FamilySetupScreen or CreateFamilyScreen (post-creation state):
//
// "Share Invite Link" OutlinedButton with share icon
// - Disabled when offline (tooltip: "Requires internet")
// - On tap:
//   1. Calls FamilyBloc.add(GenerateInviteCodeRequested(familyId))
//   2. BlocListener: on InviteCodeGenerated, calls Share.share() with the shareableUrl
//   3. Shows system share sheet with message: "Join our family on Family Chores! https://familychores.app/join?code=ABC123"
//   4. Loading state: button shows CircularProgressIndicator
//   5. Error state: SnackBar with error message
//
// See specs/16_deep_links.md Section 8.2 for share integration code.
```

### 7.4 CreateFamilyScreen

```dart
// lib/features/family/presentation/screens/create_family_screen.dart
//
// Layout:
// - AppBar with "Create Family" title and back button
// - Family name TextFormField
//   - Hint: "e.g., The Johnsons"
//   - Validation: required, 2-50 chars
// - Optional family photo selector (tappable avatar area)
//   - Placeholder: camera icon in circle
//   - Phase 2: stores local path only (no upload)
// - "Create Family" primary ElevatedButton (full width)
//
// Behavior:
// - On submit: dispatch CreateFamilyRequested
// - BlocListener: on FamilyCreated, navigate to /family-setup/add-member
// - BlocListener: on FamilyError, show SnackBar
// - Loading state: button shows CircularProgressIndicator
```

### 7.5 JoinFamilyScreen

```dart
// lib/features/family/presentation/screens/join_family_screen.dart
//
// Layout:
// - AppBar with "Join a Family" title and back button
// - Illustration or icon at top
// - "Enter the invite code shared by a family member" instruction text
// - 6-character code input (6 individual boxes, auto-focus next on entry)
//   - All caps, alphanumeric only
//   - Auto-submit when 6th character entered
// - "Join Family" primary ElevatedButton
//
// Behavior:
// - On submit: dispatch JoinFamilyRequested with code
// - BlocListener: on FamilyJoined, show family name preview, then navigate to /profiles
// - BlocListener: on FamilyError, show SnackBar with specific error message
// - Loading state: code input disabled, button shows loading
//
// Error messages:
// - "invite-code/not-found": "We couldn't find a family with that code. Please check and try again."
// - "invite-code/expired": "This code has expired. Ask a family member to generate a new one."
// - "invite-code/already-member": "You're already a member of this family!"
```

---

## 8. Impact Analysis

### 8.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| `lib/features/family/` (entire feature) | New/Modified | Medium | 12+ new files across data/domain/presentation |
| `lib/features/auth/` | Modified | Low | OnboardingScreen and OnboardingCubit added |
| `FamiliesTable` (Drift) | Dependency | Low | Already defined in Phase 1, no schema changes |
| `SyncEngine` | Dependency | Medium | Family sync adapter must be registered |
| DI container | Modified | Low | FamilyBloc, FamilyRepository, datasources registered |
| `app_router.dart` | Modified | Low | Family setup routes added (already defined in spec 08) |

### 8.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Cloud Function not deployed when testing join flow | High | Medium | Build join flow last. Test with Firebase emulator functions. |
| Offline family creation loses sync operation | Low | High | Sync engine already handles this (Phase 1). Write integration test. |
| Race condition: family created locally + Firestore listener fires | Medium | Medium | Conflict resolver handles via LWW. Test with dual-write scenario. |
| Invite code input UX issues on tablets | Low | Low | Test on multiple form factors. Responsive layout. |
| User closes app mid-family-creation | Low | Medium | Drift write is atomic. Family exists in DB even if app closes before sync. |

---

## 9. Functional Tests

### 9.1 Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| FAM-FT-001 | Create family success | User authenticated, no family | CreateFamilyRequested dispatched | FamilyCreated emitted with correct family name | High |
| FAM-FT-002 | Create family writes to Drift | Valid family name | Family created | FamiliesTable row exists with syncStatus=pending | High |
| FAM-FT-003 | Create family queues sync operation | Family created locally | After Drift write | SyncOperationsTable has pending family create operation | High |
| FAM-FT-004 | Create family also creates parent member | Family created | After creation | MembersTable row exists for creator with role=parent | High |
| FAM-FT-005 | Join family success | Valid invite code, internet available | JoinFamilyRequested dispatched | FamilyJoined emitted with family data | High |
| FAM-FT-006 | Join family with invalid code | Invalid code | JoinFamilyRequested dispatched | FamilyError emitted with appropriate message | High |
| FAM-FT-007 | Join family with expired code | Expired code | JoinFamilyRequested dispatched | FamilyError emitted with "expired" message | Medium |
| FAM-FT-008 | Get family for user -- found | User has family | getFamilyForUser called | Returns Result.success with family | High |
| FAM-FT-009 | Get family for user -- not found | User has no family | getFamilyForUser called | Returns Result.success(null) | High |
| FAM-FT-010 | Onboarding marks as seen | Onboarding completed | completeOnboarding called | SharedPreferences hasSeenOnboarding=true | Medium |
| FAM-FT-011 | Onboarding not shown on second launch | hasSeenOnboarding=true | App launches | Router skips /onboarding, goes to /sign-in | Medium |
| FAM-FT-012 | Family name validation -- empty | Empty string entered | Create button tapped | Validation error shown | Medium |
| FAM-FT-013 | Family name validation -- too long | 60-char name entered | Create button tapped | Validation error shown (max 50 chars) | Low |
| FAM-FT-014 | Join family offline | No internet | Join button tapped | Error message "Requires internet connection" | Medium |

### 9.2 Edge Cases

- Create family with Unicode characters in name (emoji, CJK, Arabic) -- should work.
- Invite code with leading/trailing whitespace -- should be trimmed before validation.
- Invite code with lowercase letters -- should be uppercased before submission.
- User creates family, kills app, reopens -- family should still exist in Drift.
- Two parents create families simultaneously on shared device -- only one account should be active.
- User joins family, internet drops before confirmation -- should show error, not partial state.

---

## 10. Implementation Recommendations

### 10.1 Prototype Checklist

1. **What can a user do?** As Marcus, I can see an onboarding carousel, create a family called "The Johnsons", and be ready to add family members.
2. **Screens delivered:** `/onboarding`, `/family-setup`, `/family-setup/create`, `/family-setup/join`
3. **Minimum data flow:** Marcus taps "Create Family" -> FamilyBloc dispatches event -> FamilyRepositoryImpl writes to Drift -> SyncEngine queues Firestore write -> Router navigates to add-member screen.
4. **Offline behavior:** Family creation works offline (Drift write + sync queue). Join family requires internet (Cloud Function). Onboarding carousel works offline (local assets).
5. **Done looks like:** A tester can complete onboarding, sign up, create a family, and see the family name displayed. The family persists across app restarts.

### 10.2 Suggested Approach

1. Create `Family` entity in domain layer.
2. Create `FamilyRepository` abstract interface.
3. Implement `FamilyLocalDatasource` (Drift DAO).
4. Implement `FamilyRemoteDatasource` (Firestore + Cloud Functions).
5. Implement `FamilyRepositoryImpl`.
6. Create `FamilyEvent` and `FamilyState` classes.
7. Implement `FamilyBloc`.
8. Implement `OnboardingCubit` and `OnboardingScreen`.
9. Implement `FamilySetupScreen`, `CreateFamilyScreen`, `JoinFamilyScreen`.
10. Write unit tests for FamilyRepositoryImpl and FamilyBloc.
11. Write widget tests for all screens.
12. Integration test: family creation + Drift persistence.

### 10.3 Estimated Effort

**T-shirt size: M** (3-5 days)

Family creation is straightforward. The join flow depends on Cloud Functions (spec 14) and can be stubbed initially. UI screens are simple forms.

---

## 11. Open Questions

- [ ] Should the onboarding carousel be skippable on the first slide, or should "Skip" only appear after viewing at least one slide?
- [ ] Should family creation allow a description or tagline in addition to the name?
- [ ] If a user creates a family, then joins another family via invite code, should the original family be deleted or should they be prompted to choose?
- [ ] Should the invite code input use individual character boxes (like OTP inputs) or a single text field?

---

*Generated by Software Architect Analyst*
*Date: 2026-03-09*
