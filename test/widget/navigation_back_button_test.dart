import 'package:bloc_test/bloc_test.dart';
import 'package:family_chores_app/app/router/route_names.dart';
import 'package:family_chores_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:family_chores_app/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:family_chores_app/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  late MockAuthBloc authBloc;

  setUp(() {
    authBloc = MockAuthBloc();
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthUnauthenticated(),
    );
  });

  testWidgets('shows a back button after navigating from sign in to sign up',
      (tester) async {
    final router = GoRouter(
      initialLocation: RouteNames.signIn,
      routes: [
        GoRoute(
          path: RouteNames.signIn,
          builder: (context, state) => const SignInScreen(),
        ),
        GoRoute(
          path: RouteNames.signUp,
          builder: (context, state) => const SignUpScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(platform: TargetPlatform.iOS),
        ),
      ),
    );

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });
}
