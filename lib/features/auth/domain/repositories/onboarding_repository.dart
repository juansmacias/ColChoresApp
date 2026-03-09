abstract class OnboardingRepository {
  bool get hasSeenOnboarding;

  Future<void> markOnboardingSeen();
}
