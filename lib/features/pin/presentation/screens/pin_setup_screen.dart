import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../family/presentation/bloc/active_profile_cubit.dart';
import '../../../family/domain/repositories/member_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../presentation/bloc/pin_cubit.dart';
import '../../../../app/di/injection.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthBloc>().state.userOrNull;

    return BlocListener<PinCubit, PinState>(
      listener: (context, state) async {
        if (state is PinSet) {
          if (authUser != null) {
            final result = await getIt<MemberRepository>().getMemberForUser(
              authUser.uid,
            );
            await result.when(
              success: (member) async {
                if (member != null) {
                  await context
                      .read<ActiveProfileCubit>()
                      .switchProfile(member);
                }
              },
              failure: (_) async {},
            );
          }
          if (context.mounted) {
            context.go(RouteNames.profileSwitcher);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Set Up PIN')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New PIN'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm PIN'),
              ),
              const SizedBox(height: 24),
              BlocBuilder<PinCubit, PinState>(
                builder: (context, state) {
                  String? helper;
                  if (state is PinSetupError) {
                    helper = state.message;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (helper != null) ...[
                        Text(helper),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (authUser == null) {
                              return;
                            }
                            final memberResult = await getIt<MemberRepository>()
                                .getMemberForUser(authUser.uid);
                            memberResult.when(
                              success: (member) {
                                if (member == null) {
                                  return;
                                }
                                context.read<PinCubit>().setPin(
                                      memberId: member.id,
                                      pin: _pinController.text,
                                      confirmPin: _confirmController.text,
                                    );
                              },
                              failure: (_) {},
                            );
                          },
                          child: const Text('Save PIN'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
