import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/family_bloc.dart';

class CreateFamilyScreen extends StatefulWidget {
  const CreateFamilyScreen({super.key});

  @override
  State<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends State<CreateFamilyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

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
        if (state is FamilyCreated) {
          context.go('/family-setup/add-member');
        }
        if (state is FamilyError) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.failure.message)));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Create Family')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _controller,
                  decoration: const InputDecoration(labelText: 'Family name'),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.length < 2) {
                      return 'Use at least 2 characters';
                    }
                    if (trimmed.length > 50) {
                      return 'Use 50 characters or fewer';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!_formKey.currentState!.validate() ||
                          authUser == null) {
                        return;
                      }

                      context.read<FamilyBloc>().add(
                            CreateFamilyRequested(
                              name: _controller.text.trim(),
                              createdByUid: authUser.uid,
                              createdByName:
                                  authUser.displayName ?? authUser.email,
                            ),
                          );
                    },
                    child: const Text('Create Family'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
