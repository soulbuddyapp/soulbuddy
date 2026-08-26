import '../data/audio_asset_store.dart';

class MemoryAudioOrphanCleanup {
  MemoryAudioOrphanCleanup({
    required Iterable<Future<Set<String>> Function()> ownedStorageKeyLoaders,
    required AudioAssetStore assetStore,
    DateTime Function()? now,
  }) : _ownedStorageKeyLoaders = List.unmodifiable(ownedStorageKeyLoaders),
       _assetStore = assetStore,
       _now = now ?? DateTime.now;

  final List<Future<Set<String>> Function()> _ownedStorageKeyLoaders;
  final AudioAssetStore _assetStore;
  final DateTime Function() _now;

  Future<void> run() async {
    try {
      final referencedKeys = <String>{};
      for (final load in _ownedStorageKeyLoaders) {
        referencedKeys.addAll(await load());
      }
      await _assetStore.cleanup(
        referencedKeys,
        olderThan: _now().subtract(const Duration(hours: 24)),
      );
    } catch (_) {
      // Cleanup is retried at the next startup. Never log private storage keys.
    }
  }
}
