# Phase 3 Foundation -- Task Management Core

## 1. Overview

### 1.1 Summary

This specification defines the foundation work required for Phase 3: Task Management Core. It covers new go_router route definitions for all task and category screens, updated bottom navigation bar with task-centric tabs, new pubspec.yaml dependencies (rrule, table_calendar, flutter_animate, cached_network_image), updated Firestore security rules for tasks and categories, design tokens for task UI states, and offline behavior across Phase 3 features. This is the umbrella spec that establishes the infrastructure on which all other Phase 3 feature specs (18 through 24) are built.

### 1.2 Business Context

Phase 3 delivers the core value proposition: **"The chore loop works end-to-end, online and offline."** After Phase 2 onboarding, families have accounts, profiles, and a family unit -- but nothing to do inside the app. Phase 3 makes the app functional by enabling task creation, assignment, completion, verification, and recurring chore scheduling. The entire task lifecycle runs offline-first, with all writes going to local Drift DB first and syncing to Firestore in the background. This phase transforms the app from an identity management tool into a household chore coordinator.

### 1.3 Scope

**In scope:**
- New go_router routes for all Phase 3 screens (7 routes)
- Updated bottom navigation bar with Tasks tab as primary destination
- New pubspec.yaml dependencies: `rrule`, `table_calendar`, `flutter_animate`, `cached_network_image`
- Design tokens for task status colors (pending, completed, overdue, syncing)
- Updated Firestore security rules stubs for tasks and categories
- Phase 3 acceptance criteria summary for each deliverable
- Offline behavior specification for all Phase 3 features
- Lottie animation assets needed for task completion celebrations
- Firebase Storage path conventions for task photo proofs

**Out of scope:**
- Task domain layer (see `specs/18_task_domain.md`)
- Task data layer (see `specs/19_task_data_layer.md`)
- Task list screen (see `specs/20_task_list_screen.md`)
- Task creation screen (see `specs/21_task_creation_screen.md`)
- Task completion flow (see `specs/22_task_completion_flow.md`)
- Recurrence engine (see `specs/23_recurrence_engine.md`)
- Category management (see `specs/24_category_management.md`)
- Phase 3 test plan (see `specs/25_phase3_test_plan.md`)

### 1.4 References

- `specs/00_project_foundation.md` -- Section 4.5 (Data Model), Section 4.4 (Sync Engine), Section 7.5 (Dependencies)
- `specs/02_isar_schemas.md` -- TasksTable, CategoriesTable definitions
- `specs/03_sync_engine.md` -- Operation queue, LWW conflict resolution
- `specs/08_phase2_foundations.md` -- go_router setup, route guards, DI modules
- `specs/12_pin_system.md` -- PinGuard for parent-only routes
- `CLAUDE.md` -- Tech stack, architecture, resolved design decisions

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| P3F-001 | All Phase 3 routes are registered in go_router | High | Every screen listed in Phase 3 has a corresponding route that resolves without error |
| P3F-002 | Bottom navigation bar includes Tasks tab | High | Tasks tab is the primary/default tab after onboarding complete |
| P3F-003 | Task creation route is PIN-gated for parents | High | Navigating to `/tasks/new` triggers PinGuard for parent profiles |
| P3F-004 | Task edit route is PIN-gated for parents | High | Navigating to `/tasks/:taskId/edit` triggers PinGuard for parent profiles |
| P3F-005 | Category management route is PIN-gated | High | Navigating to `/categories` triggers PinGuard |
| P3F-006 | New dependencies resolve without conflicts | High | `flutter pub get` succeeds with all new Phase 3 dependencies |
| P3F-007 | Task status design tokens applied consistently | Medium | Pending=amber-100, completed=green-100, overdue=red-100, syncing=blue-100 across all task widgets |
| P3F-008 | Offline banner visible when connectivity lost | High | Existing ConnectivityMonitor drives offline banner on all Phase 3 screens |
| P3F-009 | Pending sync count badge visible in AppBar | High | Sync icon in AppBar shows red badge with unsynced operation count |
| P3F-010 | Lottie animation assets available for completion flow | Medium | `task_complete.json` Lottie file is in `assets/animations/` |
| P3F-011 | Firebase Storage paths follow convention | Medium | Photo proofs stored at `families/{familyId}/task_proofs/{taskId}/{memberId}_{timestamp}.jpg` |
| P3F-012 | Child profiles see role-appropriate navigation | High | Children see their tasks only; no task creation FAB visible for child profiles |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| P3F-NFR-001 | Route transition latency | Time from tap to screen render | < 200ms on mid-range device |
| P3F-NFR-002 | Bottom nav switch time | Time from tab tap to content render | < 100ms (instant feel) |
| P3F-NFR-003 | Dependency footprint increase | APK size increase from new deps | < 3 MB total increase |
| P3F-NFR-004 | Offline task operations | All CRUD operations work without internet | 100% of operations succeed locally |

### 2.3 Assumptions

- Phase 2 is complete: Firebase Auth, family creation, member profiles, profile switcher, PIN system, and route guards are all functional.
- The existing Drift schema for TasksTable and CategoriesTable (from `specs/02_isar_schemas.md`) is fully implemented and tested.
- The SyncEngine (from `specs/03_sync_engine.md`) is operational and can process task sync operations.
- The `ActiveProfileCubit` from Phase 2 provides the current active profile (member role, memberId, familyId).
- ConnectivityMonitor from Phase 1 is functional and emits connectivity state changes.

### 2.4 Constraints

- All task reads come from local Drift DB -- never from Firestore directly. This is an architectural invariant.
- All task writes go to local Drift DB first, then enqueue a SyncOperation. The UI never waits for Firestore sync.
- PIN-gated routes must use the existing PinGuard from Phase 2 -- no new guard implementations.
- The `rrule` package must support RFC 5545 subset: FREQ, INTERVAL, BYDAY, BYMONTHDAY, COUNT, UNTIL.
- Lottie animations must be < 100KB per file to keep app bundle small.

---

## 3. Route Configuration

### 3.1 Phase 3 Routes

All routes are nested under the authenticated shell route established in Phase 2. Task-related routes require an active family and profile.

```dart
// lib/app/router/app_router.dart (additions for Phase 3)
//
// Route tree for Phase 3:
//
// /tasks                          -- TaskListScreen (default tab)
// /tasks/new                      -- TaskCreationScreen (PIN-gated)
// /tasks/:taskId                  -- TaskDetailScreen
// /tasks/:taskId/edit             -- TaskEditScreen (PIN-gated)
// /tasks/:taskId/complete         -- TaskCompletionScreen (modal)
// /categories                     -- CategoryManagementScreen (PIN-gated)
// /categories/new                 -- CategoryCreateScreen (PIN-gated)
```

### 3.2 Route Definitions

```dart
// Route name constants
// lib/app/router/route_names.dart (additions)
abstract class RouteNames {
  // ... existing Phase 2 routes ...

  // Phase 3: Task Management
  static const String taskList = 'taskList';
  static const String taskCreate = 'taskCreate';
  static const String taskDetail = 'taskDetail';
  static const String taskEdit = 'taskEdit';
  static const String taskComplete = 'taskComplete';
  static const String categoryList = 'categoryList';
  static const String categoryCreate = 'categoryCreate';
}
```

```dart
// Route path constants
// lib/app/router/route_paths.dart (additions)
abstract class RoutePaths {
  // ... existing Phase 2 paths ...

  // Phase 3: Task Management
  static const String tasks = '/tasks';
  static const String taskCreate = '/tasks/new';
  static const String taskDetail = '/tasks/:taskId';
  static const String taskEdit = '/tasks/:taskId/edit';
  static const String taskComplete = '/tasks/:taskId/complete';
  static const String categories = '/categories';
  static const String categoryCreate = '/categories/new';
}
```

### 3.3 Route Guard Matrix

| Route | Auth Required | Family Required | PIN Required | Role Restriction |
|-------|--------------|----------------|-------------|-----------------|
| `/tasks` | Yes | Yes | No | None (role-aware content) |
| `/tasks/new` | Yes | Yes | Yes | Parent only |
| `/tasks/:taskId` | Yes | Yes | No | None (role-aware actions) |
| `/tasks/:taskId/edit` | Yes | Yes | Yes | Parent only |
| `/tasks/:taskId/complete` | Yes | Yes | No | Assignee or parent |
| `/categories` | Yes | Yes | Yes | Parent only |
| `/categories/new` | Yes | Yes | Yes | Parent only |

### 3.4 go_router Configuration

```dart
// Phase 3 route branch within ShellRoute
GoRoute(
  path: RoutePaths.tasks,
  name: RouteNames.taskList,
  builder: (context, state) => const TaskListScreen(),
  routes: [
    GoRoute(
      path: 'new',
      name: RouteNames.taskCreate,
      redirect: pinGuard, // PIN-gated
      builder: (context, state) => const TaskCreationScreen(),
    ),
    GoRoute(
      path: ':taskId',
      name: RouteNames.taskDetail,
      builder: (context, state) {
        final taskId = state.pathParameters['taskId']!;
        return TaskDetailScreen(taskId: taskId);
      },
      routes: [
        GoRoute(
          path: 'edit',
          name: RouteNames.taskEdit,
          redirect: pinGuard, // PIN-gated
          builder: (context, state) {
            final taskId = state.pathParameters['taskId']!;
            return TaskEditScreen(taskId: taskId);
          },
        ),
        GoRoute(
          path: 'complete',
          name: RouteNames.taskComplete,
          pageBuilder: (context, state) {
            final taskId = state.pathParameters['taskId']!;
            return MaterialPage(
              fullscreenDialog: true, // modal presentation
              child: TaskCompletionScreen(taskId: taskId),
            );
          },
        ),
      ],
    ),
  ],
),
GoRoute(
  path: RoutePaths.categories,
  name: RouteNames.categoryList,
  redirect: pinGuard, // PIN-gated
  builder: (context, state) => const CategoryManagementScreen(),
  routes: [
    GoRoute(
      path: 'new',
      name: RouteNames.categoryCreate,
      redirect: pinGuard, // PIN-gated
      builder: (context, state) => const CategoryCreateScreen(),
    ),
  ],
),
```

---

## 4. Bottom Navigation Bar

### 4.1 Updated Navigation Structure

Phase 3 introduces a bottom navigation bar with the following tabs:

| Tab | Icon | Label | Route | Notes |
|-----|------|-------|-------|-------|
| Tasks | `Icons.task_alt` | "Tasks" | `/tasks` | Primary tab, default after onboarding |
| Dashboard | `Icons.dashboard_outlined` | "Dashboard" | `/dashboard` | Placeholder (Phase 5 content) |
| Profile | `Icons.person_outline` | "Profile" | `/profile` | Profile switcher from Phase 2 |

### 4.2 Shell Route with Navigation Bar

```dart
// lib/app/router/app_shell.dart
//
// StatelessWidget wrapping Scaffold with BottomNavigationBar.
// Uses StatefulShellRoute from go_router for tab state preservation.
// Each tab maintains its own navigation stack.
//
// The Dashboard tab shows a placeholder screen with:
// "Dashboard coming in Phase 5" centered text.
//
// Active tab determined by current route path.
// Badge on Tasks tab shows overdue count (from TaskListBloc).
```

### 4.3 Navigation Bar Design Tokens

```dart
// Navigation bar follows Material Design 3 NavigationBar widget
// Active indicator color: Theme.colorScheme.primaryContainer
// Active icon color: Theme.colorScheme.onPrimaryContainer
// Inactive icon color: Theme.colorScheme.onSurfaceVariant
// Label style: Nunito, 12sp
// Height: 80dp (M3 default)
// Elevation: 3 (subtle shadow)
```

---

## 5. New Dependencies

### 5.1 pubspec.yaml Additions

```yaml
dependencies:
  # ... existing Phase 1 + 2 dependencies ...

  # Phase 3: Task Management
  rrule: ^0.2.8                    # RFC 5545 RRULE parsing and generation
  table_calendar: ^3.1.0           # Calendar widget for due date selection
  flutter_animate: ^4.5.0          # Micro-animations (checkbox bounce, points flash)
  cached_network_image: ^3.3.0     # Cached display of task photo proofs
```

### 5.2 Dependency Justification

| Package | Purpose | Alternatives Considered | Reason for Selection |
|---------|---------|------------------------|---------------------|
| `rrule` | Parse and generate RFC 5545 RRULE strings | Hand-rolled parser | Standards-compliant, well-tested, saves ~500 lines of custom code |
| `table_calendar` | Calendar date picker for task due dates | `flutter_datetime_picker`, Material date picker | Better UX for recurring task visualization, shows task dots on dates |
| `flutter_animate` | Declarative animation chains | Raw `AnimationController` | Cleaner code for sequential animations (completion flow), composable |
| `cached_network_image` | Display task photo proofs with caching | `NetworkImage` + manual cache | Built-in placeholder, error widget, disk cache management |

### 5.3 Existing Dependencies Used in Phase 3

| Package | Already in pubspec | Phase 3 Usage |
|---------|-------------------|---------------|
| `image_picker` | Yes (Phase 2) | Camera capture for task photo proof |
| `lottie` | Yes (Phase 1) | Celebration animation on task completion |
| `flutter_bloc` | Yes (Phase 1) | TaskListBloc, TaskCreationCubit, TaskCompletionCubit |
| `go_router` | Yes (Phase 1) | New Phase 3 routes |
| `drift` | Yes (Phase 1) | Task and Category DAOs |
| `uuid` | Yes (Phase 1) | Task and Category ID generation |
| `freezed` | Yes (Phase 1) | Task and Category entities, params classes |

---

## 6. Design Tokens for Task UI

### 6.1 Task Status Colors

```dart
// lib/shared/theme/task_colors.dart
import 'package:flutter/material.dart';

/// Design tokens for task status visual indicators.
/// These colors are applied as subtle background tints on TaskCard
/// and status badges throughout Phase 3 screens.
abstract class TaskColors {
  /// Pending tasks -- warm, attention-drawing but not alarming.
  static const Color pendingBackground = Color(0xFFFFF8E1);  // amber-50
  static const Color pendingAccent = Color(0xFFFFECB3);       // amber-100
  static const Color pendingIcon = Color(0xFFF57F17);         // amber-900

  /// Completed tasks -- positive, calming green.
  static const Color completedBackground = Color(0xFFE8F5E9); // green-50
  static const Color completedAccent = Color(0xFFC8E6C9);     // green-100
  static const Color completedIcon = Color(0xFF2E7D32);       // green-800

  /// Overdue tasks -- urgent red, requires attention.
  static const Color overdueBackground = Color(0xFFFFEBEE);   // red-50
  static const Color overdueAccent = Color(0xFFFFCDD2);       // red-100
  static const Color overdueIcon = Color(0xFFC62828);         // red-800

  /// Syncing tasks -- informational blue, transient state.
  static const Color syncingBackground = Color(0xFFE3F2FD);   // blue-50
  static const Color syncingAccent = Color(0xFFBBDEFB);       // blue-100
  static const Color syncingIcon = Color(0xFF1565C0);         // blue-800

  /// Verified tasks -- gold/premium feel.
  static const Color verifiedBackground = Color(0xFFFFF3E0);  // orange-50
  static const Color verifiedAccent = Color(0xFFFFE0B2);      // orange-100
  static const Color verifiedIcon = Color(0xFFE65100);        // orange-900

  /// Skipped tasks -- muted, de-emphasized.
  static const Color skippedBackground = Color(0xFFF5F5F5);   // grey-100
  static const Color skippedAccent = Color(0xFFE0E0E0);       // grey-300
  static const Color skippedIcon = Color(0xFF616161);         // grey-700
}
```

### 6.2 Task Card Dimensions

```dart
// Design specifications for TaskCard widget
//
// Card:
//   - Elevation: 1 (resting), 4 (pressed)
//   - Border radius: 12dp
//   - Padding: 16dp horizontal, 12dp vertical
//   - Margin: 4dp horizontal, 4dp vertical (between cards)
//   - Min height: 72dp
//
// Category color strip:
//   - Width: 4dp
//   - Height: full card height
//   - Position: left edge, inside border radius
//
// Checkbox:
//   - Size: 24dp (standard), 40dp touch target
//   - Position: right side of card
//   - Animation: scale(1.0 -> 1.2 -> 1.0) + fill on check (150ms)
//
// Points badge:
//   - Background: amber-100, border-radius 12dp
//   - Text: "{N} pts", Nunito 12sp bold
//   - Position: top-right corner of card
//
// Assignee avatars:
//   - Size: 24dp diameter
//   - Overlap: 8dp (stacked)
//   - Max visible: 3 ("+N" for overflow)
```

### 6.3 Sync Status Indicator

```dart
// AppBar sync status icon specifications
//
// States:
// 1. All synced (online):
//    - Icon: Icons.cloud_done, color: green-600
//    - No badge
//
// 2. Syncing in progress:
//    - Icon: Icons.cloud_sync, color: blue-600
//    - Animated rotation (360deg, 2s, repeat)
//
// 3. Pending operations (online, queued):
//    - Icon: Icons.cloud_upload, color: amber-600
//    - Red badge with count (top-right)
//    - Badge: 16dp circle, white text, Nunito 10sp bold
//
// 4. Offline:
//    - Icon: Icons.cloud_off, color: grey-400
//    - Red badge with count if pending operations exist
//    - Offline banner: full-width, grey-800 background, white text
//    - Banner text: "You're offline. Changes will sync when connected."
//    - Banner height: 32dp, Nunito 12sp
```

---

## 7. Firestore Security Rules (Phase 3 Stubs)

### 7.1 Task Document Rules

Full rules are defined in the Firestore security rules update for Phase 3 (cross-reference with `specs/13_firestore_security_rules.md`). Stub summary:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /families/{familyId} {
      // ... existing Phase 2 rules ...

      match /tasks/{taskId} {
        // Read: any family member
        allow read: if isFamilyMember(familyId);

        // Create: parent members only
        allow create: if isFamilyMember(familyId)
                      && isParentRole(familyId);

        // Update: parent can update any field;
        //         assigned member can update status, completedAt,
        //         completedByMemberId, subtasks, photoUrl
        allow update: if isFamilyMember(familyId)
                      && (isParentRole(familyId)
                          || isAssignedMember(familyId, taskId));

        // Delete: parent members only
        allow delete: if isFamilyMember(familyId)
                      && isParentRole(familyId);

        match /audit_log/{logId} {
          // Read: any family member
          allow read: if isFamilyMember(familyId);
          // Create: any family member (audit entries are append-only)
          allow create: if isFamilyMember(familyId);
          // No update or delete -- audit log is immutable
          allow update, delete: if false;
        }
      }

      match /categories/{categoryId} {
        // Read: any family member
        allow read: if isFamilyMember(familyId);
        // Write: parent members only
        allow write: if isFamilyMember(familyId)
                     && isParentRole(familyId);
      }
    }
  }
}
```

### 7.2 Helper Functions

```
// Helper function stubs (extend existing Phase 2 helpers)
function isAssignedMember(familyId, taskId) {
  return request.auth.uid in
    get(/databases/$(database)/documents/families/$(familyId)/tasks/$(taskId)).data.assigneeIds;
}
```

Note: The `isAssignedMember` function checks against `request.auth.uid`, but since children don't have Firebase Auth accounts, child task completion is always synced under the parent's auth token. The `completedByMemberId` field in the task document distinguishes who actually completed the task at the application level.

---

## 8. Offline Behavior Summary

### 8.1 Offline Behavior Matrix

| Operation | Offline Behavior | Sync on Reconnect | User Feedback |
|-----------|-----------------|-------------------|---------------|
| View task list | Works -- reads from Drift | N/A | None needed |
| Create task | Works -- writes to Drift, enqueues SyncOp | SyncEngine pushes to Firestore | "Pending sync" badge on task card |
| Edit task | Works -- updates Drift, enqueues SyncOp | SyncEngine pushes update | "Pending sync" badge |
| Delete task | Works -- soft-deletes in Drift, enqueues SyncOp | SyncEngine deletes from Firestore | Task disappears from list |
| Complete task | Works -- marks complete in Drift, awards points locally, enqueues SyncOp | SyncEngine pushes completion | Celebration plays immediately, "Pending sync" badge |
| Verify task | Works -- updates status in Drift, enqueues SyncOp | SyncEngine pushes verification | "Pending sync" badge |
| Photo proof capture | Works -- photo saved locally, path stored in Drift | Photo uploaded to Storage on reconnect | "Photo pending upload" label |
| Recurring instance generation | Works -- client-side generation from RRULE | Cloud Function generates server-side on reconnect | No user feedback needed |
| Category CRUD | Works -- all operations local-first | SyncEngine pushes to Firestore | "Pending sync" badge |
| Pull-to-refresh | Shows "offline" message | Triggers sync when connectivity restored | Offline banner |

### 8.2 Conflict Resolution for Tasks

Task conflicts use the same LWW (Last-Write-Wins) strategy defined in `specs/03_sync_engine.md`:

- **LWW by `updatedAt` timestamp**: Firestore server timestamp wins over local timestamp if Firestore version is newer.
- **Delete wins over edit**: If a task is deleted on one device and edited on another, the delete wins.
- **Losing writes preserved**: The overwritten version is saved to the `audit_log` subcollection for traceability.
- **Completion conflicts**: If two family members complete the same task simultaneously, the first-synced completion wins. The second receives a "Task already completed by {name}" notification (Phase 7).

### 8.3 Pending Sync Badge

```dart
// The pending sync count is derived from SyncOperationsTable
// in Drift, filtered by entityType in ('task', 'category').
//
// Badge updates reactively via a Drift watch query:
//   SELECT COUNT(*) FROM sync_operations
//   WHERE family_id = ? AND status = 'pending'
//
// The badge is displayed on:
// 1. AppBar sync icon (global count)
// 2. Individual TaskCard (per-task indicator)
// 3. Tasks tab in bottom nav (total pending count)
```

---

## 9. Animation Assets

### 9.1 Lottie Files Required

| File | Path | Purpose | Size Limit | Duration |
|------|------|---------|------------|----------|
| `task_complete.json` | `assets/animations/task_complete.json` | Confetti explosion on task completion | < 100KB | 2000ms |
| `task_verified.json` | `assets/animations/task_verified.json` | Subtle checkmark animation on verification | < 50KB | 800ms |
| `points_earned.json` | `assets/animations/points_earned.json` | Coins/stars floating up on points award | < 60KB | 1200ms |

### 9.2 Asset Registration

```yaml
# pubspec.yaml
flutter:
  assets:
    # ... existing assets ...
    - assets/animations/task_complete.json
    - assets/animations/task_verified.json
    - assets/animations/points_earned.json
```

---

## 10. Firebase Storage Configuration

### 10.1 Storage Path Convention

```
families/{familyId}/
  task_proofs/
    {taskId}/
      {memberId}_{timestamp}.jpg     # e.g., "abc123_1710000000.jpg"
```

### 10.2 Storage Security Rules (Stub)

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /families/{familyId}/task_proofs/{taskId}/{fileName} {
      // Read: any authenticated family member
      allow read: if request.auth != null;

      // Write: authenticated family member, max 5MB, image only
      allow write: if request.auth != null
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```

### 10.3 Photo Compression Settings

```dart
// Photo proof settings
// Max dimension: 800px (longest edge)
// JPEG quality: 85%
// Max file size after compression: ~500KB
// Storage class: Standard (Firebase default)
// Retention: 6 months (matches task history retention from CLAUDE.md)
```

---

## 11. Phase 3 Acceptance Criteria

### 11.1 Prototype Checklist

1. **What can a user do at the end of this phase that they couldn't do before?**
   - "As Marcus, I can create a chore for my family, assign it to Alex, and see it appear in the task list -- even when offline."
   - "As Alex, I can open the app, see my assigned chores, tap the checkbox, and watch a celebration animation with points awarded."
   - "As Sofia, I can verify completed chores and see a history of who did what."
   - "As Marcus, I can set up recurring chores (e.g., dishes every weekday) and have them auto-generate."

2. **Which screens are delivered?**

   | Screen | Route | Description |
   |--------|-------|-------------|
   | TaskListScreen | `/tasks` | Main screen with filterable task list |
   | TaskCreationScreen | `/tasks/new` | Multi-section form for creating tasks |
   | TaskDetailScreen | `/tasks/:taskId` | Full task details with actions |
   | TaskEditScreen | `/tasks/:taskId/edit` | Pre-filled form for editing tasks |
   | TaskCompletionScreen | `/tasks/:taskId/complete` | Modal with celebration animation |
   | CategoryManagementScreen | `/categories` | List of categories with CRUD |
   | CategoryCreateScreen | `/categories/new` | Form for creating custom categories |

3. **What is the minimum data flow?**
   - Parent taps "+" FAB -> enters task details -> taps "Save" -> `TaskCreationCubit` calls `CreateTask` use case -> `TaskRepositoryImpl.createTask()` generates UUID, writes to Drift with `syncStatus=pending`, enqueues `SyncOperation(type=create)` -> TaskListBloc receives updated stream from Drift -> TaskCard appears in list -> SyncEngine processes queue -> writes to Firestore -> `syncStatus` updates to `synced`.

4. **What is the offline behavior?**
   - All task CRUD operations work without internet. Tasks are created, edited, completed, and deleted in the local Drift database immediately. Each operation enqueues a `SyncOperation` in the operation queue. When connectivity is restored, the SyncEngine processes the queue in FIFO order with retry/backoff. A "pending sync" badge shows the count of unsynced operations. An offline banner appears at the top of the screen when disconnected.

5. **What does "done" look like?**
   - Manual acceptance test: Open app (signed in as Marcus) -> Create a task "Wash dishes" assigned to Alex with 10 points -> Switch to airplane mode -> Switch profile to Alex -> See "Wash dishes" in task list -> Tap checkbox -> See confetti animation and "+10 pts" flash -> Turn off airplane mode -> See sync badge clear -> Switch back to Marcus profile -> See "Wash dishes" marked as completed with "Completed by Alex" attribution.

### 11.2 Phase 3 Deliverables Summary

| Deliverable | Spec | Priority | Estimated Effort |
|-------------|------|----------|-----------------|
| Task domain layer (entities, repos, use cases) | `specs/18_task_domain.md` | High | M |
| Task data layer (Drift DAOs, Firestore, repo impl) | `specs/19_task_data_layer.md` | High | L |
| Task list screen (BLoC, UI, filters) | `specs/20_task_list_screen.md` | High | L |
| Task creation/edit screens | `specs/21_task_creation_screen.md` | High | L |
| Task completion flow (animation, points, photo) | `specs/22_task_completion_flow.md` | High | M |
| Recurrence engine (RRULE, instance generation) | `specs/23_recurrence_engine.md` | High | M |
| Category management | `specs/24_category_management.md` | Medium | S |
| Phase 3 test plan | `specs/25_phase3_test_plan.md` | High | L |

T-shirt sizes: S = 1-2 days, M = 3-5 days, L = 5-8 days

---

## 12. DI Module Updates

### 12.1 Task Module

```dart
// lib/app/di/modules/task_module.dart
import 'package:injectable/injectable.dart';

/// DI module for Phase 3 task management dependencies.
/// Registers datasources, repositories, use cases, and presentation layer.
///
/// Dependencies resolved:
/// - TaskLocalDatasource (Drift DAO)
/// - TaskRemoteDatasource (Firestore)
/// - TaskRepository -> TaskRepositoryImpl
/// - CategoryLocalDatasource (Drift DAO)
/// - CategoryRemoteDatasource (Firestore)
/// - CategoryRepository -> CategoryRepositoryImpl
/// - RecurrenceEngine -> RecurrenceEngineImpl
/// - TaskInstanceGenerator
/// - All task use cases (CreateTask, CompleteTask, etc.)
///
/// All registrations use @injectable or @lazySingleton annotations
/// on the classes themselves -- this module file is for documentation.
/// The actual registration happens via build_runner code generation.
```

### 12.2 Registration Annotations

| Class | Annotation | Rationale |
|-------|-----------|-----------|
| `TaskLocalDatasource` | `@lazySingleton` | Single DAO instance shared across features |
| `TaskRemoteDatasource` | `@lazySingleton` | Single Firestore connection per datasource |
| `TaskRepositoryImpl` | `@LazySingleton(as: TaskRepository)` | Bound to abstract interface |
| `CategoryLocalDatasource` | `@lazySingleton` | Single DAO instance |
| `CategoryRemoteDatasource` | `@lazySingleton` | Single Firestore connection |
| `CategoryRepositoryImpl` | `@LazySingleton(as: CategoryRepository)` | Bound to abstract interface |
| `RecurrenceEngineImpl` | `@LazySingleton(as: RecurrenceEngine)` | Stateless, reusable |
| `TaskInstanceGenerator` | `@lazySingleton` | Stateless, reusable |
| `CreateTask` | `@injectable` | Use case, new instance per call site |
| `CompleteTask` | `@injectable` | Use case |
| `TaskListBloc` | `@injectable` | New instance per screen |
| `TaskCreationCubit` | `@injectable` | New instance per screen |
| `TaskCompletionCubit` | `@injectable` | New instance per completion flow |
| `CategoryManagementCubit` | `@injectable` | New instance per screen |

---

## 13. Cross-Phase Dependencies

### 13.1 Dependencies on Phase 1

| Phase 1 Component | Phase 3 Usage |
|-------------------|---------------|
| Drift database (`AppDatabase`) | TasksTable, CategoriesTable, SyncOperationsTable |
| SyncEngine | Enqueue and process task/category sync operations |
| ConnectivityMonitor | Drive offline banner and sync triggers |
| BLoC foundation mixins | Error handling, loading states in TaskListBloc |
| Result type | All repository and use case return types |
| Failure hierarchy | TaskFailure extends Failure |

### 13.2 Dependencies on Phase 2

| Phase 2 Component | Phase 3 Usage |
|-------------------|---------------|
| AuthBloc | Ensure user is authenticated before task operations |
| ActiveProfileCubit | Get current member role, memberId, familyId |
| PinGuard | Gate task creation, editing, deletion, category management |
| MemberRepository | Award points on task completion, get member display info |
| FamilyRepository | Get family context for task scoping |

### 13.3 Phase 3 Components Used by Later Phases

| Phase 3 Component | Later Phase Usage |
|-------------------|-------------------|
| TaskRepository | Phase 4 (Rewards -- points source), Phase 5 (Fairness Dashboard) |
| CategoryRepository | Phase 5 (Dashboard charts by category) |
| RecurrenceEngine | Phase 7 (Notification scheduling for recurring tasks) |
| Task entity | Phase 4 (point calculations), Phase 5 (fairness metrics), Phase 6 (age-appropriate display) |

---

## 14. Impact Analysis

### 14.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| `app_router.dart` | Modified | Medium | Adding 7 new routes to existing router |
| `route_names.dart` | Modified | Low | Adding constants |
| `route_paths.dart` | Modified | Low | Adding constants |
| `app.dart` | Modified | Medium | Adding TaskListBloc to MultiBlocProvider |
| `app_shell.dart` | New | Medium | Bottom navigation bar wrapper |
| `pubspec.yaml` | Modified | Low | Adding 4 new dependencies |
| `lib/features/tasks/` | New | Low | Entire new feature directory |
| `lib/shared/theme/task_colors.dart` | New | Low | Design tokens |
| `firestore.rules` | Modified | High | New task and category rules |
| `assets/animations/` | Modified | Low | New Lottie files |

### 14.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| `rrule` package incompatibility with Dart 3.x | Low | High | Verify compatibility before adding; fallback to `recurring_rrule` package |
| Bottom nav disrupts existing Phase 2 navigation | Medium | Medium | Integration test: all Phase 2 routes still accessible after nav bar added |
| Large photo proofs slow down sync | Medium | Medium | Compress to 800px/85% JPEG; upload separately from task data sync |
| Recurring task instances create Drift storage bloat | Medium | Low | 30-day window limit; cleanup job deletes instances older than 6 months |
| Sync conflicts on simultaneous task completion | Low | Medium | LWW resolution; audit log preserves losing write; UX message in Phase 7 |

---

## 15. Implementation Recommendations

### 15.1 Suggested Approach

1. **Add new dependencies** to `pubspec.yaml` and run `flutter pub get`.
2. **Create design tokens** (`TaskColors`, task card dimensions) in `lib/shared/theme/`.
3. **Add Lottie animation assets** to `assets/animations/`.
4. **Update route configuration** -- add all Phase 3 routes to `app_router.dart`.
5. **Implement bottom navigation bar** in `app_shell.dart`.
6. **Update Firestore security rules** with task and category stubs.
7. **Update Firebase Storage rules** for photo proofs.
8. **Run existing Phase 1 + 2 tests** to verify no regressions.
9. **Proceed to feature specs** (18 through 24) in dependency order.

### 15.2 Suggested Feature Implementation Order

1. Task domain layer (spec 18) -- entities and interfaces first
2. Category management (spec 24) -- simpler feature, validates data layer patterns
3. Task data layer (spec 19) -- Drift DAOs, Firestore datasource, repository
4. Recurrence engine (spec 23) -- standalone service, no UI dependency
5. Task list screen (spec 20) -- main screen, validates end-to-end flow
6. Task creation screen (spec 21) -- form with recurrence and category integration
7. Task completion flow (spec 22) -- celebration moment, points, photo proof
8. Phase 3 test plan (spec 25) -- executed throughout, finalized last

### 15.3 Estimated Effort

Total Phase 3: **L-XL (3-4 weeks for one developer)**

---

*Generated by Software Architect Analyst*
*Date: 2026-03-09*
