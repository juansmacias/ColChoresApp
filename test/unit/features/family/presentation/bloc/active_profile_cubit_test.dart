import 'package:bloc_test/bloc_test.dart';
import 'package:family_chores_app/core/enums/member_role.dart';
import 'package:family_chores_app/core/utils/result.dart';
import 'package:family_chores_app/features/family/domain/entities/member.dart';
import 'package:family_chores_app/features/family/domain/repositories/member_repository.dart';
import 'package:family_chores_app/features/family/presentation/bloc/active_profile_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockMemberRepository extends Mock implements MemberRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late MockMemberRepository repository;

  final alex = Member(
    id: '7',
    familyId: 'family-1',
    name: 'Alex',
    role: MemberRole.child,
    age: 10,
    avatarSeed: 'avatar_fox',
    accentColor: '#A8D8EA',
    createdAt: DateTime(2026, 3, 9),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    repository = MockMemberRepository();
  });

  blocTest<ActiveProfileCubit, Member?>(
    'loads persisted active profile from preferences',
    build: () {
      preferences.setString('active_profile_id', alex.id);
      when(() => repository.getMember(alex.id))
          .thenAnswer((_) async => Result.success(alex));
      return ActiveProfileCubit(preferences, repository);
    },
    act: (cubit) => cubit.loadActiveProfile(),
    expect: () => [alex],
  );

  blocTest<ActiveProfileCubit, Member?>(
    'switchProfile persists the member id and emits the member',
    build: () => ActiveProfileCubit(preferences, repository),
    act: (cubit) => cubit.switchProfile(alex),
    expect: () => [alex],
    verify: (_) {
      expect(preferences.getString('active_profile_id'), alex.id);
    },
  );
}
