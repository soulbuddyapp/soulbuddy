import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../audio/providers/memory_audio_providers.dart';
import '../data/encounter_repository.dart';
import '../data/powersync_encounter_repository.dart';
import '../domain/encounter.dart';

final encounterRepositoryProvider = FutureProvider<EncounterRepository>((
  ref,
) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  final audioAssetStore = await ref.watch(audioAssetStoreProvider.future);

  return PowerSyncEncounterRepository(
    database: database.powersync,
    ownerId: identity.ownerId,
    deviceId: identity.deviceId,
    audioAssetStore: audioAssetStore,
  );
});

final encountersProvider = StreamProvider<List<Encounter>>((ref) async* {
  final repository = await ref.watch(encounterRepositoryProvider.future);
  yield* repository.watchAll();
});

final altarEncountersProvider = Provider<AsyncValue<List<Encounter>>>((ref) {
  return ref.watch(encountersProvider).whenData((items) {
    final altars = items.where((item) => item.isAltar).toList(growable: false);
    altars.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return altars;
  });
});

final memoryReflectionsProvider = StreamProvider.autoDispose
    .family<List<MemoryReflection>, String>((ref, encounterId) async* {
      final repository = await ref.watch(encounterRepositoryProvider.future);
      yield* repository.watchReflections(encounterId);
    });
