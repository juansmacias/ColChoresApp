import '../../../../core/error/failures.dart';

sealed class AuthenticationFailure extends AuthFailure {
  const AuthenticationFailure({
    required super.message,
    super.code,
    super.stackTrace,
  });
}

final class InvalidCredentialsFailure extends AuthenticationFailure {
  const InvalidCredentialsFailure({
    super.message = 'Invalid email or password.',
    super.code = 'invalid-credentials',
    super.stackTrace,
  });
}

final class EmailAlreadyInUseFailure extends AuthenticationFailure {
  const EmailAlreadyInUseFailure({
    super.message = 'This email is already in use.',
    super.code = 'email-already-in-use',
    super.stackTrace,
  });
}

final class WeakPasswordFailure extends AuthenticationFailure {
  const WeakPasswordFailure({
    super.message = 'The password is too weak.',
    super.code = 'weak-password',
    super.stackTrace,
  });
}

final class InvalidEmailFailure extends AuthenticationFailure {
  const InvalidEmailFailure({
    super.message = 'The email address is invalid.',
    super.code = 'invalid-email',
    super.stackTrace,
  });
}

final class CancelledAuthenticationFailure extends AuthenticationFailure {
  const CancelledAuthenticationFailure({
    super.message = 'The sign-in flow was cancelled.',
    super.code = 'cancelled',
    super.stackTrace,
  });
}

final class NetworkAuthenticationFailure extends AuthenticationFailure {
  const NetworkAuthenticationFailure({
    super.message = 'No internet connection.',
    super.code = 'network-request-failed',
    super.stackTrace,
  });
}

final class UnexpectedAuthenticationFailure extends AuthenticationFailure {
  const UnexpectedAuthenticationFailure({
    super.message = 'Something went wrong. Please try again.',
    super.code = 'unexpected',
    super.stackTrace,
  });
}
