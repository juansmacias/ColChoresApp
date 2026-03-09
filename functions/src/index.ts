import { initializeApp } from 'firebase-admin/app';

import { cleanupExpiredInviteCodes } from './invite/cleanup-expired';
import { generateInviteCode } from './invite/generate-invite-code';
import { validateAndJoinFamily } from './invite/validate-and-join';

initializeApp();

export {
  cleanupExpiredInviteCodes,
  generateInviteCode,
  validateAndJoinFamily,
};
