import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { normalizeCode } from './invite-utils';

export const validateAndJoinFamily = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }

    const inviteCode = request.data.inviteCode;
    const userName = request.data.userName;
    if (!inviteCode || typeof inviteCode !== 'string') {
      throw new HttpsError('invalid-argument', 'inviteCode is required.');
    }
    if (!userName || typeof userName !== 'string') {
      throw new HttpsError('invalid-argument', 'userName is required.');
    }

    const db = getFirestore();
    const normalizedCode = normalizeCode(inviteCode);
    const families = await db
      .collection('families')
      .where('inviteCode', '==', normalizedCode)
      .limit(1)
      .get();

    if (families.empty) {
      throw new HttpsError('not-found', 'invite-code/not-found');
    }

    const familyDoc = families.docs.first;
    const familyData = familyDoc.data();
    const expiresAt = familyData.inviteCodeExpiresAt?.toDate?.();
    if (!expiresAt || expiresAt.getTime() < Date.now()) {
      throw new HttpsError('failed-precondition', 'invite-code/expired');
    }

    const memberRef = familyDoc.ref.collection('members').doc(request.auth.uid);
    const existingMember = await memberRef.get();
    if (existingMember.exists) {
      throw new HttpsError('already-exists', 'invite-code/already-member');
    }

    await memberRef.set({
      name: userName,
      role: 'parent',
      age: 30,
      accentColor: '#A8D8EA',
      avatarUrl: 'avatar_bear',
      userId: request.auth.uid,
      points: 0,
      currentStreak: 0,
      longestStreak: 0,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      familyId: familyDoc.id,
      familyName: familyData.name as string,
    };
  },
);
