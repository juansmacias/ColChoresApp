import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/deep_links/deep_link_redirect_cubit.dart';
import '../core/deep_links/deep_link_service.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/family/presentation/bloc/active_profile_cubit.dart';
import '../features/family/presentation/bloc/family_bloc.dart';
import '../features/pin/presentation/bloc/pin_cubit.dart';
import '../shared/theme/app_theme.dart';
import 'di/injection.dart';
import 'router/app_router.dart';

class FamilyChoresApp extends StatefulWidget {
  const FamilyChoresApp({super.key});

  @override
  State<FamilyChoresApp> createState() => _FamilyChoresAppState();
}

class _FamilyChoresAppState extends State<FamilyChoresApp> {
  StreamSubscription<Uri>? _deepLinkSubscription;

  @override
  void initState() {
    super.initState();
    _bootstrapNavigationState();
    _initializeDeepLinks();
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeDeepLinks() async {
    final deepLinkService = getIt<DeepLinkService>();
    final redirectCubit = getIt<DeepLinkRedirectCubit>();

    final initialUri = await deepLinkService.getInitialUri();
    if (initialUri != null) {
      redirectCubit.setPendingLink(initialUri);
    }

    _deepLinkSubscription = deepLinkService.incomingUris.listen(
      redirectCubit.setPendingLink,
    );
  }

  void _bootstrapNavigationState() {
    final authBloc = getIt<AuthBloc>();
    final familyBloc = getIt<FamilyBloc>();
    final activeProfileCubit = getIt<ActiveProfileCubit>();

    final authState = authBloc.state;
    if (authState is AuthAuthenticated && familyBloc.state is FamilyInitial) {
      familyBloc.add(FamilyCheckRequested(authState.user.uid));
    }

    final familyState = familyBloc.state;
    if (familyState is FamilyLoaded ||
        familyState is FamilyCreated ||
        familyState is FamilyJoined) {
      unawaited(activeProfileCubit.loadActiveProfile());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: getIt<AuthBloc>()),
        BlocProvider.value(value: getIt<FamilyBloc>()),
        BlocProvider.value(value: getIt<ActiveProfileCubit>()),
        BlocProvider.value(value: getIt<PinCubit>()),
        BlocProvider.value(value: getIt<DeepLinkRedirectCubit>()),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthAuthenticated) {
                context.read<FamilyBloc>().add(
                      FamilyCheckRequested(state.user.uid),
                    );
              } else if (state is AuthUnauthenticated) {
                context.read<FamilyBloc>().add(const FamilyCleared());
                context.read<ActiveProfileCubit>().clearProfile();
              }
            },
          ),
          BlocListener<FamilyBloc, FamilyState>(
            listener: (context, state) {
              if (state is FamilyLoaded ||
                  state is FamilyCreated ||
                  state is FamilyJoined) {
                context.read<ActiveProfileCubit>().loadActiveProfile();
              }
            },
          ),
        ],
        child: MaterialApp.router(
          title: 'Family Chores',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          routerConfig: getIt<AppRouter>().router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
