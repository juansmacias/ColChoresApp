part of 'family_bloc.dart';

sealed class FamilyState extends Equatable {
  const FamilyState();

  Family? get familyOrNull => null;

  @override
  List<Object?> get props => [familyOrNull];
}

final class FamilyInitial extends FamilyState {
  const FamilyInitial();
}

final class FamilyLoading extends FamilyState {
  const FamilyLoading();
}

final class FamilyNotFound extends FamilyState {
  const FamilyNotFound();
}

final class FamilyLoaded extends FamilyState {
  const FamilyLoaded(this.family);

  final Family family;

  @override
  Family get familyOrNull => family;
}

final class FamilyCreated extends FamilyState {
  const FamilyCreated(this.family);

  final Family family;

  @override
  Family get familyOrNull => family;
}

final class FamilyJoined extends FamilyState {
  const FamilyJoined(this.family);

  final Family family;

  @override
  Family get familyOrNull => family;
}

final class InviteCodeGenerated extends FamilyState {
  const InviteCodeGenerated(this.inviteCode);

  final String inviteCode;

  @override
  List<Object?> get props => [inviteCode];
}

final class FamilyError extends FamilyState {
  const FamilyError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
