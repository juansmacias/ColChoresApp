"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateCode = generateCode;
exports.getExpiryTimestamp = getExpiryTimestamp;
exports.normalizeCode = normalizeCode;
const firestore_1 = require("firebase-admin/firestore");
const node_crypto_1 = require("node:crypto");
const INVITE_CODE_ALPHABET = 'ABCDEFGHJKMNPQRTUVWXYZ2346789';
const INVITE_CODE_LENGTH = 6;
const INVITE_CODE_EXPIRY_HOURS = 48;
function generateCode() {
    let code = '';
    for (let index = 0; index < INVITE_CODE_LENGTH; index += 1) {
        code += INVITE_CODE_ALPHABET[(0, node_crypto_1.randomInt)(INVITE_CODE_ALPHABET.length)];
    }
    return code;
}
function getExpiryTimestamp() {
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + INVITE_CODE_EXPIRY_HOURS);
    return firestore_1.Timestamp.fromDate(expiresAt);
}
function normalizeCode(code) {
    return code.trim().toUpperCase();
}
//# sourceMappingURL=invite-utils.js.map