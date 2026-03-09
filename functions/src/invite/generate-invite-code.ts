import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { generateCode, getExpiryTimestamp } from './invite-utils';

export const generateInviteCode = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }

    const familyId = request.data.familyId;
    if (!familyId || typeof familyId !== 'string') {
      throw new HttpsError('invalid-argument', 'familyId is required.');
    }

    const db = getFirestore();
    const familyRef = db.collection('families').doc(familyId);
    const familyDoc = await familyRef.get();
    if (!familyDoc.exists) {
      throw new HttpsError('not-found', 'Family not found.');
    }

    const memberDoc = await familyRef
      .collection('members')
      .doc(request.auth.uid)
      .get();

    if (!memberDoc.exists || memberDoc.data()?.role !== 'parent') {
      throw new HttpsError(
        'permission-denied',
        'Only parents can generate invite codes.',
      );
    }

    const inviteCode = generateCode();
    const expiresAt = getExpiryTimestamp();

    await familyRef.update({
      inviteCode,
      inviteCodeExpiresAt: expiresAt,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      inviteCode,
      shareableUrl: `https://familychores.app/join?code=${inviteCode}`,
      expiresAt: expiresAt.toDate().toISOString(),
    };
  },
);
