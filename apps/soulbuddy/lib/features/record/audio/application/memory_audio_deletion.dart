import '../data/audio_asset_store.dart';
import '../data/memory_audio_repository.dart';

class MemoryAudioDeletion {
  const MemoryAudioDeletion({
    required MemoryAudioRepository repository,
    required AudioAssetStore assetStore,
  }) : _repository = repository,
       _assetStore = assetStore;

  final MemoryAudioRepository _repository;
  final AudioAssetStore _assetStore;

  Future<bool> deleteForEncounter(String encounterId) async {
    final storageKey = await _repository.deleteMetadata(encounterId);
    if (storageKey == null) return false;
    try {
      await _assetStore.delete(storageKey);
    } catch (_) {
      // The unreferenced asset is removed by startup orphan cleanup.
    }
    return true;
  }
}
