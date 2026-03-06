# Development Rules & Team Agreement

**Product:** Family Chores App
**Version:** 1.0
**Last updated:** 2026-03-05

This document defines the rules, conventions, and standards every contributor must follow. It is the team contract. If it's not in this document, discuss it before assuming.

---

## 1. Core Philosophy

Three non-negotiable pillars drive every line of code in this project:

1. **SOLID** — Every module, class, and function respects the five principles. No exceptions, no shortcuts.
2. **Clean Code** — Code is written to be read by humans first, executed by machines second.
3. **TDD** — Tests are written before implementation. Red-green-refactor is the workflow, not an aspiration.

---

## 2. SOLID Principles — Applied

### 2.1 Single Responsibility Principle (SRP)

- One module = one reason to change.
- Cloud Function handlers only parse input and return output. Business logic lives in service modules.
- UI components render. They do not fetch data, transform data, or manage global state.
- If a file exceeds ~200 lines, it likely violates SRP. Split it.

**Structure enforcement:**

```
handlers/    → Thin entry points (parse, delegate, respond)
services/    → Business logic (one domain concept per file)
models/      → Type definitions and interfaces
utils/       → Pure, stateless helper functions
```

### 2.2 Open/Closed Principle (OCP)

- Modules are open for extension, closed for modification.
- Use strategy patterns, composition, and dependency injection instead of modifying existing code with conditionals.
- When adding a new chore type, reward type, or notification channel, extend — don't edit switch statements.

### 2.3 Liskov Substitution Principle (LSP)

- Subtypes must be substitutable for their base types without breaking behavior.
- If a function accepts `Task`, any subtype (`RecurringTask`, `OneTimeTask`) must work without special handling.
- Avoid type-checking with `instanceof` inside business logic. If you need it, the abstraction is wrong.

### 2.4 Interface Segregation Principle (ISP)

- Define small, focused interfaces. No god-interfaces.
- A component that only reads tasks should not depend on an interface that also includes write operations.
- Prefer multiple specific interfaces over a single general-purpose one.

```typescript
// Good
interface TaskReader { getTask(id: string): Promise<Task>; }
interface TaskWriter { saveTask(task: Task): Promise<void>; }

// Bad
interface TaskRepository {
  getTask(id: string): Promise<Task>;
  saveTask(task: Task): Promise<void>;
  deleteTask(id: string): Promise<void>;
  archiveTask(id: string): Promise<void>;
  getTaskStats(): Promise<Stats>;
}
```

### 2.5 Dependency Inversion Principle (DIP)

- High-level modules depend on abstractions, not concrete implementations.
- Services receive their dependencies through constructor injection or function parameters.
- Never import Firestore, Auth, or any external SDK directly inside business logic. Wrap them behind interfaces.

```typescript
// Good — service depends on an abstraction
class ChoreService {
  constructor(private repo: TaskReader & TaskWriter) {}
}

// Bad — service depends on Firestore directly
class ChoreService {
  private db = admin.firestore();
}
```

---

## 3. Test-Driven Development (TDD)

### 3.1 The Workflow

Every feature and every bug fix follows Red-Green-Refactor:

1. **Red** — Write a failing test that defines the expected behavior.
2. **Green** — Write the minimum code to make the test pass.
3. **Refactor** — Clean up without changing behavior. Tests must stay green.

No code is merged without corresponding tests. "I'll add tests later" is not accepted.

### 3.2 Test Types & Expectations

| Type | Scope | Runs | Required |
|------|-------|------|----------|
| **Unit** | Single function/class, all deps mocked | On every save / pre-commit | Yes, for all business logic |
| **Integration** | Multiple modules working together, real Firestore emulator | Pre-push / CI | Yes, for all service-to-DB interactions |
| **E2E** | Full user flows through the UI | CI pipeline | Yes, for critical paths (auth, task completion, assignment) |

### 3.3 Test Standards

- **Naming:** `describe('ChoreService')` > `describe('assignChore')` > `it('should throw when assignee is not a family member')`
- **Structure:** Every test follows **Arrange-Act-Assert** (AAA). One assertion per test when possible.
- **Independence:** Tests must not depend on execution order. No shared mutable state between tests.
- **Coverage target:** 80% minimum line coverage for services and business logic. 100% coverage is not the goal — meaningful coverage is.
- **No test pollution:** Each test sets up its own data and tears it down. Use `beforeEach` for common setup, never rely on data left by another test.

### 3.4 What to Test

| Always test | Never test |
|-------------|------------|
| Business rules and domain logic | Framework internals |
| Input validation and edge cases | Third-party library behavior |
| Error paths and failure modes | Private implementation details |
| State transitions | Getter/setter boilerplate |
| Data transformations | Static type correctness (TypeScript handles this) |

### 3.5 Test Doubles

- Use **mocks** for external dependencies (Firestore, Auth, third-party APIs).
- Use **stubs** for deterministic return values (date providers, ID generators).
- Use **fakes** for in-memory implementations when integration-level fidelity is needed without emulators.
- Never mock what you own — if you need to mock your own service, the coupling is too tight.

---

## 4. Clean Code Standards

### 4.1 Naming

| Element | Convention | Example |
|---------|-----------|---------|
| Files (modules) | `kebab-case` | `chore-service.ts` |
| Classes / Interfaces / Types | `PascalCase` | `ChoreService`, `TaskReader` |
| Functions / Methods | `camelCase`, verb-first | `assignChore()`, `getOverdueTasks()` |
| Variables | `camelCase`, descriptive noun | `assignedMember`, `overdueCount` |
| Constants | `UPPER_SNAKE_CASE` | `MAX_CHORES_PER_DAY` |
| Boolean variables | `is/has/should` prefix | `isCompleted`, `hasReward` |
| Enums | `PascalCase`, singular | `ChoreStatus.Completed` |
| Collections / Arrays | Plural nouns | `tasks`, `familyMembers` |
| Private fields | Prefix with `private` keyword, no underscore | `private repo: TaskReader` |

### 4.2 Functions

- **Max 20 lines** per function. If longer, extract.
- **Max 3 parameters.** If more, use an options object.
- **Single level of abstraction** per function. Don't mix high-level orchestration with low-level details.
- **No side effects** in functions that return values. Command/query separation.
- **Early returns** over nested conditionals. Fail fast, exit early.

```typescript
// Good
function getVisibleTasks(tasks: Task[], member: Member): Task[] {
  if (!tasks.length) return [];
  if (member.role === 'child' && member.age < 4) {
    return tasks.filter(t => t.ageGroup === 'toddler');
  }
  return tasks.filter(t => t.assigneeId === member.id || !t.assigneeId);
}

// Bad
function getVisibleTasks(tasks: Task[], member: Member): Task[] {
  let result: Task[] = [];
  if (tasks.length > 0) {
    for (let i = 0; i < tasks.length; i++) {
      if (member.role === 'child') {
        if (member.age < 4) {
          if (tasks[i].ageGroup === 'toddler') {
            result.push(tasks[i]);
          }
        } else {
          if (tasks[i].assigneeId === member.id || !tasks[i].assigneeId) {
            result.push(tasks[i]);
          }
        }
      } else {
        if (tasks[i].assigneeId === member.id || !tasks[i].assigneeId) {
          result.push(tasks[i]);
        }
      }
    }
  }
  return result;
}
```

### 4.3 Comments

- **Don't comment what.** The code tells you what it does.
- **Do comment why** when the reason isn't obvious.
- **Do comment domain context** when business rules drive the logic.
- Delete commented-out code. Git remembers.
- TODO comments must include a name and a ticket/issue reference: `// TODO(marcus): handle recurring chores #42`

### 4.4 Error Handling

- Use typed errors. Define domain-specific error classes.
- Never swallow errors silently. Log or rethrow.
- Handle errors at the boundary (handler layer), not deep in business logic.
- Use `Result` types or equivalent patterns for expected failures. Reserve `throw` for unexpected failures.

```typescript
// Domain error
class ChoreAssignmentError extends Error {
  constructor(
    message: string,
    public readonly code: 'INVALID_MEMBER' | 'MAX_CHORES_EXCEEDED' | 'AGE_RESTRICTED'
  ) {
    super(message);
    this.name = 'ChoreAssignmentError';
  }
}
```

### 4.5 Immutability

- Default to `const`. Use `let` only when mutation is required.
- Prefer `readonly` on interface properties.
- Use spread operators or `structuredClone` instead of mutating objects.
- Arrays: prefer `map`, `filter`, `reduce` over `push` in loops.

---

## 5. TypeScript Rules

| Rule | Setting |
|------|---------|
| Strict mode | `"strict": true` — always |
| Explicit return types | Required on all exported functions |
| `any` | Forbidden. Use `unknown` and narrow. |
| Non-null assertion (`!`) | Forbidden in business logic. Allowed only in test setup. |
| Type assertions (`as`) | Minimize. Justify with a comment when unavoidable. |
| Enums | Prefer `const` objects with `as const` over TypeScript enums for tree-shaking. |
| Barrel exports | One `index.ts` per module folder. Re-export only the public API. |

---

## 6. Project Structure

```
src/
├── handlers/           # Cloud Function entry points (thin)
│   ├── chore-handlers.ts
│   └── family-handlers.ts
├── services/           # Business logic (one domain per file)
│   ├── chore-service.ts
│   ├── assignment-service.ts
│   ├── reward-service.ts
│   └── notification-service.ts
├── models/             # TypeScript interfaces and type definitions
│   ├── chore.ts
│   ├── family.ts
│   └── reward.ts
├── repositories/       # Data access layer (Firestore abstraction)
│   ├── chore-repository.ts
│   └── family-repository.ts
├── utils/              # Pure helper functions
│   ├── date-utils.ts
│   └── validation.ts
├── errors/             # Domain-specific error classes
│   └── domain-errors.ts
├── config/             # App configuration and constants
│   └── constants.ts
└── index.ts            # Function exports
tests/
├── unit/               # Mirrors src/ structure
│   ├── services/
│   └── utils/
├── integration/        # Service + repository tests with emulators
├── e2e/                # Full flow tests
└── helpers/            # Test factories, fixtures, custom matchers
```

### 6.1 File Rules

- One class or one logically cohesive set of functions per file.
- File name matches the primary export: `chore-service.ts` exports `ChoreService`.
- Test files sit in `tests/` mirroring the source path: `tests/unit/services/chore-service.test.ts`.
- No circular imports. If two modules need each other, extract the shared dependency.

---

## 7. Git Workflow

### 7.1 Branch Strategy

| Branch | Purpose | Merges to |
|--------|---------|-----------|
| `main` | Production-ready code | — |
| `develop` | Integration branch | `main` (via release) |
| `feature/<short-name>` | New feature work | `develop` |
| `fix/<short-name>` | Bug fixes | `develop` |
| `chore/<short-name>` | Tooling, config, refactors | `develop` |

### 7.2 Commit Messages

Follow **Conventional Commits**:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

| Type | Usage |
|------|-------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `test` | Adding or updating tests |
| `docs` | Documentation only |
| `chore` | Build, tooling, CI changes |
| `style` | Formatting, no logic change |

- Subject line: imperative mood, lowercase, max 72 characters, no period.
- Body: explain **why**, not what. Wrap at 72 characters.

### 7.3 Pull Request Rules

- Every PR requires at least **1 approval** before merge.
- All CI checks must pass (lint, type-check, tests).
- PRs should be small and focused. One concern per PR.
- PR description must include: **what** changed, **why**, and **how to test**.
- Squash merge into `develop`. Merge commit into `main`.

### 7.4 Pre-commit Hooks

The following run automatically on every commit:

1. Lint (ESLint)
2. Type check (`tsc --noEmit`)
3. Affected unit tests
4. Format check (Prettier)

If any check fails, the commit is rejected. Fix the issue — do not skip hooks.

---

## 8. Code Review Checklist

Every reviewer checks the following before approving:

- [ ] Does the code follow SOLID principles?
- [ ] Are tests written first (TDD evidence in commit history)?
- [ ] Do tests cover happy path, edge cases, and error paths?
- [ ] Are functions short, focused, and at a single level of abstraction?
- [ ] Is naming clear and consistent with project conventions?
- [ ] No `any`, no non-null assertions, no type assertions without justification?
- [ ] No commented-out code, no dead code, no TODOs without issue references?
- [ ] Error handling is explicit and uses domain error types?
- [ ] No direct dependency on external SDKs inside business logic?
- [ ] Does the PR description explain why the change was made?

---

## 9. Dependency Management

- **Add dependencies deliberately.** Every new package must be justified. Prefer the standard library and existing dependencies.
- **Pin versions** in `package.json`. Use exact versions, not ranges.
- **Audit regularly.** Run `npm audit` weekly. No known critical vulnerabilities in production deps.
- **Dev dependencies stay dev.** Test frameworks, linters, and build tools never end up in the production bundle.
- **One job per package.** Don't add a utility library for one function. Write the function.

---

## 10. Environment & Configuration

- **No secrets in code.** Ever. Use environment variables and Firebase config.
- **No hardcoded values.** Magic numbers and strings go in `config/constants.ts` with a descriptive name.
- **Environment parity.** Local dev, staging, and production use the same code paths. Environment-specific behavior is driven by config, not conditionals.
- `.env` files are in `.gitignore`. Provide a `.env.example` with placeholder values.

---

## 11. Documentation Rules

- **Code is the primary documentation.** Clean code with good names reduces the need for external docs.
- **README.md** in the project root: setup instructions, how to run, how to test. Keep it current.
- **Architecture decisions** go in `docs/` as markdown files (like this one).
- **API contracts** are documented in the handler files via JSDoc and in the spec docs.
- **Don't document the obvious.** If the code is clear, a comment or doc adds noise, not value.

---

## 12. CI/CD Pipeline Expectations

Every push to a PR triggers:

1. **Install** — Clean install of dependencies
2. **Lint** — ESLint with project config, zero warnings policy
3. **Type Check** — `tsc --noEmit`, strict mode
4. **Unit Tests** — All unit tests, coverage report generated
5. **Integration Tests** — Firebase emulator suite
6. **Build** — Production build completes without errors

Merge is blocked if any step fails.

---

## 13. Performance Guidelines

- **Measure before optimizing.** No premature optimization. Profile first, then act.
- **Minimize cold starts** in Cloud Functions: lazy-load heavy dependencies, keep the top-level scope lean.
- **Pagination is mandatory** for any list query. No unbounded reads from Firestore.
- **Batch writes** for multi-document operations. Never write documents in a loop.
- **Cache** configuration and reference data that doesn't change frequently.

---

## 14. Accessibility & Inclusive Design

- All UI components must meet WCAG 2.1 AA as defined in the design system.
- Accessibility is not a feature — it's a requirement. It is tested, not assumed.
- Screen reader compatibility is verified for every interactive component.
- Touch targets meet minimums defined in `design-system.md`.

---

## 15. Agreement

By contributing to this repository, you agree to follow these rules. If a rule doesn't make sense for a specific situation, discuss it with the team **before** deviating. Rules evolve — this document should too.

---

*This is a living document. Propose changes via PR to `docs/development-rules.md`.*
