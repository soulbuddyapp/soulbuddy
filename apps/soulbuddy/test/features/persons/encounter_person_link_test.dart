import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/persons/data/powersync_person_repository.dart';
import 'package:soulbuddy/features/persons/domain/prayer_person.dart';
import 'package:soulbuddy/features/record/data/powersync_encounter_repository.dart';
import 'package:soulbuddy/features/record/domain/encounter_draft.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  test(
    'links a memory to multiple owned persons and hides links on archive',
    () async {
      final directory = await Directory.systemTemp.createTemp('person-links-');
      addTearDown(() => directory.delete(recursive: true));
      final database = await openTestDatabase('${directory.path}/links.db');
      addTearDown(database.close);
      final people = PowerSyncPersonRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        deviceId: 'device-1',
      );
      final encounters = PowerSyncEncounterRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        deviceId: 'device-1',
      );
      final mum = await people.create(const PrayerPersonDraft(name: 'Mum'));
      final daniel = await people.create(
        const PrayerPersonDraft(name: 'Daniel'),
      );

      final memory = await encounters.create(
        EncounterDraft(
          title: 'Help arrived',
          body: 'They called at the right time.',
          occurredOn: '2026-08-30',
          isAltar: false,
          personIds: [mum.id, daniel.id, mum.id],
        ),
      );

      expect(await people.watchLinkedMemories(mum.id).first, hasLength(1));
      expect(await people.watchLinkedMemories(daniel.id).first, hasLength(1));

      await encounters.archive(memory.id);
      expect(await people.watchLinkedMemories(mum.id).first, isEmpty);
      final rows = await database.powersync.getAll(
        'SELECT id FROM encounter_person_links WHERE encounter_id = ?',
        [memory.id],
      );
      expect(rows, isEmpty);
    },
  );

  test('rejects links to another owner person', () async {
    final directory = await Directory.systemTemp.createTemp('person-owner-');
    addTearDown(() => directory.delete(recursive: true));
    final database = await openTestDatabase('${directory.path}/owner.db');
    addTearDown(database.close);
    final foreign = PowerSyncPersonRepository(
      database: database.powersync,
      ownerId: 'owner-2',
      deviceId: 'device-2',
    );
    final encounters = PowerSyncEncounterRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
    );
    final person = await foreign.create(
      const PrayerPersonDraft(name: 'Private'),
    );

    await expectLater(
      encounters.create(
        EncounterDraft(
          title: 'Not allowed',
          body: '',
          occurredOn: '2026-08-30',
          isAltar: false,
          personIds: [person.id],
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });
}
