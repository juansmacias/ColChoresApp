import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/failures/auth_failures.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remoteDataSource);

  final AuthRemoteDataSource _remoteDataSource;

  @override
  Stream<AppUser?> get currentUser => _remoteDataSource.currentUser;

  @override
  AppUser? get currentUserSync => _remoteDataSource.currentUserSync;

  @override
  Future<Result<AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _wrapAuthCall(
      () => _remoteDataSource.signInWithEmail(
        email: email,
        password: password,
      ),
    );
  }

  @override
  Future<Result<AppUser>> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return _wrapAuthCall(
      () => _remoteDataSource.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
  }

  @override
  Future<Result<AppUser>> signInWithGoogle() =>
      _wrapAuthCall(_remoteDataSource.signInWithGoogle);

  @override
  Future<Result<void>> signOut() async {
    try {
      await _remoteDataSource.signOut();
      return const Result.success(null);
    } on FirebaseAuthException catch (error, stackTrace) {
      return Result.failure(_mapAuthException(error, stackTrace));
    } catch (error, stackTrace) {
      return Result.failure(
        UnexpectedAuthenticationFailure(
          stackTrace: stackTrace,
          message: 'Unable to sign out right now. Please try again.',
        ),
      );
    }
  }

  Future<Result<AppUser>> _wrapAuthCall(
    Future<AppUser> Function() action,
  ) async {
    try {
      final user = await action();
      return Result.success(user);
    } on FirebaseAuthException catch (error, stackTrace) {
      return Result.failure(_mapAuthException(error, stackTrace));
    } catch (error, stackTrace) {
      return Result.failure(
        UnexpectedAuthenticationFailure(stackTrace: stackTrace),
      );
    }
  }

  AuthenticationFailure _mapAuthException(
    FirebaseAuthException error,
    StackTrace stackTrace,
  ) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return InvalidCredentialsFailure(stackTrace: stackTrace);
      case 'email-already-in-use':
        return EmailAlreadyInUseFailure(stackTrace: stackTrace);
      case 'weak-password':
        return WeakPasswordFailure(stackTrace: stackTrace);
      case 'invalid-email':
        return InvalidEmailFailure(stackTrace: stackTrace);
      case 'network-request-failed':
        return NetworkAuthenticationFailure(stackTrace: stackTrace);
      case 'cancelled':
      case 'web-context-cancelled':
      case 'popup-closed-by-user':
        return CancelledAuthenticationFailure(stackTrace: stackTrace);
      default:
        return UnexpectedAuthenticationFailure(
          code: error.code,
          stackTrace: stackTrace,
          message: error.message ?? 'Something went wrong. Please try again.',
        );
    }
  }
}
