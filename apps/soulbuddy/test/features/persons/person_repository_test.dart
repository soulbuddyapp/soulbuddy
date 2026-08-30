import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/persons/data/powersync_person_repository.dart';
import 'package:soulbuddy/features/persons/domain/prayer_person.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-persons-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('creates, edits, and archives an owner-scoped prayer person', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/crud.db',
    );
    addTearDown(database.close);
    var now = DateTime.utc(2026, 8, 30, 8);
    final repository = PowerSyncPersonRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      now: () => now,
      uuid: const Uuid(),
    );

    final person = await repository.create(
      const PrayerPersonDraft(
        name: 'Mum',
        relationship: 'Mother',
        cadence: PersonPrayerCadence.daily,
        localTime: '07:30',
        timezone: 'Africa/Lagos',
      ),
    );
    expect(person.name, 'Mum');
    expect(await repository.watchActive().first, hasLength(1));

    now = now.add(const Duration(minutes: 1));
    final edited = await repository.update(
      person.id,
      const PrayerPersonDraft(
        name: 'Mummy',
        relationship: 'Mother',
        cadence: PersonPrayerCadence.selectedDays,
        weekdaysMask: 5,
      ),
    );
    expect(edited.name, 'Mummy');
    expect(edited.weekdaysMask, 5);

    await repository.archive(person.id);
    expect(await repository.watchActive().first, isEmpty);
  });

  test('keeps reads and mutations owner scoped', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/owner.db',
    );
    addTearDown(database.close);
    final first = PowerSyncPersonRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
    );
    final second = PowerSyncPersonRepository(
      database: database.powersync,
      ownerId: 'owner-2',
      deviceId: 'device-2',
    );
    final person = await first.create(const PrayerPersonDraft(name: 'Daniel'));

    expect(await second.watch(person.id).first, isNull);
    await expectLater(
      second.update(person.id, const PrayerPersonDraft(name: 'Changed')),
      throwsA(isA<StateError>()),
    );
    await expectLater(second.archive(person.id), throwsA(isA<StateError>()));
  });

  test('selects daily, weekly, and selected-day prayer schedules', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/due.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncPersonRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      now: () => DateTime.utc(2026, 8, 31, 8),
    );
    await repository.create(
      const PrayerPersonDraft(
        name: 'Daily',
        cadence: PersonPrayerCadence.daily,
      ),
    );
    await repository.create(
      const PrayerPersonDraft(
        name: 'Weekly Monday',
        cadence: PersonPrayerCadence.weekly,
        weekdaysMask: 1,
      ),
    );
    await repository.create(
      const PrayerPersonDraft(
        name: 'Monday and Wednesday',
        cadence: PersonPrayerCadence.selectedDays,
        weekdaysMask: 5,
      ),
    );
    await repository.create(
      const PrayerPersonDraft(
        name: 'Tuesday',
        cadence: PersonPrayerCadence.weekly,
        weekdaysMask: 2,
      ),
    );

    final monday = await repository.watchDue(DateTime(2026, 8, 31)).first;
    expect(monday.map((item) => item.person.name), [
      'Daily',
      'Monday and Wednesday',
      'Weekly Monday',
    ]);
  });

  test(
    'records one prayer occurrence idempotently and removes it from due',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/pray.db',
      );
      addTearDown(database.close);
      final repository = PowerSyncPersonRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        deviceId: 'device-1',
        now: () => DateTime.utc(2026, 8, 31, 8),
      );
      final person = await repository.create(
        const PrayerPersonDraft(name: 'Ada'),
      );

      final first = await repository.recordPrayer(
        person.id,
        localDate: DateTime(2026, 8, 31),
      );
      final replay = await repository.recordPrayer(
        person.id,
        localDate: DateTime(2026, 8, 31),
      );

      expect(first, isNotNull);
      expect(replay, isNull);
      expect(await repository.watchDue(DateTime(2026, 8, 31)).first, isEmpty);
    },
  );
}
