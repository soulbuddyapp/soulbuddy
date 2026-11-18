import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../data/guide_repository.dart';

final guideRepositoryProvider = Provider<GuideRepository>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return GuideRepository(
    read: (key) => storage.read(key: key),
    write: (key, value) => storage.write(key: key, value: value),
  );
});
final guideNameProvider = FutureProvider<String?>(
  (ref) => ref.watch(guideRepositoryProvider).load(),
);
