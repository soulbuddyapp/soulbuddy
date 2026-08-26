import 'dart:typed_data';

class TemporaryAudio {
  const TemporaryAudio({required this.key, required this.locator});

  final String key;
  final String locator;
}

class CommittedAudio {
  const CommittedAudio({required this.storageKey, required this.byteSize});

  final String storageKey;
  final int byteSize;
}

sealed class AudioPlaybackSource {
  const AudioPlaybackSource();
}

class FileAudioPlaybackSource extends AudioPlaybackSource {
  const FileAudioPlaybackSource(this.path);

  final String path;
}

class BytesAudioPlaybackSource extends AudioPlaybackSource {
  const BytesAudioPlaybackSource(this.bytes, {required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

abstract interface class AudioAssetStore {
  Future<TemporaryAudio> allocateTemporary({
    required String takeId,
    required String extension,
  });

  Future<CommittedAudio> commitTemporary(
    TemporaryAudio temporary, {
    required String assetId,
    required String mimeType,
  });

  Future<void> discardTemporary(String locator);
  Future<AudioPlaybackSource?> open(String storageKey);
  Future<void> delete(String storageKey);

  Future<void> cleanup(
    Set<String> referencedStorageKeys, {
    required DateTime olderThan,
  });
}

/// Optional browser capability that moves a document-scoped recording into
/// durable local storage before a multi-step save can be retried.
abstract interface class DurableTemporaryAudioStore {
  Future<TemporaryAudio> stageTemporary(
    TemporaryAudio temporary, {
    required String mimeType,
  });
}
