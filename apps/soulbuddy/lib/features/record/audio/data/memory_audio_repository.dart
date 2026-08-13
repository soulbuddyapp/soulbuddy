import '../domain/memory_audio.dart';

abstract interface class MemoryAudioRepository {
  Stream<MemoryAudio?> watchForEncounter(String encounterId);

  Future<MemoryAudio> attach(
    MemoryAudioDraft draft, {
    required String encounterId,
    required String revisionId,
    required String durableKey,
    required int byteSize,
  });

  /// Deletes only local metadata and returns the durable key for byte removal.
  Future<String?> deleteMetadata(String encounterId);

  Future<Set<String>> ownedStorageKeys();
}
