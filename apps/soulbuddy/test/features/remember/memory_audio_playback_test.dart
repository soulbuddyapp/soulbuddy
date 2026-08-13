import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/record/audio/application/memory_audio_player.dart';
import 'package:soulbuddy/features/record/audio/application/memory_audio_deletion.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/data/memory_audio_repository.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';

void main() {
  test('starting another memory stops the first before playback', () async {
    final assets = _PlaybackAssetStore();
    final driver = _PlaybackDriver();
    final coordinator = MemoryAudioPlaybackCoordinator(
      assetStore: assets,
      driver: driver,
    );
    addTearDown(coordinator.close);

    await coordinator.play(_audio('audio-a', 'audio/a.m4a'));
    expect(coordinator.state.assetId, 'audio-a');
    expect(coordinator.state.status, MemoryAudioPlaybackStatus.playing);

    await coordinator.play(_audio('audio-b', 'audio/b.m4a'));

    expect(driver.events, ['play:file:a', 'stop', 'play:bytes:3']);
    expect(coordinator.state.assetId, 'audio-b');
    expect(coordinator.state.status, MemoryAudioPlaybackStatus.playing);
  });

  test('prepared private bytes are reused when playback starts', () async {
    final assets = _PlaybackAssetStore();
    final coordinator = MemoryAudioPlaybackCoordinator(
      assetStore: assets,
      driver: _PlaybackDriver(),
    );
    addTearDown(coordinator.close);
    final audio = _audio('audio-a', 'audio/a.m4a');

    expect(await coordinator.prepare(audio), isTrue);
    await coordinator.play(audio);

    expect(assets.openedKeys, ['audio/a.m4a']);
  });

  test('concurrent preparation opens and prepares one private asset', () async {
    final assets = _PlaybackAssetStore();
    final driver = _PlaybackDriver();
    final coordinator = MemoryAudioPlaybackCoordinator(
      assetStore: assets,
      driver: driver,
    );
    addTearDown(coordinator.close);
    final audio = _audio('audio-a', 'audio/a.m4a');

    final prepared = await Future.wait([
      coordinator.prepare(audio),
      coordinator.prepare(audio),
    ]);

    expect(prepared, [isTrue, isTrue]);
    expect(assets.openedKeys, ['audio/a.m4a']);
    expect(driver.prepareCount, 1);
  });

  test('preparation evicts the least recently used private asset', () async {
    final assets = _PlaybackAssetStore();
    final driver = _PlaybackDriver();
    final coordinator = MemoryAudioPlaybackCoordinator(
      assetStore: assets,
      driver: driver,
      preparedAssetLimit: 2,
    );
    addTearDown(coordinator.close);

    await coordinator.prepare(_audio('audio-a', 'audio/a.m4a'));
    await coordinator.prepare(_audio('audio-b', 'audio/b.m4a'));
    await coordinator.prepare(_audio('audio-c', 'audio/c.m4a'));

    expect(driver.events, contains('release:audio-a'));
    expect(driver.preparedAssetIds, {'audio-b', 'audio-c'});
  });

  test(
    'distinct private assets are opened through one bounded queue',
    () async {
      final assets = _BlockingPlaybackAssetStore();
      final coordinator = MemoryAudioPlaybackCoordinator(
        assetStore: assets,
        driver: _PlaybackDriver(),
      );
      addTearDown(coordinator.close);

      final first = coordinator.prepare(_audio('audio-a', 'audio/a.m4a'));
      final second = coordinator.prepare(_audio('audio-b', 'audio/b.m4a'));
      await Future<void>.delayed(Duration.zero);

      expect(assets.openedKeys, ['audio/a.m4a']);
      assets.releaseFirst();
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(assets.openedKeys, ['audio/a.m4a', 'audio/b.m4a']);
    },
  );

  test('close waits for an in-flight private source before disposal', () async {
    final assets = _BlockingPlaybackAssetStore();
    final driver = _PlaybackDriver();
    final coordinator = MemoryAudioPlaybackCoordinator(
      assetStore: assets,
      driver: driver,
    );

    final preparation = coordinator.prepare(_audio('audio-a', 'audio/a.m4a'));
    await Future<void>.delayed(Duration.zero);
    final closing = coordinator.close();
    await Future<void>.delayed(Duration.zero);
    expect(driver.events, isNot(contains('dispose')));

    assets.releaseFirst();
    expect(await preparation, isFalse);
    await closing;
    expect(driver.events, contains('dispose'));
  });

  test('requires room for an active and a pending private asset', () {
    expect(
      () => MemoryAudioPlaybackCoordinator(
        assetStore: _PlaybackAssetStore(),
        driver: _PlaybackDriver(),
        preparedAssetLimit: 1,
      ),
      throwsArgumentError,
    );
  });

  test(
    'a prepared first command reaches the player in the user gesture',
    () async {
      final driver = _PlaybackDriver();
      final coordinator = MemoryAudioPlaybackCoordinator(
        assetStore: _PlaybackAssetStore(),
        driver: driver,
      );
      addTearDown(coordinator.close);
      final audio = _audio('audio-a', 'audio/a.m4a');
      await coordinator.prepare(audio);

      final playback = coordinator.play(audio);

      expect(driver.events, ['play:file:a']);
      await playback;
    },
  );

  test('forwards pause, seek, completion, and releases on close', () async {
    final driver = _PlaybackDriver();
    final coordinator = MemoryAudioPlaybackCoordinator(
      assetStore: _PlaybackAssetStore(),
      driver: driver,
    );
    await coordinator.play(_audio('audio-a', 'audio/a.m4a'));

    await coordinator.pause();
    await coordinator.seek(const Duration(seconds: 2));
    driver.positions.add(const Duration(seconds: 2));
    driver.durations.add(const Duration(seconds: 7));
    driver.statuses.add(MemoryAudioDriverStatus.completed);
    await Future<void>.delayed(Duration.zero);

    expect(coordinator.state.position, const Duration(seconds: 7));
    expect(coordinator.state.duration, const Duration(seconds: 7));
    expect(coordinator.state.status, MemoryAudioPlaybackStatus.completed);

    await coordinator.close();
    expect(
      driver.events,
      containsAllInOrder(['pause', 'seek:2000', 'dispose']),
    );
  });

  test('missing private bytes becomes a recoverable generic error', () async {
    final coordinator = MemoryAudioPlaybackCoordinator(
      assetStore: _PlaybackAssetStore(),
      driver: _PlaybackDriver(),
    );
    addTearDown(coordinator.close);

    await coordinator.play(_audio('missing', 'audio/missing.m4a'));

    expect(coordinator.state.status, MemoryAudioPlaybackStatus.error);
    expect(
      coordinator.state.error,
      'This audio is not available on this device.',
    );
  });

  test('explicit deletion removes metadata before private bytes', () async {
    final events = <String>[];
    final repository = _DeletionRepository(events);
    final assets = _DeletionAssetStore(events);
    final deletion = MemoryAudioDeletion(
      repository: repository,
      assetStore: assets,
    );

    await deletion.deleteForEncounter('memory-1');

    expect(events, ['metadata:memory-1', 'bytes:audio/private.m4a']);
  });

  test(
    'byte deletion failure stays recoverable after metadata removal',
    () async {
      final events = <String>[];
      final deletion = MemoryAudioDeletion(
        repository: _DeletionRepository(events),
        assetStore: _DeletionAssetStore(events)..fail = true,
      );

      await deletion.deleteForEncounter('memory-1');

      expect(events.first, 'metadata:memory-1');
    },
  );
}

MemoryAudio _audio(String id, String storageKey) => MemoryAudio(
  id: id,
  encounterId: 'memory-$id',
  revisionId: 'revision-$id',
  storageKey: storageKey,
  mimeType: storageKey.endsWith('m4a') ? 'audio/mp4' : 'audio/webm',
  duration: const Duration(seconds: 7),
  byteSize: 3,
  waveform: const [0.2, 0.7],
  createdAt: DateTime.utc(2026, 8, 13),
);

class _PlaybackAssetStore implements AudioAssetStore {
  final openedKeys = <String>[];

  @override
  Future<AudioPlaybackSource?> open(String storageKey) async {
    openedKeys.add(storageKey);
    return switch (storageKey) {
      'audio/a.m4a' => const FileAudioPlaybackSource('a'),
      'audio/b.m4a' => BytesAudioPlaybackSource(
        Uint8List.fromList([1, 2, 3]),
        mimeType: 'audio/mp4',
      ),
      'audio/c.m4a' => const FileAudioPlaybackSource('c'),
      _ => null,
    };
  }

  @override
  Future<TemporaryAudio> allocateTemporary({
    required String takeId,
    required String extension,
  }) => throw UnimplementedError();

  @override
  Future<void> cleanup(
    Set<String> referencedStorageKeys, {
    required DateTime olderThan,
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
}

class _BlockingPlaybackAssetStore extends _PlaybackAssetStore {
  final _firstRelease = Completer<void>();

  void releaseFirst() => _firstRelease.complete();

  @override
  Future<AudioPlaybackSource?> open(String storageKey) async {
    if (openedKeys.isEmpty) {
      openedKeys.add(storageKey);
      await _firstRelease.future;
      return const FileAudioPlaybackSource('a');
    }
    return super.open(storageKey);
  }
}

class _PlaybackDriver implements MemoryAudioPlayerDriver {
  final events = <String>[];
  var prepareCount = 0;
  final positions = StreamController<Duration>.broadcast();
  final durations = StreamController<Duration>.broadcast();
  final statuses = StreamController<MemoryAudioDriverStatus>.broadcast();
  final preparedAssetIds = <String>{};

  @override
  Stream<Duration> get durationChanges => durations.stream;

  @override
  Stream<Duration> get positionChanges => positions.stream;

  @override
  Stream<MemoryAudioDriverStatus> get statusChanges => statuses.stream;

  @override
  Future<void> dispose() async {
    events.add('dispose');
    await positions.close();
    await durations.close();
    await statuses.close();
  }

  @override
  Future<void> pause() async => events.add('pause');

  @override
  Future<void> prepare(String assetId, AudioPlaybackSource source) async {
    prepareCount++;
    preparedAssetIds.add(assetId);
  }

  @override
  Future<void> release(String assetId) async {
    preparedAssetIds.remove(assetId);
    events.add('release:$assetId');
  }

  @override
  Future<void> play(String assetId, AudioPlaybackSource source) async {
    switch (source) {
      case FileAudioPlaybackSource(:final path):
        events.add('play:file:$path');
      case BytesAudioPlaybackSource(:final bytes):
        events.add('play:bytes:${bytes.length}');
    }
  }

  @override
  Future<void> resume() async => events.add('resume');

  @override
  Future<void> seek(Duration position) async =>
      events.add('seek:${position.inMilliseconds}');

  @override
  Future<void> stop() async => events.add('stop');
}

class _DeletionRepository implements MemoryAudioRepository {
  _DeletionRepository(this.events);
  final List<String> events;

  @override
  Future<String?> deleteMetadata(String encounterId) async {
    events.add('metadata:$encounterId');
    return 'audio/private.m4a';
  }

  @override
  Future<MemoryAudio> attach(
    MemoryAudioDraft draft, {
    required String encounterId,
    required String revisionId,
    required String durableKey,
    required int byteSize,
  }) => throw UnimplementedError();

  @override
  Future<Set<String>> ownedStorageKeys() => throw UnimplementedError();

  @override
  Stream<MemoryAudio?> watchForEncounter(String encounterId) =>
      const Stream.empty();
}

class _DeletionAssetStore extends _PlaybackAssetStore {
  _DeletionAssetStore(this.events);
  final List<String> events;
  bool fail = false;

  @override
  Future<void> delete(String storageKey) async {
    events.add('bytes:$storageKey');
    if (fail) throw StateError('locked');
  }
}
