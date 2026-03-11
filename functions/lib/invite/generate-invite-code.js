"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateInviteCode = void 0;
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
const invite_utils_1 = require("./invite-utils");
exports.generateInviteCode = (0, https_1.onCall)({ region: 'us-central1' }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'Must be signed in.');
    }
    const familyId = request.data.familyId;
    if (!familyId || typeof familyId !== 'string') {
        throw new https_1.HttpsError('invalid-argument', 'familyId is required.');
    }
    const db = (0, firestore_1.getFirestore)();
    const familyRef = db.collection('families').doc(familyId);
    const familyDoc = await familyRef.get();
    if (!familyDoc.exists) {
        throw new https_1.HttpsError('not-found', 'Family not found.');
    }
    const memberDoc = await familyRef
        .collection('members')
        .doc(request.auth.uid)
        .get();
    if (!memberDoc.exists || memberDoc.data()?.role !== 'parent') {
        throw new https_1.HttpsError('permission-denied', 'Only parents can generate invite codes.');
    }
    const inviteCode = (0, invite_utils_1.generateCode)();
    const expiresAt = (0, invite_utils_1.getExpiryTimestamp)();
    await familyRef.update({
        inviteCode,
        inviteCodeExpiresAt: expiresAt,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    return {
        inviteCode,
        shareableUrl: `https://familychores.app/join?code=${inviteCode}`,
        expiresAt: expiresAt.toDate().toISOString(),
    };
});
//# sourceMappingURL=generate-invite-code.js.map