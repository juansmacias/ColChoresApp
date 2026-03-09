import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_constants.dart';
import '../../domain/repositories/onboarding_repository.dart';

@LazySingleton(as: OnboardingRepository)
class OnboardingRepositoryImpl implements OnboardingRepository {
  OnboardingRepositoryImpl(this._sharedPreferences);

  final SharedPreferences _sharedPreferences;

  @override
  bool get hasSeenOnboarding =>
      _sharedPreferences.getBool(StorageConstants.hasSeenOnboardingKey) ??
      false;

  @override
  Future<void> markOnboardingSeen() async {
    await _sharedPreferences.setBool(
      StorageConstants.hasSeenOnboardingKey,
      true,
    );
  }
}
