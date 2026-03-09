import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';

export const cleanupExpiredInviteCodes = onSchedule(
  {
    schedule: '0 3 * * *',
    region: 'us-central1',
    timeZone: 'UTC',
  },
  async () => {
    const db = getFirestore();
    const now = new Date();
    const families = await db
      .collection('families')
      .where('inviteCodeExpiresAt', '<=', now)
      .get();

    await Promise.all(
      families.docs.map((doc) =>
        doc.ref.update({
          inviteCode: FieldValue.delete(),
          inviteCodeExpiresAt: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        }),
      ),
    );
  },
);
