import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/record/data/powersync_encounter_repository.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/record/domain/encounter_draft.dart';
import 'package:soulbuddy/features/remember/data/powersync_daily_memory_repository.dart';
import 'package:soulbuddy/features/remember/domain/daily_memory.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-daily-memory-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'chooses the highest-priority eligible memory and keeps it stable',
    () async {
      final path = '${temporaryDirectory.path}/soulbuddy.db';
      final database = await openTestDatabase(path);
      final encounters = PowerSyncEncounterRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        deviceId: 'device-1',
        now: () => DateTime.utc(2026, 8, 12, 8),
      );
      await encounters.create(
        const EncounterDraft(
          title: 'A revelation',
          body: '',
          occurredOn: '2026-08-11',
          isAltar: false,
          memoryType: MemoryType.revelation,
        ),
      );
      final promise = await encounters.create(
        const EncounterDraft(
          title: 'A promise before God',
          body: '',
          occurredOn: '2026-08-10',
          isAltar: true,
          memoryType: MemoryType.promise,
        ),
      );
      final repository = PowerSyncDailyMemoryRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        now: () => DateTime.utc(2026, 8, 12, 8),
      );

      final first = await repository.ensureForDate(DateTime(2026, 8, 12));
      final again = await repository.ensureForDate(DateTime(2026, 8, 12, 23));

      expect(first?.memory.id, promise.id);
      expect(again?.occurrenceId, first?.occurrenceId);
      await database.close();

      final reopened = await openTestDatabase(path);
      addTearDown(reopened.close);
      final reopenedRepository = PowerSyncDailyMemoryRepository(
        database: reopened.powersync,
        ownerId: 'owner-1',
      );
      final persisted = await reopenedRepository
          .watchForDate(DateTime(2026, 8, 12))
          .first;
      expect(persisted?.memory.id, promise.id);
    },
  );

  test('excludes paused records and respects the recall interval', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);
    final encounters = PowerSyncEncounterRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      now: () => DateTime.utc(2026, 8, 12),
    );
    final paused = await encounters.create(
      const EncounterDraft(
        title: 'Paused promise',
        body: '',
        occurredOn: '2026-08-10',
        isAltar: false,
        memoryType: MemoryType.promise,
        recallPaused: true,
      ),
    );
    final revelation = await encounters.create(
      const EncounterDraft(
        title: 'Patient understanding',
        body: '',
        occurredOn: '2026-08-10',
        isAltar: false,
        memoryType: MemoryType.revelation,
        recallIntervalDays: 7,
      ),
    );
    final repository = PowerSyncDailyMemoryRepository(
      database: database.powersync,
      ownerId: 'owner-1',
    );
    final first = await repository.ensureForDate(DateTime(2026, 8, 12));
    final tooSoon = await repository.ensureForDate(DateTime(2026, 8, 13));

    expect(first?.memory.id, revelation.id);
    expect(first?.memory.id, isNot(paused.id));
    expect(tooSoon, isNull);
  });

  test(
    'choose another and status updates target the displayed occurrence',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/soulbuddy.db',
      );
      addTearDown(database.close);
      final encounters = PowerSyncEncounterRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        deviceId: 'device-1',
      );
      for (final title in ['First promise', 'Second promise']) {
        await encounters.create(
          EncounterDraft(
            title: title,
            body: '',
            occurredOn: '2026-08-10',
            isAltar: false,
            memoryType: MemoryType.promise,
          ),
        );
      }
      final repository = PowerSyncDailyMemoryRepository(
        database: database.powersync,
        ownerId: 'owner-1',
      );
      final first = await repository.ensureForDate(DateTime(2026, 8, 12));
      final other = await repository.chooseAnother(
        DateTime(2026, 8, 12),
        expectedEncounterId: first!.memory.id,
      );
      await repository.setStatus(
        DateTime(2026, 8, 12),
        expectedEncounterId: other!.memory.id,
        status: DailyMemoryStatus.remembered,
      );
      await repository.setStatus(
        DateTime(2026, 8, 12),
        expectedEncounterId: first.memory.id,
        status: DailyMemoryStatus.postponed,
      );

      final saved = await repository.watchForDate(DateTime(2026, 8, 12)).first;
      expect(other.memory.id, isNot(first.memory.id));
      expect(saved?.status, DailyMemoryStatus.remembered);
    },
  );
}
