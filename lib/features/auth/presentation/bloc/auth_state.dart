part of 'auth_bloc.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  AppUser? get userOrNull => null;

  String? get message => null;

  bool get isLoading => false;

  @override
  List<Object?> get props => [userOrNull, message, isLoading];
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  const AuthLoading();

  @override
  bool get isLoading => true;
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.errorMessage});

  final String? errorMessage;

  @override
  String? get message => errorMessage;

  @override
  List<Object?> get props => [errorMessage];
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final AppUser user;

  @override
  AppUser get userOrNull => user;

  @override
  List<Object?> get props => [user];
}
