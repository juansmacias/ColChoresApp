part of 'family_bloc.dart';

sealed class FamilyEvent extends Equatable {
  const FamilyEvent();

  @override
  List<Object?> get props => [];
}

final class FamilyCheckRequested extends FamilyEvent {
  const FamilyCheckRequested(this.uid);

  final String uid;

  @override
  List<Object?> get props => [uid];
}

final class CreateFamilyRequested extends FamilyEvent {
  const CreateFamilyRequested({
    required this.name,
    required this.createdByUid,
    required this.createdByName,
  });

  final String name;
  final String createdByUid;
  final String createdByName;

  @override
  List<Object?> get props => [name, createdByUid, createdByName];
}

final class JoinFamilyRequested extends FamilyEvent {
  const JoinFamilyRequested({
    required this.inviteCode,
    required this.userId,
    required this.userName,
  });

  final String inviteCode;
  final String userId;
  final String userName;

  @override
  List<Object?> get props => [inviteCode, userId, userName];
}

final class GenerateInviteCodeRequested extends FamilyEvent {
  const GenerateInviteCodeRequested(this.familyId);

  final String familyId;

  @override
  List<Object?> get props => [familyId];
}

final class FamilyHydrated extends FamilyEvent {
  const FamilyHydrated(this.family);

  final Family family;

  @override
  List<Object?> get props => [family];
}

final class FamilyCleared extends FamilyEvent {
  const FamilyCleared();
}
