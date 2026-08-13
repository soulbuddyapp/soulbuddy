import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';
import 'package:soulbuddy/features/record/data/powersync_encounter_repository.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/record/domain/encounter_draft.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-encounters-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('saves and watches an encounter without a network connection', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncEncounterRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      now: () => DateTime.utc(2026, 8, 10, 12),
    );
    final encounters = repository.watchAll();

    await repository.create(
      const EncounterDraft(
        title: 'The help I received',
        body: 'I remembered that I was not alone.',
        occurredOn: '2026-08-10',
        isAltar: false,
      ),
    );

    final saved = await encounters.firstWhere((items) => items.isNotEmpty);
    expect(saved.single.title, 'The help I received');
    expect(saved.single.syncState, EncounterSyncState.pending);
  });

  test('keeps an encounter after closing and reopening the database', () async {
    final path = '${temporaryDirectory.path}/soulbuddy.db';
    final firstDatabase = await openTestDatabase(path);
    final firstRepository = PowerSyncEncounterRepository(
      database: firstDatabase.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      now: () => DateTime.utc(2026, 8, 10, 12),
    );

    await firstRepository.create(
      const EncounterDraft(
        title: 'Remember this help',
        body: '',
        occurredOn: '2026-08-09',
        isAltar: true,
      ),
    );
    await firstDatabase.close();

    final reopenedDatabase = await openTestDatabase(path);
    addTearDown(reopenedDatabase.close);
    final reopenedRepository = PowerSyncEncounterRepository(
      database: reopenedDatabase.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
    );

    final saved = await reopenedRepository.watchAll().first;
    expect(saved.single.title, 'Remember this help');
    expect(saved.single.isAltar, isTrue);
  });

  test(
    'emits a persisted encounter before the change stream attaches',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/soulbuddy.db',
      );
      addTearDown(database.close);
      await database.powersync.execute(
        '''
      INSERT INTO encounters(
        id, owner_id, title, body, occurred_on, is_altar,
        created_at, updated_at, archived_at, current_revision_id,
        memory_type, sensitive, recall_enabled, recall_paused,
        recall_interval_days
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, ?)
      ''',
        [
          'persisted-encounter',
          'owner-1',
          'Already remembered',
          '',
          '2026-08-10',
          0,
          '2026-08-10T12:00:00.000Z',
          '2026-08-10T12:00:00.000Z',
          'persisted-revision',
          'encounter',
          0,
          1,
          0,
          7,
        ],
      );
      final repository = PowerSyncEncounterRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        deviceId: 'device-1',
      );

      final first = await repository.watchAll().first;

      expect(first.single.id, 'persisted-encounter');
    },
  );

  test(
    'saves durable voice and memory metadata as one visible action',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/soulbuddy.db',
      );
      addTearDown(database.close);
      final assets = _FakeAudioAssetStore();
      final repository = PowerSyncEncounterRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        deviceId: 'device-1',
        audioAssetStore: assets,
        now: () => DateTime.utc(2026, 8, 13, 8),
      );

      final memory = await repository.create(
        EncounterDraft(
          title: 'Voice memory · 13 Aug',
          body: '',
          occurredOn: '2026-08-13',
          isAltar: false,
          audio: MemoryAudioDraft(
            temporaryKey: '/private/take-1.m4a',
            mimeType: 'audio/mp4',
            duration: const Duration(seconds: 7),
            waveform: const [0.12, 0.48, 0.83, 0.31],
          ),
        ),
      );

      final rows = await database.powersync.getAll(
        'SELECT * FROM memory_audio_assets WHERE encounter_id = ?',
        [memory.id],
      );
      expect(rows, hasLength(1));
      expect(rows.single['owner_id'], 'owner-1');
      expect(rows.single['encounter_revision_id'], memory.currentRevisionId);
      expect(rows.single['duration_ms'], 7000);
      expect(rows.single['byte_size'], 4);
      expect(assets.committedLocators, ['/private/take-1.m4a']);
      expect(assets.deletedKeys, isEmpty);

      final crud = await database.powersync.getCrudBatch();
      expect(crud, isNotNull);
      expect(
        crud!.crud.any((entry) => entry.table == 'memory_audio_assets'),
        isFalse,
      );
    },
  );

  test('failed durable import leaves no user-visible memory', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);
    final assets = _FakeAudioAssetStore()..commitError = StateError('disk');
    final repository = PowerSyncEncounterRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      audioAssetStore: assets,
    );

    await expectLater(
      repository.create(_audioDraft()),
      throwsA(isA<StateError>()),
    );

    expect(
      await database.powersync.getAll('SELECT id FROM encounters'),
      isEmpty,
    );
    expect(
      await database.powersync.getAll('SELECT id FROM memory_audio_assets'),
      isEmpty,
    );
    expect(assets.deletedKeys, isEmpty);
  });

  test('database failure deletes the newly committed durable asset', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    final assets = _FakeAudioAssetStore();
    final repository = PowerSyncEncounterRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      audioAssetStore: assets,
    );
    await database.close();

    await expectLater(repository.create(_audioDraft()), throwsA(anything));

    expect(assets.committedKeys, hasLength(1));
    expect(assets.deletedKeys, assets.committedKeys);
  });

  test('updates altar state and archives without deleting history', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncEncounterRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      now: () => DateTime.utc(2026, 8, 10, 12),
    );
    final encounter = await repository.create(
      const EncounterDraft(
        title: 'An encounter to revisit',
        body: '',
        occurredOn: '2026-08-10',
        isAltar: false,
      ),
    );

    await repository.markAsAltar(encounter.id, value: true);
    final marked = await repository.watchAll().first;
    expect(marked.single.isAltar, isTrue);

    await repository.archive(encounter.id);
    final active = await repository.watchAll().first;
    expect(active, isEmpty);

    final revisions = await database.powersync.getAll(
      'SELECT id FROM encounter_revisions WHERE encounter_id = ?',
      [encounter.id],
    );
    expect(revisions, hasLength(1));
  });

  test('persists typed remembrance fields in the immutable revision', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncEncounterRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      now: () => DateTime.utc(2026, 8, 12, 9),
    );

    final memory = await repository.create(
      const EncounterDraft(
        title: 'What I promised',
        body: 'I will return to prayer each morning.',
        occurredOn: '2026-08-12',
        isAltar: true,
        memoryType: MemoryType.promise,
        sensitive: true,
        recallEnabled: true,
        recallIntervalDays: 14,
      ),
    );

    expect(memory.memoryType, MemoryType.promise);
    expect(memory.sensitive, isTrue);
    expect(memory.recallEnabled, isTrue);
    expect(memory.recallIntervalDays, 14);
    final revision = await database.powersync.get(
      'SELECT memory_type, sensitive, recall_enabled, recall_interval_days '
      'FROM encounter_revisions WHERE id = ?',
      [memory.currentRevisionId],
    );
    expect(revision, {
      'memory_type': 'promise',
      'sensitive': 1,
      'recall_enabled': 1,
      'recall_interval_days': 14,
    });
  });

  test(
    'appends dated reflections without changing the original record',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/soulbuddy.db',
      );
      addTearDown(database.close);
      final repository = PowerSyncEncounterRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        deviceId: 'device-1',
        now: () => DateTime.utc(2026, 8, 12, 10),
      );
      final memory = await repository.create(
        const EncounterDraft(
          title: 'A lesson to revisit',
          body: 'The original understanding.',
          occurredOn: '2026-08-11',
          isAltar: false,
          memoryType: MemoryType.revelation,
        ),
      );

      await repository.addReflection(
        memory.id,
        body: 'I now understand that patience was part of the lesson.',
        localDate: '2026-08-12',
      );

      final reflections = await repository.watchReflections(memory.id).first;
      expect(reflections.single.body, contains('patience'));
      expect(reflections.single.localDate, '2026-08-12');
      final original = await repository.watchAll().first;
      expect(original.single.body, 'The original understanding.');
    },
  );
}

EncounterDraft _audioDraft() => EncounterDraft(
  title: 'Voice memory · 13 Aug',
  body: '',
  occurredOn: '2026-08-13',
  isAltar: false,
  audio: MemoryAudioDraft(
    temporaryKey: '/private/take.m4a',
    mimeType: 'audio/mp4',
    duration: const Duration(seconds: 3),
    waveform: const [0.3, 0.7],
  ),
);

class _FakeAudioAssetStore implements AudioAssetStore {
  Object? commitError;
  final committedLocators = <String>[];
  final committedKeys = <String>[];
  final deletedKeys = <String>[];

  @override
  Future<TemporaryAudio> allocateTemporary({
    required String takeId,
    required String extension,
  }) async =>
      TemporaryAudio(key: takeId, locator: '/private/$takeId.$extension');

  @override
  Future<CommittedAudio> commitTemporary(
    TemporaryAudio temporary, {
    required String assetId,
    required String mimeType,
  }) async {
    committedLocators.add(temporary.locator);
    if (commitError case final error?) throw error;
    final key = 'audio/$assetId.m4a';
    committedKeys.add(key);
    return CommittedAudio(storageKey: key, byteSize: 4);
  }

  @override
  Future<void> delete(String storageKey) async => deletedKeys.add(storageKey);

  @override
  Future<void> discardTemporary(String locator) async {}

  @override
  Future<AudioPlaybackSource?> open(String storageKey) async => null;

  @override
  Future<void> cleanup(
    Set<String> referencedStorageKeys, {
    required DateTime olderThan,
  }) async {}
}
