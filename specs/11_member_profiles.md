# Family Member Profiles

## 1. Overview

### 1.1 Summary

This specification defines the family member profile system -- adding members to a family, the profile switcher for shared devices, the active profile concept, and the settings stub screen. It covers the Member domain entity, MemberRepository interface and implementation, ActiveProfileCubit for managing the currently selected profile, the avatar selection system, and the accent color palette. Profile switching is the mechanism that enables a single device to be shared by the entire family, with each member seeing their own personalized view.

### 1.2 Business Context

The Family Chores App runs on shared devices -- a kitchen tablet or a family phone. Marcus, Sofia, Alex, and Emma all use the same device but need distinct identities for task attribution, point tracking, and fairness calculations. The profile switcher is the "who are you?" gate that appears after authentication. Children (Alex, Emma) do not have Firebase Auth accounts -- they are profiles created and managed by parents. The profile switcher must be simple enough for a 3-year-old to find their avatar and tap it.

### 1.3 Scope

**In scope:**
- Member domain entity
- MemberRepository abstract interface and implementation
- MemberLocalDatasource (Drift DAO operations on MembersTable)
- MemberRemoteDatasource (Firestore reads/writes)
- AddMemberScreen (name, age, role, avatar selection)
- ProfileSwitcherScreen (avatar grid, active indicator, add member card)
- ActiveProfileCubit (holds current profile, persisted in SharedPreferences)
- Profile switching logic (child = instant, parent = PIN gate)
- Avatar system (12 pre-defined illustrated avatars)
- Accent color palette (8 pastel colors)
- Settings stub screen (family member list, edit/add member entry points)

**Out of scope:**
- PIN verification logic (see `specs/12_pin_system.md`)
- Emma's age-appropriate UI (Phase 6)
- Profile photo upload (Phase 7)
- Account deletion (Phase 8)

### 1.4 References

- `specs/00_project_foundation.md` -- Section 4.6 (Multi-User Model), Section 4.5 (Data Model)
- `specs/02_isar_schemas.md` -- Section 5.2 (MembersTable)
- `specs/08_phase2_foundations.md` -- Route names, PinGuard
- `docs/design-system.md` -- Color palette, spacing, avatar guidelines
- `docs/user-personas.md` -- Marcus, Sofia, Alex, Emma characteristics
- `CLAUDE.md` -- Children don't have Firebase accounts, Emma's 56px touch targets

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| MEM-001 | Add a family member with name, age, and role | High | Member created in Drift with correct fields, queued for sync |
| MEM-002 | Select avatar for member from 12 options | High | Avatar selection persisted, displayed on profile switcher |
| MEM-003 | Select accent color for member from 8 options | Medium | Color persisted, used for member-specific UI theming |
| MEM-004 | Profile switcher shows all family members | High | Grid of avatars with name labels, all members visible |
| MEM-005 | Active profile indicator (ring/glow) on selected member | High | Visual distinction between active and inactive profiles |
| MEM-006 | Tap child avatar switches immediately | High | No PIN required for child profiles |
| MEM-007 | Tap parent avatar triggers PIN gate | High | PIN entry screen shown before profile switch |
| MEM-008 | Active profile persisted across app restarts | High | SharedPreferences stores active member ID |
| MEM-009 | "+ Add member" card in profile switcher | Medium | Tapping navigates to /family-setup/add-member |
| MEM-010 | Settings screen shows family member list | Medium | All members listed with name, role, avatar |
| MEM-011 | Edit member from settings | Medium | Name, age, avatar, color editable |
| MEM-012 | Delete member from settings (parent only) | Medium | Parent can remove a child member |
| MEM-013 | Creator parent cannot delete themselves | High | Delete option not shown for the family creator |
| MEM-014 | Member creation works offline | High | Drift write immediate, sync queued |
| MEM-015 | Age determines age group assignment | Medium | Age mapped to AgeGroup enum: 2-4=toddler, 5-12=child, 13-17=teen, 18+=adult |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| MEM-NFR-001 | Profile switch latency | Tap avatar to new profile active | < 200ms for child, < 500ms for parent (after PIN) |
| MEM-NFR-002 | Avatar grid rendering | Time to render 4-6 avatars | < 100ms |
| MEM-NFR-003 | Touch target size for avatars | Minimum avatar tappable area | 56px minimum (per Emma's requirements) |
| MEM-NFR-004 | Member creation time | Tap "Add" to member saved | < 500ms (local write) |

### 2.3 Assumptions

- Avatar images are bundled as local assets (`assets/images/avatars/`). No network download required.
- A family has a maximum of 8 members (2 parents + 6 children). This is an app-level limit, not a Firestore constraint.
- The profile switcher always shows all family members. There is no scrolling required for up to 8 members (grid layout).
- The active profile determines which member's data is shown across the app (tasks, points, streaks).

### 2.4 Constraints

- Children cannot be profile creators or have Firebase Auth UIDs. Their `userId` field in MembersTable is always null.
- The active member ID is stored in SharedPreferences, not Drift, because it is device-specific (not synced across devices).
- Member deletion cascades: if a member is deleted, their task assignments must be updated (Phase 3 concern -- flag here for awareness).
- PIN hash and salt are member-level fields. Each parent can have their own PIN.

---

## 3. Use Cases

### UC-001: Add Family Members After Family Creation

- **Actor**: Marcus (parent, family creator)
- **Preconditions**: Marcus has just created a family, on the add-member screen
- **Main Flow**:
  1. AddMemberScreen shows form for first member
  2. Marcus enters "Sofia", age 36, role "Parent"
  3. Marcus selects bear avatar, selects coral accent color
  4. Marcus taps "Add Member"
  5. MemberBloc dispatches AddMemberRequested
  6. MemberRepositoryImpl writes Member row to Drift
  7. SyncEngine queues Firestore sync
  8. Screen resets for next member
  9. Marcus adds "Alex", age 10, role "Child", fox avatar, blue color
  10. Marcus adds "Emma", age 3, role "Child", bunny avatar, mint color
  11. Marcus taps "Done" or "Continue"
  12. Router navigates to `/pin-setup` (Marcus needs to set up his PIN)
- **Alternative Flows**:
  - Marcus taps "Skip" -- navigates to profile switcher with only Marcus as a member
  - Marcus is offline -- all members created locally, synced later
- **Postconditions**: 4 members exist in MembersTable. Creator member (Marcus) already exists from family creation.
- **Exceptions**:
  - Duplicate name -- warning shown, allowed to proceed (names are not unique identifiers)
  - Age < 2 or > 100 -- validation error

### UC-002: Switch Profile on Shared Device

- **Actor**: Alex (child)
- **Preconditions**: App open, Marcus profile active
- **Main Flow**:
  1. Alex navigates to profile switcher (bottom nav or app bar avatar)
  2. Profile switcher grid shows all family members
  3. Marcus has active indicator (highlighted ring)
  4. Alex taps his fox avatar
  5. ActiveProfileCubit updates to Alex's member ID
  6. SharedPreferences updated
  7. App UI refreshes with Alex's data (tasks, points, theme accent)
  8. Profile switcher closes, home screen shows Alex's view
- **Alternative Flows**:
  - Alex tries to tap Marcus's avatar -- PIN entry screen appears (Marcus must enter PIN to switch to parent)
  - Emma taps her bunny avatar -- immediate switch (child, no PIN)
- **Postconditions**: Active profile is Alex. All subsequent operations attributed to Alex.

### UC-003: Edit Member Profile

- **Actor**: Marcus (parent)
- **Preconditions**: Marcus is active profile (PIN verified), on settings screen
- **Main Flow**:
  1. Settings screen shows member list
  2. Marcus taps Alex's entry
  3. Edit member form shows with pre-filled data
  4. Marcus updates Alex's age from 10 to 11
  5. Marcus taps "Save"
  6. MemberRepositoryImpl updates Drift row
  7. SyncEngine queues update
  8. Confirmation shown, back to settings
- **Postconditions**: Alex's age updated in Drift. Sync pending.

---

## 4. Domain Layer

### 4.1 Member Entity

```dart
// lib/features/family/domain/entities/member.dart
import 'package:equatable/equatable.dart';

import '../../../../core/enums/age_group.dart';
import '../../../../core/enums/member_role.dart';

/// Represents a family member in the domain layer.
/// No dependencies on Drift, Firestore, or any data-layer types.
class Member extends Equatable {
  const Member({
    required this.id,
    required this.familyId,
    required this.name,
    required this.role,
    required this.age,
    required this.avatarSeed,
    required this.accentColor,
    required this.createdAt,
    this.remoteId,
    this.userId,
    this.points = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.hasPin = false,
  });

  /// Local identifier (Drift auto-increment ID as string).
  final String id;

  /// Firestore document ID. Null until synced.
  final String? remoteId;

  /// Family this member belongs to.
  final String familyId;

  /// Display name.
  final String name;

  /// Parent or child role.
  final MemberRole role;

  /// Age in years.
  final int age;

  /// Avatar asset identifier (e.g., "avatar_fox", "avatar_bunny").
  final String avatarSeed;

  /// Hex color string for member-specific accent (e.g., "#A8D8EA").
  final String accentColor;

  /// Firebase Auth UID. Null for children.
  final String? userId;

  /// Accumulated points from completing tasks.
  final int points;

  /// Current consecutive-day streak.
  final int currentStreak;

  /// All-time longest streak.
  final int longestStreak;

  /// Whether this member has set a PIN. Derived, not stored.
  final bool hasPin;

  /// When this member was added to the family.
  final DateTime createdAt;

  /// Computed age group based on age.
  AgeGroup get ageGroup {
    if (age <= 4) return AgeGroup.toddler;
    if (age <= 12) return AgeGroup.child;
    if (age <= 17) return AgeGroup.teen;
    return AgeGroup.adult;
  }

  /// Whether this is a parent profile.
  bool get isParent => role == MemberRole.parent;

  /// Whether this is a child profile.
  bool get isChild => role == MemberRole.child;

  /// Whether this member is excluded from fairness comparisons.
  /// Per resolved decision: Emma (toddlers) excluded.
  bool get excludedFromFairness => ageGroup == AgeGroup.toddler;

  @override
  List<Object?> get props => [
        id,
        remoteId,
        familyId,
        name,
        role,
        age,
        avatarSeed,
        accentColor,
        userId,
        points,
        currentStreak,
        longestStreak,
        hasPin,
        createdAt,
      ];
}
```

### 4.2 MemberRepository Interface

```dart
// lib/features/family/domain/repositories/member_repository.dart
import '../../../../core/utils/result.dart';
import '../entities/member.dart';

/// Abstract interface for member CRUD operations.
abstract class MemberRepository {
  /// Creates a new family member.
  Future<Result<Member>> createMember({
    required String familyId,
    required String name,
    required int age,
    required MemberRole role,
    required String avatarSeed,
    required String accentColor,
    String? userId,
  });

  /// Updates an existing member.
  Future<Result<Member>> updateMember({
    required String memberId,
    String? name,
    int? age,
    String? avatarSeed,
    String? accentColor,
  });

  /// Deletes a member.
  Future<Result<void>> deleteMember(String memberId);

  /// Gets all members for a family.
  Future<Result<List<Member>>> getMembersForFamily(String familyId);

  /// Stream of all members for a family. Emits on any change.
  Stream<List<Member>> watchMembersForFamily(String familyId);

  /// Gets a single member by ID.
  Future<Result<Member?>> getMember(String memberId);

  /// Gets the member record linked to a Firebase Auth UID.
  Future<Result<Member?>> getMemberForUser(String uid);
}
```

---

## 5. Data Layer

### 5.1 MemberLocalDatasource

```dart
// lib/features/family/data/datasources/member_local_datasource.dart
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/database/app_database.dart';

/// Drift DAO operations for the MembersTable.
@lazySingleton
class MemberLocalDatasource {
  MemberLocalDatasource(this._db);

  final AppDatabase _db;

  /// Inserts a new member row. Returns auto-incremented ID.
  Future<int> insertMember(MembersTableCompanion member) {
    return _db.into(_db.membersTable).insert(member);
  }

  /// Returns all members for a family.
  Future<List<MembersTableData>> getMembersForFamily(String familyId) {
    return (_db.select(_db.membersTable)
          ..where((t) => t.familyId.equals(familyId)))
        .get();
  }

  /// Watches all members for a family.
  Stream<List<MembersTableData>> watchMembersForFamily(String familyId) {
    return (_db.select(_db.membersTable)
          ..where((t) => t.familyId.equals(familyId)))
        .watch();
  }

  /// Returns a member by local ID.
  Future<MembersTableData?> getMember(int localId) {
    return (_db.select(_db.membersTable)
          ..where((t) => t.id.equals(localId)))
        .getSingleOrNull();
  }

  /// Returns the member for a Firebase Auth UID.
  Future<MembersTableData?> getMemberForUser(String uid) {
    return (_db.select(_db.membersTable)
          ..where((t) => t.userId.equals(uid)))
        .getSingleOrNull();
  }

  /// Updates a member row.
  Future<bool> updateMember(
    int localId,
    MembersTableCompanion updates,
  ) {
    return (_db.update(_db.membersTable)
          ..where((t) => t.id.equals(localId)))
        .write(updates)
        .then((_) => true);
  }

  /// Deletes a member row.
  Future<int> deleteMember(int localId) {
    return (_db.delete(_db.membersTable)
          ..where((t) => t.id.equals(localId)))
        .go();
  }
}
```

### 5.2 MemberRemoteDatasource

```dart
// lib/features/family/data/datasources/member_remote_datasource.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

/// Firestore operations for the members subcollection.
@lazySingleton
class MemberRemoteDatasource {
  MemberRemoteDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _membersRef(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('members');
  }

  /// Creates a member document.
  Future<void> createMember(
    String familyId,
    String memberId,
    Map<String, dynamic> data,
  ) async {
    await _membersRef(familyId).doc(memberId).set(data);
  }

  /// Gets all members for a family.
  Future<QuerySnapshot<Map<String, dynamic>>> getMembers(
    String familyId,
  ) async {
    return _membersRef(familyId).get();
  }

  /// Updates a member document.
  Future<void> updateMember(
    String familyId,
    String memberId,
    Map<String, dynamic> data,
  ) async {
    await _membersRef(familyId).doc(memberId).update(data);
  }

  /// Deletes a member document.
  Future<void> deleteMember(
    String familyId,
    String memberId,
  ) async {
    await _membersRef(familyId).doc(memberId).delete();
  }

  /// Watches members subcollection for real-time changes.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchMembers(
    String familyId,
  ) {
    return _membersRef(familyId).snapshots();
  }
}
```

### 5.3 MemberRepositoryImpl

```dart
// lib/features/family/data/repositories/member_repository_impl.dart
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/enums/member_role.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/member.dart';
import '../../domain/repositories/member_repository.dart';
import '../datasources/member_local_datasource.dart';
import '../datasources/member_remote_datasource.dart';

@LazySingleton(as: MemberRepository)
class MemberRepositoryImpl implements MemberRepository {
  MemberRepositoryImpl(
    this._localDatasource,
    this._remoteDatasource,
    this._syncEngine,
    this._idGenerator,
  );

  final MemberLocalDatasource _localDatasource;
  final MemberRemoteDatasource _remoteDatasource;
  final SyncEngine _syncEngine;
  final IdGenerator _idGenerator;

  @override
  Future<Result<Member>> createMember({
    required String familyId,
    required String name,
    required int age,
    required MemberRole role,
    required String avatarSeed,
    required String accentColor,
    String? userId,
  }) async {
    try {
      final now = DateTime.now();
      final memberUuid = _idGenerator.generate();

      final localId = await _localDatasource.insertMember(
        MembersTableCompanion.insert(
          remoteId: Value(memberUuid),
          familyId: familyId,
          name: name,
          role: role,
          age: age,
          avatarUrl: Value(avatarSeed),
          accentColor: accentColor,
          userId: Value(userId),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await _syncEngine.enqueue(
        entityType: 'member',
        entityId: memberUuid,
        operationType: OperationType.create,
        payload: {
          'familyId': familyId,
          'name': name,
          'role': role.name,
          'age': age,
          'avatarSeed': avatarSeed,
          'accentColor': accentColor,
          'userId': userId,
        },
      );

      return Result.success(
        Member(
          id: localId.toString(),
          remoteId: memberUuid,
          familyId: familyId,
          name: name,
          role: role,
          age: age,
          avatarSeed: avatarSeed,
          accentColor: accentColor,
          userId: userId,
          createdAt: now,
        ),
      );
    } catch (e, st) {
      return Result.failure(
        DatabaseFailure(
          message: 'Failed to create member: $e',
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<List<Member>>> getMembersForFamily(String familyId) async {
    try {
      final rows = await _localDatasource.getMembersForFamily(familyId);
      final members = rows.map(_rowToMember).toList();
      return Result.success(members);
    } catch (e, st) {
      return Result.failure(
        DatabaseFailure(
          message: 'Failed to get members: $e',
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Stream<List<Member>> watchMembersForFamily(String familyId) {
    return _localDatasource
        .watchMembersForFamily(familyId)
        .map((rows) => rows.map(_rowToMember).toList());
  }

  Member _rowToMember(MembersTableData row) {
    return Member(
      id: row.id.toString(),
      remoteId: row.remoteId,
      familyId: row.familyId,
      name: row.name,
      role: row.role,
      age: row.age,
      avatarSeed: row.avatarUrl ?? 'avatar_default',
      accentColor: row.accentColor,
      userId: row.userId,
      points: row.points,
      currentStreak: row.currentStreak,
      longestStreak: row.longestStreak,
      hasPin: row.pinHash != null,
      createdAt: row.createdAt,
    );
  }

  // ... remaining methods follow the same pattern
}
```

---

## 6. Active Profile Management

### 6.1 ActiveProfileCubit

```dart
// lib/features/family/presentation/bloc/active_profile_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/member.dart';
import '../../domain/repositories/member_repository.dart';

/// Manages the currently active family member profile.
/// Persists the active member ID in SharedPreferences (device-specific).
@lazySingleton
class ActiveProfileCubit extends Cubit<Member?> {
  ActiveProfileCubit(this._prefs, this._memberRepository) : super(null);

  final SharedPreferences _prefs;
  final MemberRepository _memberRepository;
  static const _activeProfileKey = 'active_profile_id';

  /// Loads the persisted active profile on app start.
  Future<void> loadActiveProfile() async {
    final memberId = _prefs.getString(_activeProfileKey);
    if (memberId == null) {
      emit(null);
      return;
    }

    final result = await _memberRepository.getMember(memberId);
    result.when(
      success: (member) => emit(member),
      failure: (_) => emit(null),
    );
  }

  /// Switches to a different profile.
  /// For parent profiles, PIN verification must happen BEFORE calling this.
  Future<void> switchProfile(Member member) async {
    await _prefs.setString(_activeProfileKey, member.id);
    emit(member);
  }

  /// Clears the active profile (on sign-out).
  Future<void> clearProfile() async {
    await _prefs.remove(_activeProfileKey);
    emit(null);
  }

  /// Returns the current member ID, or null.
  String? get activeMemberId => _prefs.getString(_activeProfileKey);

  /// Whether the active profile is a parent.
  bool get isParentProfile => state?.isParent ?? false;
}
```

---

## 7. Avatar System

### 7.1 Pre-Defined Avatars

12 illustrated avatar options, stored as local assets. Each has a unique identifier (seed) used in the `avatarSeed` field.

| # | Seed | Asset Path | Description |
|---|------|-----------|-------------|
| 1 | `avatar_fox` | `assets/images/avatars/fox.png` | Friendly orange fox |
| 2 | `avatar_bunny` | `assets/images/avatars/bunny.png` | Soft pink bunny |
| 3 | `avatar_bear` | `assets/images/avatars/bear.png` | Brown bear |
| 4 | `avatar_owl` | `assets/images/avatars/owl.png` | Wise purple owl |
| 5 | `avatar_cat` | `assets/images/avatars/cat.png` | Gray cat |
| 6 | `avatar_dog` | `assets/images/avatars/dog.png` | Golden retriever |
| 7 | `avatar_panda` | `assets/images/avatars/panda.png` | Black and white panda |
| 8 | `avatar_penguin` | `assets/images/avatars/penguin.png` | Tuxedo penguin |
| 9 | `avatar_lion` | `assets/images/avatars/lion.png` | Majestic lion |
| 10 | `avatar_elephant` | `assets/images/avatars/elephant.png` | Gentle elephant |
| 11 | `avatar_giraffe` | `assets/images/avatars/giraffe.png` | Tall giraffe |
| 12 | `avatar_dolphin` | `assets/images/avatars/dolphin.png` | Playful dolphin |

### 7.2 Avatar Helper

```dart
// lib/shared/utils/avatar_utils.dart

/// Maps avatar seeds to asset paths and display names.
abstract class AvatarUtils {
  static const Map<String, String> avatarAssets = {
    'avatar_fox': 'assets/images/avatars/fox.png',
    'avatar_bunny': 'assets/images/avatars/bunny.png',
    'avatar_bear': 'assets/images/avatars/bear.png',
    'avatar_owl': 'assets/images/avatars/owl.png',
    'avatar_cat': 'assets/images/avatars/cat.png',
    'avatar_dog': 'assets/images/avatars/dog.png',
    'avatar_panda': 'assets/images/avatars/panda.png',
    'avatar_penguin': 'assets/images/avatars/penguin.png',
    'avatar_lion': 'assets/images/avatars/lion.png',
    'avatar_elephant': 'assets/images/avatars/elephant.png',
    'avatar_giraffe': 'assets/images/avatars/giraffe.png',
    'avatar_dolphin': 'assets/images/avatars/dolphin.png',
  };

  static String getAssetPath(String seed) {
    return avatarAssets[seed] ?? avatarAssets.values.first;
  }

  static List<String> get allSeeds => avatarAssets.keys.toList();
}
```

---

## 8. Accent Color Palette

8 pastel colors from the design system, one assignable per member.

| # | Name | Hex | Usage |
|---|------|-----|-------|
| 1 | Sky Blue | `#A8D8EA` | Member accent, chart color |
| 2 | Coral Pink | `#F4A9A8` | Member accent, chart color |
| 3 | Mint Green | `#B8E6D0` | Member accent, chart color |
| 4 | Lavender | `#C5B3E6` | Member accent, chart color |
| 5 | Sunny Yellow | `#F7E6A1` | Member accent, chart color |
| 6 | Peach | `#F6C9A0` | Member accent, chart color |
| 7 | Sage | `#C1D5B0` | Member accent, chart color |
| 8 | Rose | `#E8B0C9` | Member accent, chart color |

```dart
// lib/shared/theme/member_colors.dart

import 'package:flutter/material.dart';

/// Pastel accent colors for family members.
abstract class MemberColors {
  static const List<MemberAccentColor> palette = [
    MemberAccentColor(name: 'Sky Blue', hex: '#A8D8EA', color: Color(0xFFA8D8EA)),
    MemberAccentColor(name: 'Coral Pink', hex: '#F4A9A8', color: Color(0xFFF4A9A8)),
    MemberAccentColor(name: 'Mint Green', hex: '#B8E6D0', color: Color(0xFFB8E6D0)),
    MemberAccentColor(name: 'Lavender', hex: '#C5B3E6', color: Color(0xFFC5B3E6)),
    MemberAccentColor(name: 'Sunny Yellow', hex: '#F7E6A1', color: Color(0xFFF7E6A1)),
    MemberAccentColor(name: 'Peach', hex: '#F6C9A0', color: Color(0xFFF6C9A0)),
    MemberAccentColor(name: 'Sage', hex: '#C1D5B0', color: Color(0xFFC1D5B0)),
    MemberAccentColor(name: 'Rose', hex: '#E8B0C9', color: Color(0xFFE8B0C9)),
  ];

  static Color fromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('FF');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

class MemberAccentColor {
  const MemberAccentColor({
    required this.name,
    required this.hex,
    required this.color,
  });

  final String name;
  final String hex;
  final Color color;
}
```

---

## 9. Presentation Layer -- Screens

### 9.1 AddMemberScreen

```dart
// lib/features/family/presentation/screens/add_member_screen.dart
//
// Layout:
// - AppBar: "Add Family Member" title, back button
// - Name TextFormField
//   - Hint: "Member's name"
//   - Validation: required, 2-30 chars
// - Age input (horizontal number picker or slider)
//   - Range: 2-100
//   - Default: 10
//   - Shows computed age group label (e.g., "Child (5-12)")
// - Role selector (SegmentedButton: "Parent" | "Child")
//   - Default: Child
//   - Parent requires the member to have a Firebase account (userId)
//   - For Phase 2: parent role only allowed if user provides email (future)
//   - Simplified: first member is always parent (creator), subsequent are children by default
// - Avatar picker (3x4 grid of circular avatar images)
//   - Selected avatar has a highlighted border
//   - Grid scrollable if needed
// - Color picker (horizontal row of 8 color circles)
//   - Selected color has a check mark overlay
//   - Auto-assigns unused color, user can override
// - "Add Member" primary ElevatedButton (full width)
// - "Add Another" secondary OutlinedButton (visible after first add)
// - "Done" TextButton (navigates to next step)
//
// Dimensions:
// - Avatar circles: 64px diameter
// - Color circles: 40px diameter
// - Horizontal padding: 24px
```

**Validation rules:**

| Field | Validation | Error Message |
|-------|-----------|---------------|
| Name | Required | "Please enter a name" |
| Name | Min 2 chars | "Name must be at least 2 characters" |
| Name | Max 30 chars | "Name must be 30 characters or less" |
| Age | Required | "Please select an age" |
| Age | Range 2-100 | "Age must be between 2 and 100" |
| Avatar | Required | "Please select an avatar" (pre-selected by default) |
| Color | Required | "Please select a color" (pre-selected by default) |

### 9.2 ProfileSwitcherScreen

```dart
// lib/features/family/presentation/screens/profile_switcher_screen.dart
//
// Layout:
// - Full-screen with family name as AppBar title
// - "Who's using the app?" heading text
// - Avatar grid (responsive: 2 columns on phone, 3 on tablet)
//   - Each cell: circular avatar (80px), name below, role badge below name
//   - Active member has colored ring border (their accent color) + slight scale
//   - Inactive members have gray border
//   - Touch target: minimum 88px (avatar + padding)
// - "+ Add Member" card at the end of the grid
//   - Plus icon in dashed circle, "Add Member" label
//   - Only visible for parent profiles
// - Bottom: "Sign Out" text button (small, secondary)
//
// Behavior:
// - Tap child avatar: immediate switch via ActiveProfileCubit
// - Tap parent avatar: navigate to /pin with redirect back to /profiles
//   - On PIN success: ActiveProfileCubit switches to parent
// - Tap active member's own avatar: no-op (already active)
// - Tap "+ Add Member": navigate to /family-setup/add-member
//
// Accessibility:
// - Each avatar has semantics label: "Switch to {name}'s profile"
// - Active indicator announced: "{name} is currently active"
// - Grid is semantically a list for screen readers
```

### 9.3 SettingsScreen (Stub)

```dart
// lib/features/family/presentation/screens/settings_screen.dart
//
// Layout:
// - AppBar: "Settings" title
// - Section: "Family Members" header
//   - List of members (ListTile: avatar, name, role chip)
//   - Tap member -> edit member form
//   - Trailing: edit icon for parents, info icon for children
// - Section: "Family" header
//   - "Family Name" tile showing current name
//   - "Invite Code" tile with generate/copy action
//   - "Leave Family" tile (destructive, red text)
// - Section: "Account" header
//   - "Change PIN" tile
//   - "Sign Out" tile
//
// All tiles are stubs in Phase 2 except:
// - Member list (functional, shows all members)
// - Invite code (functional if Cloud Functions deployed)
// - Sign Out (functional, dispatches SignOutRequested)
```

---

## 10. Impact Analysis

### 10.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| `lib/features/family/` | New/Modified | Medium | 15+ new files across layers |
| `MembersTable` (Drift) | Dependency | Low | Schema already defined, no changes |
| `SyncEngine` | Dependency | Medium | Member sync adapter needed |
| `SharedPreferences` | Dependency | Low | Active profile persistence |
| `app_router.dart` | Modified | Low | Profile switcher and add member routes |
| DI container | Modified | Low | New cubits, repositories, datasources |
| `assets/images/avatars/` | New | Low | 12 avatar image files |

### 10.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Active profile ID refers to deleted member | Low | High | On profile load, validate member exists. Clear if not found. |
| Profile switcher grid overflows on small phones | Medium | Low | Responsive grid with ScrollView. Test on 320px width. |
| Avatar images too large (memory) | Low | Medium | Pre-scale to 256x256. Use AssetImage with caching. |
| Concurrent profile switches on shared device | Low | Medium | ActiveProfileCubit is synchronous emit. Last write wins. |
| Child adds themselves as parent via age change | Low | Medium | Role is set at creation, not derived from age. Only parents can edit. |

---

## 11. Functional Tests

### 11.1 Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| MEM-FT-001 | Create child member | Family exists | AddMemberRequested dispatched | Member row in Drift with role=child, sync queued | High |
| MEM-FT-002 | Create parent member with userId | Family exists | AddMemberRequested with userId | Member row has userId set | High |
| MEM-FT-003 | Get members for family | 4 members exist | getMembersForFamily called | Returns all 4 members | High |
| MEM-FT-004 | Watch members stream | 2 members exist | watchMembersForFamily active, third added | Stream emits list of 3 | High |
| MEM-FT-005 | Switch to child profile | Marcus active | switchProfile(alex) called | ActiveProfileCubit emits Alex, SharedPreferences updated | High |
| MEM-FT-006 | Switch to parent profile requires PIN | Child active | Tap parent avatar | Router navigates to /pin | High |
| MEM-FT-007 | Active profile persists across restart | Alex active | App killed and restarted | loadActiveProfile returns Alex | High |
| MEM-FT-008 | Active profile cleared on sign-out | Any profile active | clearProfile called | ActiveProfileCubit emits null, SharedPreferences cleared | High |
| MEM-FT-009 | Update member age | Alex age 10 | updateMember(age: 11) | Drift row updated, sync queued | Medium |
| MEM-FT-010 | Delete member | Emma member exists | deleteMember called | Drift row deleted, sync queued | Medium |
| MEM-FT-011 | Cannot delete creator | Marcus is creator | deleteMember(marcus) attempted | Returns failure | High |
| MEM-FT-012 | Age group computation | Age 3 | member.ageGroup | Returns AgeGroup.toddler | Medium |
| MEM-FT-013 | Age group computation | Age 10 | member.ageGroup | Returns AgeGroup.child | Medium |
| MEM-FT-014 | Avatar seed maps to asset | "avatar_fox" seed | AvatarUtils.getAssetPath called | Returns correct path | Low |
| MEM-FT-015 | Member creation offline | No internet | Create member | Drift write succeeds, sync queued | High |

### 11.2 Widget Tests

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| MEM-FT-020 | Add member screen renders all fields | Screen mounted | -- | Name, age, role, avatar grid, color row visible | High |
| MEM-FT-021 | Empty name shows validation error | Name field empty | Add button tapped | "Please enter a name" shown | Medium |
| MEM-FT-022 | Avatar selection highlights | Fox avatar tapped | -- | Fox has highlighted border, others do not | Medium |
| MEM-FT-023 | Color selection shows check | Coral tapped | -- | Coral has check overlay | Medium |
| MEM-FT-024 | Profile switcher shows all members | 4 members exist | Screen mounted | 4 avatar circles visible with names | High |
| MEM-FT-025 | Active indicator on current profile | Marcus active | Screen mounted | Marcus avatar has accent ring | High |
| MEM-FT-026 | Add member card visible for parents | Parent active | Screen mounted | "+ Add Member" card visible | Medium |
| MEM-FT-027 | Add member card hidden for children | Child active | Screen mounted | "+ Add Member" card not visible | Medium |

### 11.3 Edge Cases

- Member name with Unicode characters (emoji, accented letters).
- Age at boundary values (2, 4, 5, 12, 13, 17, 18).
- All 8 colors already assigned -- user must reuse a color.
- Two members with the same avatar -- allowed (avatars are not unique).
- Delete the last child in the family -- should succeed.
- Active profile points to a member in a different family after family switch -- should clear profile.

---

## 12. Implementation Recommendations

### 12.1 Prototype Checklist

1. **What can a user do?** As Marcus, I can add Sofia, Alex, and Emma as family members with avatars and colors, then switch between profiles by tapping avatars on the profile switcher.
2. **Screens delivered:** `/family-setup/add-member`, `/profiles`, `/settings` (stub)
3. **Minimum data flow:** Marcus taps "Add Member" -> enters name/age/role -> selects avatar/color -> MemberRepositoryImpl writes to Drift -> SyncEngine queues -> profile appears in switcher.
4. **Offline behavior:** All member operations work offline. Member data is stored in Drift. Profile switching is local-only (SharedPreferences). Sync happens when connectivity returns.
5. **Done looks like:** A tester can add 3 family members after family creation, see all 4 members on the profile switcher, tap a child's avatar to switch instantly, and see the active profile persist after app restart.

### 12.2 Suggested Approach

1. Create `Member` entity in domain layer.
2. Create `MemberRepository` abstract interface.
3. Implement `MemberLocalDatasource` (Drift DAO).
4. Implement `MemberRemoteDatasource` (Firestore).
5. Implement `MemberRepositoryImpl`.
6. Implement `ActiveProfileCubit`.
7. Create avatar assets (12 images) in `assets/images/avatars/`.
8. Implement `AvatarUtils` and `MemberColors`.
9. Implement `AddMemberScreen` with avatar and color pickers.
10. Implement `ProfileSwitcherScreen`.
11. Implement `SettingsScreen` (stub).
12. Write unit tests for MemberRepositoryImpl, ActiveProfileCubit.
13. Write widget tests for AddMemberScreen, ProfileSwitcherScreen.

### 12.3 Estimated Effort

**T-shirt size: M** (3-5 days)

The avatar/color picker UI requires attention to detail. ActiveProfileCubit is simple. The primary effort is in the UI and ensuring smooth profile switching.

---

## 13. Open Questions

- [ ] Should avatar images be vector (SVG) or raster (PNG)? SVGs scale better but need `flutter_svg` dependency.
- [ ] Should the profile switcher be accessible from a bottom navigation bar icon or only from the app bar?
- [ ] Should we allow custom avatar uploads in Phase 2, or only the 12 pre-defined options?
- [ ] Should the age input be a slider, a number picker, or a text field with validation?
- [ ] Should the "+ Add Member" card be visible to children, or only to parents with an active PIN session?

---

*Generated by Software Architect Analyst*
*Date: 2026-03-09*
