import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';
import 'package:soulbuddy/core/database/app_database.dart';
import 'package:soulbuddy/features/record/audio/data/powersync_memory_audio_repository.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';
import 'package:soulbuddy/features/record/data/powersync_encounter_repository.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/record/domain/encounter_draft.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-memory-audio-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('attaches and watches private metadata without upload CRUD', () async {
    final setup = await _setup(temporaryDirectory);
    addTearDown(setup.database.close);
    await _drainCrud(setup.database.powersync);

    final saved = await setup.audio.attach(
      _draft(),
      encounterId: setup.encounter.id,
      revisionId: setup.encounter.currentRevisionId,
      durableKey: 'audio/asset-1.m4a',
      byteSize: 2048,
    );

    expect(
      await setup.audio.watchForEncounter(setup.encounter.id).first,
      saved,
    );
    expect(saved.duration, const Duration(seconds: 12));
    expect(saved.waveform, [0.1, 0.4, 0.8, 0.3]);
    expect(await setup.audio.ownedStorageKeys(), {'audio/asset-1.m4a'});
    expect(await setup.database.powersync.getNextCrudTransaction(), isNull);
  });

  test('scopes reads, writes, and deletion to the owner', () async {
    final setup = await _setup(temporaryDirectory);
    addTearDown(setup.database.close);
    final foreign = PowerSyncMemoryAudioRepository(
      database: setup.database.powersync,
      ownerId: 'owner-2',
      now: () => DateTime.utc(2026, 8, 13, 12),
    );

    await expectLater(
      foreign.attach(
        _draft(),
        encounterId: setup.encounter.id,
        revisionId: setup.encounter.currentRevisionId,
        durableKey: 'audio/foreign.m4a',
        byteSize: 100,
      ),
      throwsStateError,
    );
    expect(await foreign.watchForEncounter(setup.encounter.id).first, isNull);
    expect(await foreign.deleteMetadata(setup.encounter.id), isNull);
  });

  test('rejects a missing or mismatched immutable revision', () async {
    final setup = await _setup(temporaryDirectory);
    addTearDown(setup.database.close);

    await expectLater(
      setup.audio.attach(
        _draft(),
        encounterId: setup.encounter.id,
        revisionId: 'not-the-current-revision',
        durableKey: 'audio/mismatch.m4a',
        byteSize: 100,
      ),
      throwsStateError,
    );
  });

  test(
    'refuses replacement and preserves metadata when memory is archived',
    () async {
      final setup = await _setup(temporaryDirectory);
      addTearDown(setup.database.close);
      final saved = await setup.audio.attach(
        _draft(),
        encounterId: setup.encounter.id,
        revisionId: setup.encounter.currentRevisionId,
        durableKey: 'audio/original.m4a',
        byteSize: 100,
      );

      await expectLater(
        setup.audio.attach(
          _draft(),
          encounterId: setup.encounter.id,
          revisionId: setup.encounter.currentRevisionId,
          durableKey: 'audio/replacement.m4a',
          byteSize: 200,
        ),
        throwsStateError,
      );

      await setup.encounters.archive(setup.encounter.id);
      expect(
        await setup.audio.watchForEncounter(setup.encounter.id).first,
        saved,
      );
    },
  );

  test(
    'explicit metadata deletion returns only the durable storage key',
    () async {
      final setup = await _setup(temporaryDirectory);
      addTearDown(setup.database.close);
      await setup.audio.attach(
        _draft(),
        encounterId: setup.encounter.id,
        revisionId: setup.encounter.currentRevisionId,
        durableKey: 'audio/delete-me.m4a',
        byteSize: 100,
      );

      expect(
        await setup.audio.deleteMetadata(setup.encounter.id),
        'audio/delete-me.m4a',
      );
      expect(
        await setup.audio.watchForEncounter(setup.encounter.id).first,
        isNull,
      );
      expect(await setup.audio.deleteMetadata(setup.encounter.id), isNull);
    },
  );

  test('validates capture metadata in release-safe constructors', () async {
    expect(
      () => MemoryAudioDraft(
        temporaryKey: 'take-1',
        mimeType: 'text/plain',
        duration: const Duration(seconds: 1),
        waveform: const [0.5],
      ),
      throwsArgumentError,
    );
    expect(
      () => MemoryAudioDraft(
        temporaryKey: 'take-1',
        mimeType: 'audio/mp4',
        duration: Duration.zero,
        waveform: const [0.5],
      ),
      throwsArgumentError,
    );
    expect(
      () => MemoryAudioDraft(
        temporaryKey: 'take-1',
        mimeType: 'audio/mp4',
        duration: const Duration(minutes: 16),
        waveform: const [0.5],
      ),
      throwsArgumentError,
    );
    expect(
      () => MemoryAudioDraft(
        temporaryKey: 'take-1',
        mimeType: 'audio/mp4',
        duration: const Duration(seconds: 1),
        waveform: const [],
      ),
      throwsArgumentError,
    );
    expect(
      () => MemoryAudioDraft(
        temporaryKey: 'take-1',
        mimeType: 'audio/mp4',
        duration: const Duration(seconds: 1),
        waveform: [double.nan],
      ),
      throwsArgumentError,
    );

    final clamped = MemoryAudioDraft(
      temporaryKey: 'take-1',
      mimeType: 'audio/mp4',
      duration: const Duration(seconds: 1),
      waveform: const [-1, 0.5, 2],
    );
    expect(clamped.waveform, [0, 0.5, 1]);
  });

  test('rejects malformed durable metadata before writing', () async {
    final setup = await _setup(temporaryDirectory);
    addTearDown(setup.database.close);

    for (final byteSize in [0, 64 * 1024 * 1024 + 1]) {
      await expectLater(
        setup.audio.attach(
          _draft(),
          encounterId: setup.encounter.id,
          revisionId: setup.encounter.currentRevisionId,
          durableKey: 'audio/invalid.m4a',
          byteSize: byteSize,
        ),
        throwsArgumentError,
      );
    }
  });
}

MemoryAudioDraft _draft() => MemoryAudioDraft(
  temporaryKey: 'tmp/take-1.m4a',
  mimeType: 'audio/mp4',
  duration: const Duration(seconds: 12),
  waveform: const [0.1, 0.4, 0.8, 0.3],
);

Future<
  ({
    AppDatabase database,
    PowerSyncEncounterRepository encounters,
    PowerSyncMemoryAudioRepository audio,
    Encounter encounter,
  })
>
_setup(Directory directory) async {
  final database = await openTestDatabase('${directory.path}/soulbuddy.db');
  final encounters = PowerSyncEncounterRepository(
    database: database.powersync,
    ownerId: 'owner-1',
    deviceId: 'device-1',
    now: () => DateTime.utc(2026, 8, 13, 12),
  );
  final encounter = await encounters.create(
    const EncounterDraft(
      title: 'A voice to remember',
      body: '',
      occurredOn: '2026-08-13',
      isAltar: false,
    ),
  );
  final audio = PowerSyncMemoryAudioRepository(
    database: database.powersync,
    ownerId: 'owner-1',
    now: () => DateTime.utc(2026, 8, 13, 12),
  );
  return (
    database: database,
    encounters: encounters,
    audio: audio,
    encounter: encounter,
  );
}

Future<void> _drainCrud(PowerSyncDatabase database) async {
  while (true) {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;
    await transaction.complete();
  }
}
