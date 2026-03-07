# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Family Chores App — a Flutter mobile app helping families coordinate household chores, build responsibility in children, and make invisible household labor visible. Designed for a family of four: Marcus (dad, 38), Sofia (mom, 36), Alex (child, 10), Emma (toddler, 3).

**Status:** Phase 1 in progress (project scaffold complete, Drift schemas implemented).

## Tech Stack

- **Frontend:** Flutter/Dart with BLoC/Cubit state management
- **Local DB:** Drift (SQLite via Drift ORM — Isar was rejected due to Dart 3.x incompatibility)
- **Backend:** Firebase (Auth, Firestore, Cloud Functions, FCM, Crashlytics, Analytics)
- **DI:** get_it + injectable
- **Routing:** go_router with auth and PIN route guards
- **Design:** Material Design 3, pastel palette, Nunito font (google_fonts)
- **Animations:** Lottie (celebrations), fl_chart (fairness dashboard)

## Commands

```bash
flutter pub get                                          # Install dependencies
dart run build_runner build --delete-conflicting-outputs  # Generate DI, Drift, freezed, json_serializable
flutterfire configure                                    # Configure Firebase
firebase emulators:start                                 # Local Firebase emulators
flutter run                                              # Run the app
flutter test                                             # Run all tests
flutter test --coverage                                  # Run tests with coverage
flutter test test/unit/core/sync/sync_engine_test.dart   # Run a single test file
```

## Architecture

Offline-first, layered clean architecture with vertical feature slices.

```
Presentation (Screens → BLoC/Cubit)
    ↓ depends on abstractions only
Domain (Services → Repository Interfaces, Use Cases, Entities)
    ↓ implemented by
Data (Local Datasource [Drift/SQLite] + Remote Datasource [Firestore] → Repository Implementations)
    ↓ mediated by
Sync Engine (Operation Queue, Conflict Resolver, Connectivity Monitor)
```

**Key rule:** Domain layer never imports Drift, Firestore, or any external SDK. It depends only on abstract repository interfaces (DIP).

### Feature Structure (each feature under `lib/features/`)

```
feature_name/
  data/           # Datasources (local + remote), models, repository implementations
  domain/         # Entities, abstract repository interfaces, use cases
  presentation/   # BLoC/Cubit, screens, widgets
```

Features: `auth`, `family`, `tasks`, `rewards`, `dashboard`, `pin`, `notifications`.

### Sync Engine (`lib/core/sync/`)

The most architecturally significant component. All writes go to local Drift DB first, then queue for Firestore sync. All reads come from local Drift DB only.

- **Conflict resolution:** Last-Write-Wins (LWW) using Firestore server timestamps. Losing writes preserved in `audit_log` subcollection. Delete always wins over edit.
- **Operation queue:** FIFO processing, retry up to 3x with exponential backoff (1s, 4s, 16s).
- **Sync triggers:** App foreground, connectivity restored, online write, Firestore listener, pull-to-refresh.
- Sync runs in a separate isolate — never blocks UI.

### Multi-User Model

- **Account** = Firebase Auth identity (parents only). **Profile** = in-app family member identity (everyone).
- Children don't have Firebase accounts — they're profiles managed by parents.
- Shared devices authenticate as a parent; active profile determines UI and attribution.
- PIN (4-6 digits, SHA-256 + salt) gates parent-only features. Biometric bypass optional via `local_auth`.

## Firestore Collections

```
families/{familyId}
  members/{memberId}          # role, age, avatar, points, streaks, PIN hash
  tasks/{taskId}              # title, assignees, due date, recurrence (RRULE), status, points
    audit_log/{logId}         # immutable conflict/history log
  rewards/{rewardId}          # title, point cost
  redemptions/{redemptionId}  # member, reward, points spent, status
  categories/{categoryId}     # name, icon, color
```

Local Drift DB mirrors Firestore with added sync metadata: `remoteId`, `syncStatus` (synced/pending/conflict), `lastSyncedAt`.

## Development Standards

- **TDD:** Red-green-refactor. Tests before implementation. 80% coverage minimum on business logic.
- **SOLID:** Strictly enforced. SRP (~200 line file limit), DIP (no SDK imports in domain), ISP (small focused interfaces).
- **Clean Code:** Functions max 20 lines, max 3 params, early returns, command/query separation, no `dynamic`, no force-unwraps in business logic.
- **Dart analysis:** Strict mode. Equivalent to TypeScript strict — no shortcuts.
- **Commits:** Conventional Commits (`feat`, `fix`, `refactor`, `test`, `docs`, `chore`). Imperative mood, lowercase, max 72 chars.
- **Branches:** `main` → `develop` → `feature/<name>`, `fix/<name>`, `chore/<name>`.
- **Test naming:** `describe('Service') > describe('method') > it('should behavior')`. Arrange-Act-Assert pattern.
- **Test doubles:** Mocks for externals, stubs for deterministic values, fakes for in-memory. Never mock what you own.
- **Error handling:** Domain-specific error classes. `Result` types for expected failures. `throw` only for unexpected failures.

## Key Documents

| Document | Path |
|----------|------|
| Architecture Spec | `specs/00_project_foundation.md` |
| Development Rules | `docs/development-rules.md` |
| Design System | `docs/design-system.md` |
| User Personas | `docs/user-personas.md` |
| Jobs to Be Done | `docs/jobs-to-be-done.md` |

## Resolved Design Decisions

- Reward redemptions: auto-approved when points sufficient (no parent approval needed)
- Task reassignment: parent-only (children cannot reassign)
- Automatic chore rotation: supported (e.g., dishes Mon=Alex, Tue=Marcus)
- Multi-family: not supported (one family per account)
- Completed task history retention: 6 months in Firestore
- Emma (age 3): excluded from fairness comparisons; gets simplified picture-based UI with 56px touch targets and 2.5s celebrations
- **Local DB: Drift** — Isar 3.x requires Dart <3.0.0, incompatible with the project's Dart 3.11.1. Drift is the final decision.
