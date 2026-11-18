import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';
import 'package:soulbuddy/core/database/app_database.dart';
import 'package:soulbuddy/features/record/audio/data/powersync_memory_audio_repository.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';
import 'package:soulbuddy/features/record/data/powersync_encounter_repository.dart';
import 'package:soulbuddy/features/record/data/voice_note_repository.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/record/domain/encounter_draft.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory directory;
  late AppDatabase database;
  const scope = (type: 'goal', id: 'goal-1', field: 'situation');

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('soulbuddy-voice-notes-');
    database = await openTestDatabase('${directory.path}/notes.db');
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  VoiceNoteRepository notes(String ownerId) =>
      VoiceNoteRepository(database: database.powersync, ownerId: ownerId);

  test(
    'reads only the owner’s memories, even with a forged local link',
    () async {
      final first = await _memory(
        database.powersync,
        ownerId: 'owner-1',
        title: 'My note',
      );
      final other = await _memory(
        database.powersync,
        ownerId: 'owner-2',
        title: 'Other note',
      );
      await notes('owner-1').attach(scope, first.id);
      await notes('owner-2').attach(scope, other.id);
      await database.powersync.execute(
        'INSERT INTO voice_note_links '
        '(id, owner_id, context_type, context_id, field_key, encounter_id, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          'forged-link',
          'owner-1',
          'goal',
          'goal-1',
          'situation',
          other.id,
          '2026-11-03T00:00:00Z',
        ],
      );

      final firstNotes = await notes('owner-1').watch(scope).first;
      final otherNotes = await notes('owner-2').watch(scope).first;
      expect(firstNotes.map((note) => note.encounterId), [first.id]);
      expect(firstNotes.single.title, 'My note');
      expect(otherNotes.map((note) => note.encounterId), [other.id]);
      expect(await notes('owner-3').watch(scope).first, isEmpty);
    },
  );

  test(
    'attachment requires owned, active memory and owned audio metadata',
    () async {
      final textOnly = await _memory(
        database.powersync,
        ownerId: 'owner-1',
        title: 'Earlier writing',
        withAudio: false,
      );
      final archived = await _memory(
        database.powersync,
        ownerId: 'owner-1',
        title: 'Archived',
      );
      await _encounters(database.powersync, 'owner-1').archive(archived.id);
      final foreign = await _memory(
        database.powersync,
        ownerId: 'owner-2',
        title: 'Private',
      );
      final mismatched = await _memory(
        database.powersync,
        ownerId: 'owner-1',
        title: 'Mismatched',
      );
      await database.powersync.execute(
        'UPDATE memory_audio_assets SET owner_id = ? WHERE encounter_id = ?',
        ['owner-2', mismatched.id],
      );

      for (final id in [
        'missing-memory',
        textOnly.id,
        archived.id,
        foreign.id,
        mismatched.id,
      ]) {
        await expectLater(notes('owner-1').attach(scope, id), throwsStateError);
      }
      expect(
        await database.powersync.getAll('SELECT id FROM voice_note_links'),
        isEmpty,
      );

      final valid = await _memory(
        database.powersync,
        ownerId: 'owner-1',
        title: 'A recording',
      );
      await notes('owner-1').attach(scope, valid.id);
      expect(
        (await notes('owner-1').watch(scope).first).single.encounterId,
        valid.id,
      );
    },
  );

  test(
    'concurrent retries deduplicate the same context and recording',
    () async {
      final memory = await _memory(
        database.powersync,
        ownerId: 'owner-1',
        title: 'One take',
      );
      final repository = notes('owner-1');
      await Future.wait([
        repository.attach(scope, memory.id),
        repository.attach(scope, memory.id),
      ]);
      final firstRows = await database.powersync.getAll(
        'SELECT id FROM voice_note_links',
      );
      expect(firstRows, hasLength(1));
      await repository.attach(scope, memory.id);
      expect(
        await database.powersync.getAll('SELECT id FROM voice_note_links'),
        firstRows,
      );

      await repository.attach((
        type: 'goal',
        id: 'goal-1',
        field: 'action',
      ), memory.id);
      expect(await repository.watch(scope).first, hasLength(1));
      expect(
        await database.powersync.getAll('SELECT id FROM voice_note_links'),
        hasLength(2),
      );
    },
  );

  test(
    'wildcard reads all fields within one context and hides archived memories',
    () async {
      final repository = notes('owner-1');
      final situation = await _memory(
        database.powersync,
        ownerId: 'owner-1',
        title: 'Situation',
      );
      final action = await _memory(
        database.powersync,
        ownerId: 'owner-1',
        title: 'Action',
      );
      final elsewhere = await _memory(
        database.powersync,
        ownerId: 'owner-1',
        title: 'Elsewhere',
      );
      await repository.attach(scope, situation.id);
      await repository.attach((
        type: 'goal',
        id: 'goal-1',
        field: 'action',
      ), action.id);
      await repository.attach((
        type: 'goal',
        id: 'goal-2',
        field: 'situation',
      ), elsewhere.id);
      await repository.attach((
        type: 'person',
        id: 'goal-1',
        field: 'situation',
      ), elsewhere.id);
      const allFields = (type: 'goal', id: 'goal-1', field: '*');

      expect(
        (await repository.watch(allFields).first).map(
          (note) => note.encounterId,
        ),
        unorderedEquals([situation.id, action.id]),
      );
      expect(
        (await repository.watch(scope).first).single.encounterId,
        situation.id,
      );

      await _encounters(database.powersync, 'owner-1').archive(situation.id);
      expect(
        (await repository.watch(allFields).first).single.encounterId,
        action.id,
      );
      expect(await repository.watch(scope).first, isEmpty);
    },
  );

  test(
    'moving a draft preserves other owners, types, and field names',
    () async {
      final repository = notes('owner-1');
      final one = await _memory(
        database.powersync,
        ownerId: 'owner-1',
        title: 'One',
      );
      final two = await _memory(
        database.powersync,
        ownerId: 'owner-1',
        title: 'Two',
      );
      final other = await _memory(
        database.powersync,
        ownerId: 'owner-2',
        title: 'Other',
      );
      const draft = (type: 'goal', id: 'draft', field: 'situation');
      await repository.attach(draft, one.id);
      await repository.attach((
        type: 'goal',
        id: 'draft',
        field: 'action',
      ), two.id);
      await repository.attach((
        type: 'person',
        id: 'draft',
        field: 'notes',
      ), one.id);
      await notes('owner-2').attach(draft, other.id);

      await repository.move(type: 'goal', fromId: 'draft', toId: 'saved-goal');

      expect(await repository.watch(draft).first, isEmpty);
      expect(
        (await repository.watch((
          type: 'goal',
          id: 'saved-goal',
          field: 'situation',
        )).first).single.encounterId,
        one.id,
      );
      expect(
        (await repository.watch((
          type: 'goal',
          id: 'saved-goal',
          field: 'action',
        )).first).single.encounterId,
        two.id,
      );
      expect(
        (await notes('owner-2').watch(draft).first).single.encounterId,
        other.id,
      );
      expect(
        (await repository.watch((
          type: 'person',
          id: 'draft',
          field: 'notes',
        )).first).single.encounterId,
        one.id,
      );
    },
  );

  test('context links survive reopen and never enter upload CRUD', () async {
    final memory = await _memory(
      database.powersync,
      ownerId: 'owner-1',
      title: 'Keep my voice',
    );
    await _drainCrud(database.powersync);
    await notes('owner-1').attach(scope, memory.id);
    await notes(
      'owner-1',
    ).move(type: 'goal', fromId: 'goal-1', toId: 'saved-goal');
    expect(await database.powersync.getNextCrudTransaction(), isNull);

    await database.close();
    database = await openTestDatabase('${directory.path}/notes.db');
    final kept = await notes(
      'owner-1',
    ).watch((type: 'goal', id: 'saved-goal', field: 'situation')).first;
    expect(kept.single.encounterId, memory.id);
    expect(kept.single.title, 'Keep my voice');
    expect(
      await database.powersync.getAll('SELECT id FROM memory_audio_assets'),
      hasLength(1),
    );
    expect(await database.powersync.getNextCrudTransaction(), isNull);
  });
}

PowerSyncEncounterRepository _encounters(
  PowerSyncDatabase database,
  String ownerId,
) => PowerSyncEncounterRepository(
  database: database,
  ownerId: ownerId,
  deviceId: 'test-device',
);

Future<Encounter> _memory(
  PowerSyncDatabase database, {
  required String ownerId,
  required String title,
  bool withAudio = true,
}) async {
  final encounter = await _encounters(database, ownerId).create(
    EncounterDraft(
      title: title,
      body: '',
      occurredOn: '2026-11-03',
      isAltar: false,
    ),
  );
  if (withAudio) {
    await PowerSyncMemoryAudioRepository(
      database: database,
      ownerId: ownerId,
    ).attach(
      MemoryAudioDraft(
        temporaryKey: 'test-take',
        mimeType: 'audio/mp4',
        duration: const Duration(seconds: 5),
        waveform: const [0.1, 0.4, 0.2],
      ),
      encounterId: encounter.id,
      revisionId: encounter.currentRevisionId,
      durableKey: 'audio/${encounter.id}.m4a',
      byteSize: 512,
    );
  }
  return encounter;
}

Future<void> _drainCrud(PowerSyncDatabase database) async {
  while (true) {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;
    await transaction.complete();
  }
}
