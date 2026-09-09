import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/local_identity_providers.dart';
import '../data/formation_progress_repository.dart';

final formationProgressRepositoryProvider =
    Provider<FormationProgressRepository>((ref) {
      final storage = ref.watch(secureStorageProvider);
      return FormationProgressRepository(
        read: (key) => storage.read(key: key),
        write: (key, value) => storage.write(key: key, value: value),
      );
    });

final formationProgressProvider = FutureProvider<FormationProgress>((ref) {
  return ref.watch(formationProgressRepositoryProvider).load();
});
