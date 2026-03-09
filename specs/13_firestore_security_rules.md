# Firestore Security Rules v1

## 1. Overview

### 1.1 Summary

This specification defines the Firestore Security Rules for Phase 2 of the Family Chores App. These rules enforce authenticated-only access, family-scoped data isolation, role-based write permissions, and safe invite code handling. Every read and write to Firestore passes through these rules -- they are the last line of defense against unauthorized data access, whether from a compromised client, a direct API call, or a misconfigured sync engine.

### 1.2 Business Context

The app stores sensitive family data: children's names and ages, parental PIN hashes, household schedules, and behavioral data (points, streaks). A data breach or unauthorized access would erode trust permanently. The security rules must ensure that:

1. No one outside a family can read or modify that family's data.
2. Children's profile data cannot be exfiltrated by other families' parents.
3. PIN hashes are not readable by anyone except the member themselves.
4. Invite codes are readable by authenticated users (necessary for the join flow) but writable only by Cloud Functions.

### 1.3 Scope

**In scope:**
- `families/{familyId}` document rules (read, create, update)
- `families/{familyId}/members/{memberId}` subcollection rules
- Helper functions for common checks (isAuthenticated, isFamilyMember, isFamilyParent)
- Placeholder rules for `tasks/**`, `rewards/**`, `redemptions/**`, `categories/**`
- PIN hash field-level protection
- Invite code write restriction (Cloud Functions admin SDK bypasses rules)
- Testing strategy with `@firebase/rules-unit-testing`

**Out of scope:**
- Task-specific rules (Phase 3)
- Reward/redemption-specific rules (Phase 4)
- Rate limiting (not natively supported by Firestore -- handled by Cloud Functions)
- Firebase Storage security rules (Phase 7)
- Custom claims for role-based access (considered, deferred)

### 1.4 References

- `specs/00_project_foundation.md` -- Section 4.7 (Security Rules)
- `specs/10_family_onboarding.md` -- Family creation, join flow
- `specs/11_member_profiles.md` -- Member CRUD operations
- `specs/12_pin_system.md` -- PIN hash storage
- `specs/14_cloud_functions_invite.md` -- Invite code Cloud Functions

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| SEC-001 | Unauthenticated requests denied | High | Any request without valid Firebase Auth token returns permission denied |
| SEC-002 | Family data readable only by members | High | User A in family 1 cannot read family 2's document |
| SEC-003 | Family creation allowed for authenticated users | High | Any authenticated user can create a new family document |
| SEC-004 | Family updates restricted to parents | High | Only members with role=parent can update the family document |
| SEC-005 | Family deletion not allowed | High | No client can delete a family document |
| SEC-006 | Member data readable by family members | High | Any member of a family can read all member docs in that family |
| SEC-007 | Member creation restricted to parents | High | Only parents can add new member documents |
| SEC-008 | Member self-update for non-sensitive fields | Medium | A member can update their own name, avatar, accentColor |
| SEC-009 | PIN hash writable by self or parent | High | A member can write their own pinHash/pinSalt, parents can write any member's |
| SEC-010 | Member deletion restricted to parents (not self) | High | Parents can delete members but cannot delete themselves |
| SEC-011 | Invite code not writable by clients | High | The inviteCode field on a family doc is only writable by Cloud Functions (admin SDK) |
| SEC-012 | Invite code readable by authenticated users | Medium | Any authenticated user can read a family's invite code (needed for join flow preview) |
| SEC-013 | Placeholder rules for Phase 3+ collections | Medium | tasks, rewards, redemptions, categories have deny-all rules until implemented |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| SEC-NFR-001 | Rule evaluation time | Time for Firestore to evaluate rules | < 100ms per request |
| SEC-NFR-002 | Rule complexity | Number of `get()` calls per rule | <= 2 (Firestore limit: 10 per request) |
| SEC-NFR-003 | Test coverage | Security rules test scenarios | 100% of rules have at least one allow + one deny test |

### 2.3 Assumptions

- Firebase Auth tokens are trustworthy (Firebase-issued, not forgeable).
- The Admin SDK (used by Cloud Functions) bypasses security rules entirely.
- `request.auth.uid` matches the Firebase Auth UID used in the member's `userId` field.
- Family membership is determined by the existence of a member document with a matching `userId`.
- The `role` field in member documents is set by the app and enforced by rules (a member cannot change their own role).

### 2.4 Constraints

- Firestore security rules can read other documents via `get()` and `exists()`, but each call counts toward the 10-call limit per evaluation.
- Rules cannot perform complex queries or aggregations.
- Rules cannot call external services or Cloud Functions.
- Field-level access control is supported via `request.resource.data` (what the client wants to write) vs `resource.data` (what currently exists).
- Cloud Functions using the Admin SDK bypass all rules. This is intentional for invite code management.

---

## 3. Helper Functions

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ===== HELPER FUNCTIONS =====

    /// Returns true if the request is from an authenticated user.
    function isAuthenticated() {
      return request.auth != null;
    }

    /// Returns true if the authenticated user is a member of the specified family.
    /// Performs a document existence check on the members subcollection.
    function isFamilyMember(familyId) {
      return isAuthenticated() &&
        exists(/databases/$(database)/documents/families/$(familyId)/members/$(getMemberIdForUser(familyId)));
    }

    /// Returns the member document for the current user in the specified family.
    /// Uses a query-like pattern: looks for a member with userId == auth.uid.
    /// NOTE: Since Firestore rules cannot query, we use a convention where
    /// the member document ID is the user's UID for parents (simplifies lookup).
    function getMemberDoc(familyId) {
      return get(/databases/$(database)/documents/families/$(familyId)/members/$(request.auth.uid));
    }

    /// Returns true if the authenticated user is a parent in the specified family.
    function isFamilyParent(familyId) {
      return isAuthenticated() &&
        exists(/databases/$(database)/documents/families/$(familyId)/members/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/families/$(familyId)/members/$(request.auth.uid)).data.role == 'parent';
    }

    /// Returns true if the authenticated user is the creator of the family.
    function isFamilyCreator(familyId) {
      return isAuthenticated() &&
        resource.data.createdBy == request.auth.uid;
    }

    /// Returns true if the document being written has all required fields.
    function hasRequiredFields(fields) {
      return request.resource.data.keys().hasAll(fields);
    }

    /// Returns true if only the allowed fields are being modified.
    function onlyUpdatingFields(allowedFields) {
      return request.resource.data.diff(resource.data).affectedKeys().hasOnly(allowedFields);
    }
```

---

## 4. Security Rules

### 4.1 Family Document Rules

```javascript
    // ===== FAMILY RULES =====
    match /families/{familyId} {

      // READ: Only family members can read the family document.
      // Exception: Authenticated users can read the inviteCode field
      // for the join flow (handled at the field level, not doc level).
      // For Phase 2 simplicity, we allow any authenticated user to read
      // family docs (needed for invite code lookup by code value).
      allow read: if isAuthenticated();

      // CREATE: Any authenticated user can create a family.
      // The createdBy field must match the authenticated user's UID.
      allow create: if isAuthenticated()
        && request.resource.data.createdBy == request.auth.uid
        && hasRequiredFields(['name', 'createdBy', 'createdAt', 'updatedAt']);

      // UPDATE: Only parents in the family can update.
      // inviteCode and inviteCodeExpiresAt are NOT client-writable
      // (only Cloud Functions via Admin SDK can set these).
      allow update: if isFamilyParent(familyId)
        && !request.resource.data.diff(resource.data).affectedKeys().hasAny(['inviteCode', 'inviteCodeExpiresAt', 'createdBy']);

      // DELETE: Not allowed from client. Use Cloud Functions for family deletion.
      allow delete: if false;
```

### 4.2 Member Document Rules

```javascript
      // ===== MEMBER RULES =====
      match /members/{memberId} {

        // READ: Any family member can read member documents.
        // This includes the member's own data and other members' data
        // (needed for profile switcher, task assignments, fairness dashboard).
        allow read: if isAuthenticated()
          && exists(/databases/$(database)/documents/families/$(familyId)/members/$(request.auth.uid));

        // CREATE: Only parents can add new members.
        allow create: if isFamilyParent(familyId)
          && hasRequiredFields(['name', 'role', 'age', 'accentColor', 'createdAt', 'updatedAt']);

        // UPDATE: Parents can update any member.
        // Non-parent members can update ONLY their own document
        // and ONLY specific non-sensitive fields.
        allow update: if isFamilyParent(familyId)
          || (isAuthenticated()
              && memberId == request.auth.uid
              && onlyUpdatingFields(['name', 'avatarUrl', 'accentColor', 'updatedAt', 'pinHash', 'pinSalt']));

        // DELETE: Only parents can delete members.
        // Cannot delete yourself (prevent family from losing all parents).
        allow delete: if isFamilyParent(familyId)
          && memberId != request.auth.uid;
      }
```

### 4.3 Phase 3+ Placeholder Rules

```javascript
      // ===== TASK RULES (Phase 3) =====
      match /tasks/{taskId} {
        // Placeholder: deny all until Phase 3 rules are implemented.
        allow read, write: if false;

        match /audit_log/{logId} {
          allow read, write: if false;
        }
      }

      // ===== REWARD RULES (Phase 4) =====
      match /rewards/{rewardId} {
        allow read, write: if false;
      }

      // ===== REDEMPTION RULES (Phase 4) =====
      match /redemptions/{redemptionId} {
        allow read, write: if false;
      }

      // ===== CATEGORY RULES (Phase 3) =====
      match /categories/{categoryId} {
        allow read, write: if false;
      }
    }
  }
}
```

### 4.4 Complete Rules File

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ===== HELPER FUNCTIONS =====

    function isAuthenticated() {
      return request.auth != null;
    }

    function isFamilyParent(familyId) {
      return isAuthenticated()
        && exists(/databases/$(database)/documents/families/$(familyId)/members/$(request.auth.uid))
        && get(/databases/$(database)/documents/families/$(familyId)/members/$(request.auth.uid)).data.role == 'parent';
    }

    function hasRequiredFields(fields) {
      return request.resource.data.keys().hasAll(fields);
    }

    function onlyUpdatingFields(allowedFields) {
      return request.resource.data.diff(resource.data).affectedKeys().hasOnly(allowedFields);
    }

    // ===== FAMILY RULES =====
    match /families/{familyId} {
      allow read: if isAuthenticated();

      allow create: if isAuthenticated()
        && request.resource.data.createdBy == request.auth.uid
        && hasRequiredFields(['name', 'createdBy', 'createdAt', 'updatedAt']);

      allow update: if isFamilyParent(familyId)
        && !request.resource.data.diff(resource.data).affectedKeys()
            .hasAny(['inviteCode', 'inviteCodeExpiresAt', 'createdBy']);

      allow delete: if false;

      // ===== MEMBER RULES =====
      match /members/{memberId} {
        allow read: if isAuthenticated()
          && exists(/databases/$(database)/documents/families/$(familyId)/members/$(request.auth.uid));

        allow create: if isFamilyParent(familyId)
          && hasRequiredFields(['name', 'role', 'age', 'accentColor', 'createdAt', 'updatedAt']);

        allow update: if isFamilyParent(familyId)
          || (isAuthenticated()
              && memberId == request.auth.uid
              && onlyUpdatingFields(['name', 'avatarUrl', 'accentColor', 'updatedAt', 'pinHash', 'pinSalt']));

        allow delete: if isFamilyParent(familyId)
          && memberId != request.auth.uid;
      }

      // ===== PHASE 3+ PLACEHOLDERS =====
      match /tasks/{taskId} {
        allow read, write: if false;
        match /audit_log/{logId} {
          allow read, write: if false;
        }
      }

      match /rewards/{rewardId} {
        allow read, write: if false;
      }

      match /redemptions/{redemptionId} {
        allow read, write: if false;
      }

      match /categories/{categoryId} {
        allow read, write: if false;
      }
    }
  }
}
```

---

## 5. Design Decisions

### 5.1 Member Document ID Convention

For security rules to efficiently check family membership and role, we use the following convention:

- **Parent member documents** use the Firebase Auth UID as their Firestore document ID. This allows `exists(/families/{familyId}/members/{request.auth.uid})` to work without a query.
- **Child member documents** use a client-generated UUID as their document ID (children don't have auth UIDs).

This convention is critical for the `isFamilyMember()` and `isFamilyParent()` helper functions. Without it, we would need to query the members subcollection (not supported in security rules) or maintain a separate lookup structure.

### 5.2 Family Read Access

The current rules allow any authenticated user to read any family document. This is intentional for Phase 2:

- The join flow requires looking up a family by invite code. Since Firestore rules cannot filter reads by field value (rules apply to the document, not the query), the client must read the family doc to check the invite code.
- In Phase 3, this can be tightened if needed by using a separate `inviteCodes` top-level collection.

### 5.3 Invite Code Protection

The `inviteCode` and `inviteCodeExpiresAt` fields on the family document are not client-writable. The update rule explicitly blocks changes to these fields:

```javascript
!request.resource.data.diff(resource.data).affectedKeys()
    .hasAny(['inviteCode', 'inviteCodeExpiresAt', 'createdBy'])
```

Only Cloud Functions (using the Admin SDK, which bypasses security rules) can set these fields. This prevents a malicious client from generating their own invite codes.

### 5.4 PIN Hash Protection

PIN hashes (`pinHash`, `pinSalt`) are sensitive but not secret in the same way passwords are -- they are SHA-256 hashes of 4-6 digit PINs, which are already rate-limited by the lockout mechanism. The rules allow:

- **Read**: Any family member can read member documents (including pinHash). This is needed because PIN verification happens client-side. The hash and salt must be readable.
- **Write**: A member can write their own pinHash/pinSalt (PIN setup/change). A parent can write any member's pinHash/pinSalt (resetting a child's PIN).

**Note:** In a higher-security scenario, PIN verification would happen server-side. For this app's threat model (preventing children, not sophisticated attackers), client-side verification is acceptable.

---

## 6. Testing Strategy

### 6.1 Setup

Security rules are tested using the Firebase Emulator Suite with `@firebase/rules-unit-testing`:

```bash
npm install --save-dev @firebase/rules-unit-testing firebase-admin
```

### 6.2 Test File Structure

```
test/
  security-rules/
    family_rules_test.ts
    member_rules_test.ts
    placeholder_rules_test.ts
    helpers.ts
```

### 6.3 Test Helper

```typescript
// test/security-rules/helpers.ts
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';

export async function setupTestEnv(): Promise<RulesTestEnvironment> {
  return initializeTestEnvironment({
    projectId: 'family-chores-test',
    firestore: {
      rules: readFileSync('firestore.rules', 'utf8'),
    },
  });
}

export function getAuthedFirestore(
  testEnv: RulesTestEnvironment,
  uid: string,
) {
  return testEnv.authenticatedContext(uid).firestore();
}

export function getUnauthFirestore(testEnv: RulesTestEnvironment) {
  return testEnv.unauthenticatedContext().firestore();
}
```

### 6.4 Test Scenarios

| Test ID | Scenario | Operation | Expected | Priority |
|---------|----------|-----------|----------|----------|
| SEC-FT-001 | Unauthenticated read family | GET /families/{id} without auth | DENIED | High |
| SEC-FT-002 | Authenticated read family | GET /families/{id} with auth | ALLOWED | High |
| SEC-FT-003 | Create family with matching UID | CREATE /families/{id} with createdBy=auth.uid | ALLOWED | High |
| SEC-FT-004 | Create family with mismatched UID | CREATE /families/{id} with createdBy!=auth.uid | DENIED | High |
| SEC-FT-005 | Parent updates family name | UPDATE name on /families/{id} by parent | ALLOWED | High |
| SEC-FT-006 | Non-member updates family | UPDATE /families/{id} by non-member | DENIED | High |
| SEC-FT-007 | Client writes inviteCode | UPDATE inviteCode on /families/{id} | DENIED | High |
| SEC-FT-008 | Delete family | DELETE /families/{id} | DENIED | High |
| SEC-FT-009 | Family member reads members | GET /families/{id}/members/{mid} by member | ALLOWED | High |
| SEC-FT-010 | Non-member reads members | GET /families/{id}/members/{mid} by outsider | DENIED | High |
| SEC-FT-011 | Parent creates member | CREATE /families/{id}/members/{mid} by parent | ALLOWED | High |
| SEC-FT-012 | Child creates member | CREATE /families/{id}/members/{mid} by child | DENIED | High |
| SEC-FT-013 | Parent updates any member | UPDATE /families/{id}/members/{mid} by parent | ALLOWED | High |
| SEC-FT-014 | Member updates own avatar | UPDATE avatarUrl on own doc by non-parent | ALLOWED | High |
| SEC-FT-015 | Member updates own role | UPDATE role on own doc by non-parent | DENIED | High |
| SEC-FT-016 | Member updates own pinHash | UPDATE pinHash on own doc | ALLOWED | High |
| SEC-FT-017 | Member updates other's pinHash | UPDATE pinHash on other's doc (non-parent) | DENIED | High |
| SEC-FT-018 | Parent deletes child member | DELETE /families/{id}/members/{childId} by parent | ALLOWED | High |
| SEC-FT-019 | Parent deletes self | DELETE /families/{id}/members/{ownId} by parent | DENIED | High |
| SEC-FT-020 | Read tasks (placeholder) | GET /families/{id}/tasks/{tid} | DENIED | Medium |
| SEC-FT-021 | Write rewards (placeholder) | CREATE /families/{id}/rewards/{rid} | DENIED | Medium |
| SEC-FT-022 | Create family missing required fields | CREATE without 'name' | DENIED | Medium |

---

## 7. Deployment

### 7.1 Deploy Rules

```bash
# Deploy rules only
firebase deploy --only firestore:rules

# Deploy rules and indexes
firebase deploy --only firestore
```

### 7.2 Rollback

Firestore rules are versioned in the Firebase Console. If a deployment breaks access, roll back to the previous version via the Console or re-deploy the previous rules file.

### 7.3 CI Integration

```yaml
# .github/workflows/security-rules.yml (excerpt)
- name: Run security rules tests
  run: |
    firebase emulators:exec --only firestore \
      "npx jest test/security-rules/ --forceExit"
```

---

## 8. Impact Analysis

### 8.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| `firestore.rules` | New | High | Incorrect rules = data breach or access denial |
| Sync engine | Dependency | Medium | Sync writes must conform to rules or they will fail |
| Family repository | Dependency | Medium | Write operations must send required fields |
| Member repository | Dependency | Medium | Self-update must only touch allowed fields |
| Cloud Functions | Dependency | Low | Admin SDK bypasses rules (by design) |

### 8.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Rules too restrictive -- blocks legitimate writes | High | High | Test every write path in emulator. Monitor Firestore errors in Crashlytics. |
| Rules too permissive -- allows unauthorized reads | Medium | High | Test every deny scenario. Security review before production deploy. |
| `get()` call limit (10) exceeded | Low | Medium | Current rules use max 2 `get()` calls. Monitor if rules grow. |
| Rule evaluation latency impacts sync | Low | Medium | Firestore rules evaluate in < 10ms for simple checks. Profile if complex. |
| Member document ID convention breaks | Medium | High | Enforce convention in repository layer. Add assertion tests. |

---

## 9. Implementation Recommendations

### 9.1 Suggested Approach

1. Write `firestore.rules` file at project root.
2. Configure `firebase.json` to point to `firestore.rules`.
3. Set up `@firebase/rules-unit-testing` in a `test/security-rules/` directory.
4. Write all test scenarios (Section 6.4) against the emulator.
5. Run tests: `firebase emulators:exec --only firestore "npx jest test/security-rules/"`.
6. Deploy rules: `firebase deploy --only firestore:rules`.
7. Verify sync engine writes succeed against deployed rules.
8. Add rules tests to CI pipeline.

### 9.2 Estimated Effort

**T-shirt size: S** (1-2 days)

The rules themselves are ~50 lines. Most effort is in writing comprehensive tests and verifying that the sync engine's write patterns conform to the rules.

---

## 10. Open Questions

- [ ] Should family read access be restricted to members only, or remain open to all authenticated users for the invite code lookup flow?
- [ ] Should PIN hashes be readable by all family members, or restricted to self-read only? (Current: readable by all members -- needed for client-side verification.)
- [ ] Should we add a `deletedAt` field for soft-delete support in rules, or continue with hard deletes?
- [ ] Should custom claims (e.g., `role: parent` in the auth token) be used instead of document lookups for role checks? Custom claims require Cloud Functions to set.
- [ ] Should the placeholder deny-all rules for Phase 3+ be `allow read: if false; allow write: if false;` or a single `allow read, write: if false;`?

---

*Generated by Software Architect Analyst*
*Date: 2026-03-09*
