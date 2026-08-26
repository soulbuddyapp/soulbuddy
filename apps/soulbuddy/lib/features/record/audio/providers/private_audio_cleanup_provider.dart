import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../prayers/providers/voice_tablet_providers.dart';
import '../application/memory_audio_orphan_cleanup.dart';
import 'memory_audio_providers.dart';

/// Cleans only audio that is not referenced by any private-audio feature.
final privateAudioStartupCleanupProvider = FutureProvider<void>((ref) async {
  final memoryAudio = await ref.watch(memoryAudioRepositoryProvider.future);
  final voiceTablets = await ref.watch(voiceTabletRepositoryProvider.future);
  final assetStore = await ref.watch(audioAssetStoreProvider.future);
  await MemoryAudioOrphanCleanup(
    ownedStorageKeyLoaders: [
      memoryAudio.ownedStorageKeys,
      voiceTablets.ownedStorageKeys,
    ],
    assetStore: assetStore,
  ).run();
});
