import 'package:family_chores_app/core/constants/storage_constants.dart';
import 'package:family_chores_app/features/auth/data/repositories/onboarding_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns false when onboarding has not been seen', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = OnboardingRepositoryImpl(preferences);

    expect(repository.hasSeenOnboarding, isFalse);
  });

  test('persists onboarding completion', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = OnboardingRepositoryImpl(preferences);

    await repository.markOnboardingSeen();

    expect(repository.hasSeenOnboarding, isTrue);
    expect(
      preferences.getBool(StorageConstants.hasSeenOnboardingKey),
      isTrue,
    );
  });
}
