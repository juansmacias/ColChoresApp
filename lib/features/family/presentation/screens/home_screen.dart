import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../bloc/active_profile_cubit.dart';
import '../bloc/family_bloc.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final family = context.select((FamilyBloc bloc) => bloc.state.familyOrNull);
    final profile = context.watch<ActiveProfileCubit>().state;

    return Scaffold(
      appBar: AppBar(
        title: Text(family?.name ?? 'Family Chores'),
        actions: [
          IconButton(
            onPressed: () => context.go(RouteNames.profileSwitcher),
            icon: const Icon(Icons.switch_account_rounded),
          ),
          IconButton(
            onPressed: () => context.go(RouteNames.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active profile',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Text(
              profile?.name ?? 'No profile selected',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              profile == null
                  ? 'Choose who is using this device.'
                  : 'Role: ${profile.role.name} · Age ${profile.age}',
            ),
          ],
        ),
      ),
    );
  }
}
