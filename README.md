# Family Chores App

A Flutter mobile application that helps families coordinate household chores, build responsibility in children, and make invisible household labor visible. Designed for real family life: works offline, syncs across devices, and supports every family member from a 3-year-old to a working parent.

---

## Why This App Exists

Families don't need another task list. They need to solve three problems:

1. **The mental load problem** — One parent (usually Mom) carries the burden of remembering, reminding, and chasing everyone. The app offloads coordination to a shared system.
2. **The parenting problem** — Chores are a tool for teaching responsibility. The app makes contribution structured, visible, and motivating for kids.
3. **The fairness problem** — "I feel like I do everything" has no answer without data. The app creates shared visibility so conversations about fairness are fact-based, not emotional.

See [docs/jobs-to-be-done.md](docs/jobs-to-be-done.md) for the full JTBD analysis.

---

## Core Design Decisions

### Offline-First

The app works fully without internet. Tasks are created, assigned, completed, and viewed from a local database (Drift/SQLite). Changes sync to Firebase when connectivity is available. The user never waits for a server round-trip.

This is non-negotiable. Families use the app in kitchens, basements, and backyards where Wi-Fi drops. An app that fails without internet gets abandoned.

### Multi-User, Shared Devices

A kitchen tablet can serve the whole family. Profile switching is instant. Children don't need accounts — they are profiles managed by parents. Parents authenticate once with Firebase Auth; children tap their avatar to see their tasks.

### PIN Protection for Parents

Sensitive actions (settings, task management, fairness data, rewards) are gated by a 4-6 digit PIN. This isn't about security from the outside (Firebase Auth handles that). It's about preventing a 10-year-old from editing his own chore list on the family tablet.

### Age-Appropriate UI

Alex (10) gets a clean Material Design 3 interface with gamification. Emma (3) gets a separate picture-based view with 56px touch targets and 2.5-second confetti celebrations. Same app, different experience.

---

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| **Framework** | Flutter | Cross-platform (iOS + Android), single codebase, M3 native support |
| **State Management** | BLoC / Cubit | Strict separation of UI and logic, stream-based reactivity, excellent testability |
| **Local Database** | Drift (SQLite) | SQL with type-safe query builder, TypeConverter support, code-generated DAOs |
| **Remote Database** | Cloud Firestore | Real-time sync, offline SDK, security rules, scales with Firebase ecosystem |
| **Authentication** | Firebase Auth | Email, Google, Apple sign-in. Handles tokens, session persistence |
| **Backend Logic** | Cloud Functions for Firebase | Server-authoritative operations (points, notifications, invite codes) |
| **Push Notifications** | Firebase Cloud Messaging | Task reminders, completion alerts |
| **Crash Reporting** | Firebase Crashlytics | Production error tracking |
| **Analytics** | Firebase Analytics | Usage patterns and feature adoption |
| **Routing** | go_router | Declarative, deep links, guard-based navigation (auth + PIN gates) |
| **DI** | get_it + injectable | Compile-time dependency injection, supports DIP |
| **Animations** | Lottie | Celebration overlays, lightweight, prebuilt assets |
| **Charts** | fl_chart | Fairness dashboard contribution visualizations |
| **Font** | Nunito (via google_fonts) | Rounded, welcoming, matches iOS Reminders aesthetic |

---

## Architecture

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
|  +-----------+----------------------------+--------------------+  |
+--------------+----------------------------+-----------------------+
               |                            |
+--------------v----------------------------v-----------------------+
|                         DATA LAYER                                |
|                                                                   |
|  +----------------------------+  +-----------------------------+  |
|  |   Local Data Source        |  |   Remote Data Source        |  |
|  |   (Drift/SQLite)          |  |   (Firestore)              |  |
|  +------------+---------------+  +-------------+---------------+  |
|               |                                |                  |
|  +------------v--------------------------------v---------------+  |
|  |                      SYNC ENGINE                            |  |
|  |  Operation Queue | Conflict Resolver | Connectivity Monitor |  |
|  +---------------------------------------------------------+   |  |
+----------------------------------------------------------------+  |
+-------------------------------------------------------------------+
|                     CROSS-CUTTING CONCERNS                        |
|  Firebase Auth | FCM | Crashlytics | Analytics                    |
+-------------------------------------------------------------------+
```

**Key principle:** The domain layer depends only on abstractions (repository interfaces). It never imports Drift, Firestore, or any external SDK. The data layer implements those interfaces with concrete local and remote data sources. The sync engine sits between them.

See [specs/00_project_foundation.md](specs/00_project_foundation.md) for the full architectural specification.

---

## Offline-First: How It Works

### Write Path

1. User performs an action (create task, complete chore, redeem reward).
2. Local Drift DB is updated immediately. UI updates optimistically.
3. A `SyncOperation` is added to the operation queue (Drift table).
4. If online, the sync engine pushes it to Firestore within seconds.
5. If offline, it stays in the queue until connectivity resumes.

### Read Path

1. All reads come from the local Drift DB. Never from Firestore directly.
2. When online, Firestore real-time listeners push changes into the local DB.
3. BLoC/Cubit layers observe local DB changes and emit new UI states.

### Conflict Resolution

**Last-Write-Wins (LWW)** with full audit trail:

- Every entity has a server-set `updatedAt` timestamp.
- When two devices edit the same entity offline, the later timestamp wins.
- The losing write is preserved in an `audit_log` subcollection — no data is silently lost.
- Delete always wins over edit (a parent who deletes a task has made an explicit decision).

### Sync Triggers

| Event | Action |
|-------|--------|
| App comes to foreground | Full push + pull |
| Connectivity restored | Push pending, then pull |
| Write while online | Immediate push |
| Firestore listener fires | Pull changed document |
| Pull-to-refresh | Full sync |

### Connectivity UI

| State | Indicator |
|-------|-----------|
| Online, synced | No indicator (default) |
| Online, syncing | Animated sync icon in app bar |
| Offline | Yellow banner: "You're offline. Changes will sync when you reconnect." |
| Reconnecting | Banner: "Reconnected. Syncing..." |
| Partial failure | "Some changes pending" (tap for details) |

### Feature Degradation

| Feature | Offline |
|---------|---------|
| View / create / edit / complete tasks | Fully available |
| Fairness dashboard | Available (shows "last synced" time) |
| Switch profiles | Fully available |
| Redeem rewards | Available (optimistic, confirmed on sync) |
| Sign in / Sign up | Requires internet |
| Join family / Invite member | Requires internet |
| Push notifications | Requires internet |

---

## Multi-User Model

### Accounts vs Profiles

- **Account** = Firebase Auth identity. Only parents have accounts.
- **Profile** = Family member identity in-app. Everyone has a profile (parents + children).
- A device authenticates with a parent's account. The active profile determines the UI.

### Device Scenarios

| Device | Auth | Profiles |
|--------|------|----------|
| Dad's phone | Marcus's account | Marcus (default) |
| Mom's phone | Sofia's account | Sofia (default) |
| Kitchen tablet | Either parent's account | All family members |
| Alex's tablet | Parent's account | Alex (pinned), parents available |

### PIN Protection

| Action | PIN Required |
|--------|:----------:|
| Settings, family management | Yes |
| Create / edit / delete tasks | Yes |
| Create / edit / delete rewards | Yes |
| Fairness dashboard | Configurable (default: Yes) |
| View own task list | No |
| Complete a task | No |
| Redeem a reward | No |
| Switch to child profile | No |
| Switch to parent profile (protected sections) | Yes |

PIN is 4-6 digits, hashed with SHA-256 + device salt. Optional biometric bypass via `local_auth`. Lockout after 5 failed attempts (5 minutes, escalating).

---

## Family Members

The app is designed for a specific family shape and adapts to each member:

| Member | Role | App Experience |
|--------|------|----------------|
| **Marcus** (Dad, 38) | Contributor | Quick dashboard, actionable notifications, fairness visibility |
| **Sofia** (Mom, 36) | Administrator | Full control, task management, reduced mental load |
| **Alex** (10) | Self-tracker | Gamified task list, streaks, points, rewards |
| **Emma** (3) | Symbolic participant | Picture-based view, large touch targets, instant celebrations |

See [docs/user-personas.md](docs/user-personas.md) for full persona profiles.

---

## Project Structure

```
lib/
  app/                          # App config, DI, routing
  core/                         # Sync engine, connectivity, errors, constants
  features/                     # Feature modules (clean architecture per feature)
    auth/                       # Firebase Auth integration
    family/                     # Family + member management, profile switching
    tasks/                      # Task CRUD, recurring tasks, completion
    rewards/                    # Points, rewards, redemption
    dashboard/                  # Fairness data, contribution charts, streaks
    pin/                        # PIN setup, verification, biometric bypass
    notifications/              # FCM, preferences
  shared/                       # Theme tokens, reusable widgets

test/
  unit/                         # Mirrors lib/ structure
  integration/                  # Firebase emulator tests
  e2e/                          # Full user flow tests
```

Each feature follows **clean architecture**:
```
feature/
  data/           # Datasources (local + remote), models, repository implementations
  domain/         # Entities, repository interfaces (abstract), use cases
  presentation/   # BLoC/Cubit, screens, widgets
```

---

## Data Model

### Firestore Collections

```
families/{familyId}
  members/{memberId}          # name, role, age, avatar, points, streaks, PIN hash
  tasks/{taskId}              # title, assignees, due date, recurrence, status, points
    audit_log/{logId}         # immutable action log (conflict resolution, history)
  rewards/{rewardId}          # title, point cost, active status
  redemptions/{redemptionId}  # member, reward, points spent, approval status
  categories/{categoryId}     # name, icon, color, sort order
```

### Local (Drift/SQLite)

Mirrors Firestore with additional sync metadata per entity:
- `remoteId` — Firestore document ID
- `syncStatus` — `synced`, `pending`, `conflict`
- `lastSyncedAt` — Timestamp of last successful sync

---

## Development Standards

The project enforces **SOLID principles**, **Clean Code**, and **TDD** as non-negotiable practices.

- **TDD workflow:** Red-green-refactor. Tests before implementation.
- **Coverage target:** 80% minimum on business logic.
- **TypeScript-strict equivalent:** Dart strict analysis, no `dynamic`, no force-unwraps in business logic.
- **Commit format:** Conventional Commits (`feat`, `fix`, `refactor`, `test`, `docs`, `chore`).
- **PR rules:** 1 approval, all CI green, small and focused.

See [docs/development-rules.md](docs/development-rules.md) for the complete team agreement.

---

## Design System

- **Palette:** Pastel colors (blue, green, pink, yellow, lavender, peach) on warm neutral backgrounds.
- **Typography:** Nunito — rounded, welcoming, inspired by iOS Reminders.
- **Components:** Material Design 3, customized with the pastel theme.
- **Spacing:** 8px base grid.
- **Elevation:** Minimal shadows, depth via background differences.
- **Accessibility:** WCAG 2.1 AA, 44px minimum touch targets, screen reader tested.

See [docs/design-system.md](docs/design-system.md) for full tokens, components, and guidelines.

---

## Getting Started

### Prerequisites

- Flutter SDK >= 3.19
- Dart >= 3.3
- Firebase CLI (`firebase-tools`)
- A Firebase project on the Blaze plan (required for Cloud Functions)
- Xcode (for iOS builds)
- Android Studio or VS Code with Flutter extension

### Key Flutter Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_bloc` | ^8.0.0 | State management — BLoC and Cubit patterns for strict UI/logic separation |

### Setup

```bash
# Clone the repository
git clone <repo-url>
cd choresApp

# Install dependencies
flutter pub get

# Generate code (DI, Drift, freezed, json_serializable)
dart run build_runner build --delete-conflicting-outputs

# Configure Firebase
flutterfire configure

# Start Firebase emulators (for local development)
firebase emulators:start

# Run the app
flutter run

# Run tests
flutter test

# Run tests with coverage
flutter test --coverage
```

### Environment

Create a `.env` file from the template:

```bash
cp .env.example .env
```

The app uses Firebase configuration generated by `flutterfire configure`. No manual API key management needed.

---

## Implementation Phases

Each phase after the Foundation delivers a **fully working prototype** that a real family can install and use. Phases build on each other vertically — every phase ships screens, data, and sync together.

| Phase | Name | User-Visible Outcome | Status |
|-------|------|----------------------|--------|
| **1** | Foundation | No user-facing screens. Invisible infrastructure: scaffold, Drift DB, sync engine, BLoC patterns, error handling. | **Complete** |
| **2** | Auth & Family Onboarding | Sign up → create a family → add kids as profiles → switch between profiles → see an empty dashboard. | Planned |
| **3** | Task Management Core | Create tasks → assign to family members → mark complete → see offline badge → watch sync resume. | Planned |
| **4** | Rewards & Gamification | Earn points for chores → browse reward catalog → redeem rewards → enjoy celebration animations. | Planned |
| **5** | Fairness Dashboard | See who did what this week → compare contributions → filter by time period → track streaks. | Planned |
| **6** | Age-Appropriate Experiences | Emma gets picture-based tasks + huge touch targets + 2.5s celebrations. Alex gets streaks + points front and center. | Planned |
| **7** | Notifications & Polish | Get push reminders → get notified when a chore is done → use dark mode → unlock PIN with Face ID. | Planned |
| **8** | Production Hardening | E2E tests, performance profiling, Crashlytics, analytics events, App Store / Play Store submission. | Planned |

### Phase Deliverables Detail

#### Phase 1 — Foundation ✅ Complete
- Flutter project scaffold with DI (`get_it` + `injectable`), routing shell (`go_router`), and theme
- Drift database schema: all tables, DAOs, and TypeConverters
- Sync engine: operation queue, conflict resolver (LWW), retry with exponential backoff
- Connectivity monitor: stream-based online/offline detection
- BLoC foundation: base state classes, `SyncAwareMixin`, `ConnectivityAwareMixin`
- Error handling: domain error classes, `Result` type, global error boundary

#### Phase 2 — Auth & Family Onboarding
**Prototype goal:** A parent can go from app install to a configured family in under 5 minutes.

Screens delivered:
- Splash / onboarding carousel
- Sign In (email + Google Sign-In)
- Sign Up
- Family Setup (create or join via invite code)
- Add Family Member (name, age, avatar, role)
- Profile Switcher (avatar grid, active profile indicator)
- PIN Setup + PIN Entry gate
- Settings stub (family management entry point)

Backend delivered:
- Firebase Auth integration (email, Google)
- Firestore security rules v1
- Family and member sync (create, update, delete)
- Cloud Function: generate and validate invite codes

#### Phase 3 — Task Management Core
**Prototype goal:** The core chore loop works end-to-end, online and offline.

Screens delivered:
- Task List (parent view: all tasks; child view: my tasks)
- Task Creation / Edit form (title, category, assignee, due date, recurrence, points)
- Task Detail
- Task Completion flow (checkbox animation, confetti, points flash)
- Category management (list + create)
- Sync status indicator (offline banner, animated sync icon)
- Recurring task instance generation

Backend delivered:
- Task CRUD synced to Firestore
- Recurrence engine (RRULE-based instance generation)
- Offline queue visible to user as "pending" badge

#### Phase 4 — Rewards & Gamification
**Prototype goal:** Points make the chore loop motivating. Kids can see their balance and spend it.

Screens delivered:
- Points balance display (on profile and task list)
- Reward Catalog (card grid with point costs)
- Reward Detail
- Redemption confirmation
- Redemption history
- Lottie celebration overlays (task complete + redemption)
- "Not enough points" state with progress indicator

Backend delivered:
- Points accumulation on task completion
- Reward CRUD (PIN-protected for parents)
- Redemption recording and points deduction (auto-approved)

#### Phase 5 — Fairness Dashboard
**Prototype goal:** Parents can open the dashboard and have a fact-based conversation about who is contributing.

Screens delivered:
- Dashboard / Fairness tab (PIN-gated, configurable)
- Contribution rings per member (fl_chart donut)
- Daily bar chart for the current period
- Time period selector (Today / This Week / This Month)
- Streak cards per member
- Member detail stats (tasks completed, points earned, completion rate)
- "Last synced" banner when offline

Data delivered:
- Aggregation queries on local Drift DB
- Emma excluded from comparative views
- Streak calculation (consecutive days with 100% completion)

#### Phase 6 — Age-Appropriate Experiences
**Prototype goal:** Emma can use the app. Alex's view feels like a game, not a to-do list.

Screens delivered (Emma):
- Emma's simplified home view (large illustrated task cards, no text required)
- 56px minimum touch targets throughout
- 2.5s confetti + chime celebration on completion
- "Complete on behalf of" quick action for parents

Screens delivered (Alex / child mode):
- Streak flame counter prominently on home
- Points balance with level/rank visual
- Task card with XP bar (progress to next reward)
- "Nice work!" micro-celebration on every completion

#### Phase 7 — Notifications & Polish
**Prototype goal:** The app feels production-ready. Parents get notified. Kids are reminded.

Delivered:
- FCM push notifications (task reminders, completion alerts)
- Notification preferences (per member, per type)
- Dark mode (full Material Design 3 dark theme)
- Biometric PIN bypass (Face ID / fingerprint via `local_auth`)
- i18n string audit (all user-facing strings in ARB files, English only for v1)
- Accessibility pass (WCAG 2.1 AA, screen reader labels, color contrast)
- Animation polish (timing, easing, reduced-motion support)

#### Phase 8 — Production Hardening
**Prototype goal:** Ship it. Real family, real data, App Store.

Delivered:
- Integration tests against Firebase emulators
- E2E tests for all primary user flows (onboarding → task → reward → dashboard)
- Performance profiling (startup time, scroll frame rate, sync latency)
- Crashlytics production configuration + custom keys
- Firebase Analytics events for all key actions
- App Store + Play Store assets (screenshots, descriptions, privacy policy URL)
- Beta TestFlight / Firebase App Distribution release

See [specs/00_project_foundation.md](specs/00_project_foundation.md) for full architectural specification.

---

## Open Questions

These require stakeholder decisions before or during implementation:

1. Should reward redemptions require parent approval or auto-approve when points are sufficient? Auto approval.
2. Can children reassign tasks among themselves, or is reassignment parent-only? parent only
3. Should automatic chore rotation be supported (e.g., dishes Monday=Alex, Tuesday=Marcus)? Yes
4. Can a parent belong to more than one family (blended families)? No
5. How long should completed task history be retained in Firestore? 6 months
6. ~~Isar maintenance status~~ — **Resolved:** Drift is used. Isar 3.x requires Dart <3.0.0, incompatible with the project's Dart 3.11.1.

---

## Documentation Index

| Document | Path | Contents |
|----------|------|----------|
| Jobs to Be Done | [docs/jobs-to-be-done.md](docs/jobs-to-be-done.md) | Three core jobs the app solves |
| User Personas | [docs/user-personas.md](docs/user-personas.md) | Marcus, Sofia, Alex, Emma profiles |
| Design System | [docs/design-system.md](docs/design-system.md) | Colors, typography, spacing, components |
| Development Rules | [docs/development-rules.md](docs/development-rules.md) | SOLID, TDD, clean code, git workflow |
| Architecture Spec | [specs/00_project_foundation.md](specs/00_project_foundation.md) | Full technical specification |

---

## License

TBD
