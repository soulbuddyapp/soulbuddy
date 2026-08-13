import 'dart:io';

import 'package:path/path.dart' as path;

import '../domain/memory_audio.dart';
import 'audio_asset_store.dart';

class IoAudioAssetStore implements AudioAssetStore {
  IoAudioAssetStore({
    required Directory applicationSupportDirectory,
    required Directory temporaryDirectory,
  }) : _durableBase = Directory(
         path.join(applicationSupportDirectory.path, 'soulbuddy'),
       ),
       _temporaryAudio = Directory(
         path.join(temporaryDirectory.path, 'soulbuddy', 'audio'),
       );

  final Directory _durableBase;
  final Directory _temporaryAudio;

  Directory get _durableAudio =>
      Directory(path.join(_durableBase.path, 'audio'));

  @override
  Future<TemporaryAudio> allocateTemporary({
    required String takeId,
    required String extension,
  }) async {
    final normalizedId = _safeIdentifier(takeId, 'takeId');
    final normalizedExtension = _safeExtension(extension);
    await _temporaryAudio.create(recursive: true);
    final locator = path.join(
      _temporaryAudio.path,
      '$normalizedId.$normalizedExtension',
    );
    _requireLexicallyWithin(_temporaryAudio.path, locator, 'temporary path');
    return TemporaryAudio(key: normalizedId, locator: locator);
  }

  @override
  Future<CommittedAudio> commitTemporary(
    TemporaryAudio temporary, {
    required String assetId,
    required String mimeType,
  }) async {
    final normalizedId = _safeIdentifier(assetId, 'assetId');
    final extension = _extensionForMime(mimeType);
    await _temporaryAudio.create(recursive: true);
    await _durableAudio.create(recursive: true);

    final source = File(temporary.locator);
    await _requireExistingWithin(_temporaryAudio, source, 'temporary audio');
    final byteSize = await source.length();
    if (byteSize < 1 || byteSize > maximumMemoryAudioBytes) {
      throw ArgumentError.value(byteSize, 'byteSize');
    }

    final storageKey = 'audio/$normalizedId.$extension';
    final target = File(_durablePath(storageKey));
    final partial = File('${target.path}.partial');
    if (await target.exists() || await partial.exists()) {
      throw StateError('The durable audio asset already exists.');
    }

    try {
      await source.copy(partial.path);
      final durable = await partial.open(mode: FileMode.append);
      try {
        await durable.flush();
      } finally {
        await durable.close();
      }
      await partial.rename(target.path);
      await source.delete();
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    }

    return CommittedAudio(storageKey: storageKey, byteSize: byteSize);
  }

  @override
  Future<void> discardTemporary(String locator) async {
    _requireLexicallyWithin(_temporaryAudio.path, locator, 'temporary audio');
    final file = File(locator);
    if (!await file.exists()) return;
    await _requireExistingWithin(_temporaryAudio, file, 'temporary audio');
    await file.delete();
  }

  @override
  Future<AudioPlaybackSource?> open(String storageKey) async {
    final file = File(_durablePath(storageKey));
    if (!await file.exists()) return null;
    await _requireExistingWithin(_durableAudio, file, 'durable audio');
    return FileAudioPlaybackSource(file.path);
  }

  @override
  Future<void> delete(String storageKey) async {
    final file = File(_durablePath(storageKey));
    if (!await file.exists()) return;
    await _requireExistingWithin(_durableAudio, file, 'durable audio');
    await file.delete();
  }

  @override
  Future<void> cleanup(
    Set<String> referencedStorageKeys, {
    required DateTime olderThan,
  }) async {
    final referencedPaths = <String>{};
    for (final key in referencedStorageKeys) {
      referencedPaths.add(path.normalize(path.absolute(_durablePath(key))));
    }

    await _deleteOldFiles(
      _durableAudio,
      olderThan: olderThan,
      keepAbsolutePaths: referencedPaths,
    );
    await _deleteOldFiles(_temporaryAudio, olderThan: olderThan);
  }

  Future<void> _deleteOldFiles(
    Directory directory, {
    required DateTime olderThan,
    Set<String> keepAbsolutePaths = const {},
  }) async {
    if (!await directory.exists()) return;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      await _requireExistingWithin(directory, entity, 'audio cleanup');
      final absolute = path.normalize(path.absolute(entity.path));
      if (keepAbsolutePaths.contains(absolute)) continue;
      if ((await entity.lastModified()).isBefore(olderThan)) {
        await entity.delete();
      }
    }
  }

  String _durablePath(String storageKey) {
    if (!RegExp(
      r'^audio/[A-Za-z0-9_-]+\.(m4a|wav|webm|ogg)$',
    ).hasMatch(storageKey)) {
      throw ArgumentError.value(storageKey, 'storageKey');
    }
    final candidate = path.join(_durableBase.path, storageKey);
    _requireLexicallyWithin(_durableBase.path, candidate, 'storageKey');
    return candidate;
  }
}

String _safeIdentifier(String value, String name) {
  final normalized = value.trim();
  if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, name);
  }
  return normalized;
}

String _safeExtension(String value) {
  final normalized = value.trim().toLowerCase();
  if (!{'m4a', 'wav', 'webm', 'ogg'}.contains(normalized)) {
    throw ArgumentError.value(value, 'extension');
  }
  return normalized;
}

String _extensionForMime(String mimeType) => switch (mimeType.toLowerCase()) {
  'audio/mp4' || 'audio/aac' || 'audio/x-m4a' => 'm4a',
  'audio/wav' || 'audio/wave' || 'audio/x-wav' => 'wav',
  'audio/webm' => 'webm',
  'audio/ogg' => 'ogg',
  _ => throw ArgumentError.value(mimeType, 'mimeType'),
};

void _requireLexicallyWithin(String root, String candidate, String name) {
  final normalizedRoot = path.normalize(path.absolute(root));
  final normalizedCandidate = path.normalize(path.absolute(candidate));
  if (!path.isWithin(normalizedRoot, normalizedCandidate)) {
    throw ArgumentError.value(candidate, name);
  }
}

Future<void> _requireExistingWithin(
  Directory root,
  File file,
  String name,
) async {
  _requireLexicallyWithin(root.path, file.path, name);
  final resolvedRoot = await root.resolveSymbolicLinks();
  final resolvedFile = await file.resolveSymbolicLinks();
  if (!path.isWithin(resolvedRoot, resolvedFile)) {
    throw ArgumentError.value(file.path, name);
  }
}
