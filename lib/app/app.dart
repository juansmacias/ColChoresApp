import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/family/presentation/bloc/active_profile_cubit.dart';
import '../features/family/presentation/bloc/family_bloc.dart';
import '../features/pin/presentation/bloc/pin_cubit.dart';
import '../shared/theme/app_theme.dart';
import 'di/injection.dart';
import 'router/app_router.dart';

class FamilyChoresApp extends StatelessWidget {
  const FamilyChoresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: getIt<AuthBloc>()),
        BlocProvider.value(value: getIt<FamilyBloc>()),
        BlocProvider.value(value: getIt<ActiveProfileCubit>()),
        BlocProvider.value(value: getIt<PinCubit>()),
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
