export interface GenerateInviteCodeRequest {
  familyId: string;
}

export interface ValidateAndJoinFamilyRequest {
  inviteCode: string;
  userId: string;
  userName: string;
}
