import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store_io.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store_web.dart';

void main() {
  late Directory root;
  late Directory support;
  late Directory temporary;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('soulbuddy-audio-store-');
    support = Directory('${root.path}/support');
    temporary = Directory('${root.path}/temporary');
  });

  tearDown(() => root.delete(recursive: true));

  test(
    'commits a take atomically and opens its private durable bytes',
    () async {
      final store = IoAudioAssetStore(
        applicationSupportDirectory: support,
        temporaryDirectory: temporary,
      );
      final take = await store.allocateTemporary(
        takeId: 'take-1',
        extension: 'm4a',
      );
      await File(take.locator).writeAsBytes([1, 2, 3, 4], flush: true);

      final committed = await store.commitTemporary(
        take,
        assetId: 'asset-1',
        mimeType: 'audio/mp4',
      );

      expect(committed.storageKey, 'audio/asset-1.m4a');
      expect(committed.byteSize, 4);
      expect(await File(take.locator).exists(), isFalse);
      final opened = await store.open(committed.storageKey);
      expect(opened, isA<FileAudioPlaybackSource>());
      expect(
        await File((opened! as FileAudioPlaybackSource).path).readAsBytes(),
        [1, 2, 3, 4],
      );

      await store.delete(committed.storageKey);
      expect(await store.open(committed.storageKey), isNull);
    },
  );

  test(
    'a duplicate asset never overwrites bytes and leaves the take',
    () async {
      final store = IoAudioAssetStore(
        applicationSupportDirectory: support,
        temporaryDirectory: temporary,
      );
      final first = await store.allocateTemporary(
        takeId: 'take-1',
        extension: 'm4a',
      );
      await File(first.locator).writeAsBytes([1, 2, 3]);
      final committed = await store.commitTemporary(
        first,
        assetId: 'same-id',
        mimeType: 'audio/mp4',
      );
      final second = await store.allocateTemporary(
        takeId: 'take-2',
        extension: 'm4a',
      );
      await File(second.locator).writeAsBytes([9, 9, 9]);

      await expectLater(
        store.commitTemporary(
          second,
          assetId: 'same-id',
          mimeType: 'audio/mp4',
        ),
        throwsStateError,
      );

      expect(await File(second.locator).exists(), isTrue);
      final opened = await store.open(committed.storageKey);
      expect(
        await File((opened! as FileAudioPlaybackSource).path).readAsBytes(),
        [1, 2, 3],
      );
    },
  );

  test(
    'rejects traversal and invalid identifiers outside exact roots',
    () async {
      final store = IoAudioAssetStore(
        applicationSupportDirectory: support,
        temporaryDirectory: temporary,
      );

      await expectLater(store.open('../private.txt'), throwsArgumentError);
      await expectLater(
        store.delete('audio/../private.txt'),
        throwsArgumentError,
      );
      await expectLater(
        store.allocateTemporary(takeId: '../escape', extension: 'm4a'),
        throwsArgumentError,
      );
    },
  );

  test(
    'cleanup removes only old unreferenced durable and temporary files',
    () async {
      final store = IoAudioAssetStore(
        applicationSupportDirectory: support,
        temporaryDirectory: temporary,
      );
      final old = DateTime.utc(2026, 8, 10);
      final threshold = DateTime.utc(2026, 8, 12);

      Future<CommittedAudio> commit(String id, List<int> bytes) async {
        final take = await store.allocateTemporary(
          takeId: 'take-$id',
          extension: 'm4a',
        );
        await File(take.locator).writeAsBytes(bytes);
        final saved = await store.commitTemporary(
          take,
          assetId: id,
          mimeType: 'audio/mp4',
        );
        await File(
          (await store.open(saved.storageKey) as FileAudioPlaybackSource).path,
        ).setLastModified(old);
        return saved;
      }

      final kept = await commit('kept', [1]);
      final orphan = await commit('orphan', [2]);
      final temporaryTake = await store.allocateTemporary(
        takeId: 'old-take',
        extension: 'm4a',
      );
      await File(temporaryTake.locator).writeAsBytes([3]);
      await File(temporaryTake.locator).setLastModified(old);

      await store.cleanup({kept.storageKey}, olderThan: threshold);

      expect(await store.open(kept.storageKey), isNotNull);
      expect(await store.open(orphan.storageKey), isNull);
      expect(await File(temporaryTake.locator).exists(), isFalse);
    },
  );

  group('IndexedDB store', () {
    late Map<String, Uint8List> temporaryBytes;
    late List<String> released;

    setUp(() {
      temporaryBytes = {
        'blob:first': Uint8List.fromList([4, 3, 2, 1]),
        'blob:second': Uint8List.fromList([9, 9]),
      };
      released = [];
    });

    WebAudioAssetStore createStore({
      DateTime Function()? now,
      String databaseName = 'audio-assets',
    }) => WebAudioAssetStore(
      idbFactory: idbFactoryMemory,
      databaseName: databaseName,
      readTemporary: (locator) async {
        final bytes = temporaryBytes[locator];
        if (bytes == null) throw StateError('Temporary audio is unavailable.');
        return bytes;
      },
      releaseTemporary: (locator) async {
        released.add(locator);
        temporaryBytes.remove(locator);
      },
      now: now,
    );

    test('persists bytes before releasing a browser take', () async {
      final store = createStore(databaseName: 'web-commit');

      final committed = await store.commitTemporary(
        const TemporaryAudio(key: 'take-1', locator: 'blob:first'),
        assetId: 'asset-1',
        mimeType: 'audio/webm',
      );

      expect(committed.storageKey, 'audio/asset-1.webm');
      expect(committed.byteSize, 4);
      expect(released, ['blob:first']);
      final opened = await store.open(committed.storageKey);
      expect(opened, isA<BytesAudioPlaybackSource>());
      final bytesSource = opened! as BytesAudioPlaybackSource;
      expect(bytesSource.bytes, [4, 3, 2, 1]);
      expect(bytesSource.mimeType, 'audio/webm');

      await store.delete(committed.storageKey);
      expect(await store.open(committed.storageKey), isNull);
    });

    test('a failed or duplicate import keeps the browser take', () async {
      final store = createStore(databaseName: 'web-failure');
      await store.commitTemporary(
        const TemporaryAudio(key: 'take-1', locator: 'blob:first'),
        assetId: 'same-id',
        mimeType: 'audio/webm',
      );

      await expectLater(
        store.commitTemporary(
          const TemporaryAudio(key: 'take-2', locator: 'blob:second'),
          assetId: 'same-id',
          mimeType: 'audio/webm',
        ),
        throwsStateError,
      );

      expect(temporaryBytes['blob:second'], [9, 9]);
      expect(released, ['blob:first']);
      final opened = await store.open('audio/same-id.webm');
      expect((opened! as BytesAudioPlaybackSource).bytes, [4, 3, 2, 1]);
    });

    test(
      'cleanup preserves referenced assets and removes old orphans',
      () async {
        var clock = DateTime.utc(2026, 8, 10);
        final store = createStore(
          databaseName: 'web-cleanup',
          now: () => clock,
        );
        final kept = await store.commitTemporary(
          const TemporaryAudio(key: 'take-1', locator: 'blob:first'),
          assetId: 'kept',
          mimeType: 'audio/webm',
        );
        temporaryBytes['blob:third'] = Uint8List.fromList([7]);
        final orphan = await store.commitTemporary(
          const TemporaryAudio(key: 'take-3', locator: 'blob:third'),
          assetId: 'orphan',
          mimeType: 'audio/webm',
        );
        clock = DateTime.utc(2026, 8, 13);

        await store.cleanup({
          kept.storageKey,
        }, olderThan: DateTime.utc(2026, 8, 12));

        expect(await store.open(kept.storageKey), isNotNull);
        expect(await store.open(orphan.storageKey), isNull);
      },
    );

    test('rejects malformed durable keys and identifiers', () async {
      final store = createStore(databaseName: 'web-validation');

      await expectLater(store.open('../private'), throwsArgumentError);
      await expectLater(
        store.commitTemporary(
          const TemporaryAudio(key: 'take', locator: 'blob:first'),
          assetId: '../escape',
          mimeType: 'audio/webm',
        ),
        throwsArgumentError,
      );
    });
  });
}
