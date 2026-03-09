import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../family/domain/repositories/member_repository.dart';
import '../../../family/presentation/bloc/active_profile_cubit.dart';
import '../../presentation/bloc/pin_cubit.dart';
import '../../../../app/di/injection.dart';

class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({
    super.key,
    required this.memberId,
  });

  final String memberId;

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PinCubit, PinState>(
      listener: (context, state) async {
        if (state is PinVerified) {
          final result =
              await getIt<MemberRepository>().getMember(widget.memberId);
          final member = result.valueOrNull;
          if (!context.mounted) {
            return;
          }
          if (member != null) {
            await context.read<ActiveProfileCubit>().switchProfile(member);
            if (context.mounted) {
              context.go(RouteNames.home);
            }
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Enter PIN')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'PIN'),
              ),
              const SizedBox(height: 24),
              BlocBuilder<PinCubit, PinState>(
                builder: (context, state) {
                  var helper = 'Enter the parent PIN.';
                  if (state is PinFailed) {
                    helper = '${state.attemptsRemaining} attempts remaining.';
                  } else if (state is PinLocked) {
                    helper = 'Too many attempts. Try again later.';
                  } else if (state is PinSetupError) {
                    helper = state.message;
                  }

                  return Column(
                    children: [
                      Text(helper),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.read<PinCubit>().verifyPin(
                                memberId: widget.memberId,
                                pin: _controller.text,
                              ),
                          child: const Text('Verify PIN'),
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
