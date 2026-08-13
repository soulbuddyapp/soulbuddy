import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database_provider.dart';
import '../../../../core/identity/local_identity_providers.dart';
import '../application/memory_audio_orphan_cleanup.dart';
import '../data/audio_asset_store.dart';
import '../data/audio_asset_store_factory.dart';
import '../data/memory_audio_repository.dart';
import '../data/powersync_memory_audio_repository.dart';

final audioAssetStoreProvider = FutureProvider<AudioAssetStore>((ref) async {
  return createAudioAssetStore();
});

final memoryAudioRepositoryProvider = FutureProvider<MemoryAudioRepository>((
  ref,
) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  return PowerSyncMemoryAudioRepository(
    database: database.powersync,
    ownerId: identity.ownerId,
  );
});

final memoryAudioStartupCleanupProvider = FutureProvider<void>((ref) async {
  final repository = await ref.watch(memoryAudioRepositoryProvider.future);
  final assetStore = await ref.watch(audioAssetStoreProvider.future);
  await MemoryAudioOrphanCleanup(
    repository: repository,
    assetStore: assetStore,
  ).run();
});
