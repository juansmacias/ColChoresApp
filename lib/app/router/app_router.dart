import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

import '../../features/auth/domain/repositories/onboarding_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import 'route_names.dart';

@singleton
class AppRouter {
  AppRouter(
    AuthBloc authBloc,
    OnboardingRepository onboardingRepository,
  ) : router = GoRouter(
          initialLocation: RouteNames.splash,
          debugLogDiagnostics: true,
          refreshListenable: GoRouterRefreshStream(authBloc.stream),
          redirect: (context, state) => _redirect(
            state,
            authBloc.state,
            onboardingRepository,
          ),
          routes: [
            GoRoute(
              path: RouteNames.splash,
              builder: (context, state) => const SplashScreen(),
            ),
            GoRoute(
              path: RouteNames.onboarding,
              builder: (context, state) => const OnboardingScreen(),
            ),
            GoRoute(
              path: RouteNames.signIn,
              builder: (context, state) => const SignInScreen(),
            ),
            GoRoute(
              path: RouteNames.signUp,
              builder: (context, state) => const SignUpScreen(),
            ),
            GoRoute(
              path: RouteNames.home,
              builder: (context, state) =>
                  const _PlaceholderScreen(title: 'Home'),
            ),
            GoRoute(
              path: RouteNames.familySetup,
              builder: (context, state) =>
                  const _PlaceholderScreen(title: 'Family Setup'),
            ),
            GoRoute(
              path: RouteNames.taskList,
              builder: (context, state) =>
                  const _PlaceholderScreen(title: 'Tasks'),
            ),
          ],
        );

  final GoRouter router;
}

String? _redirect(
  GoRouterState state,
  AuthState authState,
  OnboardingRepository onboardingRepository,
) {
  final location = state.matchedLocation;
  const publicRoutes = {
    RouteNames.splash,
    RouteNames.onboarding,
    RouteNames.signIn,
    RouteNames.signUp,
  };

  if (authState is AuthInitial || authState is AuthLoading) {
    return location == RouteNames.splash ? null : RouteNames.splash;
  }

  if (authState is AuthUnauthenticated) {
    if (!onboardingRepository.hasSeenOnboarding &&
        location != RouteNames.onboarding) {
      return RouteNames.onboarding;
    }

    if (publicRoutes.contains(location)) {
      return null;
    }

    return RouteNames.signIn;
  }

  if (publicRoutes.contains(location)) {
    return RouteNames.familySetup;
  }

  return null;
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title — coming soon')),
    );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<Object?> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (_) => notifyListeners(),
        );
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
