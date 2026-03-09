part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

final class AuthCurrentUserChanged extends AuthEvent {
  const AuthCurrentUserChanged(this.user);

  final AppUser? user;

  @override
  List<Object?> get props => [user];
}

final class SignInWithEmailRequested extends AuthEvent {
  const SignInWithEmailRequested({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

final class SignUpWithEmailRequested extends AuthEvent {
  const SignUpWithEmailRequested({
    required this.displayName,
    required this.email,
    required this.password,
  });

  final String displayName;
  final String email;
  final String password;

  @override
  List<Object?> get props => [displayName, email, password];
}

final class SignInWithGoogleRequested extends AuthEvent {
  const SignInWithGoogleRequested();
}

final class SignOutRequested extends AuthEvent {
  const SignOutRequested();
}
