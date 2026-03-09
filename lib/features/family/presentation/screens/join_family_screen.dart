import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../app/router/route_names.dart';
import '../bloc/family_bloc.dart';

class JoinFamilyScreen extends StatefulWidget {
  const JoinFamilyScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  State<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends State<JoinFamilyScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialCode ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = context.select((AuthBloc bloc) => bloc.state.userOrNull);

    return BlocListener<FamilyBloc, FamilyState>(
      listener: (context, state) {
        if (state is FamilyJoined) {
          context.go(RouteNames.profileSwitcher);
        }
        if (state is FamilyError) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.failure.message)));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Join Family')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Invite code',
                  hintText: 'ABC123',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final code = _controller.text.trim().toUpperCase();
                    if (authUser == null || code.length != 6) {
                      return;
                    }

                    context.read<FamilyBloc>().add(
                          JoinFamilyRequested(
                            inviteCode: code,
                            userId: authUser.uid,
                            userName: authUser.displayName ?? authUser.email,
                          ),
                        );
                  },
                  child: const Text('Join Family'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
