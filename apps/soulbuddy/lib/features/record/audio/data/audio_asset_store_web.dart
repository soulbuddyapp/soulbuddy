import 'dart:typed_data';

import 'package:idb_shim/idb.dart';

import '../domain/memory_audio.dart';
import 'audio_asset_store.dart';

typedef TemporaryAudioReader = Future<Uint8List> Function(String locator);
typedef TemporaryAudioReleaser = Future<void> Function(String locator);

class WebAudioAssetStore implements AudioAssetStore {
  WebAudioAssetStore({
    required IdbFactory idbFactory,
    required TemporaryAudioReader readTemporary,
    required TemporaryAudioReleaser releaseTemporary,
    DateTime Function()? now,
    this.databaseName = 'soulbuddy-audio',
  }) : _idbFactory = idbFactory,
       _readTemporary = readTemporary,
       _releaseTemporary = releaseTemporary,
       _now = now ?? DateTime.now;

  static const _storeName = 'assets';

  final IdbFactory _idbFactory;
  final TemporaryAudioReader _readTemporary;
  final TemporaryAudioReleaser _releaseTemporary;
  final DateTime Function() _now;
  final String databaseName;

  @override
  Future<TemporaryAudio> allocateTemporary({
    required String takeId,
    required String extension,
  }) async {
    final normalizedId = _safeIdentifier(takeId, 'takeId');
    _safeExtension(extension);
    return TemporaryAudio(key: normalizedId, locator: '');
  }

  @override
  Future<CommittedAudio> commitTemporary(
    TemporaryAudio temporary, {
    required String assetId,
    required String mimeType,
  }) async {
    final normalizedId = _safeIdentifier(assetId, 'assetId');
    final extension = _extensionForMime(mimeType);
    if (temporary.locator.isEmpty) {
      throw ArgumentError.value(temporary.locator, 'temporary.locator');
    }
    final storageKey = 'audio/$normalizedId.$extension';
    _validateStorageKey(storageKey);

    final bytes = Uint8List.fromList(await _readTemporary(temporary.locator));
    if (bytes.isEmpty || bytes.length > maximumMemoryAudioBytes) {
      throw ArgumentError.value(bytes.length, 'byteSize');
    }

    final database = await _openDatabase();
    try {
      final transaction = database.transaction(_storeName, idbModeReadWrite);
      final store = transaction.objectStore(_storeName);
      final existing = await store.getObject(storageKey);
      if (existing != null) {
        await transaction.completed;
        throw StateError('The durable audio asset already exists.');
      }
      await store.add({
        'storageKey': storageKey,
        'mimeType': mimeType,
        'bytes': bytes,
        'createdAt': _now().toUtc().toIso8601String(),
      }, storageKey);
      await transaction.completed;
    } catch (_) {
      rethrow;
    } finally {
      database.close();
    }

    await _releaseTemporary(temporary.locator);
    return CommittedAudio(storageKey: storageKey, byteSize: bytes.length);
  }

  @override
  Future<void> discardTemporary(String locator) async {
    if (!locator.startsWith('blob:') || locator.length > 4096) {
      throw ArgumentError.value(locator, 'locator');
    }
    await _releaseTemporary(locator);
  }

  @override
  Future<AudioPlaybackSource?> open(String storageKey) async {
    _validateStorageKey(storageKey);
    final database = await _openDatabase();
    try {
      final transaction = database.transaction(_storeName, idbModeReadOnly);
      final value = await transaction
          .objectStore(_storeName)
          .getObject(storageKey);
      await transaction.completed;
      if (value == null) return null;
      final record = _parseRecord(value, expectedStorageKey: storageKey);
      return BytesAudioPlaybackSource(record.bytes, mimeType: record.mimeType);
    } finally {
      database.close();
    }
  }

  @override
  Future<void> delete(String storageKey) async {
    _validateStorageKey(storageKey);
    final database = await _openDatabase();
    try {
      final transaction = database.transaction(_storeName, idbModeReadWrite);
      await transaction.objectStore(_storeName).delete(storageKey);
      await transaction.completed;
    } finally {
      database.close();
    }
  }

  @override
  Future<void> cleanup(
    Set<String> referencedStorageKeys, {
    required DateTime olderThan,
  }) async {
    for (final key in referencedStorageKeys) {
      _validateStorageKey(key);
    }
    final database = await _openDatabase();
    try {
      final read = database.transaction(_storeName, idbModeReadOnly);
      final values = await read.objectStore(_storeName).getAll();
      await read.completed;
      final keysToDelete = <String>[];
      for (final value in values) {
        final record = _parseRecord(value);
        if (!referencedStorageKeys.contains(record.storageKey) &&
            record.createdAt.isBefore(olderThan)) {
          keysToDelete.add(record.storageKey);
        }
      }
      if (keysToDelete.isEmpty) return;
      final write = database.transaction(_storeName, idbModeReadWrite);
      final store = write.objectStore(_storeName);
      for (final key in keysToDelete) {
        await store.delete(key);
      }
      await write.completed;
    } finally {
      database.close();
    }
  }

  Future<Database> _openDatabase() => _idbFactory.open(
    databaseName,
    version: 1,
    onUpgradeNeeded: (event) {
      if (!event.database.objectStoreNames.contains(_storeName)) {
        event.database.createObjectStore(_storeName);
      }
    },
  );
}

class _WebAudioRecord {
  const _WebAudioRecord({
    required this.storageKey,
    required this.mimeType,
    required this.bytes,
    required this.createdAt,
  });

  final String storageKey;
  final String mimeType;
  final Uint8List bytes;
  final DateTime createdAt;
}

_WebAudioRecord _parseRecord(Object value, {String? expectedStorageKey}) {
  if (value is! Map) throw const FormatException('Invalid audio asset.');
  final storageKey = value['storageKey'];
  final mimeType = value['mimeType'];
  final rawBytes = value['bytes'];
  final rawCreatedAt = value['createdAt'];
  if (storageKey is! String ||
      mimeType is! String ||
      rawBytes is! List<int> ||
      rawCreatedAt is! String) {
    throw const FormatException('Invalid audio asset.');
  }
  _validateStorageKey(storageKey);
  if (expectedStorageKey != null && storageKey != expectedStorageKey) {
    throw const FormatException('Invalid audio asset key.');
  }
  final createdAt = DateTime.tryParse(rawCreatedAt);
  if (createdAt == null || !mimeType.startsWith('audio/')) {
    throw const FormatException('Invalid audio asset metadata.');
  }
  final bytes = Uint8List.fromList(rawBytes);
  if (bytes.isEmpty || bytes.length > maximumMemoryAudioBytes) {
    throw const FormatException('Invalid audio asset bytes.');
  }
  return _WebAudioRecord(
    storageKey: storageKey,
    mimeType: mimeType,
    bytes: bytes,
    createdAt: createdAt,
  );
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

void _validateStorageKey(String storageKey) {
  if (!RegExp(
    r'^audio/[A-Za-z0-9_-]+\.(m4a|wav|webm|ogg)$',
  ).hasMatch(storageKey)) {
    throw ArgumentError.value(storageKey, 'storageKey');
  }
}
