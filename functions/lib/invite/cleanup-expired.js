"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanupExpiredInviteCodes = void 0;
const firestore_1 = require("firebase-admin/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
exports.cleanupExpiredInviteCodes = (0, scheduler_1.onSchedule)({
    schedule: '0 3 * * *',
    region: 'us-central1',
    timeZone: 'UTC',
}, async () => {
    const db = (0, firestore_1.getFirestore)();
    const now = new Date();
    const families = await db
        .collection('families')
        .where('inviteCodeExpiresAt', '<=', now)
        .get();
    await Promise.all(families.docs.map((doc) => doc.ref.update({
        inviteCode: firestore_1.FieldValue.delete(),
        inviteCodeExpiresAt: firestore_1.FieldValue.delete(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    })));
});
//# sourceMappingURL=cleanup-expired.js.map