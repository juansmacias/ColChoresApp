# Project Foundation -- Family Chores App

## 1. Overview

### 1.1 Summary

This document defines the foundational architecture for the Family Chores App, a Flutter-based mobile application that helps families coordinate household chores, build responsibility in children, and make invisible household labor visible. The app follows an offline-first architecture with cloud synchronization, supports multiple family members across shared and individual devices, and provides age-appropriate interfaces for users ranging from age 3 to adults.

### 1.2 Business Context

The app addresses three core Jobs to Be Done identified in the discovery phase:

1. **Coordinate Without Conflict** -- Offload the mental load of household management from a single parent to a shared system.
2. **Build Responsibility in Children** -- Provide a structured, motivating framework for teaching kids that contributing to the household is normal.
3. **Make the Invisible Work Visible** -- Create shared visibility into who is contributing what, enabling fact-based fairness conversations instead of emotionally charged arguments.

The offline-first constraint is driven by the primary usage context: families operate in kitchens, basements, garages, backyards, and other areas where connectivity is unreliable. A chore app that fails when the Wi-Fi drops is a chore app that gets abandoned. The system must be fully functional without internet at all times.

### 1.3 Scope

**In scope:**
- Flutter mobile application (iOS and Android)
- Firebase backend (Auth, Firestore, Cloud Functions, Cloud Messaging, Crashlytics, Analytics)
- Offline-first local storage with sync engine
- Multi-user family management with profile switching
- Parental PIN protection for sensitive operations
- Age-appropriate UI (standard view, simplified toddler view)
- Task management (create, assign, complete, verify, recur)
- Reward and points system
- Fairness dashboard and contribution tracking
- Push notifications for reminders and completions

**Out of scope (v1):**
- Web application
- Tablet-optimized layout (responsive support deferred to v1.1)
- Integration with external calendars or smart home devices
- Social features between families
- In-app purchases or monetization
- AI-powered task suggestions

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| FR-001 | Family group creation and management | High | A parent can create a family group, invite members via link or code, and manage membership. All data is scoped to the family group. |
| FR-002 | Family member profiles | High | Each family member has a profile with name, role (parent/child), age, avatar, and personal accent color. Profiles are stored locally and synced to cloud. |
| FR-003 | Profile switching on shared devices | High | On a shared device (e.g., kitchen tablet), any family member can switch to their profile with a single tap. Parent profiles require PIN to access settings. |
| FR-004 | Task creation with full metadata | High | Parents can create tasks with: title, description, category, assignee(s), due date/time, recurrence rule, difficulty/points value, age group, checklist of subtasks, and optional photo verification requirement. |
| FR-005 | Task assignment | High | Tasks can be assigned to one or more family members. Unassigned tasks appear in a shared pool. Tasks can be reassigned by parents at any time. |
| FR-006 | Task completion | High | Any assigned member can mark their task as complete. Completion records timestamp, member ID, and optional photo proof. Completion triggers celebration animation. |
| FR-007 | Task verification by parent | Medium | Parents can optionally require verification before a task is marked as truly complete. Unverified completions show as "pending review." |
| FR-008 | Recurring tasks | High | Tasks can recur daily, weekly, on specific weekdays, biweekly, or monthly. Recurrence generates new task instances automatically. |
| FR-009 | Reward and points system | Medium | Completed tasks earn points. Points accumulate per family member. Parents define rewards with point costs. Members can redeem rewards when they have sufficient points. |
| FR-010 | Fairness dashboard | High | A dashboard shows contribution data per family member over configurable time periods (today, this week, this month). Includes task counts, points earned, and completion rates. Emma's data is excluded from comparative views. |
| FR-011 | Push notifications | Medium | Reminders for upcoming and overdue tasks. Notifications when a family member completes a task. Configurable per member. Requires cloud connectivity to send. |
| FR-012 | Offline task management | High | All CRUD operations on tasks work without internet. Changes are queued and synced when connectivity resumes. |
| FR-013 | Emma's simplified view | Medium | When Emma's profile is active, the UI switches to a picture-based, large-touch-target view with no text requirements and immediate celebration animations. |
| FR-014 | Parent PIN protection | High | Sensitive operations (settings, task creation/deletion, reward management, fairness data, family management) are protected by a 4-6 digit PIN set by each parent. |
| FR-015 | Connectivity status indicator | High | The app clearly communicates whether it is online, offline, or syncing. Users understand which operations are local-only and which have been synced. |
| FR-016 | Category management | Low | Parents can create and manage task categories (e.g., Kitchen, Bathroom, Yard, Pets). Categories have icons and colors. |
| FR-017 | Task history and audit log | Medium | A chronological log of all task events (created, assigned, completed, verified, skipped) accessible to parents. |
| FR-018 | Streak tracking | Low | Consecutive days of completing all assigned tasks tracked per member. Visible on profile and dashboard. |
| FR-019 | Complete on behalf of | Medium | A parent can mark a task as complete on behalf of Emma or any other member, with a single tap plus attribution. |
| FR-020 | Authentication | High | Parents authenticate via Firebase Auth (email/password, Google Sign-In, Apple Sign-In). Children do not need individual Firebase accounts -- they exist as family member profiles managed by parents. |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| NFR-001 | Offline availability | Time to usable state without network | < 1 second (cold start from local cache) |
| NFR-002 | Sync latency | Time from connectivity restored to sync complete | < 5 seconds for typical queue (< 50 operations) |
| NFR-003 | Local storage size | Maximum local database size | < 50 MB for a family with 1 year of data |
| NFR-004 | App startup time | Cold start to interactive | < 2 seconds on mid-range device |
| NFR-005 | Battery impact | Background sync frequency | Sync only on app foreground or significant connectivity change, no polling |
| NFR-006 | Data consistency | Conflict resolution correctness | Zero data loss on merge conflicts; last-write-wins with full audit trail |
| NFR-007 | Security | PIN brute force protection | Lockout after 5 failed attempts for 5 minutes, escalating |
| NFR-008 | Accessibility | WCAG compliance | AA level for all interactive elements |
| NFR-009 | Crash rate | Production crash-free sessions | > 99.5% measured via Crashlytics |
| NFR-010 | Test coverage | Line coverage on business logic | >= 80% |
| NFR-011 | Supported platforms | Minimum OS versions | iOS 15+, Android API 26+ (Android 8.0) |
| NFR-012 | Localization readiness | i18n support | All user-facing strings externalized from day one. English only for v1, structure supports future languages. |

### 2.3 Assumptions

- The family size for v1 is capped at 8 members (2 parents + up to 6 children). This simplifies sync and permissions.
- Parents have Firebase accounts (email or social login). Children are represented as profiles within the family group, not as independent Firebase users.
- A single device can host multiple family member profiles (shared tablet use case).
- The app is designed for smartphones first. Tablet optimization is a follow-up.
- Internet connectivity is available at least intermittently (the app is not designed for permanent offline use with zero sync).
- Firebase Blaze plan is acceptable for the backend (required for Cloud Functions).
- The app will not handle financial transactions for rewards -- rewards are symbolic or tracked externally by parents.

### 2.4 Constraints

- **Flutter only** -- no native platform code except through established plugins.
- **Firebase ecosystem** -- no mixing of backend providers. All server-side logic runs on Firebase.
- **SOLID, Clean Code, TDD** -- enforced per `development-rules.md`. All architecture decisions must support testability.
- **Design system compliance** -- all UI must follow `design-system.md` (Material Design 3, Nunito font, pastel palette).
- **Offline-first is non-negotiable** -- every feature must specify its offline behavior. Features that cannot work offline must clearly communicate this to the user.

---

## 3. Use Cases

### UC-001: Family Onboarding

- **Actor**: Parent (Sofia or Marcus)
- **Preconditions**: App is installed. No family group exists on this device.
- **Main Flow**:
  1. Parent opens the app for the first time.
  2. App presents sign-in options (email/password, Google, Apple).
  3. Parent authenticates via Firebase Auth.
  4. App prompts: "Create a new family or join an existing one?"
  5. Parent selects "Create new family."
  6. Parent enters family name and sets up their own profile (name, role=parent, avatar).
  7. App generates a family invite code (6-character alphanumeric, valid for 48 hours).
  8. Parent adds child profiles directly (name, age, avatar) -- children do not need accounts.
  9. Family group is created locally and synced to Firestore.
  10. Parent is taken to the empty dashboard with an onboarding prompt to create first tasks.
- **Alternative Flows**:
  - 5a. Parent selects "Join existing family" and enters an invite code. App validates the code against Firestore, adds the parent to the family, and syncs all family data locally.
  - 3a. Parent is offline during signup. Signup is blocked -- Firebase Auth requires connectivity. App shows a clear message: "Internet connection required to create your account. You'll be fully offline-capable after first setup."
- **Postconditions**: Family group exists in Firestore and local DB. Parent profile is active. Child profiles are created.
- **Exceptions**:
  - Invalid invite code: "This code is invalid or has expired. Ask a family member for a new one."
  - Network failure mid-signup: Partial state is rolled back. User is asked to retry.

### UC-002: Create and Assign a Chore

- **Actor**: Parent (Sofia)
- **Preconditions**: Family group exists. At least one family member profile exists.
- **Main Flow**:
  1. Sofia taps the FAB (+) button on the dashboard.
  2. Bottom sheet opens with the task creation form.
  3. Sofia enters: title ("Unload dishwasher"), category (Kitchen), assignee (Alex), due date (today, 5 PM), recurrence (daily on weekdays), points (10), and optionally a checklist ("Top rack", "Bottom rack", "Silverware").
  4. Sofia taps "Create."
  5. Task is saved to local DB immediately. UI updates optimistically.
  6. Task is added to the sync queue for upload to Firestore.
  7. If online, sync happens within seconds. If offline, task persists locally and syncs when connectivity resumes.
  8. Alex receives a push notification (if online): "New chore: Unload dishwasher -- due today at 5 PM."
- **Alternative Flows**:
  - 3a. Sofia assigns the task to "Anyone" (unassigned). The task appears in the shared task pool visible to all family members.
  - 3b. Sofia creates a task for Emma. The task is tagged with ageGroup=toddler and appears in Emma's simplified view with a picture icon.
- **Postconditions**: Task exists in local DB. Task is queued for sync. Assigned member sees the task in their view.
- **Exceptions**:
  - Validation failure (e.g., no title): Inline error message, form is not submitted.
  - Local DB write failure: Error toast, user asked to retry. Logged to Crashlytics.

### UC-003: Complete a Chore (Alex, age 10)

- **Actor**: Alex (child, age 10)
- **Preconditions**: Alex has an assigned task that is not yet completed.
- **Main Flow**:
  1. Alex opens the app and sees his task list (profile auto-selected on his personal device, or he taps his avatar on shared device).
  2. Alex taps the checkbox on "Unload dishwasher."
  3. The checkbox animates to filled (green checkmark, 400ms spring animation).
  4. A celebration overlay appears briefly (confetti, 1.5s).
  5. Points are added to Alex's balance locally.
  6. Task status changes to "completed" (or "pending review" if verification is required).
  7. Completion event is queued for sync.
  8. When synced, Sofia and Marcus receive a push notification: "Alex completed: Unload dishwasher."
- **Alternative Flows**:
  - 2a. The task requires photo verification. After tapping complete, the camera opens. Alex takes a photo. The photo is stored locally and queued for upload. Task is marked "pending review."
  - 6a. The task has a subtask checklist. Alex must check off each subtask before the main completion is available. Progress bar shows on the task card.
- **Postconditions**: Task is marked complete with timestamp and actor ID. Points are credited. Sync queue updated.
- **Exceptions**:
  - Alex tries to complete a task assigned to someone else: Blocked. "This task is assigned to Emma."
  - Photo capture fails: Task can still be marked complete without photo. A note is attached: "Photo unavailable."

### UC-004: Complete a Chore on Behalf of Emma (Parent-Mediated)

- **Actor**: Parent (Sofia) acting for Emma (age 3)
- **Preconditions**: Emma has an assigned toddler task. Sofia's device or shared device is available.
- **Main Flow**:
  1. Sofia switches to Emma's profile on the shared tablet (or opens Emma's view within her own profile).
  2. Emma's simplified view loads: large icons, picture-based tasks, pink-tinted background.
  3. Emma (with Sofia guiding) taps the large task card ("Put toys in bin" with a toy box illustration).
  4. Extended celebration animation plays (confetti + chime, 2.5s).
  5. Task is marked as completed, attributed to Emma, with a note "completed with parent."
  6. Completion is queued for sync.
- **Alternative Flows**:
  - 1a. Sofia uses "Complete on behalf of" from her own parent view without switching profiles. She selects Emma and the task. Same result, less ceremony.
- **Postconditions**: Task completed and attributed to Emma. No points are added to fairness comparisons (Emma is excluded).
- **Exceptions**: None specific beyond general offline/sync handling.

### UC-005: Review Fairness Dashboard (Marcus)

- **Actor**: Marcus (parent)
- **Preconditions**: Family has been using the app for at least a few days. Tasks have been completed.
- **Main Flow**:
  1. Marcus opens the app and navigates to the Dashboard/Fairness tab.
  2. PIN entry is required (fairness data is PIN-protected to prevent children from obsessing over comparisons).
  3. Marcus enters his 4-digit PIN.
  4. Dashboard shows: contribution rings for Marcus, Sofia, and Alex (Emma excluded). Each ring shows percentage of assigned tasks completed this week.
  5. Below the rings: a bar chart showing tasks completed per day per member for the current week.
  6. Marcus taps "This Month" to change the time period.
  7. Data updates from local DB. If online, a fresh sync is triggered first.
- **Alternative Flows**:
  - 2a. PIN is disabled for this parent (configurable). Dashboard loads directly.
  - 7a. Marcus is offline. Data is served from local DB with a banner: "Showing data from last sync: 2 hours ago."
- **Postconditions**: Marcus has reviewed contribution data. No data is modified.
- **Exceptions**:
  - PIN incorrect 5 times: Lockout for 5 minutes. Message: "Too many attempts. Try again in 5 minutes."

### UC-006: Manage Rewards (Sofia)

- **Actor**: Sofia (parent)
- **Preconditions**: Family group exists. Points system is active.
- **Main Flow**:
  1. Sofia navigates to Rewards section (PIN-protected).
  2. Sofia enters PIN.
  3. Sofia taps "Create Reward."
  4. Sofia enters: title ("30 min extra screen time"), point cost (50), optional description, optional icon.
  5. Reward is saved locally and queued for sync.
  6. Reward appears in Alex's reward catalog.
  7. When Alex accumulates 50 points, he can tap "Redeem" on the reward.
  8. Redemption is recorded. Points are deducted. Parents are notified.
- **Alternative Flows**:
  - 7a. Alex does not have enough points. "Redeem" button is disabled with tooltip: "You need 20 more points."
- **Postconditions**: Reward exists. Redemption logged if applicable.
- **Exceptions**: None beyond general offline/sync.

### UC-007: Handle Offline-to-Online Transition

- **Actor**: System (automated)
- **Preconditions**: Device has been offline. User has performed operations (task creation, completions, edits). Operations are queued locally.
- **Main Flow**:
  1. Device regains internet connectivity (detected via connectivity_plus plugin).
  2. Sync engine is activated.
  3. Pending operations queue is read in FIFO order.
  4. Each operation is sent to Firestore.
  5. For each operation, the server timestamp is recorded.
  6. Incoming changes from other family members' devices are pulled via Firestore snapshots.
  7. Conflicts are detected (same document modified by multiple devices while offline).
  8. Conflicts are resolved using last-write-wins based on server timestamp, with the losing write preserved in an audit log.
  9. Local DB is updated with merged state.
  10. UI is refreshed reactively via BLoC state emission.
  11. Sync status indicator transitions from "Syncing..." to "Up to date."
- **Alternative Flows**:
  - 4a. A specific operation fails (e.g., document deleted by another user). The operation is moved to a dead-letter queue. A non-blocking notification informs the user: "A task you edited was deleted by another family member."
  - 6a. Connectivity drops mid-sync. Sync pauses. Remaining operations stay in queue. Resumes on next connectivity event.
- **Postconditions**: Local and remote state are consistent. All successful syncs are confirmed. Failed operations are logged.
- **Exceptions**:
  - Firestore quota exceeded: Sync pauses, user informed, retry with exponential backoff.
  - Auth token expired: Silent re-authentication attempted. If fails, user prompted to sign in again.

### UC-008: Switch Profiles on Shared Device

- **Actor**: Any family member
- **Preconditions**: Device has multiple profiles configured. Current user is viewing one profile.
- **Main Flow**:
  1. User taps the current profile avatar in the top app bar.
  2. A bottom sheet shows all family member avatars in a horizontal row.
  3. User taps the desired profile.
  4. If the target profile is a parent, PIN entry is required for protected sections.
  5. The UI transitions to the selected member's personalized view (their tasks, their accent color, their progress ring).
  6. If the target is Emma, the entire UI switches to the simplified toddler view.
- **Alternative Flows**:
  - 3a. User taps "Add Profile" (only available to parents after PIN). Opens the profile creation form.
- **Postconditions**: Active profile is changed. UI reflects the selected member's data and theme.
- **Exceptions**: None specific.

---

## 4. Architectural Design

### 4.1 Current State

This is a greenfield project. No codebase exists. The project has documentation for Jobs to Be Done, User Personas, Design System, and Development Rules. The architecture is being defined from scratch.

### 4.2 Proposed Architecture

The architecture follows a **layered, offline-first** pattern with clear separation of concerns, designed to satisfy the SOLID principles mandated by the development rules.

**Key architectural decisions:**

1. **State Management: BLoC/Cubit** -- Chosen for its strict separation of UI and logic, testability, and stream-based reactivity that maps naturally to offline-first data flows.

2. **Local Database: Isar** -- Selected over Hive and Drift for the following reasons:
   - Isar provides full-text search, composite indexes, and multi-isolate support -- critical for querying tasks by assignee, date, category, and status without performance degradation.
   - Isar's object-based schema maps cleanly to Firestore documents, reducing serialization complexity.
   - Isar supports lazy loading and pagination natively, satisfying the performance guidelines in development-rules.md ("pagination is mandatory for any list query").
   - Hive was rejected because it lacks query capabilities (it is a key-value store) and requires manual indexing. For a relational data model with tasks, members, rewards, and categories, this creates unnecessary complexity.
   - Drift was considered (strong SQL query support) but rejected because it introduces an ORM abstraction over SQLite that adds cognitive load when the data model is document-oriented (matching Firestore's document model). Isar's NoSQL approach provides a more natural mapping.

3. **Sync Engine: Custom implementation** -- A dedicated sync engine manages the bidirectional flow between Isar (local) and Firestore (remote). This is the most architecturally significant component.

4. **Dependency Injection: get_it + injectable** -- Compile-time DI registration supporting the Dependency Inversion Principle.

5. **Routing: go_router** -- Declarative routing with deep link support and guard-based navigation (PIN protection, auth gates).

### 4.3 Architecture Diagram

```
+------------------------------------------------------------------+
|                        PRESENTATION LAYER                         |
|                                                                   |
|  +------------------+  +------------------+  +----------------+  |
|  |   Dashboard      |  |   Task List      |  |  Emma's View   |  |
|  |   Screen         |  |   Screen         |  |  (Simplified)  |  |
|  +--------+---------+  +--------+---------+  +-------+--------+  |
|           |                      |                    |           |
|  +--------v---------+  +--------v---------+  +-------v--------+  |
|  |  DashboardCubit  |  |   TaskListBloc   |  | EmmaViewCubit  |  |
|  +--------+---------+  +--------+---------+  +-------+--------+  |
|           |                      |                    |           |
+-----------+----------------------+--------------------+-----------+
            |                      |                    |
+-----------v----------------------v--------------------v-----------+
|                        DOMAIN LAYER                               |
|                                                                   |
|  +------------------+  +------------------+  +----------------+  |
|  |  ChoreService    |  | RewardService    |  | FamilyService  |  |
|  +--------+---------+  +--------+---------+  +-------+--------+  |
|           |                      |                    |           |
|  +--------v----------------------v--------------------v--------+  |
|  |                   Repository Interfaces                     |  |
|  |  TaskRepository | RewardRepository | FamilyRepository       |  |
|  +---+----------------------------+---------------------------+   |
|      |                            |                               |
+------+----------------------------+-------------------------------+
       |                            |
+------v----------------------------v-------------------------------+
|                         DATA LAYER                                |
|                                                                   |
|  +------------------------------+  +---------------------------+  |
|  |    Local Data Source          |  |   Remote Data Source      |  |
|  |    (Isar Database)            |  |   (Firestore)            |  |
|  |                              |  |                           |  |
|  |  +----------+ +----------+  |  |  +----------+ +--------+  |  |
|  |  | TaskDAO  | | MemberDAO|  |  |  |TaskRemote| |MemberR..|  |  |
|  |  +----------+ +----------+  |  |  +----------+ +--------+  |  |
|  +-------+----------------------+  +------------+--------------+  |
|          |                                       |                |
|  +-------v---------------------------------------v-------------+  |
|  |                      SYNC ENGINE                            |  |
|  |                                                             |  |
|  |  +-------------+  +----------------+  +-----------------+  |  |
|  |  | Operation   |  | Conflict       |  | Connectivity    |  |  |
|  |  | Queue       |  | Resolver       |  | Monitor         |  |  |
|  |  +-------------+  +----------------+  +-----------------+  |  |
|  |                                                             |  |
|  +-------------------------------------------------------------+  |
|                                                                   |
+-------------------------------------------------------------------+

+-------------------------------------------------------------------+
|                     CROSS-CUTTING CONCERNS                        |
|                                                                   |
|  +---------------+  +-----------+  +------------+  +-----------+  |
|  | Firebase Auth |  | FCM       |  | Crashlytics|  | Analytics |  |
|  | (PIN + Auth)  |  | (Push)    |  | (Errors)   |  | (Events)  |  |
|  +---------------+  +-----------+  +------------+  +-----------+  |
+-------------------------------------------------------------------+
```

### 4.4 Sync Engine -- Detailed Design

The sync engine is the core architectural component that enables the offline-first experience. It operates as an independent subsystem that mediates between the local database and Firestore.

#### 4.4.1 Operation Queue

Every write operation (create, update, delete) performed locally is recorded as a `SyncOperation` in a dedicated Isar collection:

```
SyncOperation {
  id: int (auto-generated)
  entityType: String          // "task", "reward", "member", "family"
  entityId: String            // UUID of the affected entity
  operationType: String       // "create", "update", "delete"
  payload: String             // JSON-serialized entity state at time of operation
  timestamp: DateTime         // Local device time when operation was performed
  status: String              // "pending", "in_progress", "completed", "failed"
  retryCount: int             // Number of sync attempts
  errorMessage: String?       // Last error if failed
  createdAt: DateTime
}
```

Operations are processed FIFO. If an operation fails, it is retried up to 3 times with exponential backoff (1s, 4s, 16s). After 3 failures, it is moved to `status: "failed"` and surfaces a user-visible notification.

#### 4.4.2 Conflict Resolution Strategy

The app uses **Last-Write-Wins (LWW) with audit trail** as the conflict resolution strategy.

**Why LWW over merge:**
- The data model is simple enough that field-level merge adds complexity without proportionate benefit. A task has a single assignee, a single status, a single due date. Two parents editing the same task simultaneously is rare, and when it happens, the most recent intent should prevail.
- True merge (CRDT-based) is justified for collaborative text editing but is over-engineering for a chore app with discrete fields.

**How it works:**
1. Every entity has an `updatedAt` timestamp set by the **server** (Firestore server timestamp) on write.
2. When syncing a local change, the sync engine sends the local `updatedAt` along with the new state.
3. A Firestore Cloud Function (or security rule with a custom claim) compares the incoming `updatedAt` with the stored `updatedAt`.
4. If the stored `updatedAt` is newer, the local change loses. The server state is sent back to the client.
5. The losing change is recorded in an `audit_log` subcollection with full before/after state, so no data is ever silently lost.
6. The client receives the authoritative state and updates the local DB.

**Edge case -- delete conflicts:**
- If Device A deletes a task while Device B edits it (both offline), the delete wins. The edited version is preserved in the audit log. Rationale: a parent who deletes a task has explicitly decided it should not exist. An edit to a deleted task is a stale operation.

#### 4.4.3 Sync Triggers

The sync engine activates under these conditions:

| Trigger | Behavior |
|---------|----------|
| App comes to foreground | Full sync: push pending operations, pull latest state |
| Connectivity restored (was offline) | Push pending operations, then pull |
| User performs a write operation while online | Immediate push of that operation (optimistic) |
| Firestore real-time listener fires | Pull the changed document into local DB |
| Manual pull-to-refresh | Full sync |
| Every 5 minutes while app is in foreground and online | Background pull for changes from other devices |

**The sync engine does NOT:**
- Run background sync when the app is not in foreground (battery conservation, per NFR-005).
- Poll Firestore. It uses Firestore's real-time snapshot listeners when online.
- Block the UI. All sync operations run in a separate isolate.

#### 4.4.4 Partial Sync Failure Handling

When a sync batch partially fails (e.g., 8 of 10 operations succeed, 2 fail):

1. Successful operations are marked `completed` in the queue and removed.
2. Failed operations remain in queue with `retryCount` incremented.
3. The UI shows: "Most changes synced. 2 items pending." (not an error -- a status).
4. Failed operations are retried on the next sync trigger.
5. If an operation fails 3 times consecutively, it is flagged, and the user sees: "Some changes could not be saved to the cloud. Tap to review." Tapping shows the specific items.

### 4.5 Data Model

#### 4.5.1 Firestore Document Structure

```
families/
  {familyId}/
    name: String
    createdAt: Timestamp
    inviteCode: String
    inviteCodeExpiresAt: Timestamp
    createdBy: String (userId)

    members/
      {memberId}/
        name: String
        role: "parent" | "child"
        age: int
        avatarUrl: String?
        accentColor: String
        userId: String?           // Firebase Auth UID (null for children)
        pinHash: String?          // bcrypt hash (parents only)
        deviceIds: [String]       // devices this member has logged into
        points: int
        currentStreak: int
        longestStreak: int
        createdAt: Timestamp
        updatedAt: Timestamp

    tasks/
      {taskId}/
        title: String
        description: String?
        category: String
        assigneeIds: [String]     // member IDs
        createdBy: String         // member ID
        dueDate: Timestamp?
        dueTime: String?          // "17:00" format
        recurrenceRule: String?   // RRULE format (RFC 5545 subset)
        points: int
        ageGroup: "toddler" | "child" | "teen" | "adult" | "any"
        status: "pending" | "in_progress" | "completed" | "verified" | "skipped"
        requiresVerification: bool
        requiresPhoto: bool
        subtasks: [{title: String, completed: bool}]
        completedAt: Timestamp?
        completedBy: String?      // member ID
        verifiedAt: Timestamp?
        verifiedBy: String?       // member ID (parent)
        photoUrl: String?
        createdAt: Timestamp
        updatedAt: Timestamp

        audit_log/
          {logId}/
            action: String
            before: Map?
            after: Map?
            performedBy: String
            timestamp: Timestamp
            deviceId: String
            syncConflict: bool

    rewards/
      {rewardId}/
        title: String
        description: String?
        pointCost: int
        iconName: String?
        isActive: bool
        createdBy: String
        createdAt: Timestamp
        updatedAt: Timestamp

    redemptions/
      {redemptionId}/
        rewardId: String
        memberId: String
        pointsSpent: int
        redeemedAt: Timestamp
        approvedBy: String?       // parent member ID (if approval required)
        status: "pending" | "approved" | "rejected"

    categories/
      {categoryId}/
        name: String
        iconName: String
        colorHex: String
        sortOrder: int
```

#### 4.5.2 Isar Local Schema (mirrors Firestore)

The local Isar schema mirrors the Firestore structure with additional sync metadata fields:

```dart
@collection
class TaskEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String remoteId;         // Firestore document ID

  late String familyId;
  late String title;
  String? description;
  late String category;
  late List<String> assigneeIds;
  late String createdBy;
  DateTime? dueDate;
  String? dueTime;
  String? recurrenceRule;
  late int points;
  @Enumerated(EnumType.name)
  late AgeGroup ageGroup;
  @Enumerated(EnumType.name)
  late TaskStatus status;
  late bool requiresVerification;
  late bool requiresPhoto;
  late List<SubtaskEntity> subtasks;
  DateTime? completedAt;
  String? completedBy;
  DateTime? verifiedAt;
  String? verifiedBy;
  String? localPhotoPath;       // Local file path before upload
  String? photoUrl;             // Remote URL after upload
  late DateTime createdAt;
  late DateTime updatedAt;

  // Sync metadata (local only, not sent to Firestore)
  @Enumerated(EnumType.name)
  late SyncStatus syncStatus;   // synced, pending, conflict
  DateTime? lastSyncedAt;
}
```

Each entity type (Task, Member, Reward, Redemption, Category, Family) follows this pattern: a Firestore document schema plus an Isar entity with `remoteId`, `syncStatus`, and `lastSyncedAt` fields.

#### 4.5.3 Indexes

| Collection | Index | Purpose |
|------------|-------|---------|
| tasks | `[familyId, status, dueDate]` | Dashboard query: pending tasks sorted by due date |
| tasks | `[familyId, assigneeIds]` | Member task list |
| tasks | `[familyId, completedAt]` | Fairness dashboard: completed tasks over time |
| tasks | `[familyId, category]` | Category-based filtering |
| sync_operations | `[status, createdAt]` | Queue processing: pending ops in FIFO order |
| members | `[familyId, role]` | List parents vs children |
| redemptions | `[memberId, redeemedAt]` | Member reward history |

### 4.6 API Surface (Firebase Cloud Functions)

Cloud Functions handle operations that require server authority or cross-device coordination.

| Function | Trigger | Purpose |
|----------|---------|---------|
| `onFamilyCreate` | Firestore onCreate: `families/{familyId}` | Initialize default categories, set server timestamps |
| `generateInviteCode` | HTTPS callable | Generate a unique, time-limited invite code for family joining |
| `joinFamily` | HTTPS callable | Validate invite code, add parent user to family, sync initial data |
| `onTaskComplete` | Firestore onUpdate: `tasks/{taskId}` (status -> completed) | Award points to member, update streak, send push notifications to parents |
| `onTaskCreate` | Firestore onCreate: `tasks/{taskId}` | Send push notification to assignees |
| `sendReminder` | Scheduled (Cloud Scheduler) | Every hour, check for tasks due within the next hour that haven't been completed. Send push reminders. |
| `redeemReward` | HTTPS callable | Validate points balance, deduct points atomically, create redemption record |
| `resolveConflict` | Firestore onUpdate (with conflict flag) | Log conflict to audit trail, apply LWW resolution |
| `cleanupExpiredInvites` | Scheduled (daily) | Remove invite codes older than 48 hours |
| `generateFairnessSummary` | HTTPS callable | Compute aggregated fairness data server-side for large date ranges |

### 4.7 Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper: Check if the requesting user is a parent in the family
    function isParentInFamily(familyId) {
      return request.auth != null &&
        exists(/databases/$(database)/documents/families/$(familyId)/members/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/families/$(familyId)/members/$(request.auth.uid)).data.role == 'parent';
    }

    // Helper: Check if the requesting user is any member of the family
    function isFamilyMember(familyId) {
      return request.auth != null &&
        exists(/databases/$(database)/documents/families/$(familyId)/members/$(request.auth.uid));
    }

    match /families/{familyId} {
      allow read: if isFamilyMember(familyId);
      allow create: if request.auth != null;
      allow update: if isParentInFamily(familyId);
      allow delete: if false; // families are never deleted through client

      match /members/{memberId} {
        allow read: if isFamilyMember(familyId);
        allow create: if isParentInFamily(familyId);
        allow update: if isParentInFamily(familyId) ||
          (request.auth.uid == resource.data.userId &&
           request.resource.data.diff(resource.data).affectedKeys()
             .hasOnly(['points', 'currentStreak', 'longestStreak']));
        allow delete: if isParentInFamily(familyId);
      }

      match /tasks/{taskId} {
        allow read: if isFamilyMember(familyId);
        allow create: if isParentInFamily(familyId);
        allow update: if isFamilyMember(familyId);
        // Children can update status (complete), parents can update anything
        allow delete: if isParentInFamily(familyId);

        match /audit_log/{logId} {
          allow read: if isParentInFamily(familyId);
          allow create: if isFamilyMember(familyId);
          allow update, delete: if false; // audit logs are immutable
        }
      }

      match /rewards/{rewardId} {
        allow read: if isFamilyMember(familyId);
        allow create, update, delete: if isParentInFamily(familyId);
      }

      match /redemptions/{redemptionId} {
        allow read: if isFamilyMember(familyId);
        allow create: if isFamilyMember(familyId); // children can redeem
        allow update: if isParentInFamily(familyId); // parents approve/reject
        allow delete: if false;
      }

      match /categories/{categoryId} {
        allow read: if isFamilyMember(familyId);
        allow create, update, delete: if isParentInFamily(familyId);
      }
    }
  }
}
```

**Important note on security rules and children:** Children do not have Firebase Auth UIDs. They are profiles managed by parents. When a child uses a shared device, the device is authenticated as a parent. The app-level PIN and profile switching handle child identity. This means Firestore security rules protect against unauthorized external access, while app-level logic handles intra-family permissions. The PIN is the boundary between "child can do" and "parent can do."

### 4.8 Offline-First UI Communication Strategy

The app communicates connectivity and sync state through a persistent, non-intrusive status system.

#### 4.8.1 Connectivity States

| State | Visual Indicator | User Message | Behavior |
|-------|-----------------|--------------|----------|
| **Online, synced** | No indicator (default state) | None | Normal operation |
| **Online, syncing** | Small animated sync icon in app bar | None (silent) | Sync in progress |
| **Online, sync error** | Orange dot on sync icon | "Some changes pending" (tap for details) | Partial failure |
| **Offline** | Subtle banner below app bar, muted pastel-yellow background | "You're offline. Changes will sync when you reconnect." | Full local operation |
| **Offline, returning online** | Banner transitions to syncing animation | "Reconnected. Syncing..." | Queue processing |

#### 4.8.2 Feature Degradation Matrix

| Feature | Offline Behavior | Notes |
|---------|-----------------|-------|
| View task list | Fully available | From local DB |
| Create task | Fully available | Queued for sync |
| Complete task | Fully available | Queued for sync |
| Edit task | Fully available | Queued for sync |
| Delete task | Fully available | Queued for sync |
| View fairness dashboard | Available (stale data) | Shows "last synced" timestamp |
| Switch profiles | Fully available | Local operation |
| Redeem reward | Available (optimistic) | Points deducted locally, confirmed on sync |
| Push notifications | Unavailable | Notifications require cloud connectivity |
| Photo upload for verification | Photo captured locally | Uploaded on next sync |
| Sign in / Sign up | Unavailable | Requires Firebase Auth (online) |
| Join family | Unavailable | Requires invite code validation (online) |
| Invite new member | Unavailable | Requires cloud function |
| View streaks | Available (may be stale) | Updated on sync |

#### 4.8.3 Optimistic UI Updates

All write operations update the UI immediately from local state. The user never waits for a server round-trip to see their action reflected. If a sync later fails or a conflict is resolved differently, the UI is updated reactively through the BLoC layer.

Example flow:
1. User taps "Complete" on a task.
2. Local Isar DB is updated immediately. BLoC emits new state with task completed.
3. UI renders the completion animation and updated task list.
4. Sync operation is queued.
5. (If online) Operation is sent to Firestore. If successful, `syncStatus` is updated silently. If a conflict occurs, BLoC emits a corrected state with a brief notification explaining what changed.

### 4.9 Multi-User and Device Strategy

#### 4.9.1 Device Types

| Device Type | Authentication | Profiles Available | Use Case |
|-------------|---------------|-------------------|----------|
| **Personal phone** (Marcus) | Authenticated as Marcus | Marcus only (default), can add other profiles | Marcus checks his tasks on his phone |
| **Personal phone** (Sofia) | Authenticated as Sofia | Sofia only (default), can add other profiles | Sofia manages from her phone |
| **Shared tablet** (kitchen) | Authenticated as either parent | All family members | Family hub, Emma's completion station |
| **Alex's tablet** | Authenticated as a parent, Alex's profile pinned | Alex (primary), parent profiles available | Alex's personal task view |

#### 4.9.2 Profile vs Account Distinction

- **Account** = Firebase Auth identity. Only parents have accounts. An account grants access to the family's Firestore data.
- **Profile** = Family member identity within the app. All family members (including children) have profiles. Profiles determine what the user sees and what actions are attributed to them.
- A device is always authenticated with a parent **account**. The active **profile** determines the UI and attribution.

#### 4.9.3 Per-Device Data

| Data Type | Scope | Storage |
|-----------|-------|---------|
| Active profile selection | Per-device | Local only (SharedPreferences) |
| PIN configuration | Per-parent-profile | Synced (Firestore member document) |
| Notification preferences | Per-profile | Synced |
| Theme preference (light/dark) | Per-device | Local only |
| Cached family data | Per-device | Local only (Isar) |
| Sync queue | Per-device | Local only (Isar) |
| Photo cache | Per-device | Local filesystem |

### 4.10 PIN Protection -- Detailed Design

#### 4.10.1 What the PIN Protects

| Action | PIN Required | Rationale |
|--------|-------------|-----------|
| Access Settings | Yes | Prevents children from changing app configuration |
| Create / Edit / Delete tasks | Yes | Task management is a parent responsibility |
| Create / Edit / Delete rewards | Yes | Reward values should not be tampered with |
| View fairness dashboard | Configurable (default: Yes) | Prevents children from obsessing over comparisons |
| Manage family members | Yes | Adding/removing members is sensitive |
| Redeem a reward | No | Children should be able to self-serve (parents are notified) |
| View own task list | No | Core functionality for all users |
| Complete a task | No | Core functionality for all users |
| Switch to child profile | No | Low friction for children |
| Switch to parent profile (in protected sections) | Yes | Protects parent-only features on shared devices |
| View task history/audit | Yes | Contains detailed activity data |

#### 4.10.2 PIN Implementation

- PIN is 4-6 digits, set by each parent during onboarding or in settings.
- PIN is hashed (SHA-256 with device-specific salt) before storage. Raw PIN is never persisted.
- PIN hash is stored in the member's Isar record and synced to Firestore (so the same PIN works across devices).
- PIN entry UI: numeric keypad with large touch targets (per design system), subtle haptic feedback, PIN dots.
- Failed attempts counter: stored locally per device session. Resets on app restart (to prevent lockout from sync issues).
- Biometric unlock: optional, can be enabled per parent to bypass PIN entry via fingerprint or Face ID. Uses `local_auth` Flutter plugin.

#### 4.10.3 PIN vs Firebase Auth Boundaries

```
+------------------------------------------------------------------+
|                                                                    |
|  FIREBASE AUTH (Account-level)                                     |
|  - Required: first-time setup, joining a family, re-authentication |
|  - Scope: proves identity to Firestore security rules              |
|  - Frequency: once per device (persistent session)                 |
|                                                                    |
+------------------------------------------------------------------+
                           |
                           v
+------------------------------------------------------------------+
|                                                                    |
|  PIN (Profile-level)                                               |
|  - Required: accessing parent-only features on any device          |
|  - Scope: intra-app access control, prevents children from         |
|    accessing parent features on shared devices                     |
|  - Frequency: every time a protected action is attempted           |
|    (with optional biometric bypass)                                |
|                                                                    |
+------------------------------------------------------------------+
```

Firebase Auth protects the family's data from the outside world. PIN protects parent features from children within the family.

---

## 5. Impact Analysis

### 5.1 Affected Components

Since this is a greenfield project, this table defines the components that must be built and their relative complexity.

| Component | Type | Risk Level | Notes |
|-----------|------|------------|-------|
| Sync Engine | New | **High** | Most complex component. Handles queuing, conflict resolution, partial failure, retry. Must be rock-solid. |
| Isar Data Layer | New | **Medium** | Schema design, migrations, indexes. Risk is in data consistency across sync. |
| BLoC State Management | New | **Medium** | Must handle reactive updates from both user actions and sync events. |
| Firebase Auth Integration | New | **Low** | Well-documented, standard Firebase Auth flow. |
| Firestore Remote Data Source | New | **Medium** | Real-time listeners, batch writes, security rules. |
| Cloud Functions | New | **Medium** | Notification sending, invite code management, scheduled tasks. |
| PIN Protection System | New | **Low** | Straightforward hashing and gating. Risk is in UX friction. |
| Profile Switching | New | **Medium** | Must handle UI theme changes, data scoping, and PIN gates fluidly. |
| Task Management UI | New | **Low** | Standard CRUD UI following design system. |
| Fairness Dashboard | New | **Medium** | Data aggregation across time periods, charting, exclusion of Emma. |
| Emma's Simplified View | New | **Low** | Separate widget tree, large touch targets, celebration animations. |
| Notification System | New | **Medium** | FCM integration, per-member preferences, offline queuing. |
| Connectivity Monitor | New | **Low** | Wraps connectivity_plus, exposes stream to sync engine and UI. |
| Celebration Animations | New | **Low** | Lottie/Rive integration per design system. |

### 5.2 Dependencies

**Upstream (the app depends on):**
- Firebase Auth service availability (for initial setup and re-auth only)
- Firestore service availability (for sync only -- app works without it)
- Firebase Cloud Messaging service (for push notifications -- non-critical)
- Google Play Services / Apple Push Notification service (for FCM delivery)
- Device local storage (Isar database, filesystem for photos)
- Device connectivity APIs

**Downstream (affected by this app):**
- No downstream systems in v1. The app is self-contained.

### 5.3 Breaking Changes

N/A -- greenfield project. No existing users or data to migrate.

### 5.4 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Sync conflicts cause data loss | Medium | High | LWW with full audit trail. Every losing write is preserved. Extensive integration tests for conflict scenarios. |
| Isar schema migration breaks local data | Medium | High | Version all Isar schemas from day one. Write migration functions for every schema change. Test migrations with fixture data. |
| Sync queue grows unbounded during extended offline | Low | Medium | Cap queue at 1000 operations. Alert user if approaching limit. Oldest completed-and-synced operations are purged. |
| PIN is forgotten | Medium | Low | Recovery flow: re-authenticate with Firebase Auth (email/password or social) to reset PIN. No PIN recovery without full auth. |
| Children discover how to bypass PIN | Low | Medium | PIN check is enforced at the BLoC layer, not just the UI. Even if a child navigates to a protected route, the BLoC gate prevents data access. |
| Firestore quota exceeded (free tier) | Low | Medium | Monitor usage via Firebase Analytics. Implement read batching and caching. Alert before approaching limits. |
| Celebration animations impact performance on low-end devices | Medium | Low | Respect `prefers-reduced-motion`. Provide a "lite animations" toggle. Pre-cache Lottie files. |
| Real-time listeners cause excessive Firestore reads | Medium | Medium | Scope listeners narrowly (per-family, with query filters). Detach listeners when app is backgrounded. Use local cache as primary data source, not Firestore. |
| App size exceeds acceptable limits (fonts, animations, Isar) | Low | Low | Monitor APK/IPA size in CI. Tree-shake unused assets. Compress Lottie files. Target < 30 MB. |

---

## 6. Functional Tests

### 6.1 Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| FT-001 | Create family group | Parent is authenticated, no family exists | Parent submits family creation form | Family is created in local DB and Firestore. Parent is the first member with role=parent. | High |
| FT-002 | Join family with invite code | Parent is authenticated, has valid invite code | Parent enters code and submits | Parent is added to family. All family data is synced to local DB. | High |
| FT-003 | Join family with expired code | Parent is authenticated, has expired invite code | Parent enters code and submits | Error: "This code is invalid or has expired." Family is not joined. | High |
| FT-004 | Create task offline | Parent is offline | Parent creates a task with all fields | Task is saved locally with syncStatus=pending. Task appears in assignee's list. | High |
| FT-005 | Sync task after reconnection | Device has pending task creation, was offline | Device comes online | Task is pushed to Firestore. syncStatus changes to synced. | High |
| FT-006 | Complete task and earn points | Alex has a 10-point task assigned | Alex taps complete | Task status=completed. Alex's points increase by 10. Celebration animation plays. | High |
| FT-007 | Complete task with photo | Task requires photo verification | Alex taps complete | Camera opens. After photo, task status=pending_review. Photo stored locally. | Medium |
| FT-008 | Parent verifies task | Task is in pending_review status | Parent taps verify | Task status=verified. Points awarded (if not already). | Medium |
| FT-009 | Conflict resolution LWW | Sofia edits task title on Phone A (offline). Marcus edits same task title on Phone B (offline). | Both devices come online | The edit with the later timestamp wins. Losing edit is in audit log. | High |
| FT-010 | Delete-edit conflict | Sofia deletes task (offline). Marcus edits same task (offline). | Both devices come online | Task is deleted. Marcus's edit is preserved in audit log. | High |
| FT-011 | PIN protects settings | Child profile is active on shared device | Child navigates to settings | PIN entry screen is displayed. Settings are not accessible without correct PIN. | High |
| FT-012 | PIN lockout after 5 failures | Parent profile, PIN entry screen | 5 incorrect PIN attempts | Lockout message displayed. PIN entry disabled for 5 minutes. | Medium |
| FT-013 | Profile switching | Marcus profile is active on shared device | User taps Sofia's avatar | Sofia's profile loads with her accent color, her task list, and her progress ring. | High |
| FT-014 | Switch to Emma's view | Any profile active on shared device | User taps Emma's avatar | UI switches to simplified view: large icons, pink tint, no text requirements. | Medium |
| FT-015 | Fairness dashboard excludes Emma | Tasks completed by all members including Emma | Parent views fairness dashboard | Dashboard shows Marcus, Sofia, Alex. Emma's data is not in comparison charts. | High |
| FT-016 | Redeem reward | Alex has 50 points, reward costs 50 points | Alex taps redeem on the reward | Points deducted to 0. Redemption recorded. Parents notified. | Medium |
| FT-017 | Redeem reward insufficient points | Alex has 30 points, reward costs 50 | Alex views reward | Redeem button disabled. Tooltip: "You need 20 more points." | Medium |
| FT-018 | Recurring task generation | Daily recurring task exists, today is Monday | App opens on Tuesday | A new task instance for Tuesday is created (if Monday's was completed or skipped). | High |
| FT-019 | Offline indicator shown | Device loses connectivity | Any screen | Yellow banner appears below app bar: "You're offline. Changes will sync when you reconnect." | High |
| FT-020 | Sync status after reconnection | Device was offline with pending changes | Device reconnects | Banner shows "Reconnected. Syncing..." then disappears when sync completes. | High |
| FT-021 | Complete on behalf of Emma | Sofia is on her profile, Emma has a task | Sofia uses "complete on behalf of" | Task marked complete, attributed to Emma. No fairness impact. | Medium |
| FT-022 | Streak tracking | Alex completes all tasks 3 days in a row | 3rd day all tasks complete | Alex's currentStreak shows 3. If this is his best, longestStreak updates. | Low |
| FT-023 | Biometric PIN bypass | Parent has biometric enabled | Parent attempts protected action | Biometric prompt appears instead of PIN. Successful scan grants access. | Low |
| FT-024 | Partial sync failure | 10 operations queued, 2 fail | Sync runs | 8 operations marked completed. 2 remain pending. UI shows "2 items pending." | High |
| FT-025 | App cold start offline | Device has no internet, app has local data | App opens | App loads from local DB in < 2 seconds. All local data is available. | High |

### 6.2 Edge Cases

- **Simultaneous profile switch and sync**: If a sync updates task assignments while a user is mid-profile-switch, the final view must reflect the synced state.
- **Task completed on two devices simultaneously offline**: Both completions should be accepted (idempotent), with the first timestamp winning for attribution but no double-point award.
- **Family member removed while offline**: If a parent removes a member profile while another device is offline, the offline device should handle the member removal gracefully on sync (orphaned tasks reassigned or unassigned).
- **Clock skew between devices**: The sync engine uses server timestamps (Firestore) as the source of truth, not local device clocks. Local timestamps are used only for queue ordering.
- **Extremely long offline period (days/weeks)**: The sync queue must remain stable. On reconnection, a full reconciliation pull is performed before pushing queued operations to detect stale state.
- **App killed mid-sync**: Isar transactions ensure atomicity. The sync engine tracks operation status in the queue. On restart, it resumes from the last incomplete operation.
- **Photo captured offline, task deleted by another user before sync**: Photo is orphaned. Cleanup job removes orphaned local photos after 7 days.
- **Reward redeemed offline, points changed by sync**: If sync reveals insufficient points (another device spent them), the redemption is rolled back with a notification: "Your reward redemption could not be completed because your points balance changed."

### 6.3 Integration Test Requirements

| Test Area | Setup | Validates |
|-----------|-------|-----------|
| Sync engine -- happy path | Two Isar instances simulating two devices, Firestore emulator | Operations from Device A appear on Device B after sync |
| Sync engine -- conflict resolution | Two devices edit same document offline, then sync | LWW produces correct winner, audit log has loser |
| Sync engine -- partial failure | Firestore emulator with injected failures | Successful ops are committed, failed ops remain in queue |
| Auth flow | Firebase Auth emulator | Sign up, sign in, session persistence, token refresh |
| Cloud Functions -- task completion | Firestore emulator + Functions emulator | Points awarded, notification sent, streak updated |
| Cloud Functions -- invite code | Functions emulator | Code generated, validated, expired code rejected |
| Security rules | Firestore emulator with rules | Non-family-members cannot read family data. Children cannot delete tasks. Audit log is immutable. |
| Recurring task generation | Isar with seed data, time manipulation | Correct instances generated for daily, weekly, monthly rules |

---

## 7. Implementation Recommendations

### 7.1 Suggested Approach

The implementation should proceed in vertical slices, each delivering a usable increment. The offline-first architecture means the data layer and sync engine must be built early -- they are the foundation everything else depends on.

### 7.2 Estimated Effort

| Phase | Effort (T-shirt) | Rationale |
|-------|------------------|-----------|
| Phase 1: Foundation | **L** | Core infrastructure: project setup, DI, Isar schemas, sync engine, connectivity monitor. High complexity, low UI. |
| Phase 2: Auth + Family | **M** | Firebase Auth, family creation/joining, member profiles, profile switching. Well-documented integrations. |
| Phase 3: Task Management | **L** | Full task CRUD, recurring tasks, categories. The primary feature set with offline-first implications on every operation. |
| Phase 4: Completion + Rewards | **M** | Task completion flow, points system, reward CRUD, redemption. Includes celebration animations. |
| Phase 5: Dashboard + Fairness | **M** | Contribution charts, time-period filtering, Emma exclusion. Data aggregation logic. |
| Phase 6: Notifications + Polish | **M** | FCM integration, Cloud Functions for scheduled reminders, PIN refinement, Emma's view, streaks. |
| Phase 7: Testing + Hardening | **L** | Integration tests, E2E tests, sync edge cases, performance profiling, Crashlytics integration. |

### 7.3 Suggested Order of Implementation

**Phase 1: Foundation (Weeks 1-3)**
1. Flutter project scaffolding with folder structure per development-rules.md (adapted for Flutter/Dart).
2. Dependency injection setup (get_it + injectable).
3. Isar database setup with all entity schemas and indexes.
4. Connectivity monitor service (wrapping connectivity_plus).
5. Sync engine: operation queue, FIFO processing, retry logic.
6. Sync engine: conflict detection and LWW resolution.
7. BLoC/Cubit base classes with offline-aware state patterns.
8. Unit tests for sync engine (all conflict scenarios).

**Phase 2: Auth + Family (Weeks 4-5)**
1. Firebase Auth integration (email, Google, Apple sign-in).
2. Family creation flow (Firestore + Isar).
3. Invite code generation and joining flow (Cloud Function + client).
4. Member profile CRUD (local + synced).
5. Profile switching UI and logic.
6. PIN setup, entry, and verification.
7. Auth gate and PIN gate route guards (go_router).
8. Firestore security rules deployment and testing.

**Phase 3: Task Management (Weeks 6-8)**
1. Task creation form (bottom sheet, all fields).
2. Task list screen with filtering (by assignee, status, category, date).
3. Task editing and deletion.
4. Category management.
5. Recurring task engine (RRULE parsing, instance generation).
6. Offline CRUD with sync queue integration.
7. Optimistic UI update pattern in TaskListBloc.

**Phase 4: Completion + Rewards (Weeks 9-10)**
1. Task completion flow (tap, animate, record).
2. Photo capture and local storage for verification.
3. Task verification flow (parent approval).
4. Points service (award, deduct, balance).
5. Reward CRUD (parent-only, PIN-gated).
6. Reward redemption flow.
7. Celebration animations (Lottie integration).
8. "Complete on behalf of" for Emma.

**Phase 5: Dashboard + Fairness (Weeks 11-12)**
1. Dashboard screen with category cards and progress rings.
2. Fairness data aggregation service.
3. Time-period selector (today, week, month).
4. Per-member contribution charts.
5. Emma exclusion logic.
6. Task history / audit log viewer (parent-only).
7. Streak calculation and display.

**Phase 6: Notifications + Polish (Weeks 13-14)**
1. FCM setup and token management.
2. Cloud Function: send notification on task completion.
3. Cloud Function: scheduled reminder check.
4. Per-member notification preferences.
5. Emma's simplified view (full implementation).
6. Connectivity status UI (banner, sync indicator).
7. Biometric PIN bypass (local_auth).
8. Dark mode theming.

**Phase 7: Testing + Hardening (Weeks 15-16)**
1. Integration tests with Firebase emulators.
2. E2E tests for critical paths (onboarding, task lifecycle, sync).
3. Sync edge case testing (long offline, conflicts, partial failures).
4. Performance profiling (startup time, scroll jank, DB query times).
5. Crashlytics integration and error reporting.
6. Analytics event tracking (key user actions).
7. Accessibility audit (screen reader, contrast, touch targets).
8. App size optimization.

### 7.4 Flutter Project Structure

Adapted from the TypeScript structure in development-rules.md to follow Flutter/Dart conventions:

```
lib/
  app/                          # App-level configuration
    app.dart                    # MaterialApp setup, theme, router
    di/                         # Dependency injection modules
      injection.dart
    router/                     # go_router configuration
      app_router.dart
      guards/
        auth_guard.dart
        pin_guard.dart

  core/                         # Shared infrastructure
    error/                      # Domain error classes
      failures.dart
      exceptions.dart
    network/                    # Connectivity monitoring
      connectivity_service.dart
    sync/                       # Sync engine
      sync_engine.dart
      operation_queue.dart
      conflict_resolver.dart
      sync_status.dart
    constants/
      app_constants.dart

  features/                     # Feature modules (vertical slices)
    auth/
      data/
        datasources/
          auth_remote_datasource.dart
        repositories/
          auth_repository_impl.dart
      domain/
        entities/
          user.dart
        repositories/
          auth_repository.dart       # Abstract interface
        usecases/
          sign_in.dart
          sign_up.dart
      presentation/
        bloc/
          auth_bloc.dart
        screens/
          sign_in_screen.dart
        widgets/

    family/
      data/
        datasources/
          family_local_datasource.dart
          family_remote_datasource.dart
        models/
          family_model.dart
          member_model.dart
        repositories/
          family_repository_impl.dart
      domain/
        entities/
          family.dart
          member.dart
        repositories/
          family_repository.dart
        usecases/
          create_family.dart
          join_family.dart
          switch_profile.dart
      presentation/
        bloc/
          family_bloc.dart
          profile_cubit.dart
        screens/
          family_setup_screen.dart
          profile_switcher.dart
        widgets/

    tasks/
      data/
        datasources/
          task_local_datasource.dart
          task_remote_datasource.dart
        models/
          task_model.dart
          subtask_model.dart
        repositories/
          task_repository_impl.dart
      domain/
        entities/
          task.dart
          subtask.dart
        repositories/
          task_repository.dart
        usecases/
          create_task.dart
          complete_task.dart
          get_tasks_for_member.dart
      presentation/
        bloc/
          task_list_bloc.dart
          task_creation_cubit.dart
        screens/
          task_list_screen.dart
          task_detail_screen.dart
        widgets/
          task_card.dart
          task_form.dart

    rewards/
      (same structure as tasks)

    dashboard/
      (same structure)

    pin/
      data/
        repositories/
          pin_repository_impl.dart
      domain/
        repositories/
          pin_repository.dart
        usecases/
          verify_pin.dart
          set_pin.dart
      presentation/
        bloc/
          pin_cubit.dart
        widgets/
          pin_entry_widget.dart

    notifications/
      (same structure)

  shared/                       # Shared UI components
    theme/
      app_theme.dart
      color_tokens.dart
      text_styles.dart
    widgets/
      celebration_overlay.dart
      connectivity_banner.dart
      progress_ring.dart
      member_avatar.dart
      empty_state.dart

test/
  unit/
    core/
      sync/
        sync_engine_test.dart
        conflict_resolver_test.dart
        operation_queue_test.dart
    features/
      tasks/
        domain/
          usecases/
        data/
          repositories/
  integration/
    sync/
    auth/
  e2e/
    onboarding_test.dart
    task_lifecycle_test.dart
```

### 7.5 Key Flutter Dependencies

| Package | Version (pin) | Purpose |
|---------|--------------|---------|
| `flutter_bloc` | ^8.1.0 | State management (BLoC/Cubit) |
| `isar` | ^3.1.0 | Local database |
| `isar_flutter_libs` | ^3.1.0 | Isar platform bindings |
| `firebase_core` | ^2.25.0 | Firebase initialization |
| `firebase_auth` | ^4.17.0 | Authentication |
| `cloud_firestore` | ^4.15.0 | Remote database |
| `firebase_messaging` | ^14.7.0 | Push notifications |
| `firebase_crashlytics` | ^3.4.0 | Crash reporting |
| `firebase_analytics` | ^10.8.0 | Usage analytics |
| `get_it` | ^7.6.0 | Service locator for DI |
| `injectable` | ^2.3.0 | Code generation for DI |
| `go_router` | ^13.2.0 | Declarative routing |
| `connectivity_plus` | ^5.0.0 | Network connectivity detection |
| `local_auth` | ^2.1.0 | Biometric authentication |
| `lottie` | ^3.0.0 | Celebration animations |
| `google_fonts` | ^6.1.0 | Nunito font loading |
| `equatable` | ^2.0.0 | Value equality for BLoC states |
| `freezed` | ^2.4.0 | Immutable data classes |
| `json_serializable` | ^6.7.0 | JSON serialization |
| `image_picker` | ^1.0.0 | Photo capture for task verification |
| `fl_chart` | ^0.66.0 | Fairness dashboard charts |
| `shared_preferences` | ^2.2.0 | Simple key-value local storage |
| `uuid` | ^4.2.0 | UUID generation for entity IDs |
| `intl` | ^0.19.0 | Date formatting, i18n readiness |
| `mocktail` | ^1.0.0 | (dev) Mocking for tests |
| `bloc_test` | ^9.1.0 | (dev) BLoC testing utilities |

---

## 8. Open Questions

- [ ] **Reward approval flow**: Should reward redemptions by children require explicit parent approval, or are they auto-approved when points are sufficient? Current assumption: auto-approved with parent notification.
- [ ] **Maximum family size**: Is 8 members the correct cap, or should it be configurable? Larger families affect sync performance and Firestore read costs.
- [ ] **Task delegation between children**: Can Alex reassign one of his tasks to Sofia? Or is reassignment a parent-only action? Current assumption: parent-only.
- [ ] **Chore rotation**: Should the app support automatic rotation of recurring tasks among family members (e.g., Alex does dishes Monday, Marcus does dishes Tuesday)? This is not in v1 scope but affects data model design.
- [ ] **Multi-family support**: Can a parent belong to more than one family (e.g., blended families)? Current assumption: one family per account in v1.
- [ ] **Data retention**: How long should completed task history be retained? Current assumption: indefinitely locally, 1 year in Firestore.
- [ ] **Notification sound customization**: Should family members be able to choose custom notification sounds? Current assumption: default system sound only.
- [ ] **Guest/temporary member**: Should there be support for temporary household helpers (babysitter, grandparent visiting)? Deferred to v2.
- [ ] **Isar vs Drift re-evaluation**: Isar's development status should be verified before committing. If Isar is no longer actively maintained, Drift with its SQL query capabilities becomes the safer choice despite the document-vs-relational mismatch. A decision gate should be placed at the start of Phase 1.

---

## 9. References

- `docs/jobs-to-be-done.md` -- JTBD framework defining the three core jobs the app serves
- `docs/user-personas.md` -- Detailed persona profiles for Marcus, Sofia, Alex, and Emma
- `docs/design-system.md` -- Complete design token system, component library, and accessibility requirements
- `docs/development-rules.md` -- SOLID principles, TDD workflow, Clean Code standards, git workflow, and project structure
- [Firebase Documentation](https://firebase.google.com/docs) -- Auth, Firestore, Cloud Functions, FCM, Crashlytics, Analytics
- [Isar Database Documentation](https://isar.dev) -- Local database for Flutter
- [BLoC Library Documentation](https://bloclibrary.dev) -- State management pattern
- [Material Design 3 Guidelines](https://m3.material.io) -- Component specifications and theming
- [RFC 5545 (iCalendar)](https://tools.ietf.org/html/rfc5545) -- RRULE format reference for recurring tasks

---

*Generated by Software Architect Analyst*
*Date: 2026-03-05*
