import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/onboarding/data/onboarding_repository.dart';

void main() {
  test('welcome is incomplete until completion is stored', () async {
    final values = <String, String>{};
    final repository = OnboardingRepository(
      read: (key) async => values[key],
      write: (key, value) async => values[key] = value,
    );

    expect(await repository.isComplete(), isFalse);

    await repository.complete();

    expect(values[onboardingCompleteStorageKey], '1');
    expect(await repository.isComplete(), isTrue);
  });
}
