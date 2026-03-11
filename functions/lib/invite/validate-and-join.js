"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateAndJoinFamily = void 0;
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
const invite_utils_1 = require("./invite-utils");
exports.validateAndJoinFamily = (0, https_1.onCall)({ region: 'us-central1' }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'Must be signed in.');
    }
    const inviteCode = request.data.inviteCode;
    const userName = request.data.userName;
    if (!inviteCode || typeof inviteCode !== 'string') {
        throw new https_1.HttpsError('invalid-argument', 'inviteCode is required.');
    }
    if (!userName || typeof userName !== 'string') {
        throw new https_1.HttpsError('invalid-argument', 'userName is required.');
    }
    const db = (0, firestore_1.getFirestore)();
    const normalizedCode = (0, invite_utils_1.normalizeCode)(inviteCode);
    const families = await db
        .collection('families')
        .where('inviteCode', '==', normalizedCode)
        .limit(1)
        .get();
    if (families.empty) {
        throw new https_1.HttpsError('not-found', 'invite-code/not-found');
    }
    const familyDoc = families.docs[0];
    const familyData = familyDoc.data();
    const expiresAt = familyData.inviteCodeExpiresAt?.toDate?.();
    if (!expiresAt || expiresAt.getTime() < Date.now()) {
        throw new https_1.HttpsError('failed-precondition', 'invite-code/expired');
    }
    const memberRef = familyDoc.ref.collection('members').doc(request.auth.uid);
    const existingMember = await memberRef.get();
    if (existingMember.exists) {
        throw new https_1.HttpsError('already-exists', 'invite-code/already-member');
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
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    return {
        familyId: familyDoc.id,
        familyName: familyData.name,
    };
});
//# sourceMappingURL=validate-and-join.js.map