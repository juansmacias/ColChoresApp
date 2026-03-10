import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:family_chores_app/core/error/failures.dart';
import 'package:family_chores_app/core/utils/result.dart';
import 'package:family_chores_app/features/auth/domain/entities/app_user.dart';
import 'package:family_chores_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:family_chores_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository authRepository;
  late StreamController<AppUser?> authController;

  const user = AppUser(
    uid: 'uid-1',
    email: 'marcus@example.com',
    displayName: 'Marcus',
  );

  setUp(() {
    authRepository = MockAuthRepository();
    authController = StreamController<AppUser?>.broadcast();

    when(() => authRepository.currentUser)
        .thenAnswer((_) => authController.stream);
    when(() => authRepository.currentUserSync).thenReturn(null);
  });

  tearDown(() async {
    await authController.close();
  });

  blocTest<AuthBloc, AuthState>(
    'emits authenticated when auth stream provides a user',
    build: () => AuthBloc(authRepository),
    act: (_) => authController.add(user),
    expect: () => [
      const AuthUnauthenticated(),
      const AuthAuthenticated(user),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'emits authenticated immediately when a cached user exists',
    build: () {
      when(() => authRepository.currentUserSync).thenReturn(user);
      return AuthBloc(authRepository);
    },
    expect: () => [const AuthAuthenticated(user)],
  );

  blocTest<AuthBloc, AuthState>(
    'emits loading then unauthenticated with error on failed sign in',
    build: () {
      when(
        () => authRepository.signInWithEmail(
          email: 'marcus@example.com',
          password: 'bad-pass',
        ),
      ).thenAnswer(
        (_) async => const Result.failure(
          AuthFailure(message: 'Invalid email or password.'),
        ),
      );

      return AuthBloc(authRepository);
    },
    act: (bloc) => bloc.add(
      const SignInWithEmailRequested(
        email: 'marcus@example.com',
        password: 'bad-pass',
      ),
    ),
    expect: () => [
      const AuthUnauthenticated(),
      const AuthLoading(),
      const AuthUnauthenticated(errorMessage: 'Invalid email or password.'),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'emits loading then unauthenticated on sign out success',
    build: () {
      when(() => authRepository.signOut())
          .thenAnswer((_) async => const Result.success(null));
      return AuthBloc(authRepository);
    },
    act: (bloc) => bloc.add(const SignOutRequested()),
    expect: () => [
      const AuthUnauthenticated(),
      const AuthLoading(),
      const AuthUnauthenticated(),
    ],
  );
}
