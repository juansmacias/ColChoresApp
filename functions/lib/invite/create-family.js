"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createFamily = void 0;
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
exports.createFamily = (0, https_1.onCall)({ region: 'us-central1' }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'Must be signed in.');
    }
    const name = request.data.name;
    const createdByName = request.data.createdByName;
    if (!name || typeof name !== 'string') {
        throw new https_1.HttpsError('invalid-argument', 'name is required.');
    }
    if (!createdByName || typeof createdByName !== 'string') {
        throw new https_1.HttpsError('invalid-argument', 'createdByName is required.');
    }
    const trimmedName = name.trim();
    const trimmedCreatedByName = createdByName.trim();
    if (trimmedName.length == 0) {
        throw new https_1.HttpsError('invalid-argument', 'name is required.');
    }
    if (trimmedCreatedByName.length == 0) {
        throw new https_1.HttpsError('invalid-argument', 'createdByName is required.');
    }
    const db = (0, firestore_1.getFirestore)();
    const familyRef = db.collection('families').doc();
    await db.runTransaction(async (transaction) => {
        transaction.set(familyRef, {
            name: trimmedName,
            createdBy: request.auth.uid,
            createdAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
        transaction.set(familyRef.collection('members').doc(request.auth.uid), {
            name: trimmedCreatedByName,
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
    });
    return {
        familyId: familyRef.id,
        familyName: trimmedName,
    };
});
//# sourceMappingURL=create-family.js.map