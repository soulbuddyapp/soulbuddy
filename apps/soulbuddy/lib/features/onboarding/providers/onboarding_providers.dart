import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/local_identity_providers.dart';
import '../data/onboarding_repository.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return OnboardingRepository(
    read: (key) => storage.read(key: key),
    write: (key, value) => storage.write(key: key, value: value),
  );
});

final onboardingCompleteProvider = FutureProvider<bool>((ref) {
  return ref.watch(onboardingRepositoryProvider).isComplete();
});
