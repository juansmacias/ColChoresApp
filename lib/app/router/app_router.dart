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
import '../../features/family/presentation/bloc/active_profile_cubit.dart';
import '../../features/family/presentation/bloc/family_bloc.dart';
import '../../features/family/presentation/screens/add_member_screen.dart';
import '../../features/family/presentation/screens/create_family_screen.dart';
import '../../features/family/presentation/screens/family_setup_screen.dart';
import '../../features/family/presentation/screens/home_screen.dart';
import '../../features/family/presentation/screens/join_family_screen.dart';
import '../../features/family/presentation/screens/profile_switcher_screen.dart';
import '../../features/family/presentation/screens/settings_screen.dart';
import '../../features/pin/presentation/bloc/pin_cubit.dart';
import '../../features/pin/presentation/screens/pin_entry_screen.dart';
import '../../features/pin/presentation/screens/pin_setup_screen.dart';
import 'route_names.dart';

@singleton
class AppRouter {
  AppRouter(
    AuthBloc authBloc,
    OnboardingRepository onboardingRepository,
    FamilyBloc familyBloc,
    ActiveProfileCubit activeProfileCubit,
    PinCubit pinCubit,
  ) : router = GoRouter(
          initialLocation: RouteNames.splash,
          debugLogDiagnostics: true,
          refreshListenable: GoRouterRefreshStream([
            authBloc.stream,
            familyBloc.stream,
            activeProfileCubit.stream,
            pinCubit.stream,
          ]),
          redirect: (context, state) => _redirect(
            state: state,
            authState: authBloc.state,
            onboardingRepository: onboardingRepository,
            familyState: familyBloc.state,
            hasActiveProfile: activeProfileCubit.state != null,
            activeProfileId: activeProfileCubit.state?.id,
            isParentProfile: activeProfileCubit.state?.isParent ?? false,
            isPinSessionActive: pinCubit.isSessionActive,
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
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: RouteNames.familySetup,
              builder: (context, state) => const FamilySetupScreen(),
            ),
            GoRoute(
              path: RouteNames.createFamily,
              builder: (context, state) => const CreateFamilyScreen(),
            ),
            GoRoute(
              path: RouteNames.joinFamily,
              builder: (context, state) => JoinFamilyScreen(
                initialCode: state.uri.queryParameters['code'],
              ),
            ),
            GoRoute(
              path: RouteNames.addMember,
              builder: (context, state) => const AddMemberScreen(),
            ),
            GoRoute(
              path: RouteNames.profileSwitcher,
              builder: (context, state) => const ProfileSwitcherScreen(),
            ),
            GoRoute(
              path: RouteNames.pinEntry,
              builder: (context, state) => PinEntryScreen(
                memberId: state.uri.queryParameters['memberId'] ?? '',
              ),
            ),
            GoRoute(
              path: RouteNames.pinSetup,
              builder: (context, state) => const PinSetupScreen(),
            ),
            GoRoute(
              path: RouteNames.settings,
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        );

  final GoRouter router;
}

String? _redirect({
  required GoRouterState state,
  required AuthState authState,
  required OnboardingRepository onboardingRepository,
  required FamilyState familyState,
  required bool hasActiveProfile,
  required String? activeProfileId,
  required bool isParentProfile,
  required bool isPinSessionActive,
}) {
  final location = state.matchedLocation;
  const publicRoutes = {
    RouteNames.splash,
    RouteNames.onboarding,
    RouteNames.signIn,
    RouteNames.signUp,
  };
  const familyRoutes = {
    RouteNames.familySetup,
    RouteNames.createFamily,
    RouteNames.joinFamily,
  };
  const profileRoutes = {
    RouteNames.profileSwitcher,
    RouteNames.addMember,
    RouteNames.pinSetup,
    RouteNames.pinEntry,
  };

  if (authState is AuthInitial || authState is AuthLoading) {
    return location == RouteNames.splash ? null : RouteNames.splash;
  }

  if (authState is AuthUnauthenticated) {
    if (!onboardingRepository.hasSeenOnboarding &&
        location != RouteNames.onboarding) {
      return RouteNames.onboarding;
    }
    return publicRoutes.contains(location) ? null : RouteNames.signIn;
  }

  if (familyState is FamilyInitial || familyState is FamilyLoading) {
    return location == RouteNames.splash ? null : RouteNames.splash;
  }

  if (familyState is FamilyNotFound) {
    return familyRoutes.contains(location) ? null : RouteNames.familySetup;
  }

  if ((familyState is FamilyLoaded ||
          familyState is FamilyCreated ||
          familyState is FamilyJoined) &&
      !hasActiveProfile &&
      !profileRoutes.contains(location)) {
    return RouteNames.profileSwitcher;
  }

  if (publicRoutes.contains(location) || familyRoutes.contains(location)) {
    return hasActiveProfile ? RouteNames.home : RouteNames.profileSwitcher;
  }

  if (location == RouteNames.settings &&
      isParentProfile &&
      !isPinSessionActive &&
      activeProfileId != null) {
    return '${RouteNames.pinEntry}?memberId=$activeProfileId';
  }

  return null;
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(List<Stream<Object?>> streams) {
    notifyListeners();
    _subscriptions = streams
        .map(
          (stream) =>
              stream.asBroadcastStream().listen((_) => notifyListeners()),
        )
        .toList(growable: false);
  }

  late final List<StreamSubscription<Object?>> _subscriptions;

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
