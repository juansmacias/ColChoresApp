import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/enums/member_role.dart';
import '../../../../shared/theme/member_colors.dart';
import '../../../../shared/utils/avatar_utils.dart';
import '../bloc/family_bloc.dart';
import '../../domain/repositories/member_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../app/di/injection.dart';

class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _avatarSeed = AvatarUtils.allSeeds.first;
  String _accentColor = MemberColors.palette.first.hex;
  MemberRole _role = MemberRole.child;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _addMember() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final family = context.read<FamilyBloc>().state.familyOrNull;
    if (family == null) {
      return;
    }

    final authUser = context.read<AuthBloc>().state.userOrNull;
    final result = await getIt<MemberRepository>().createMember(
      familyId: family.syncId,
      name: _nameController.text.trim(),
      age: int.parse(_ageController.text),
      role: _role,
      avatarSeed: _avatarSeed,
      accentColor: _accentColor,
      userId: _role == MemberRole.parent ? authUser?.uid : null,
    );

    result.when(
      success: (_) {
        _formKey.currentState!.reset();
        _nameController.clear();
        _ageController.clear();
        setState(() {
          _avatarSeed = AvatarUtils.allSeeds.first;
          _accentColor = MemberColors.palette.first.hex;
          _role = MemberRole.child;
        });
      },
      failure: (failure) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Members'),
        actions: [
          TextButton(
            onPressed: () => context.push(RouteNames.pinSetup),
            child: const Text('Continue'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter a name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age'),
                validator: (value) {
                  final age = int.tryParse(value ?? '');
                  if (age == null || age < 2 || age > 100) {
                    return 'Enter an age between 2 and 100';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SegmentedButton<MemberRole>(
                segments: const [
                  ButtonSegment(value: MemberRole.child, label: Text('Child')),
                  ButtonSegment(
                    value: MemberRole.parent,
                    label: Text('Parent'),
                  ),
                ],
                selected: {_role},
                onSelectionChanged: (selection) {
                  setState(() => _role = selection.first);
                },
              ),
              const SizedBox(height: 24),
              Text('Avatar', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AvatarUtils.allSeeds.map((seed) {
                  final isSelected = _avatarSeed == seed;
                  return ChoiceChip(
                    label: Text(AvatarUtils.getLabel(seed)),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _avatarSeed = seed),
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 24),
              Text(
                'Accent Color',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: MemberColors.palette.map((color) {
                  final isSelected = _accentColor == color.hex;
                  return GestureDetector(
                    onTap: () => setState(() => _accentColor = color.hex),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addMember,
                  child: const Text('Add Member'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
