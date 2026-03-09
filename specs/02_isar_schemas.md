# Drift Database Schemas (formerly Drift)

## 1. Overview

### 1.1 Summary

This specification defines every Drift table (entity), nested JSON model, enum, index, and sync metadata field required by the Family Chores App. The local Drift database is the primary data source for all reads and the immediate target for all writes. It mirrors the Firestore document structure with additional sync metadata fields that enable the offline-first sync engine.

### 1.2 Business Context

The offline-first architecture requires a fully functional local database that can serve the entire app without any network connectivity. Users must be able to create tasks, complete chores, redeem rewards, and view dashboards entirely from local data. The Drift schema design directly impacts query performance, sync reliability, and the user experience of instantaneous UI updates.

### 1.3 Scope

**In scope:**
- 7 Drift table: FamiliesTable, MembersTable, TasksTable, RewardsTable, RedemptionsTable, CategoriesTable, SyncOperationsTable
- 1 nested JSON model: SubtaskModel
- 6 enums: SyncStatus, TaskStatus, AgeGroup, MemberRole, OperationType, RedemptionStatus
- All composite indexes with purpose documentation
- Drift initialization and multi-isolate configuration
- Schema migration strategy
- Data retention and cleanup policies

**Out of scope:**
- Firestore document structure (defined in `specs/00_project_foundation.md` Section 4.5.1)
- Sync engine logic (see `specs/03_sync_engine.md`)
- Repository implementations that query these schemas (Phase 2+)

### 1.4 References

- `specs/00_project_foundation.md` -- Section 4.5 (Data Model), Section 4.5.2 (Drift Local Schema), Section 4.5.3 (Indexes)
- `specs/01_project_scaffolding.md` -- DI modules (DatabaseModule), folder structure
- `CLAUDE.md` -- Resolved decisions: 6-month retention, auto-approved rewards, chore rotation support

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| IS-001 | All 7 Drift table open successfully | High | `Drift.open()` with all schemas completes without error |
| IS-002 | Every field from the Firestore document model has a corresponding Drift field | High | 1:1 mapping verified for all entities, with Dart-appropriate types |
| IS-003 | Sync metadata fields exist on every syncable entity | High | `remoteId`, `syncStatus`, `lastSyncedAt` present on Family, Member, Task, Reward, Redemption, Category |
| IS-004 | All indexes from the foundation spec are defined | High | Composite indexes match Section 4.5.3 exactly |
| IS-005 | Enums are stored as name strings (not ordinal ints) | High | `@Enumerated(EnumType.name)` on all enum fields for migration safety |
| IS-006 | Embedded objects serialize correctly | Medium | SubtaskModel round-trips through Drift write/read |
| IS-007 | Schema version is tracked from day one | Medium | Migration infrastructure exists even if no migrations are needed yet |
| IS-008 | SyncOperationsTable stores full operation queue data | High | All fields from Section 4.4.1 of foundation spec are present |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| IS-NFR-001 | Database size for typical usage | 1 year of family data (4 members, ~30 tasks/week) | < 50 MB (per NFR-003 of foundation spec) |
| IS-NFR-002 | Query performance for dashboard | Task query by family + status + date range | < 10ms on mid-range device |
| IS-NFR-003 | Write performance | Single entity insert | < 5ms |

### 2.3 Assumptions

- Drift v3.1.0 is the target version (pending decision gate from `specs/01_project_scaffolding.md` Section 14.3).
- All entity IDs are UUIDs generated client-side (using the `uuid` package). The Drift auto-increment `Id` is used only for the local primary key.
- Server timestamps from Firestore are stored as `DateTime` in Drift (UTC).
- Photo files are stored on the local filesystem, not in Drift. Only the file path is stored in the entity.

### 2.4 Constraints

- Drift does not support relational joins. Relationships are modeled via ID references (string fields) and queried separately.
- Drift enum storage must use `EnumType.name` (string), not `EnumType.ordinal` (int), to allow safe enum reordering in future versions.
- Maximum Drift database size is configured at 64 MiB, sufficient for the 50 MB target with headroom.

---

## 3. Enums

All enums are defined in a shared location (`lib/core/enums/`) and used across both domain entities and Drift models.

```dart
// lib/core/enums/sync_status.dart
/// Tracks the synchronization state of a local entity relative to Firestore.
enum SyncStatus {
  /// Entity is in sync with Firestore.
  synced,

  /// Entity has local changes not yet pushed to Firestore.
  pending,

  /// Entity has a detected conflict requiring resolution.
  conflict,
}
```

```dart
// lib/core/enums/task_status.dart
/// Lifecycle status of a task.
enum TaskStatus {
  /// Task is created but not started.
  pending,

  /// Task is actively being worked on (optional intermediate state).
  inProgress,

  /// Task has been marked as done by the assignee.
  completed,

  /// Task completion has been verified by a parent.
  verified,

  /// Task was skipped (e.g., recurring task not done that day).
  skipped,
}
```

```dart
// lib/core/enums/age_group.dart
/// Age-appropriate grouping for task assignment.
enum AgeGroup {
  /// Ages 2-4: picture-based, parent-mediated tasks.
  toddler,

  /// Ages 5-12: standard tasks with clear instructions.
  child,

  /// Ages 13-17: more complex responsibilities.
  teen,

  /// Ages 18+: adult household tasks.
  adult,

  /// No age restriction.
  any,
}
```

```dart
// lib/core/enums/member_role.dart
/// Role of a family member within the household.
enum MemberRole {
  /// Has Firebase Auth account, can manage tasks/rewards/settings.
  parent,

  /// Profile managed by parents, no Firebase Auth account.
  child,
}
```

```dart
// lib/core/enums/operation_type.dart
/// Type of CRUD operation recorded in the sync queue.
enum OperationType {
  create,
  update,
  delete,
}
```

```dart
// lib/core/enums/redemption_status.dart
/// Status of a reward redemption.
enum RedemptionStatus {
  /// Redemption created, not yet processed.
  /// Note: per resolved decision, redemptions are auto-approved
  /// when points are sufficient. This status exists for the
  /// sync window between local creation and server confirmation.
  pending,

  /// Redemption approved (auto or by parent).
  approved,

  /// Redemption rejected (e.g., points insufficient after sync).
  rejected,
}
```

---

## 4. Embedded Objects

```dart
// lib/features/tasks/data/models/subtask_embedded.dart
import 'package:drift/drift.dart';

/// Represents a single subtask within a task's checklist.
/// Stored as an nested JSON model inside TasksTable.
@embedded
class SubtaskModel {
  /// Title of the subtask (e.g., "Top rack", "Bottom rack").
  late String title;

  /// Whether this subtask has been completed.
  late bool completed;
}
```

---

## 5. Entity Schemas

### 5.1 FamiliesTable

```dart
// lib/features/family/data/models/family_entity.dart
import 'package:drift/drift.dart';

part 'family_entity.g.dart';

class extends Table
class FamiliesTable {
  Id id = Drift.autoIncrement;

  /// Firestore document ID. Null for locally-created families not yet synced.
  @Index(unique: true)
  String? remoteId;

  /// Family display name (e.g., "The Johnsons").
  late String name;

  /// Firebase Auth UID of the parent who created this family.
  late String createdBy;

  /// Invite code for other parents to join.
  /// 6-character alphanumeric, valid for 48 hours.
  String? inviteCode;

  /// Expiration timestamp for the invite code.
  DateTime? inviteCodeExpiresAt;

  // --- Timestamps ---
  late DateTime createdAt;
  late DateTime updatedAt;

  // --- Sync Metadata (local only, not sent to Firestore) ---
  @Enumerated(EnumType.name)
  late SyncStatus syncStatus;

  DateTime? lastSyncedAt;
}
```

### 5.2 MembersTable

```dart
// lib/features/family/data/models/member_entity.dart
import 'package:drift/drift.dart';

part 'member_entity.g.dart';

class extends Table
class MembersTable {
  Id id = Drift.autoIncrement;

  @Index(unique: true)
  String? remoteId;

  /// Reference to the family this member belongs to.
  @Index()
  late String familyId;

  /// Display name.
  late String name;

  /// Role within the family.
  @Enumerated(EnumType.name)
  late MemberRole role;

  /// Age of the family member.
  late int age;

  /// URL or asset path for the member's avatar image.
  String? avatarUrl;

  /// Personal accent color hex (e.g., "#A8D8EA").
  /// Maps to per-member accent from design-system.md Section 2.5.
  late String accentColor;

  /// Firebase Auth UID. Null for children (they don't have accounts).
  String? userId;

  /// SHA-256 hash of the parent's PIN with device-specific salt.
  /// Null for children. See foundation spec Section 4.10.2.
  String? pinHash;

  /// Salt used for PIN hashing, stored alongside the hash.
  String? pinSalt;

  /// List of device IDs this member has logged into.
  late List<String> deviceIds;

  /// Accumulated points from completing tasks.
  late int points;

  /// Current consecutive days of completing all assigned tasks.
  late int currentStreak;

  /// Longest streak ever achieved.
  late int longestStreak;

  // --- Timestamps ---
  late DateTime createdAt;
  late DateTime updatedAt;

  // --- Sync Metadata ---
  @Enumerated(EnumType.name)
  late SyncStatus syncStatus;

  DateTime? lastSyncedAt;
}
```

**Indexes:**

```dart
class extends Table
class MembersTable {
  // ... fields above ...

  // Composite index: list members by family and role
  // Purpose: "List parents vs children" (from foundation spec Section 4.5.3)
}
```

Note: The index `[familyId, role]` is defined via the `@Index` annotation on `familyId` above. For the composite, Drift requires:

```dart
@Index(composite: [CompositeIndex('role')])
late String familyId;
```

The updated field declaration replaces the simple `@Index()`:

```dart
@Index(composite: [CompositeIndex('role')])
late String familyId;
```

### 5.3 TasksTable

The most complex entity, with the most indexes.

```dart
// lib/features/tasks/data/models/task_entity.dart
import 'package:drift/drift.dart';

part 'task_entity.g.dart';

class extends Table
class TasksTable {
  Id id = Drift.autoIncrement;

  @Index(unique: true)
  String? remoteId;

  /// Family this task belongs to. Every query is scoped to a family.
  late String familyId;

  /// Task title (e.g., "Unload dishwasher").
  late String title;

  /// Optional detailed description.
  String? description;

  /// Category name reference (e.g., "Kitchen", "Bathroom").
  late String category;

  /// Member IDs assigned to this task. Empty list = unassigned (shared pool).
  late List<String> assigneeIds;

  /// Member ID of the parent who created this task.
  late String createdBy;

  /// Due date (date only, time is separate). Null = no due date.
  DateTime? dueDate;

  /// Due time in "HH:mm" format (e.g., "17:00"). Null = anytime.
  String? dueTime;

  /// Recurrence rule in RRULE format (RFC 5545 subset).
  /// Examples: "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR", "FREQ=WEEKLY;BYDAY=SA"
  /// Null = one-time task.
  String? recurrenceRule;

  /// Points awarded on completion.
  late int points;

  /// Age group this task is appropriate for.
  @Enumerated(EnumType.name)
  late AgeGroup ageGroup;

  /// Current lifecycle status.
  @Enumerated(EnumType.name)
  late TaskStatus status;

  /// Whether a parent must verify completion.
  late bool requiresVerification;

  /// Whether photo evidence is required on completion.
  late bool requiresPhoto;

  /// Ordered list of subtasks (checklist items).
  late List<SubtaskModel> subtasks;

  /// Timestamp when the task was marked completed.
  DateTime? completedAt;

  /// Member ID who completed the task.
  String? completedBy;

  /// Timestamp when a parent verified the completion.
  DateTime? verifiedAt;

  /// Member ID of the verifying parent.
  String? verifiedBy;

  /// Local filesystem path for the verification photo (before upload).
  String? localPhotoPath;

  /// Remote URL of the verification photo (after upload).
  String? photoUrl;

  // --- Timestamps ---
  late DateTime createdAt;
  late DateTime updatedAt;

  // --- Sync Metadata ---
  @Enumerated(EnumType.name)
  late SyncStatus syncStatus;

  DateTime? lastSyncedAt;
}
```

**Indexes (from foundation spec Section 4.5.3):**

```dart
class extends Table
class TasksTable {
  // ... fields ...

  // Index 1: Dashboard query - pending tasks sorted by due date
  // Usage: "Show me all pending tasks for this family, ordered by due date"
  @Index(composite: [CompositeIndex('status'), CompositeIndex('dueDate')])
  late String familyId;

  // Index 2: Member task list
  // Usage: "Show me all tasks assigned to Alex"
  // Note: Drift supports indexing on List<String> for contains queries
  @Index()
  late List<String> assigneeIds;

  // Index 3: Fairness dashboard - completed tasks over time
  // Usage: "Show completed tasks in this family for the past week"
  // This requires a separate composite index on familyId + completedAt
  @Index(composite: [CompositeIndex('completedAt')])
  // (applied to familyId via second index annotation -- see implementation note)

  // Index 4: Category-based filtering
  // Usage: "Show all Kitchen tasks for this family"
  @Index(composite: [CompositeIndex('category')])
  // (applied to familyId via third index annotation -- see implementation note)
}
```

**Implementation note on multiple composite indexes:** Drift allows multiple `@Index` annotations on the same field. The actual implementation will use the following pattern:

```dart
// The familyId field carries multiple composite indexes.
// In practice, define them as separate index entries:

@Index(name: 'familyId_status_dueDate',
       composite: [CompositeIndex('status'), CompositeIndex('dueDate')])
@Index(name: 'familyId_completedAt',
       composite: [CompositeIndex('completedAt')])
@Index(name: 'familyId_category',
       composite: [CompositeIndex('category')])
late String familyId;
```

### 5.4 RewardsTable

```dart
// lib/features/rewards/data/models/reward_entity.dart
import 'package:drift/drift.dart';

part 'reward_entity.g.dart';

class extends Table
class RewardsTable {
  Id id = Drift.autoIncrement;

  @Index(unique: true)
  String? remoteId;

  /// Family this reward belongs to.
  @Index()
  late String familyId;

  /// Reward title (e.g., "30 min extra screen time").
  late String title;

  /// Optional description of the reward.
  String? description;

  /// Point cost to redeem this reward.
  late int pointCost;

  /// Material icon name for display.
  String? iconName;

  /// Whether this reward is currently available for redemption.
  late bool isActive;

  /// Member ID of the parent who created this reward.
  late String createdBy;

  // --- Timestamps ---
  late DateTime createdAt;
  late DateTime updatedAt;

  // --- Sync Metadata ---
  @Enumerated(EnumType.name)
  late SyncStatus syncStatus;

  DateTime? lastSyncedAt;
}
```

### 5.5 RedemptionsTable

```dart
// lib/features/rewards/data/models/redemption_entity.dart
import 'package:drift/drift.dart';

part 'redemption_entity.g.dart';

class extends Table
class RedemptionsTable {
  Id id = Drift.autoIncrement;

  @Index(unique: true)
  String? remoteId;

  /// Family this redemption belongs to.
  late String familyId;

  /// Remote ID of the redeemed reward.
  late String rewardId;

  /// Member ID of the redeemer.
  @Index(composite: [CompositeIndex('redeemedAt')])
  late String memberId;

  /// Points spent on this redemption.
  late int pointsSpent;

  /// When the redemption was made.
  late DateTime redeemedAt;

  /// Parent member ID who approved (null for auto-approved).
  /// Per resolved decision: redemptions are auto-approved when points sufficient.
  String? approvedBy;

  /// Redemption status.
  @Enumerated(EnumType.name)
  late RedemptionStatus status;

  // --- Sync Metadata ---
  @Enumerated(EnumType.name)
  late SyncStatus syncStatus;

  DateTime? lastSyncedAt;
}
```

**Index:** `[memberId, redeemedAt]` -- "Member reward history" from foundation spec.

### 5.6 CategoriesTable

```dart
// lib/features/tasks/data/models/category_entity.dart
import 'package:drift/drift.dart';

part 'category_entity.g.dart';

class extends Table
class CategoriesTable {
  Id id = Drift.autoIncrement;

  @Index(unique: true)
  String? remoteId;

  /// Family this category belongs to.
  @Index()
  late String familyId;

  /// Category display name (e.g., "Kitchen", "Bathroom", "Yard").
  late String name;

  /// Material icon name for display.
  late String iconName;

  /// Color hex string (e.g., "#A8D8EA").
  late String colorHex;

  /// Sort order for display.
  late int sortOrder;

  // --- Sync Metadata ---
  @Enumerated(EnumType.name)
  late SyncStatus syncStatus;

  DateTime? lastSyncedAt;
}
```

### 5.7 SyncOperationsTable

The operation queue for the sync engine. This entity is local-only and never synced to Firestore.

```dart
// lib/core/sync/models/sync_operation_entity.dart
import 'package:drift/drift.dart';

part 'sync_operation_entity.g.dart';

/// Represents a single pending synchronization operation.
/// See specs/03_sync_engine.md for processing logic.
/// See specs/00_project_foundation.md Section 4.4.1 for field definitions.
class extends Table
class SyncOperationsTable {
  Id id = Drift.autoIncrement;

  /// Type of entity being synced: "task", "reward", "member", "family",
  /// "redemption", "category".
  late String entityType;

  /// UUID of the affected entity (matches the entity's remoteId or local UUID).
  late String entityId;

  /// Type of operation performed.
  @Enumerated(EnumType.name)
  late OperationType operationType;

  /// JSON-serialized entity state at the time of the operation.
  /// Used to replay the operation during sync.
  late String payload;

  /// Local device time when the operation was performed.
  /// Used for queue ordering (FIFO). NOT used for conflict resolution
  /// (server timestamps are authoritative -- see specs/03_sync_engine.md).
  late DateTime timestamp;

  /// Current processing status of this operation.
  /// "pending" -> "inProgress" -> "completed" or "failed"
  late String status;

  /// Number of sync attempts made. Max 3 before moving to "failed".
  /// Retry intervals: 1s, 4s, 16s (exponential, base=1, factor=4).
  late int retryCount;

  /// Last error message if the operation failed.
  String? errorMessage;

  /// When this operation was first created.
  late DateTime createdAt;

  // Index: Queue processing -- pending operations in FIFO order
  // From foundation spec Section 4.5.3
  @Index(name: 'status_createdAt', composite: [CompositeIndex('createdAt')])
  String get statusIndex => status;
}
```

**Important:** The `status` field uses `String` rather than an enum because the sync operation status values ("pending", "inProgress", "completed", "failed") are distinct from `SyncStatus` (which tracks entity sync state). Using a String here avoids confusing two similarly-named but different enums.

---

## 6. Index Summary

All indexes defined across entities, consolidated for reference:

| Collection | Index Name | Fields | Purpose |
|------------|-----------|--------|---------|
| FamiliesTable | `remoteId` (unique) | `remoteId` | Lookup by Firestore ID |
| MembersTable | `remoteId` (unique) | `remoteId` | Lookup by Firestore ID |
| MembersTable | `familyId_role` | `[familyId, role]` | List parents vs children per family |
| TasksTable | `remoteId` (unique) | `remoteId` | Lookup by Firestore ID |
| TasksTable | `familyId_status_dueDate` | `[familyId, status, dueDate]` | Dashboard: pending tasks by due date |
| TasksTable | `familyId_completedAt` | `[familyId, completedAt]` | Fairness: completed tasks over time |
| TasksTable | `familyId_category` | `[familyId, category]` | Category-based filtering |
| TasksTable | `assigneeIds` | `assigneeIds` | Member task list (list index) |
| RewardsTable | `remoteId` (unique) | `remoteId` | Lookup by Firestore ID |
| RewardsTable | `familyId` | `familyId` | List rewards per family |
| RedemptionsTable | `remoteId` (unique) | `remoteId` | Lookup by Firestore ID |
| RedemptionsTable | `memberId_redeemedAt` | `[memberId, redeemedAt]` | Member reward history |
| CategoriesTable | `remoteId` (unique) | `remoteId` | Lookup by Firestore ID |
| CategoriesTable | `familyId` | `familyId` | List categories per family |
| SyncOperationsTable | `status_createdAt` | `[status, createdAt]` | Queue processing: FIFO order |

---

## 7. Drift Initialization

### 7.1 Database Opening

```dart
// Called from DatabaseModule in DI setup (specs/01_project_scaffolding.md Section 5.2)
Future<Drift> openDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  return Drift.open(
    [
      FamiliesTableSchema,
      MembersTableSchema,
      TasksTableSchema,
      RewardsTableSchema,
      RedemptionsTableSchema,
      CategoriesTableSchema,
      SyncOperationsTableSchema,
    ],
    directory: dir.path,
    name: 'family_chores',
    maxSizeMiB: 64,
    inspector: kDebugMode, // Enable Drift Inspector in debug builds only
  );
}
```

### 7.2 Multi-Isolate Support

The sync engine runs in a separate isolate (see `specs/03_sync_engine.md`). Drift supports concurrent access from multiple isolates when opened with the same name and directory:

```dart
// In the sync isolate:
Future<Drift> openDatabaseInIsolate(String directoryPath) async {
  return Drift.open(
    [
      FamiliesTableSchema,
      MembersTableSchema,
      TasksTableSchema,
      RewardsTableSchema,
      RedemptionsTableSchema,
      CategoriesTableSchema,
      SyncOperationsTableSchema,
    ],
    directory: directoryPath,
    name: 'family_chores',  // Same name = same database
    maxSizeMiB: 64,
    inspector: false,  // No inspector in isolate
  );
}
```

**Critical constraint:** The schema list and database name must be identical in both the main isolate and the sync isolate. Any mismatch will cause a runtime error.

### 7.3 Database Closing

```dart
// On app termination or during testing:
Future<void> closeDatabase(Drift isar) async {
  await isar.close();
}
```

---

## 8. Schema Migration Strategy

### 8.1 Versioning Approach

Even though this is a greenfield project, schema migration infrastructure is established from day one to prevent data loss when schemas evolve.

```dart
// lib/core/constants/storage_constants.dart

/// Current Drift schema version. Increment when any entity schema changes.
const int currentSchemaVersion = 1;

/// Key used to store the schema version in SharedPreferences.
const String schemaVersionKey = 'isar_schema_version';
```

### 8.2 Migration Check on Startup

```dart
// lib/core/database/database_migrator.dart

/// Checks if the local database needs migration and executes it.
class DatabaseMigrator {
  final SharedPreferences _prefs;
  final Drift _isar;

  DatabaseMigrator(this._prefs, this._isar);

  Future<void> migrateIfNeeded() async {
    final storedVersion = _prefs.getInt(schemaVersionKey) ?? 0;

    if (storedVersion < currentSchemaVersion) {
      await _runMigrations(fromVersion: storedVersion);
      await _prefs.setInt(schemaVersionKey, currentSchemaVersion);
    }
  }

  Future<void> _runMigrations({required int fromVersion}) async {
    // Migration functions are added here as the schema evolves.
    // Example:
    // if (fromVersion < 2) await _migrateV1ToV2();
    // if (fromVersion < 3) await _migrateV2ToV3();
  }
}
```

### 8.3 Migration Rules

1. **Additive changes** (new fields with defaults, new indexes): Drift handles these automatically. Increment schema version. No migration function needed.
2. **Field type changes** or **field removals**: Require a migration function that reads old data, transforms it, and writes new records. Increment schema version.
3. **Collection additions**: Drift handles automatically when the new schema is added to `Drift.open()`.
4. **Collection removals**: Remove from schema list. Data is orphaned but harmless. Increment schema version.
5. **Testing**: Every migration function must have a unit test with fixture data from the old schema version.

---

## 9. Data Retention & Cleanup

### 9.1 Completed Task Cleanup

Per the resolved decision: completed task history is retained for 6 months in Firestore. Locally, the same policy applies to prevent unbounded database growth.

```dart
// lib/core/database/database_cleanup.dart

/// Removes completed/verified tasks older than the retention period.
class DatabaseCleanup {
  static const retentionDays = 180; // 6 months

  final Drift _isar;

  DatabaseCleanup(this._isar);

  /// Runs cleanup. Called on app startup after sync.
  Future<int> cleanupOldTasks() async {
    final cutoff = DateTime.now().subtract(
      const Duration(days: retentionDays),
    );

    return _isar.writeTxn(() async {
      return _isar.taskEntitys
          .filter()
          .statusEqualTo(TaskStatus.completed.name)
          .or()
          .statusEqualTo(TaskStatus.verified.name)
          .completedAtLessThan(cutoff)
          .deleteAll();
    });
  }
}
```

### 9.2 Sync Queue Cleanup

Completed sync operations are purged immediately after successful sync. Failed operations are retained for review. See `specs/03_sync_engine.md` for queue management details.

### 9.3 Orphaned Photo Cleanup

Local photos whose associated tasks have been deleted (either locally or via sync) are cleaned up after 7 days:

```dart
/// Removes local photo files that no longer have associated tasks.
Future<void> cleanupOrphanedPhotos() async {
  // Implementation deferred to Phase 3 (task management)
  // Listed here for schema awareness
}
```

---

## 10. Sync Metadata Pattern

Every syncable entity follows this pattern. The three sync metadata fields are local-only and never sent to Firestore:

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `remoteId` | `String?` | `null` | Firestore document ID. Null until first sync. |
| `syncStatus` | `SyncStatus` | `SyncStatus.pending` | Current sync state (synced, pending, conflict) |
| `lastSyncedAt` | `DateTime?` | `null` | Timestamp of last successful sync for this entity |

### 10.1 Lifecycle

1. **Entity created locally:** `remoteId = null`, `syncStatus = pending`, `lastSyncedAt = null`
2. **Entity synced to Firestore:** `remoteId = firestoreDocId`, `syncStatus = synced`, `lastSyncedAt = now`
3. **Entity modified locally after sync:** `syncStatus = pending` (remoteId and lastSyncedAt unchanged)
4. **Conflict detected during sync:** `syncStatus = conflict` (until resolved)
5. **Entity pulled from Firestore (no local changes):** `remoteId = firestoreDocId`, `syncStatus = synced`, `lastSyncedAt = now`

### 10.2 Serialization Exclusion

When converting an Drift table to a Firestore document, the three sync metadata fields are excluded:

```dart
// In the model-to-Firestore-document mapper:
Map<String, dynamic> toFirestoreMap(TasksTable entity) {
  return {
    'title': entity.title,
    'description': entity.description,
    // ... all domain fields ...
    // Do NOT include: remoteId, syncStatus, lastSyncedAt
  };
}
```

---

## 11. Impact Analysis

### 11.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| Drift database collections | New | Medium | 7 collections, all new. Incorrect schema = broken queries. |
| Sync engine | Dependency | High | SyncOperationsTable is the queue. Schema must match engine expectations exactly. |
| Repository implementations | Dependency | Medium | All CRUD operations depend on correct entity schemas. |
| DI database module | Modified | Low | Must register all 7 schemas in correct order. |
| Domain entities | Related | Low | Drift tables are data-layer models; domain entities are separate (Clean Architecture). |

### 11.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Drift schema change requires migration | Medium | High | Establish migration infrastructure from day one (Section 8). Test every migration. |
| Index misconfiguration causes slow queries | Medium | Medium | Benchmark every composite index query with realistic data volume during Phase 1 testing. |
| Embedded SubtaskModel serialization issues | Low | Medium | Write roundtrip tests for embedded objects (Section 12). |
| Drift list index on assigneeIds underperforms | Medium | Medium | Profile query performance. If slow, denormalize to a separate collection. |
| Database size exceeds 64 MiB limit | Low | High | Monitor with Drift Inspector in debug builds. Implement cleanup policies (Section 9). |
| Schema mismatch between main and sync isolates | Low | High | Extract schema list into a shared constant. Enforce via test. |

---

## 12. Functional Tests

### 12.1 Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| IS-FT-001 | Open database with all schemas | App starts for the first time | `Drift.open()` is called with all 7 schemas | Database opens successfully, all collections accessible | High |
| IS-FT-002 | Write and read TasksTable | A TasksTable is constructed with all fields | Entity is written to Drift and read back by ID | All fields match, including embedded subtasks | High |
| IS-FT-003 | Write and read MembersTable | A MembersTable with role=parent, PIN hash set | Entity is written and read back | All fields match, enum stored as name string | High |
| IS-FT-004 | Query tasks by family + status + dueDate | 10 tasks exist: 5 pending, 5 completed, across 2 families | Query for familyId=A, status=pending, ordered by dueDate | Returns exactly the pending tasks for family A, sorted | High |
| IS-FT-005 | Query tasks by assigneeIds | Tasks assigned to [Alex], [Marcus], and [Alex, Marcus] | Query for tasks containing Alex's ID | Returns tasks assigned to Alex and tasks assigned to both | High |
| IS-FT-006 | Query completed tasks for fairness | 20 completed tasks over 30 days for family A | Query familyId=A, completedAt in last 7 days | Returns only tasks completed in the last 7 days | High |
| IS-FT-007 | SyncOperation FIFO ordering | 5 sync operations with different createdAt timestamps | Query status=pending, ordered by createdAt asc | Returns operations in chronological order | High |
| IS-FT-008 | SubtaskModel roundtrip | Task with 3 subtasks: 2 completed, 1 not | Write and read task | Subtask list preserves order, completion state, and titles | Medium |
| IS-FT-009 | Unique remoteId constraint | Two TaskEntities with the same remoteId | Second write attempted | Drift throws unique constraint violation | Medium |
| IS-FT-010 | Null remoteId for unsynced entity | Entity created locally, never synced | Entity written with remoteId=null | Write succeeds. Entity queryable by local ID. | Medium |
| IS-FT-011 | SyncStatus enum stored as name | Entity with syncStatus=pending | Read raw Drift data | Stored value is the string "pending", not an integer | Medium |
| IS-FT-012 | Multi-isolate access | Main isolate writes a task | Sync isolate reads the same task | Task is visible in both isolates | High |
| IS-FT-013 | Category query by family | 5 categories for family A, 3 for family B | Query familyId=A | Returns exactly 5 categories | Low |
| IS-FT-014 | Redemption history by member | 10 redemptions for Alex over 3 months | Query memberId=Alex, ordered by redeemedAt desc | Returns all 10, newest first | Medium |
| IS-FT-015 | Database cleanup removes old tasks | Tasks completed 200 days ago and 100 days ago | Cleanup runs with 180-day retention | 200-day-old task deleted, 100-day-old task retained | Medium |

### 12.2 Edge Cases

- **Empty subtask list:** Task with `subtasks = []` should serialize and deserialize correctly.
- **Very long task title:** 500+ character title should be stored and retrieved without truncation.
- **Unicode in all string fields:** Names, titles, descriptions with emoji and non-Latin characters.
- **DateTime at epoch boundaries:** `DateTime(1970, 1, 1)` and far-future dates.
- **Maximum assigneeIds list size:** A task assigned to all 8 family members (max family size).
- **Concurrent writes from main and sync isolates:** Both write to the same collection simultaneously.
- **Database opened twice with same name:** Should reuse the same instance, not corrupt data.

---

## 13. Implementation Recommendations

### 13.1 Suggested Approach

1. Define all enums in `lib/core/enums/`.
2. Define `SubtaskModel` in the tasks feature models directory.
3. Define all 7 entity classes with fields, annotations, and indexes.
4. Run `dart run build_runner build` to generate `.g.dart` files.
5. Implement `openDatabase()` in the DI database module.
6. Write the roundtrip read/write test for every entity (IS-FT-001 through IS-FT-011).
7. Write the index query tests (IS-FT-004 through IS-FT-007).
8. Implement `DatabaseMigrator` and `DatabaseCleanup`.
9. Write the multi-isolate access test (IS-FT-012).

### 13.2 Estimated Effort

**T-shirt size: M** (3-4 days)

Primary complexity is in getting all indexes correct and writing comprehensive tests. The entity definitions themselves are straightforward.

---

## 14. Open Questions

- [ ] Should `remoteId` be nullable (as specified) or should we generate a UUID client-side and use it as both local and remote ID? Client-side UUID generation simplifies the sync engine but requires Firestore to accept client-generated document IDs.
- [ ] Should the `dueTime` field remain a `String` ("HH:mm") or be stored as a separate `int` representing minutes-since-midnight for easier comparison? String is simpler but comparison queries are harder.
- [ ] Should we add a `deletedAt` soft-delete field to syncable entities, or rely on hard deletes with sync operations tracking deletions?

---

*Generated by Software Architect Analyst*
*Date: 2026-03-05*
