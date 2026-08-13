import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/record/audio/application/memory_audio_orphan_cleanup.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/data/memory_audio_repository.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';

void main() {
  test(
    'keeps referenced audio and removes only assets older than one day',
    () async {
      final repository = _FakeMemoryAudioRepository({'audio/kept.m4a'});
      final assets = _CleanupAssetStore();
      final cleanup = MemoryAudioOrphanCleanup(
        repository: repository,
        assetStore: assets,
        now: () => DateTime.utc(2026, 8, 13, 12),
      );

      await cleanup.run();

      expect(assets.referenced, {'audio/kept.m4a'});
      expect(assets.olderThan, DateTime.utc(2026, 8, 12, 12));
    },
  );

  test('startup cleanup failure is nonfatal and can be retried', () async {
    final repository = _FakeMemoryAudioRepository({'audio/kept.m4a'});
    final assets = _CleanupAssetStore()..failure = StateError('storage');
    final cleanup = MemoryAudioOrphanCleanup(
      repository: repository,
      assetStore: assets,
      now: () => DateTime.utc(2026, 8, 13),
    );

    await cleanup.run();
    assets.failure = null;
    await cleanup.run();

    expect(assets.calls, 2);
  });
}

class _FakeMemoryAudioRepository implements MemoryAudioRepository {
  _FakeMemoryAudioRepository(this.keys);
  final Set<String> keys;

  @override
  Future<Set<String>> ownedStorageKeys() async => keys;

  @override
  Future<MemoryAudio> attach(
    MemoryAudioDraft draft, {
    required String encounterId,
    required String revisionId,
    required String durableKey,
    required int byteSize,
  }) => throw UnimplementedError();

  @override
  Future<String?> deleteMetadata(String encounterId) =>
      throw UnimplementedError();

  @override
  Stream<MemoryAudio?> watchForEncounter(String encounterId) =>
      const Stream.empty();
}

class _CleanupAssetStore implements AudioAssetStore {
  Set<String>? referenced;
  DateTime? olderThan;
  Object? failure;
  int calls = 0;

  @override
  Future<void> cleanup(
    Set<String> referencedStorageKeys, {
    required DateTime olderThan,
  }) async {
    calls++;
    referenced = referencedStorageKeys;
    this.olderThan = olderThan;
    if (failure case final error?) throw error;
  }

  @override
  Future<TemporaryAudio> allocateTemporary({
    required String takeId,
    required String extension,
  }) => throw UnimplementedError();

  @override
  Future<CommittedAudio> commitTemporary(
    TemporaryAudio temporary, {
    required String assetId,
    required String mimeType,
  }) => throw UnimplementedError();

  @override
  Future<void> delete(String storageKey) => throw UnimplementedError();

  @override
  Future<void> discardTemporary(String locator) => throw UnimplementedError();

  @override
  Future<AudioPlaybackSource?> open(String storageKey) =>
      throw UnimplementedError();
}
