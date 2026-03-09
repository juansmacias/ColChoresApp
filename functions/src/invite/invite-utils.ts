import { Timestamp } from 'firebase-admin/firestore';
import { randomInt } from 'node:crypto';

const INVITE_CODE_ALPHABET = 'ABCDEFGHJKMNPQRTUVWXYZ2346789';
const INVITE_CODE_LENGTH = 6;
const INVITE_CODE_EXPIRY_HOURS = 48;

export function generateCode(): string {
  let code = '';
  for (let index = 0; index < INVITE_CODE_LENGTH; index += 1) {
    code += INVITE_CODE_ALPHABET[randomInt(INVITE_CODE_ALPHABET.length)];
  }
  return code;
}

export function getExpiryTimestamp(): Timestamp {
  const expiresAt = new Date();
  expiresAt.setHours(expiresAt.getHours() + INVITE_CODE_EXPIRY_HOURS);
  return Timestamp.fromDate(expiresAt);
}

export function normalizeCode(code: string): string {
  return code.trim().toUpperCase();
}
