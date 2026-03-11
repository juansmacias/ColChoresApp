"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateAndJoinFamily = exports.generateInviteCode = exports.cleanupExpiredInviteCodes = exports.createFamily = void 0;
const app_1 = require("firebase-admin/app");
const create_family_1 = require("./invite/create-family");
Object.defineProperty(exports, "createFamily", { enumerable: true, get: function () { return create_family_1.createFamily; } });
const cleanup_expired_1 = require("./invite/cleanup-expired");
Object.defineProperty(exports, "cleanupExpiredInviteCodes", { enumerable: true, get: function () { return cleanup_expired_1.cleanupExpiredInviteCodes; } });
const generate_invite_code_1 = require("./invite/generate-invite-code");
Object.defineProperty(exports, "generateInviteCode", { enumerable: true, get: function () { return generate_invite_code_1.generateInviteCode; } });
const validate_and_join_1 = require("./invite/validate-and-join");
Object.defineProperty(exports, "validateAndJoinFamily", { enumerable: true, get: function () { return validate_and_join_1.validateAndJoinFamily; } });
(0, app_1.initializeApp)();
//# sourceMappingURL=index.js.map