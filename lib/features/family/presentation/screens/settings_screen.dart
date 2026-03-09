import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/member.dart';
import '../../domain/repositories/member_repository.dart';
import '../bloc/family_bloc.dart';
import '../../../../app/di/injection.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final family = context.watch<FamilyBloc>().state.familyOrNull;

    if (family == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<List<Member>>(
      stream: getIt<MemberRepository>().watchMembersForFamily(family.syncId),
      builder: (context, snapshot) {
        final members = snapshot.data ?? const <Member>[];

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView.separated(
            itemCount: members.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final member = members[index];
              return ListTile(
                title: Text(member.name),
                subtitle: Text('${member.role.name} · Age ${member.age}'),
                trailing: member.hasPin
                    ? const Icon(Icons.lock_outline)
                    : const Icon(Icons.chevron_right),
              );
            },
          ),
        );
      },
    );
  }
}
