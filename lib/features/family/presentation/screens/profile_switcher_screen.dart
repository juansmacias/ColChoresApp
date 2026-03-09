import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../shared/theme/member_colors.dart';
import '../bloc/active_profile_cubit.dart';
import '../bloc/family_bloc.dart';
import '../../domain/entities/member.dart';
import '../../domain/repositories/member_repository.dart';
import '../../../../app/di/injection.dart';

class ProfileSwitcherScreen extends StatelessWidget {
  const ProfileSwitcherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final family = context.watch<FamilyBloc>().state.familyOrNull;
    final activeProfile = context.watch<ActiveProfileCubit>().state;

    if (family == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<List<Member>>(
      stream: getIt<MemberRepository>().watchMembersForFamily(family.syncId),
      builder: (context, snapshot) {
        final members = snapshot.data ?? const <Member>[];

        return Scaffold(
          appBar: AppBar(title: const Text('Who is using the app?')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                ...members.map(
                  (member) => _ProfileCard(
                    member: member,
                    isActive: activeProfile?.id == member.id,
                    onTap: () async {
                      if (member.isParent && member.hasPin) {
                        context
                            .go('${RouteNames.pinEntry}?memberId=${member.id}');
                        return;
                      }

                      await context
                          .read<ActiveProfileCubit>()
                          .switchProfile(member);
                      if (context.mounted) {
                        context.go(RouteNames.home);
                      }
                    },
                  ),
                ),
                _AddMemberCard(
                  onTap: () => context.go(RouteNames.addMember),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.member,
    required this.isActive,
    required this.onTap,
  });

  final Member member;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = MemberColors.palette
        .firstWhere(
          (entry) => entry.hex == member.accentColor,
          orElse: () => MemberColors.palette.first,
        )
        .color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: color,
                child: Text(
                  member.name.characters.first.toUpperCase(),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 12),
              Text(member.name, style: Theme.of(context).textTheme.titleMedium),
              Text(member.role.name),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddMemberCard extends StatelessWidget {
  const _AddMemberCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline_rounded, size: 32),
          SizedBox(height: 12),
          Text('Add Member'),
        ],
      ),
    );
  }
}
