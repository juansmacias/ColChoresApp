# Recurrence Engine

## 1. Overview

### 1.1 Summary

This specification defines the Recurrence Engine -- the service responsible for parsing, generating, and managing RFC 5545 RRULE-based recurring task instances. It covers the `RecurrenceEngine` abstract interface and implementation, the `TaskInstanceGenerator` service, the `RecurrenceConfig` model, supported RRULE patterns, the lazy instance generation strategy, the Cloud Function for server-side generation, automatic chore rotation support, and the recurrence builder UI integration. The recurrence engine is a core enabler for the "set it and forget it" workflow parents need for weekly household routines.

### 1.2 Business Context

Most household chores are recurring -- dishes every day, trash every Tuesday, laundry every Saturday. Marcus needs to set up a chore once and have it automatically appear in the task list on the right days. The recurrence engine generates task instances from RRULE templates, ensuring the family always has an up-to-date list of upcoming chores. Without this, parents would need to manually create the same task every day/week, which defeats the purpose of the app.

### 1.3 Scope

**In scope:**
- `RecurrenceEngine` abstract interface and `RecurrenceEngineImpl`
- `RecurrenceConfig` freezed model
- Supported RRULE patterns (RFC 5545 subset)
- `TaskInstanceGenerator` service (lazy, client-side generation)
- Instance deduplication strategy
- Cloud Function `generateRecurringInstances` (scheduled, server-side)
- Template task vs instance task relationship
- Automatic chore rotation design
- Human-readable RRULE descriptions
- RRULE round-trip (build and parse)

**Out of scope:**
- Recurrence builder UI widget (see `specs/21_task_creation_screen.md` Section 6)
- Task CRUD operations (see `specs/18_task_domain.md`, `specs/19_task_data_layer.md`)
- Notification scheduling for recurring tasks (Phase 7)

### 1.4 References

- `specs/17_phase3_foundations.md` -- `rrule` package dependency
- `specs/18_task_domain.md` -- Task entity with `recurrenceRule`, `parentTaskId`, `isTemplate` fields
- `specs/19_task_data_layer.md` -- TaskLocalDatasource.instanceExists, getRecurringTemplates
- `CLAUDE.md` -- Automatic chore rotation supported, recurrenceRule uses RRULE format

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| RE-001 | Parse Daily RRULE | High | `FREQ=DAILY` parsed correctly |
| RE-002 | Parse Weekday RRULE | High | `FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR` parsed correctly |
| RE-003 | Parse Weekly RRULE with specific days | High | `FREQ=WEEKLY;BYDAY=MO,WE` parsed correctly |
| RE-004 | Parse Biweekly RRULE | High | `FREQ=WEEKLY;INTERVAL=2;BYDAY=SA` parsed correctly |
| RE-005 | Parse Monthly RRULE | High | `FREQ=MONTHLY;BYMONTHDAY=1` parsed correctly |
| RE-006 | Parse Count-limited RRULE | Medium | `FREQ=WEEKLY;COUNT=4` respects count limit |
| RE-007 | Parse Until-date RRULE | Medium | `FREQ=DAILY;UNTIL=20261231T000000Z` stops at until date |
| RE-008 | Generate next N occurrences | High | Given RRULE and start date, returns correct future dates |
| RE-009 | Build RRULE from RecurrenceConfig | High | Config -> RRULE string -> re-parse -> same config |
| RE-010 | Human-readable RRULE description | High | "Every weekday", "Every Monday and Wednesday" |
| RE-011 | Task instances generated for next 30 days | High | Client-side lazy generation creates instances |
| RE-012 | Instance deduplication | High | No duplicate instances for same template + date |
| RE-013 | Template task not shown in list | High | isTemplate=true tasks excluded from task list |
| RE-014 | Cloud Function generates instances nightly | Medium | Scheduled function creates 7-day lookahead |
| RE-015 | Chore rotation via multiple templates | Medium | Separate recurring tasks per assignee per day |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| RE-NFR-001 | Instance generation speed | Time for 30-day generation from 10 templates | < 500ms |
| RE-NFR-002 | RRULE parsing speed | Time to parse a single RRULE | < 1ms |
| RE-NFR-003 | Memory for instance generation | Peak memory during generation | < 5 MB |
| RE-NFR-004 | Cloud Function execution time | Time for 100 families, 20 templates each | < 30 seconds |

### 2.3 Assumptions

- The `rrule` Dart package (v0.2.8) provides RFC 5545 compliant parsing and iteration.
- Client-side generation runs on app startup and when templates change.
- Cloud Function runs in the same Firebase project as the app.
- All times are stored in UTC; local timezone conversion happens in the presentation layer.

### 2.4 Constraints

- Only the RFC 5545 subset listed in this spec is supported. Complex patterns (BYSETPOS, BYHOUR, etc.) are not needed and not implemented.
- The `rrule` package may have limitations with certain edge cases (e.g., Feb 29 for monthly). These must be documented and tested.
- Instance generation must not block the UI thread -- run in an isolate or as a microtask.

---

## 3. Supported RRULE Patterns

### 3.1 Pattern Catalog

| Pattern | RRULE String | Description | Example |
|---------|-------------|-------------|---------|
| Daily | `FREQ=DAILY` | Every day | "Make beds" every day |
| Weekdays | `FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR` | Every weekday | "Pack lunch" on school days |
| Weekly (single day) | `FREQ=WEEKLY;BYDAY=TU` | Every week on Tuesday | "Trash day" every Tuesday |
| Weekly (multi-day) | `FREQ=WEEKLY;BYDAY=MO,WE,FR` | Multiple days per week | "Dishes" Mon/Wed/Fri |
| Biweekly | `FREQ=WEEKLY;INTERVAL=2;BYDAY=SA` | Every 2 weeks on Saturday | "Deep clean" biweekly |
| Monthly (by date) | `FREQ=MONTHLY;BYMONTHDAY=1` | First of every month | "Pay allowance" monthly |
| Monthly (by date, alt) | `FREQ=MONTHLY;BYMONTHDAY=15` | 15th of every month | "Change air filters" |
| Count-limited | `FREQ=WEEKLY;BYDAY=MO;COUNT=4` | Repeats N times total | "4-week chore trial" |
| Until-date | `FREQ=DAILY;UNTIL=20261231T000000Z` | Repeats until date | "Summer chores" |

### 3.2 RRULE Component Reference

| Component | Values | Notes |
|-----------|--------|-------|
| `FREQ` | `DAILY`, `WEEKLY`, `MONTHLY` | Required. `YEARLY` not supported. |
| `INTERVAL` | Integer >= 1 | Default 1. Interval between recurrences. |
| `BYDAY` | `MO,TU,WE,TH,FR,SA,SU` | Day-of-week list. Required for WEEKLY. |
| `BYMONTHDAY` | 1-31 | Day-of-month. For MONTHLY only. |
| `COUNT` | Integer >= 1 | Max number of occurrences. Mutually exclusive with UNTIL. |
| `UNTIL` | ISO 8601 datetime | End date. Mutually exclusive with COUNT. |
| `DTSTART` | ISO 8601 datetime | Not stored in RRULE string -- inferred from task.dueDate. |

---

## 4. RecurrenceEngine Interface and Implementation

### 4.1 RecurrenceConfig Model

```dart
// lib/features/tasks/domain/models/recurrence_config.dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../presentation/models/task_draft.dart';

part 'recurrence_config.freezed.dart';

/// Parsed representation of an RRULE string.
/// Used for human-readable display and form pre-population.
@freezed
class RecurrenceConfig with _$RecurrenceConfig {
  const factory RecurrenceConfig({
    /// The recurrence frequency.
    required RecurrenceFrequency frequency,

    /// Interval between occurrences (default 1).
    @Default(1) int interval,

    /// Selected weekdays (1=Mon, 7=Sun, ISO 8601).
    @Default([]) List<int> weekdays,

    /// Day of month for monthly recurrence (1-31).
    int? dayOfMonth,

    /// Maximum number of occurrences (mutually exclusive with until).
    int? count,

    /// End date for recurrence (mutually exclusive with count).
    DateTime? until,
  }) = _RecurrenceConfig;
}
```

### 4.2 RecurrenceEngine Interface

```dart
// lib/features/tasks/domain/services/recurrence_engine.dart

/// Abstract interface for RRULE-based recurrence operations.
///
/// The domain layer depends on this interface.
/// Implementation uses the `rrule` package.
abstract class RecurrenceEngine {
  /// Returns the next [limit] occurrence dates starting from [from].
  ///
  /// [rrule] is an RFC 5545 RRULE string.
  /// [from] is the start date (typically today or task.dueDate).
  /// [limit] is the maximum number of occurrences to return (default 30).
  ///
  /// Returns dates in chronological order.
  /// Returns empty list if RRULE is invalid or no occurrences exist.
  List<DateTime> getNextOccurrences(
    String rrule,
    DateTime from, {
    int limit = 30,
  });

  /// Returns the next single occurrence after [from].
  /// Returns null if no more occurrences exist.
  DateTime? getNextOccurrence(String rrule, DateTime from);

  /// Builds an RRULE string from a human-readable configuration.
  ///
  /// This is the inverse of [parseRrule].
  /// Throws [ArgumentError] if the config is invalid.
  String buildRrule(RecurrenceConfig config);

  /// Parses an RRULE string into a [RecurrenceConfig].
  ///
  /// This is the inverse of [buildRrule].
  /// Returns a default config if the RRULE is invalid.
  RecurrenceConfig parseRrule(String rrule);

  /// Returns a human-readable description of the RRULE.
  ///
  /// Examples:
  /// - "FREQ=DAILY" -> "Every day"
  /// - "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR" -> "Every weekday"
  /// - "FREQ=WEEKLY;BYDAY=MO,WE" -> "Every Monday and Wednesday"
  /// - "FREQ=WEEKLY;INTERVAL=2;BYDAY=SA" -> "Every 2 weeks on Saturday"
  /// - "FREQ=MONTHLY;BYMONTHDAY=1" -> "Monthly on the 1st"
  /// - "FREQ=WEEKLY;BYDAY=MO;COUNT=4" -> "Every Monday, 4 times"
  String getHumanReadableDescription(String rrule);
}
```

### 4.3 RecurrenceEngineImpl

```dart
// lib/features/tasks/data/services/recurrence_engine_impl.dart
import 'package:injectable/injectable.dart';
import 'package:rrule/rrule.dart';

import '../../domain/models/recurrence_config.dart';
import '../../domain/services/recurrence_engine.dart';
import '../../presentation/models/task_draft.dart';

/// Implementation of [RecurrenceEngine] using the `rrule` package.
@LazySingleton(as: RecurrenceEngine)
class RecurrenceEngineImpl implements RecurrenceEngine {
  /// Day-of-week mapping: ISO 8601 (1=Mon) to rrule package format.
  static const _isoToRruleDay = {
    1: ByWeekDayEntry(DateTime.monday),
    2: ByWeekDayEntry(DateTime.tuesday),
    3: ByWeekDayEntry(DateTime.wednesday),
    4: ByWeekDayEntry(DateTime.thursday),
    5: ByWeekDayEntry(DateTime.friday),
    6: ByWeekDayEntry(DateTime.saturday),
    7: ByWeekDayEntry(DateTime.sunday),
  };

  /// Reverse mapping: rrule weekday to ISO 8601 int.
  static const _rruleDayToIso = {
    DateTime.monday: 1,
    DateTime.tuesday: 2,
    DateTime.wednesday: 3,
    DateTime.thursday: 4,
    DateTime.friday: 5,
    DateTime.saturday: 6,
    DateTime.sunday: 7,
  };

  static const _dayNames = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  @override
  List<DateTime> getNextOccurrences(
    String rrule,
    DateTime from, {
    int limit = 30,
  }) {
    try {
      final rule = RecurrenceRule.fromString('RRULE:$rrule');
      final instances = rule
          .getInstances(start: from.toUtc())
          .take(limit)
          .map((dt) => dt.toLocal())
          .toList();
      return instances;
    } catch (_) {
      return [];
    }
  }

  @override
  DateTime? getNextOccurrence(String rrule, DateTime from) {
    final occurrences = getNextOccurrences(rrule, from, limit: 1);
    return occurrences.isEmpty ? null : occurrences.first;
  }

  @override
  String buildRrule(RecurrenceConfig config) {
    final parts = <String>[];

    switch (config.frequency) {
      case RecurrenceFrequency.none:
        return ''; // No recurrence
      case RecurrenceFrequency.daily:
        parts.add('FREQ=DAILY');
      case RecurrenceFrequency.weekdays:
        parts.add('FREQ=DAILY');
        parts.add('BYDAY=MO,TU,WE,TH,FR');
      case RecurrenceFrequency.weekly:
        parts.add('FREQ=WEEKLY');
        if (config.weekdays.isNotEmpty) {
          final days = config.weekdays
              .map(_isoDayToRruleString)
              .join(',');
          parts.add('BYDAY=$days');
        }
      case RecurrenceFrequency.biweekly:
        parts.add('FREQ=WEEKLY');
        parts.add('INTERVAL=2');
        if (config.weekdays.isNotEmpty) {
          final days = config.weekdays
              .map(_isoDayToRruleString)
              .join(',');
          parts.add('BYDAY=$days');
        }
      case RecurrenceFrequency.monthly:
        parts.add('FREQ=MONTHLY');
        if (config.dayOfMonth != null) {
          parts.add('BYMONTHDAY=${config.dayOfMonth}');
        }
    }

    if (config.interval > 1 &&
        config.frequency != RecurrenceFrequency.biweekly) {
      parts.add('INTERVAL=${config.interval}');
    }

    if (config.count != null) {
      parts.add('COUNT=${config.count}');
    }

    if (config.until != null) {
      final formatted = config.until!
          .toUtc()
          .toIso8601String()
          .replaceAll('-', '')
          .replaceAll(':', '')
          .split('.')
          .first;
      parts.add('UNTIL=${formatted}Z');
    }

    return parts.join(';');
  }

  @override
  RecurrenceConfig parseRrule(String rrule) {
    if (rrule.isEmpty) {
      return const RecurrenceConfig(frequency: RecurrenceFrequency.none);
    }

    try {
      final components = <String, String>{};
      for (final part in rrule.split(';')) {
        final kv = part.split('=');
        if (kv.length == 2) {
          components[kv[0]] = kv[1];
        }
      }

      final freq = components['FREQ'] ?? '';
      final interval = int.tryParse(components['INTERVAL'] ?? '1') ?? 1;
      final byDay = components['BYDAY']?.split(',') ?? [];
      final byMonthDay = int.tryParse(components['BYMONTHDAY'] ?? '');
      final count = int.tryParse(components['COUNT'] ?? '');

      // Determine frequency enum
      RecurrenceFrequency frequency;
      if (freq == 'DAILY' && byDay.length == 5 &&
          byDay.toSet().containsAll(['MO', 'TU', 'WE', 'TH', 'FR'])) {
        frequency = RecurrenceFrequency.weekdays;
      } else if (freq == 'DAILY') {
        frequency = RecurrenceFrequency.daily;
      } else if (freq == 'WEEKLY' && interval == 2) {
        frequency = RecurrenceFrequency.biweekly;
      } else if (freq == 'WEEKLY') {
        frequency = RecurrenceFrequency.weekly;
      } else if (freq == 'MONTHLY') {
        frequency = RecurrenceFrequency.monthly;
      } else {
        frequency = RecurrenceFrequency.none;
      }

      // Parse weekdays to ISO ints
      final weekdays = byDay
          .map(_rruleStringToIsoDay)
          .whereType<int>()
          .toList();

      return RecurrenceConfig(
        frequency: frequency,
        interval: interval,
        weekdays: weekdays,
        dayOfMonth: byMonthDay,
        count: count,
      );
    } catch (_) {
      return const RecurrenceConfig(frequency: RecurrenceFrequency.none);
    }
  }

  @override
  String getHumanReadableDescription(String rrule) {
    if (rrule.isEmpty) return 'Does not repeat';

    final config = parseRrule(rrule);

    return switch (config.frequency) {
      RecurrenceFrequency.none => 'Does not repeat',
      RecurrenceFrequency.daily => _describeDaily(config),
      RecurrenceFrequency.weekdays => _describeWeekdays(config),
      RecurrenceFrequency.weekly => _describeWeekly(config),
      RecurrenceFrequency.biweekly => _describeBiweekly(config),
      RecurrenceFrequency.monthly => _describeMonthly(config),
    };
  }

  // --- Private helpers ---

  String _isoDayToRruleString(int isoDay) {
    return const {
      1: 'MO', 2: 'TU', 3: 'WE', 4: 'TH',
      5: 'FR', 6: 'SA', 7: 'SU',
    }[isoDay] ?? 'MO';
  }

  int? _rruleStringToIsoDay(String day) {
    return const {
      'MO': 1, 'TU': 2, 'WE': 3, 'TH': 4,
      'FR': 5, 'SA': 6, 'SU': 7,
    }[day];
  }

  String _describeDaily(RecurrenceConfig config) {
    final suffix = config.count != null ? ', ${config.count} times' : '';
    return 'Every day$suffix';
  }

  String _describeWeekdays(RecurrenceConfig config) {
    final suffix = config.count != null ? ', ${config.count} times' : '';
    return 'Every weekday (Mon-Fri)$suffix';
  }

  String _describeWeekly(RecurrenceConfig config) {
    if (config.weekdays.isEmpty) return 'Weekly';
    final dayNames = config.weekdays
        .map((d) => _dayNames[d] ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    final daysStr = _joinWithAnd(dayNames);
    final suffix = config.count != null ? ', ${config.count} times' : '';
    return 'Every $daysStr$suffix';
  }

  String _describeBiweekly(RecurrenceConfig config) {
    if (config.weekdays.isEmpty) return 'Every 2 weeks';
    final dayNames = config.weekdays
        .map((d) => _dayNames[d] ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    final daysStr = _joinWithAnd(dayNames);
    return 'Every 2 weeks on $daysStr';
  }

  String _describeMonthly(RecurrenceConfig config) {
    if (config.dayOfMonth == null) return 'Monthly';
    final ordinal = _ordinal(config.dayOfMonth!);
    return 'Monthly on the $ordinal';
  }

  String _joinWithAnd(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    if (items.length == 2) return '${items[0]} and ${items[1]}';
    return '${items.sublist(0, items.length - 1).join(", ")} and ${items.last}';
  }

  String _ordinal(int number) {
    if (number >= 11 && number <= 13) return '${number}th';
    return switch (number % 10) {
      1 => '${number}st',
      2 => '${number}nd',
      3 => '${number}rd',
      _ => '${number}th',
    };
  }
}
```

---

## 5. Task Instance Generator

### 5.1 Instance Generation Strategy

**Lazy generation** is the chosen strategy (over eager generation):

- **Client-side:** On app startup (or when templates change), generate instances for the next 30 days. This ensures the task list always has upcoming chores visible, even offline.
- **Server-side:** A Cloud Function runs nightly to generate instances for the next 7 days. This provides a safety net for devices that haven't opened the app recently and ensures Firestore has the instances for multi-device sync.
- **Overlap:** The 7-day server window overlaps with the 30-day client window. Deduplication prevents duplicate instances.

### 5.2 TaskInstanceGenerator Service

```dart
// lib/features/tasks/data/services/task_instance_generator.dart
import 'package:injectable/injectable.dart';

import '../../../../core/utils/id_generator.dart';
import '../../domain/entities/task.dart';
import '../../domain/services/recurrence_engine.dart';
import '../datasources/task_local_datasource.dart';
import '../mappers/task_mapper.dart';

/// Generates upcoming task instances from recurring templates.
///
/// This service runs on app startup and when template tasks change.
/// It generates instances for the next [daysAhead] days (default 30)
/// and inserts them into the local Drift database.
///
/// Deduplication: Before inserting, checks if an instance already
/// exists for the (parentTaskId, dueDate) pair.
@lazySingleton
class TaskInstanceGenerator {
  TaskInstanceGenerator(
    this._localDatasource,
    this._recurrenceEngine,
    this._idGenerator,
  );

  final TaskLocalDatasource _localDatasource;
  final RecurrenceEngine _recurrenceEngine;
  final IdGenerator _idGenerator;

  /// Generates upcoming instances for all recurring templates in a family.
  ///
  /// Returns the total number of new instances created.
  Future<int> generateForFamily(
    String familyId, {
    int daysAhead = 30,
  }) async {
    final templates = await _localDatasource.getRecurringTemplates(familyId);
    int totalCreated = 0;

    for (final templateRow in templates) {
      final template = TaskMapper.fromDrift(templateRow);
      final count = await generateForTemplate(
        template,
        daysAhead: daysAhead,
      );
      totalCreated += count;
    }

    return totalCreated;
  }

  /// Generates upcoming instances for a single recurring template.
  ///
  /// [template] must have isTemplate=true and a non-null recurrenceRule.
  /// Returns the number of new instances created.
  Future<int> generateForTemplate(
    Task template, {
    int daysAhead = 30,
  }) async {
    if (!template.isTemplate || template.recurrenceRule == null) return 0;

    final startDate = template.dueDate ?? DateTime.now();
    final occurrences = _recurrenceEngine.getNextOccurrences(
      template.recurrenceRule!,
      startDate,
      limit: daysAhead, // Approximate: generate up to daysAhead occurrences
    );

    // Filter to only occurrences within the next N days
    final cutoff = DateTime.now().add(Duration(days: daysAhead));
    final relevantOccurrences = occurrences
        .where((date) => date.isBefore(cutoff))
        .toList();

    int created = 0;

    for (final occurrence in relevantOccurrences) {
      // Normalize to date-only for deduplication
      final normalizedDate = DateTime(
        occurrence.year,
        occurrence.month,
        occurrence.day,
      );

      // Check if instance already exists (deduplication)
      final exists = await _localDatasource.instanceExists(
        template.id,
        normalizedDate,
      );
      if (exists) continue;

      // Create instance
      final instanceId = _idGenerator.generateId();
      final now = DateTime.now();

      final instance = template.copyWith(
        id: instanceId,
        parentTaskId: template.id,
        isTemplate: false,
        dueDate: normalizedDate,
        recurrenceRule: null, // Instances don't recur themselves
        status: TaskStatus.pending,
        completedAt: null,
        completedByMemberId: null,
        photoUrl: null,
        syncStatus: SyncStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      await _localDatasource.insertTask(
        TaskMapper.toDriftCompanion(instance),
      );
      created++;
    }

    return created;
  }

  /// Cleans up stale future instances beyond the generation window.
  ///
  /// Instances that are:
  /// - Still pending (not completed/verified/skipped)
  /// - Have a dueDate beyond [daysAhead] from now
  /// - Were generated by this service (have a parentTaskId)
  ///
  /// This is called periodically to prevent instance accumulation
  /// if the generation window changes or templates are modified.
  Future<int> cleanupStaleInstances(
    String familyId, {
    int daysAhead = 30,
  }) async {
    // Implementation note: query Drift for pending instances
    // with dueDate > now + daysAhead and parentTaskId != null,
    // then soft-delete them.
    // This is a maintenance operation, not called on every app start.
    return 0; // Placeholder
  }
}
```

### 5.3 Instance Generation Trigger Points

| Trigger | When | Action |
|---------|------|--------|
| App startup | After auth + family load | `generateForFamily(familyId, daysAhead: 30)` |
| Template created | After TaskRepositoryImpl.createTask (recurring) | `generateForTemplate(template, daysAhead: 30)` |
| Template modified | After TaskRepositoryImpl.updateTask (recurring) | Delete pending instances, regenerate |
| Template deleted | After TaskRepositoryImpl.deleteTask (recurring) | Pending instances already soft-deleted |
| SyncEngine incoming change | Remote recurring template synced | `generateForTemplate(template, daysAhead: 30)` |
| Pull-to-refresh | User manual refresh | `generateForFamily(familyId, daysAhead: 30)` |

### 5.4 Template vs Instance Relationship

```
Recurring Template (isTemplate=true):
  id: "template-001"
  title: "Wash Dishes"
  recurrenceRule: "FREQ=DAILY;BYDAY=MO,WE,FR"
  isTemplate: true
  parentTaskId: null
  status: pending (always pending, never completed)

Generated Instance (isTemplate=false):
  id: "instance-001"           # New UUID
  title: "Wash Dishes"         # Copied from template
  recurrenceRule: null          # Instances don't recur
  isTemplate: false
  parentTaskId: "template-001" # Links back to template
  dueDate: 2026-03-10          # Specific occurrence date
  status: pending               # Can be completed/verified/skipped
  assigneeIds: ["alex-id"]     # Copied from template
  points: 10                    # Copied from template
```

**Key rules:**
- Templates are NEVER shown in the task list (filtered by `isTemplate = false` in Drift query).
- Instances are shown and behave like regular tasks.
- Completing an instance does NOT affect the template or other instances.
- Editing a template does NOT retroactively change existing instances.
- Deleting a template soft-deletes all future pending instances.

---

## 6. Cloud Function: generateRecurringInstances

### 6.1 Function Specification

```typescript
// functions/src/generateRecurringInstances.ts
//
// Scheduled Cloud Function that generates recurring task instances.
// Runs daily at 2:00 AM UTC.
//
// For each family:
//   For each recurring task template:
//     Generate instances for the next 7 days.
//     Skip instances that already exist (deduplication).
//     Write new instances to Firestore.
//
// This provides a server-side safety net for:
// - Devices that haven't opened the app recently
// - Multi-device sync (instances created server-side sync to all devices)
// - Backup in case client-side generation fails

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { RRule } from 'rrule';

export const generateRecurringInstances = functions.pubsub
  .schedule('0 2 * * *')  // Every day at 2:00 AM UTC
  .timeZone('UTC')
  .onRun(async (context) => {
    const db = admin.firestore();
    const familiesSnapshot = await db.collection('families').get();

    for (const familyDoc of familiesSnapshot.docs) {
      const familyId = familyDoc.id;
      const tasksRef = db
        .collection('families')
        .doc(familyId)
        .collection('tasks');

      // Get all recurring templates
      const templatesSnapshot = await tasksRef
        .where('isTemplate', '==', true)
        .where('status', '!=', 'deleted')
        .get();

      for (const templateDoc of templatesSnapshot.docs) {
        const template = templateDoc.data();
        const rruleStr = template.recurrenceRule;
        if (!rruleStr) continue;

        try {
          const rule = RRule.fromString(`RRULE:${rruleStr}`);
          const now = new Date();
          const sevenDaysOut = new Date(now);
          sevenDaysOut.setDate(sevenDaysOut.getDate() + 7);

          const occurrences = rule.between(now, sevenDaysOut);

          for (const occurrence of occurrences) {
            // Normalize to date-only string for deduplication key
            const dateKey = occurrence.toISOString().split('T')[0];
            const instanceId = `${templateDoc.id}_${dateKey}`;

            // Check if instance already exists
            const existingDoc = await tasksRef.doc(instanceId).get();
            if (existingDoc.exists) continue;

            // Create instance
            await tasksRef.doc(instanceId).set({
              ...template,
              parentTaskId: templateDoc.id,
              isTemplate: false,
              recurrenceRule: null,
              dueDate: admin.firestore.Timestamp.fromDate(occurrence),
              status: 'pending',
              completedAt: null,
              completedByMemberId: null,
              photoUrl: null,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        } catch (error) {
          console.error(
            `Error generating instances for template ${templateDoc.id}:`,
            error,
          );
        }
      }
    }
  });
```

### 6.2 Cloud Function Configuration

```
# Deploy command:
firebase deploy --only functions:generateRecurringInstances

# Local testing:
firebase functions:shell
> generateRecurringInstances()

# Monitoring:
# View in Firebase Console > Functions > Logs
# Alert on execution failures via Cloud Monitoring
```

---

## 7. Automatic Chore Rotation

### 7.1 Design

Per CLAUDE.md resolved decision: "Automatic chore rotation: supported (e.g., dishes Mon=Alex, Tue=Marcus)."

**Implementation approach:** Rotation is achieved by creating multiple recurring tasks with the same title but different assignees and different BYDAY values.

### 7.2 Example: Dishes Rotation

```
Template 1:
  title: "Wash Dishes"
  assigneeIds: ["alex-id"]
  recurrenceRule: "FREQ=WEEKLY;BYDAY=MO,WE,FR"

Template 2:
  title: "Wash Dishes"
  assigneeIds: ["marcus-id"]
  recurrenceRule: "FREQ=WEEKLY;BYDAY=TU,TH"

Template 3:
  title: "Wash Dishes"
  assigneeIds: ["sofia-id"]
  recurrenceRule: "FREQ=WEEKLY;BYDAY=SA,SU"
```

### 7.3 Rotation UI

```dart
// In the TaskCreationScreen (spec 21), when creating a recurring task:
//
// Below the recurrence builder, show a "Rotation" section:
//
// "Add Rotation" button:
//   - Only visible when recurrence is weekly or daily
//   - Tap opens a rotation builder dialog
//
// Rotation builder dialog:
//   - Header: "Chore Rotation"
//   - List of rotation entries:
//     Entry 1: [Assignee picker] on [Weekday picker]
//     Entry 2: [Assignee picker] on [Weekday picker]
//     "+ Add rotation entry"
//   - "Create" button: creates N separate recurring templates
//
// When the user creates a rotation, the TaskCreationCubit:
// 1. Creates separate CreateTaskParams for each rotation entry
// 2. Calls CreateTask for each one
// 3. All templates share the same title but differ in assignees and days
//
// In the TaskListScreen:
// - The generated instances appear as regular tasks
// - Alex sees "Wash Dishes" on Mon/Wed/Fri
// - Marcus sees "Wash Dishes" on Tue/Thu
// - The visual effect is a natural rotation
```

---

## 8. Impact Analysis

### 8.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| `lib/features/tasks/domain/services/recurrence_engine.dart` | New | Low | Interface |
| `lib/features/tasks/domain/models/recurrence_config.dart` | New | Low | Freezed model |
| `lib/features/tasks/data/services/recurrence_engine_impl.dart` | New | Medium | RRULE parsing logic |
| `lib/features/tasks/data/services/task_instance_generator.dart` | New | Medium | Instance generation with dedup |
| `functions/src/generateRecurringInstances.ts` | New | Medium | Cloud Function |
| `lib/app/app.dart` | Modified | Low | Trigger instance generation on startup |

### 8.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| `rrule` package incompatibility | Low | High | Test all patterns in unit tests before integration |
| Instance generation blocks UI | Medium | Medium | Run in separate isolate or as microtask |
| Deduplication fails (duplicate instances) | Low | Medium | Unique constraint on (parentTaskId, dueDate) in Drift |
| Monthly recurrence on 31st for short months | Low | Low | Document behavior: falls back to last day of month |
| Cloud Function timeout for large families | Low | Medium | Batch processing with 7-day window limit |
| Instance accumulation over months | Medium | Low | Cleanup job removes completed instances > 6 months |

---

## 9. Functional Tests

### 9.1 RecurrenceEngine Unit Tests

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| RE-T001 | Parse daily RRULE | "FREQ=DAILY" | parseRrule | frequency=daily | High |
| RE-T002 | Parse weekday RRULE | "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR" | parseRrule | frequency=weekdays | High |
| RE-T003 | Parse weekly multi-day | "FREQ=WEEKLY;BYDAY=MO,WE" | parseRrule | frequency=weekly, weekdays=[1,3] | High |
| RE-T004 | Parse biweekly | "FREQ=WEEKLY;INTERVAL=2;BYDAY=SA" | parseRrule | frequency=biweekly | High |
| RE-T005 | Parse monthly by date | "FREQ=MONTHLY;BYMONTHDAY=15" | parseRrule | frequency=monthly, dayOfMonth=15 | High |
| RE-T006 | Parse count-limited | "FREQ=WEEKLY;BYDAY=MO;COUNT=4" | parseRrule | count=4 | Medium |
| RE-T007 | Build daily RRULE | RecurrenceConfig(daily) | buildRrule | "FREQ=DAILY" | High |
| RE-T008 | Build weekly multi-day | Config(weekly, weekdays=[1,3]) | buildRrule | "FREQ=WEEKLY;BYDAY=MO,WE" | High |
| RE-T009 | Round-trip build-parse | Any valid config | buildRrule then parseRrule | Same config | High |
| RE-T010 | Get next 3 occurrences daily | "FREQ=DAILY", from=Mon | getNextOccurrences(limit:3) | [Mon, Tue, Wed] | High |
| RE-T011 | Get next 3 occurrences weekly | "FREQ=WEEKLY;BYDAY=MO,WE", from=Mon | getNextOccurrences(limit:3) | [Mon, Wed, next Mon] | High |
| RE-T012 | Human-readable daily | "FREQ=DAILY" | getHumanReadableDescription | "Every day" | Medium |
| RE-T013 | Human-readable weekdays | weekday RRULE | getHumanReadableDescription | "Every weekday (Mon-Fri)" | Medium |
| RE-T014 | Human-readable weekly | "FREQ=WEEKLY;BYDAY=MO,WE" | getHumanReadableDescription | "Every Monday and Wednesday" | Medium |
| RE-T015 | Invalid RRULE returns empty | "INVALID" | getNextOccurrences | Returns [] | Medium |

### 9.2 TaskInstanceGenerator Unit Tests

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| RE-T016 | Generates daily instances for 7 days | Daily template | generateForTemplate(daysAhead:7) | 7 instances created | High |
| RE-T017 | Deduplication skips existing | Instance for Mon already exists | generateForTemplate | Mon skipped, others created | High |
| RE-T018 | Non-template skipped | Task with isTemplate=false | generateForTemplate | Returns 0 | Medium |
| RE-T019 | Respects 30-day window | Daily template | generateForTemplate(daysAhead:30) | <= 30 instances | High |
| RE-T020 | Instance has correct parentTaskId | Template id="t1" | generateForTemplate | Instance.parentTaskId="t1" | High |
| RE-T021 | Instance has null recurrenceRule | Template with RRULE | generateForTemplate | Instance.recurrenceRule=null | High |
| RE-T022 | Instance copies assignees | Template with assignees=[a,b] | generateForTemplate | Instance.assigneeIds=[a,b] | Medium |
| RE-T023 | generateForFamily processes all templates | 3 templates in family | generateForFamily | All 3 templates processed | High |

---

## 10. Implementation Recommendations

### 10.1 Prototype Checklist

1. **What can a user do?** "As Marcus, I can create a recurring 'Wash Dishes' chore set to every weekday. When I open the app the next day, today's instance appears automatically in the task list without me creating it manually."
2. **Which screens are delivered?** No new screens -- the recurrence engine is a background service. Its UI is the RecurrenceBuilder widget in the TaskCreationScreen (spec 21).
3. **What is the minimum data flow?** Parent creates recurring task -> template stored in Drift -> TaskInstanceGenerator runs on next app start -> instances for next 30 days created in Drift -> TaskListBloc stream emits updated list -> instances appear as regular tasks.
4. **What is the offline behavior?** Instance generation is 100% offline. It reads templates from Drift and writes instances to Drift. No internet needed.
5. **What does "done" look like?** Create a "Dishes" task recurring every weekday. Close and reopen the app. See 5 instances for this week in the task list (Mon-Fri). Complete Monday's instance. Tuesday's still shows as pending.

### 10.2 Suggested Approach

1. Implement RecurrenceConfig freezed model.
2. Implement RecurrenceEngineImpl with all RRULE patterns.
3. Write 15 unit tests for RecurrenceEngine.
4. Implement TaskInstanceGenerator with deduplication.
5. Write 8 unit tests for TaskInstanceGenerator.
6. Integrate instance generation into app startup flow.
7. Implement Cloud Function (can be done in parallel with client-side work).
8. Write Cloud Function tests (Jest).

### 10.3 Estimated Effort

**M (3-5 days)** -- The `rrule` package handles the heavy lifting of RRULE parsing. The main effort is in instance generation, deduplication logic, and thorough testing of edge cases.

---

*Generated by Software Architect Analyst*
*Date: 2026-03-09*
