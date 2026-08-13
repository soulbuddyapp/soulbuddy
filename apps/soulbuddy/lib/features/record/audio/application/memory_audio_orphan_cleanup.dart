import '../data/audio_asset_store.dart';
import '../data/memory_audio_repository.dart';

class MemoryAudioOrphanCleanup {
  MemoryAudioOrphanCleanup({
    required MemoryAudioRepository repository,
    required AudioAssetStore assetStore,
    DateTime Function()? now,
  }) : _repository = repository,
       _assetStore = assetStore,
       _now = now ?? DateTime.now;

  final MemoryAudioRepository _repository;
  final AudioAssetStore _assetStore;
  final DateTime Function() _now;

  Future<void> run() async {
    try {
      final referencedKeys = await _repository.ownedStorageKeys();
      await _assetStore.cleanup(
        referencedKeys,
        olderThan: _now().subtract(const Duration(hours: 24)),
      );
    } catch (_) {
      // Cleanup is retried at the next startup. Never log private storage keys.
    }
  }
}
