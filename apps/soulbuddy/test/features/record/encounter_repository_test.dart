import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}
