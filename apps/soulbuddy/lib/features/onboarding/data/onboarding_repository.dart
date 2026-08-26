const onboardingCompleteStorageKey = 'soulbuddy.onboarding_complete';

typedef OnboardingValueReader = Future<String?> Function(String key);
typedef OnboardingValueWriter = Future<void> Function(String key, String value);

class OnboardingRepository {
  const OnboardingRepository({required this.read, required this.write});

  final OnboardingValueReader read;
  final OnboardingValueWriter write;

  Future<bool> isComplete() async {
    return await read(onboardingCompleteStorageKey) == '1';
  }

  Future<void> complete() {
    return write(onboardingCompleteStorageKey, '1');
  }
}
