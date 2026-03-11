import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/route_names.dart';
import '../../domain/repositories/family_repository.dart';
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
            onPressed: family == null
                ? null
                : () => _shareInviteCode(
                      context,
                      family.syncId,
                    ),
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            onPressed: () => context.push(RouteNames.profileSwitcher),
            icon: const Icon(Icons.switch_account_rounded),
          ),
          IconButton(
            onPressed: () => context.push(RouteNames.settings),
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

  Future<void> _shareInviteCode(
    BuildContext context,
    String familyId,
  ) async {
    final result = await getIt<FamilyRepository>().generateInviteCode(familyId);
    await result.when(
      success: (inviteCode) async {
        await SharePlus.instance.share(
          ShareParams(
            text: 'Join our family on Family Chores: '
                'https://familychores.app/join?code=$inviteCode',
          ),
        );
      },
      failure: (failure) async {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }
}
