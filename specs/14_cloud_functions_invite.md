# Cloud Functions -- Invite Code System

## 1. Overview

### 1.1 Summary

This specification defines the Firebase Cloud Functions that power the family invite code system. Three functions are implemented: `generateInviteCode` (creates a shareable code for joining a family), `validateAndJoinFamily` (validates a code and adds a user to the family), and `cleanupExpiredInviteCodes` (scheduled daily cleanup of expired codes). These functions run server-side and use the Firebase Admin SDK, which bypasses Firestore security rules, allowing them to write invite codes and modify family membership safely.

### 1.2 Business Context

The invite code system enables the secondary onboarding path: Sofia installs the app after Marcus has already set up the family. Instead of Marcus having to share his credentials or manually add Sofia's account, he generates a short, human-readable code that Sofia enters on her device. The code is temporary (48-hour expiry), simple (6 alphanumeric characters), and secure (validated server-side). This flow must be frictionless -- Marcus should be able to text the code to Sofia, and she should be able to join the family in under 30 seconds.

### 1.3 Scope

**In scope:**
- `generateInviteCode` Cloud Function (callable, parent-only)
- `validateAndJoinFamily` Cloud Function (callable, authenticated)
- `cleanupExpiredInviteCodes` Cloud Function (scheduled, daily)
- TypeScript implementation with proper error handling
- Input validation and typed error responses
- Firebase emulator testing configuration
- Flutter client call patterns
- Unit test plan (Jest)

**Out of scope:**
- Family removal (leave family) -- handled client-side with Firestore writes
- Email-based invitations (considered, deferred -- code-based is simpler)
- QR code generation (Phase 7 -- nice-to-have, wraps the same invite code)
- Push notification to family when new member joins (Phase 7)

### 1.4 References

- `specs/00_project_foundation.md` -- Section 4.6 (Multi-User Model)
- `specs/10_family_onboarding.md` -- Join family flow, FamilyRemoteDatasource
- `specs/13_firestore_security_rules.md` -- Invite code field protection
- `CLAUDE.md` -- Cloud Functions in tech stack

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| CF-001 | Generate a 6-character alphanumeric invite code | High | Code is uppercase, no ambiguous characters (0/O, 1/I/L), 48-hour expiry |
| CF-002 | Store invite code on family document | High | `inviteCode` and `inviteCodeExpiresAt` fields set on `families/{familyId}` |
| CF-003 | Only parents can generate invite codes | High | Non-parent callers receive `permission-denied` error |
| CF-004 | Validate invite code and return family ID | High | Given a valid, non-expired code, returns the familyId |
| CF-005 | Add user as parent member on join | High | Creates member document in `families/{familyId}/members/{userId}` with role=parent |
| CF-006 | Reject expired invite codes | High | Expired code returns `invite-code/expired` error |
| CF-007 | Reject invalid invite codes | High | Non-existent code returns `invite-code/not-found` error |
| CF-008 | Reject already-member requests | Medium | User already in family returns `invite-code/already-member` error |
| CF-009 | Cleanup expired invite codes daily | Medium | Scheduled function runs at 3:00 AM UTC, clears expired codes |
| CF-010 | Previous invite code overwritten on new generation | Medium | Generating a new code replaces the previous one |
| CF-011 | Code is case-insensitive on validation | Medium | "abc123" matches "ABC123" |

### 2.2 Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| CF-NFR-001 | Code generation response time | Cold start to response | < 3 seconds (cold), < 500ms (warm) |
| CF-NFR-002 | Code validation response time | Validate + create member | < 2 seconds (warm) |
| CF-NFR-003 | Code collision probability | Probability of duplicate active code | < 0.001% (32^6 = ~1 billion combinations) |
| CF-NFR-004 | Cleanup function runtime | Process all families | < 60 seconds |

### 2.3 Assumptions

- Cloud Functions are deployed in the same region as the Firestore database (e.g., `us-central1`).
- The Firebase project is on the Blaze plan (required for Cloud Functions).
- The Admin SDK has full access to Firestore (bypasses security rules).
- The scheduled function uses Cloud Scheduler (available on Blaze plan).

### 2.4 Constraints

- Cloud Functions Gen 2 (based on Cloud Run) is used for improved cold start times.
- The invite code alphabet excludes ambiguous characters: `0, O, 1, I, L, S, 5` to improve human readability. This leaves 25 characters: `ABCDEFGHJKMNPQRTUVWXYZ2346789`.
- Only one active invite code per family at a time. Generating a new code invalidates the previous one.
- Invite codes are not reusable -- once used to join, the code is consumed (but remains on the family doc until overwritten or expired).

---

## 3. Project Structure

### 3.1 Functions Directory

```
functions/
  src/
    index.ts                   # Export all functions
    invite/
      generate-invite-code.ts  # generateInviteCode function
      validate-and-join.ts     # validateAndJoinFamily function
      cleanup-expired.ts       # cleanupExpiredInviteCodes function
      invite-utils.ts          # Shared utilities (code generation, validation)
    types/
      invite-types.ts          # TypeScript interfaces
  test/
    generate-invite-code.test.ts
    validate-and-join.test.ts
    cleanup-expired.test.ts
  package.json
  tsconfig.json
  .eslintrc.js
```

### 3.2 package.json

```json
{
  "name": "family-chores-functions",
  "scripts": {
    "build": "tsc",
    "serve": "npm run build && firebase emulators:start --only functions",
    "shell": "npm run build && firebase functions:shell",
    "start": "npm run shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log",
    "test": "jest --forceExit",
    "test:watch": "jest --watch"
  },
  "engines": {
    "node": "20"
  },
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0"
  },
  "devDependencies": {
    "@types/jest": "^29.5.0",
    "jest": "^29.7.0",
    "ts-jest": "^29.1.0",
    "typescript": "^5.3.0",
    "firebase-functions-test": "^3.1.0",
    "@typescript-eslint/eslint-plugin": "^7.0.0",
    "@typescript-eslint/parser": "^7.0.0",
    "eslint": "^8.57.0"
  },
  "private": true
}
```

### 3.3 tsconfig.json

```json
{
  "compilerOptions": {
    "module": "commonjs",
    "noImplicitReturns": true,
    "noUnusedLocals": true,
    "outDir": "lib",
    "sourceMap": true,
    "strict": true,
    "target": "es2022",
    "skipLibCheck": true
  },
  "compileOnSave": true,
  "include": ["src"]
}
```

---

## 4. Function Implementations

### 4.1 Invite Utilities

```typescript
// functions/src/invite/invite-utils.ts

/**
 * Alphabet for invite codes. Excludes ambiguous characters:
 * 0/O, 1/I/L, S/5 to improve human readability.
 */
const INVITE_CODE_ALPHABET = 'ABCDEFGHJKMNPQRTUVWXYZ2346789';
const INVITE_CODE_LENGTH = 6;
const INVITE_CODE_EXPIRY_HOURS = 48;

/**
 * Generates a random invite code.
 * Uses crypto.randomInt for unbiased random character selection.
 */
export function generateCode(): string {
  const crypto = require('crypto');
  let code = '';
  for (let i = 0; i < INVITE_CODE_LENGTH; i++) {
    const index = crypto.randomInt(INVITE_CODE_ALPHABET.length);
    code += INVITE_CODE_ALPHABET[index];
  }
  return code;
}

/**
 * Calculates the expiry timestamp for a new invite code.
 * Returns a Firestore Timestamp.
 */
export function getExpiryTimestamp(): FirebaseFirestore.Timestamp {
  const expiryDate = new Date();
  expiryDate.setHours(expiryDate.getHours() + INVITE_CODE_EXPIRY_HOURS);
  return FirebaseFirestore.Timestamp.fromDate(expiryDate);
}

/**
 * Normalizes an invite code for comparison.
 * Uppercases and trims whitespace.
 */
export function normalizeCode(code: string): string {
  return code.trim().toUpperCase();
}
```

### 4.2 generateInviteCode

```typescript
// functions/src/invite/generate-invite-code.ts
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { generateCode, getExpiryTimestamp } from './invite-utils';

/**
 * Generates a 6-character invite code for a family.
 *
 * Callable function. Requires authenticated parent.
 *
 * Input: { familyId: string }
 * Output: { inviteCode: string, expiresAt: string }
 *
 * Errors:
 * - unauthenticated: Not signed in
 * - permission-denied: Not a parent in the family
 * - not-found: Family does not exist
 * - internal: Unexpected error
 */
export const generateInviteCode = onCall(
  { region: 'us-central1' },
  async (request) => {
    // 1. Verify authentication
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }

    const { familyId } = request.data;

    // 2. Validate input
    if (!familyId || typeof familyId !== 'string') {
      throw new HttpsError(
        'invalid-argument',
        'familyId is required and must be a string.',
      );
    }

    const db = getFirestore();
    const uid = request.auth.uid;

    // 3. Verify family exists
    const familyRef = db.collection('families').doc(familyId);
    const familyDoc = await familyRef.get();

    if (!familyDoc.exists) {
      throw new HttpsError('not-found', 'Family not found.');
    }

    // 4. Verify caller is a parent in this family
    const memberRef = db
      .collection('families')
      .doc(familyId)
      .collection('members')
      .doc(uid);
    const memberDoc = await memberRef.get();

    if (!memberDoc.exists || memberDoc.data()?.role !== 'parent') {
      throw new HttpsError(
        'permission-denied',
        'Only parents can generate invite codes.',
      );
    }

    // 5. Generate code and set expiry
    const inviteCode = generateCode();
    const expiresAt = getExpiryTimestamp();

    // 6. Store on family document
    await familyRef.update({
      inviteCode,
      inviteCodeExpiresAt: expiresAt,
      updatedAt: FirebaseFirestore.FieldValue.serverTimestamp(),
    });

    // Return code, shareable URL, and expiry (see specs/16_deep_links.md Section 8)
    return {
      code: inviteCode,
      shareableUrl: `https://familychores.app/join?code=${inviteCode}`,
      expiresAt: expiresAt.toDate().toISOString(),
    };
  },
);
```

### 4.3 validateAndJoinFamily

```typescript
// functions/src/invite/validate-and-join.ts
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { normalizeCode } from './invite-utils';

/**
 * Validates an invite code and adds the user to the family.
 *
 * Callable function. Requires authentication.
 *
 * Input: { inviteCode: string, userName: string }
 * Output: { familyId: string, familyName: string }
 *
 * Errors:
 * - unauthenticated: Not signed in
 * - not-found: No family with this invite code (invite-code/not-found)
 * - failed-precondition: Code expired (invite-code/expired)
 * - already-exists: User is already a member (invite-code/already-member)
 * - internal: Unexpected error
 */
export const validateAndJoinFamily = onCall(
  { region: 'us-central1' },
  async (request) => {
    // 1. Verify authentication
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }

    const { inviteCode, userName } = request.data;

    // 2. Validate input
    if (!inviteCode || typeof inviteCode !== 'string') {
      throw new HttpsError(
        'invalid-argument',
        'inviteCode is required.',
      );
    }
    if (!userName || typeof userName !== 'string') {
      throw new HttpsError(
        'invalid-argument',
        'userName is required.',
      );
    }

    const db = getFirestore();
    const uid = request.auth.uid;
    const normalizedCode = normalizeCode(inviteCode);

    // 3. Find family with this invite code
    const familiesRef = db.collection('families');
    const querySnapshot = await familiesRef
      .where('inviteCode', '==', normalizedCode)
      .limit(1)
      .get();

    if (querySnapshot.empty) {
      throw new HttpsError(
        'not-found',
        'No family found with this invite code.',
      );
    }

    const familyDoc = querySnapshot.docs[0];
    const familyData = familyDoc.data();
    const familyId = familyDoc.id;

    // 4. Check code expiry
    const expiresAt = familyData.inviteCodeExpiresAt?.toDate();
    if (!expiresAt || expiresAt < new Date()) {
      throw new HttpsError(
        'failed-precondition',
        'This invite code has expired.',
      );
    }

    // 5. Check if user is already a member
    const existingMember = await db
      .collection('families')
      .doc(familyId)
      .collection('members')
      .doc(uid)
      .get();

    if (existingMember.exists) {
      throw new HttpsError(
        'already-exists',
        'You are already a member of this family.',
      );
    }

    // 6. Add user as parent member (using batch write)
    const batch = db.batch();

    // Create member document (using auth UID as doc ID per convention)
    const memberRef = db
      .collection('families')
      .doc(familyId)
      .collection('members')
      .doc(uid);

    batch.set(memberRef, {
      name: userName,
      role: 'parent',
      age: 0, // Parent must set their own age
      avatarUrl: null,
      accentColor: '#A8D8EA', // Default color, can be changed later
      userId: uid,
      pinHash: null,
      pinSalt: null,
      deviceIds: [],
      points: 0,
      currentStreak: 0,
      longestStreak: 0,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return {
      familyId,
      familyName: familyData.name,
    };
  },
);
```

### 4.4 cleanupExpiredInviteCodes

```typescript
// functions/src/invite/cleanup-expired.ts
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

/**
 * Scheduled function that runs daily at 3:00 AM UTC.
 * Removes expired invite codes from family documents.
 */
export const cleanupExpiredInviteCodes = onSchedule(
  {
    schedule: '0 3 * * *', // Every day at 3:00 AM UTC
    region: 'us-central1',
    timeoutSeconds: 120,
  },
  async () => {
    const db = getFirestore();
    const now = new Date();

    // Query families with expired invite codes
    const snapshot = await db
      .collection('families')
      .where('inviteCodeExpiresAt', '<', now)
      .get();

    if (snapshot.empty) {
      console.log('No expired invite codes found.');
      return;
    }

    // Batch clear expired codes
    const batch = db.batch();
    let count = 0;

    for (const doc of snapshot.docs) {
      batch.update(doc.ref, {
        inviteCode: FieldValue.delete(),
        inviteCodeExpiresAt: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      count++;

      // Firestore batch limit is 500
      if (count % 500 === 0) {
        await batch.commit();
      }
    }

    if (count % 500 !== 0) {
      await batch.commit();
    }

    console.log(`Cleaned up ${count} expired invite codes.`);
  },
);
```

### 4.5 Index File

```typescript
// functions/src/index.ts
import { initializeApp } from 'firebase-admin/app';

initializeApp();

export { generateInviteCode } from './invite/generate-invite-code';
export { validateAndJoinFamily } from './invite/validate-and-join';
export { cleanupExpiredInviteCodes } from './invite/cleanup-expired';
```

---

## 5. Flutter Client Integration

### 5.1 Cloud Functions Call Pattern

```dart
// Usage in FamilyRemoteDatasource (specs/10_family_onboarding.md)
import 'package:cloud_functions/cloud_functions.dart';

// Generate invite code
final callable = FirebaseFunctions.instance.httpsCallable(
  'generateInviteCode',
  options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
);
final result = await callable.call<Map<String, dynamic>>(
  {'familyId': familyId},
);
final inviteCode = result.data['code'] as String;
final shareableUrl = result.data['shareableUrl'] as String; // https://familychores.app/join?code=ABC123

// Validate and join family
final joinCallable = FirebaseFunctions.instance.httpsCallable(
  'validateAndJoinFamily',
);
final joinResult = await joinCallable.call<Map<String, dynamic>>({
  'inviteCode': code,
  'userName': displayName,
});
final familyId = joinResult.data['familyId'] as String;
```

### 5.2 Error Handling in Flutter

```dart
// Mapping Cloud Function errors to domain failures
try {
  final result = await callable.call(data);
  // Handle success
} on FirebaseFunctionsException catch (e) {
  switch (e.code) {
    case 'not-found':
      return const Result.failure(
        ValidationFailure(message: 'No family found with this invite code.'),
      );
    case 'failed-precondition':
      return const Result.failure(
        ValidationFailure(message: 'This invite code has expired.'),
      );
    case 'already-exists':
      return const Result.failure(
        ValidationFailure(message: 'You are already a member of this family.'),
      );
    case 'permission-denied':
      return const Result.failure(
        PermissionFailure(message: 'Only parents can generate invite codes.'),
      );
    case 'unauthenticated':
      return const Result.failure(
        AuthFailure(message: 'Please sign in to continue.'),
      );
    default:
      return Result.failure(
        UnexpectedFailure(message: 'Something went wrong: ${e.message}'),
      );
  }
}
```

### 5.3 Emulator Configuration

```dart
// In FirebaseConfig (specs/08_phase2_foundations.md)
if (useEmulator) {
  FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
}
```

---

## 6. Error Codes

| Code | HTTP Status | Function | Meaning |
|------|------------|----------|---------|
| `unauthenticated` | 401 | Both | No Firebase Auth token provided |
| `invalid-argument` | 400 | Both | Missing or invalid input parameters |
| `not-found` | 404 | generate | Family document does not exist |
| `not-found` | 404 | validate | No family with this invite code |
| `permission-denied` | 403 | generate | Caller is not a parent in the family |
| `failed-precondition` | 400 | validate | Invite code has expired |
| `already-exists` | 409 | validate | User is already a family member |
| `internal` | 500 | Both | Unexpected server error |

---

## 7. Deployment

### 7.1 Commands

```bash
# Build TypeScript
cd functions && npm run build

# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:generateInviteCode

# View function logs
firebase functions:log --only generateInviteCode

# Run locally with emulator
firebase emulators:start --only functions,firestore,auth
```

### 7.2 Environment Configuration

No environment-specific configuration is needed for Phase 2. All configuration comes from the Firebase project setup. In future phases, if API keys or external service URLs are needed:

```bash
firebase functions:config:set someservice.key="value"
```

---

## 8. Impact Analysis

### 8.1 Affected Components

| Component | Type of Change | Risk Level | Notes |
|-----------|---------------|------------|-------|
| `functions/` directory | New | Medium | New server-side code, requires Firebase Blaze plan |
| `firebase.json` | Modified | Low | Functions source directory added |
| `firestore.rules` | Dependency | Low | Invite code fields protected (spec 13) |
| `FamilyRemoteDatasource` | Modified | Medium | Cloud Function calls added |
| `pubspec.yaml` | Modified | Low | `cloud_functions` dependency already included |

### 8.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Cold start latency > 3 seconds | Medium | Medium | Use Gen 2 functions (Cloud Run). Keep function lightweight. Warm function if needed. |
| Invite code collision | Very Low | Low | 29^6 = ~594M combinations. With < 1000 active families, probability is negligible. |
| Scheduled cleanup fails silently | Low | Low | Monitor via Cloud Logging. Add alert for errors. Codes auto-expire anyway. |
| Firestore query for invite code is slow | Low | Medium | Add index on `inviteCode` field. Query is limited to 1 result. |
| User joins family multiple times via race condition | Low | Medium | `existingMember.exists` check + batch write. Idempotent member doc ID (auth UID). |
| Firebase Blaze plan billing surprise | Low | Medium | Set budget alerts. Functions are pay-per-invocation. Expected volume: < 100 invocations/day. |

---

## 9. Functional Tests

### 9.1 Test Scenarios

| Test ID | Scenario | Given | When | Then | Priority |
|---------|----------|-------|------|------|----------|
| CF-FT-001 | Generate code successfully | Family exists, caller is parent | generateInviteCode called | Returns 6-char code, stored on family doc | High |
| CF-FT-002 | Generate code -- not authenticated | No auth token | generateInviteCode called | Throws unauthenticated | High |
| CF-FT-003 | Generate code -- not a parent | Caller is child member | generateInviteCode called | Throws permission-denied | High |
| CF-FT-004 | Generate code -- family not found | Invalid familyId | generateInviteCode called | Throws not-found | High |
| CF-FT-005 | Generate code overwrites previous | Family has existing code | generateInviteCode called | Previous code replaced, new code stored | Medium |
| CF-FT-006 | Validate and join successfully | Valid non-expired code, new user | validateAndJoinFamily called | User added as parent member, familyId returned | High |
| CF-FT-007 | Validate -- code not found | Non-existent code | validateAndJoinFamily called | Throws not-found | High |
| CF-FT-008 | Validate -- code expired | Expired code | validateAndJoinFamily called | Throws failed-precondition | High |
| CF-FT-009 | Validate -- already member | User already in family | validateAndJoinFamily called | Throws already-exists | High |
| CF-FT-010 | Validate -- not authenticated | No auth token | validateAndJoinFamily called | Throws unauthenticated | High |
| CF-FT-011 | Validate -- case insensitive | Code "abc123" when stored as "ABC123" | validateAndJoinFamily called | Code matches, join succeeds | Medium |
| CF-FT-012 | Cleanup removes expired codes | 3 families with expired codes | cleanupExpiredInviteCodes runs | All 3 invite codes removed | Medium |
| CF-FT-013 | Cleanup ignores valid codes | 2 expired, 1 valid | cleanupExpiredInviteCodes runs | Only 2 cleared, 1 remains | Medium |
| CF-FT-014 | Cleanup handles empty result | No expired codes | cleanupExpiredInviteCodes runs | No errors, no changes | Low |
| CF-FT-015 | Generated code uses safe alphabet | -- | generateCode called 1000 times | All codes contain only safe characters | Medium |
| CF-FT-016 | Member doc created with correct fields | Join succeeds | Member doc read | Has name, role=parent, userId, timestamps | High |

### 9.2 Test Setup

```typescript
// functions/test/generate-invite-code.test.ts
import * as admin from 'firebase-admin';
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';

// Use firebase-functions-test for wrapping functions
import * as functionsTest from 'firebase-functions-test';

const testEnv = functionsTest.default({
  projectId: 'family-chores-test',
});

describe('generateInviteCode', () => {
  // ... test cases from CF-FT-001 through CF-FT-005
});

describe('validateAndJoinFamily', () => {
  // ... test cases from CF-FT-006 through CF-FT-011
});

describe('cleanupExpiredInviteCodes', () => {
  // ... test cases from CF-FT-012 through CF-FT-014
});
```

### 9.3 Edge Cases

- Invite code generation when family doc has no existing invite code fields.
- Code with leading/trailing whitespace submitted by user.
- Extremely rapid consecutive calls to generateInviteCode (rate limiting not enforced, but each call overwrites the previous).
- `validateAndJoinFamily` called during network partition (Firestore retry handles this).
- Batch commit in cleanup function for > 500 expired codes.
- Timezone handling in expiry comparison (all timestamps are UTC Firestore server timestamps).

---

## 10. Firestore Index Requirements

```json
// firestore.indexes.json
{
  "indexes": [
    {
      "collectionGroup": "families",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "inviteCode", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "families",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "inviteCodeExpiresAt", "order": "ASCENDING" }
      ]
    }
  ]
}
```

---

## 11. Implementation Recommendations

### 11.1 Prototype Checklist

1. **What can a user do?** As Marcus, I can tap "Generate Invite Code" in settings to get a 6-character code. I text it to Sofia. Sofia enters the code on her device and joins the family instantly.
2. **Screens delivered:** No new screens -- the invite code UI is part of FamilySetupScreen (join path) and SettingsScreen.
3. **Minimum data flow:** Marcus taps "Generate Code" -> Flutter calls Cloud Function -> Function generates code, writes to Firestore family doc -> Code displayed in app. Sofia enters code -> Flutter calls validateAndJoinFamily -> Function validates, creates member doc -> Sofia sees family data.
4. **Offline behavior:** Both Cloud Functions require internet. The Flutter UI disables the "Generate Code" and "Join" buttons when offline.
5. **Done looks like:** A tester on device A generates an invite code. A tester on device B enters the code and is added to the family. Both devices show the same family members.

### 11.2 Suggested Approach

1. Initialize the `functions/` directory with `firebase init functions`.
2. Configure `tsconfig.json` and `package.json`.
3. Implement `invite-utils.ts` with code generation and normalization.
4. Implement `generateInviteCode` function.
5. Implement `validateAndJoinFamily` function.
6. Implement `cleanupExpiredInviteCodes` function.
7. Write Jest tests for all three functions.
8. Deploy to Firebase emulator: `firebase emulators:start --only functions,firestore,auth`.
9. Test from Flutter client against emulator.
10. Deploy to production: `firebase deploy --only functions`.
11. Add Firestore indexes for invite code queries.

### 11.3 Estimated Effort

**T-shirt size: S-M** (2-3 days)

The functions are straightforward CRUD with validation. Primary effort is in testing setup and emulator integration with the Flutter client.

---

## 12. Open Questions

- [x] Should the invite code be shareable via a deep link (e.g., `familychores.app/join?code=ABC123`)? Resolved: YES -- implemented in Phase 2. Uses native Universal Links (iOS) and App Links (Android) instead of deprecated Firebase Dynamic Links. See `specs/16_deep_links.md`.
- [ ] Should there be a rate limit on invite code generation (e.g., max 5 codes per hour per family)?
- [ ] Should the joining parent's age be collected during the join flow, or left as 0 for them to set later?
- [ ] Should the invite code be consumed (deleted) after successful use, or left to expire naturally?
- [ ] Should we send a push notification to existing family members when someone joins? (Deferred to Phase 7.)

---

*Generated by Software Architect Analyst*
*Date: 2026-03-09*
