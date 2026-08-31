import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/database/app_database.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/sacred_hours/data/powersync_sacred_hour_repository.dart';
import 'package:soulbuddy/features/sacred_hours/domain/sacred_hour.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  const ownerId = 'owner-1';
  late Directory temporaryDirectory;
  late AppDatabase database;
  late PowerSyncSacredHourRepository repository;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-sacred-hours-',
    );
    database = await openTestDatabase('${temporaryDirectory.path}/app.db');
    repository = PowerSyncSacredHourRepository(
      database: database.powersync,
      ownerId: ownerId,
      deviceId: 'device-a',
      now: () => DateTime.utc(2026, 8, 31, 0),
    );
  });

  tearDown(() async {
    await database.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('seeds exactly one morning and evening across retries', () async {
    await repository.ensureDefaults(timezone: 'Africa/Lagos');
    await repository.ensureDefaults(timezone: 'Africa/Lagos');

    final hours = await repository.watchActive().first;
    expect(hours.map((item) => item.purpose), [
      SacredHourPurpose.morning,
      SacredHourPurpose.evening,
    ]);
    expect(hours.map((item) => item.localTime.wireValue), ['06:00', '22:00']);
    expect(
      await database.powersync.getAll('SELECT id FROM sacred_hours'),
      hasLength(2),
    );
    expect(await repository.watchDeliveries().first, hasLength(2));
  });

  test('shares hours but keeps delivery rows isolated by device', () async {
    await repository.ensureDefaults(timezone: 'Africa/Lagos');
    final second = PowerSyncSacredHourRepository(
      database: database.powersync,
      ownerId: ownerId,
      deviceId: 'device-b',
      now: () => DateTime.utc(2026, 8, 31, 0),
    );

    expect(await second.watchActive().first, hasLength(2));
    expect(await second.watchDeliveries().first, isEmpty);
    await second.ensureDefaults(timezone: 'Africa/Lagos');
    expect(await second.watchDeliveries().first, hasLength(2));
    expect(
      await database.powersync.getAll('SELECT id FROM sacred_hours'),
      hasLength(2),
    );
  });

  test('finds the current hour before the next hour', () async {
    await repository.ensureDefaults(timezone: 'Africa/Lagos');

    final current = await repository
        .watchCurrentOrNext(DateTime.utc(2026, 8, 31, 5, 30))
        .first;
    final next = await repository
        .watchCurrentOrNext(DateTime.utc(2026, 8, 31, 20))
        .first;

    expect(current?.purpose, SacredHourPurpose.morning);
    expect(next?.purpose, SacredHourPurpose.evening);
  });

  test('validates prayer and Person ownership before saving links', () async {
    await _seedLibraryPrayer(database);
    await _seedPerson(database, ownerId: ownerId);
    final hour = await repository.save(
      SacredHourDraft(
        name: 'Before work',
        localTime: PrayerLocalTime(hour: 7, minute: 0),
        timezone: 'Africa/Lagos',
        prayer: const PrayerReference.library('library-prayer-1'),
        personId: 'person-1',
      ),
    );

    expect(hour.prayer, const PrayerReference.library('library-prayer-1'));
    expect(hour.personId, 'person-1');

    await expectLater(
      repository.save(
        SacredHourDraft(
          name: 'Unavailable link',
          localTime: PrayerLocalTime(hour: 8, minute: 0),
          timezone: 'Africa/Lagos',
          prayer: const PrayerReference.personal('another-owner-prayer'),
        ),
      ),
      throwsStateError,
    );
  });

  test('updates, disables, and archives only owned hours', () async {
    final hour = await repository.save(_customDraft('First', 7));
    final edited = await repository.save(
      _customDraft('Edited', 8),
      id: hour.id,
    );
    expect(edited.name, 'Edited');
    expect(edited.localTime.wireValue, '08:00');
    final editedDelivery = (await repository.watchDeliveries().first).single;
    expect(editedDelivery.nextOccurrenceAt, DateTime.utc(2026, 8, 31, 7));

    await repository.setEnabled(hour.id, false);
    expect(await repository.watchActive().first, isEmpty);
    expect(await repository.watchAll().first, hasLength(1));
    await repository.setEnabled(hour.id, true);
    await repository.archive(hour.id);
    expect(await repository.watch(hour.id).first, isNull);

    final anotherOwner = PowerSyncSacredHourRepository(
      database: database.powersync,
      ownerId: 'owner-2',
      deviceId: 'device-b',
    );
    await expectLater(anotherOwner.setEnabled(hour.id, true), throwsStateError);
  });

  test('same occurrence response is recorded once and can advance', () async {
    final hour = await repository.save(_customDraft('Morning', 6));
    final dueAt = DateTime.utc(2026, 8, 31, 5);

    await repository.markOccurrence(
      hour.id,
      dueAt,
      SacredHourOccurrenceStatus.begun,
    );
    await repository.markOccurrence(
      hour.id,
      dueAt,
      SacredHourOccurrenceStatus.begun,
    );
    await repository.markOccurrence(
      hour.id,
      dueAt,
      SacredHourOccurrenceStatus.completed,
    );

    final rows = await database.powersync.getAll(
      'SELECT * FROM sacred_hour_occurrences',
    );
    expect(rows, hasLength(1));
    expect(rows.single['status'], 'completed');
    expect(rows.single['local_date'], '2026-08-31');
  });

  test('device delivery changes never enter the sync CRUD queue', () async {
    final hour = await repository.save(_customDraft('Morning', 6));
    final synced = await database.powersync.getNextCrudTransaction();
    expect(synced, isNotNull);
    expect(synced!.crud.map((entry) => entry.table).toSet(), {'sacred_hours'});
    await _drainCrud(database);

    await repository.updateDeviceDelivery(
      hour.id,
      SacredHourDeviceDraft(
        enabledOnDevice: true,
        reminderMode: SacredHourReminderMode.precise,
        nextOccurrenceAt: DateTime.utc(2026, 8, 31, 5),
        platformNotificationId: 12345,
        scheduledTimezone: 'Africa/Lagos',
      ),
    );

    expect(await database.powersync.getNextCrudTransaction(), isNull);
    final delivery = (await repository.watchDeliveries().first).single;
    expect(delivery.reminderMode, SacredHourReminderMode.precise);
  });
}

SacredHourDraft _customDraft(String name, int hour) => SacredHourDraft(
  name: name,
  localTime: PrayerLocalTime(hour: hour, minute: 0),
  timezone: 'Africa/Lagos',
);

Future<void> _seedLibraryPrayer(AppDatabase database) async {
  await database.powersync.execute(
    '''
    INSERT INTO library_prayers(
      id, title, body, grounding, language_style, purpose, action,
      helpful_count, published_at, archived_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
    ''',
    [
      'library-prayer-1',
      'Morning prayer',
      'Father, lead me today. Amen.',
      'general_christian',
      'daily',
      'daily',
      null,
      0,
      '2026-08-31T00:00:00.000Z',
    ],
  );
}

Future<void> _seedPerson(AppDatabase database, {required String ownerId}) {
  return database.powersync.execute(
    '''
    INSERT INTO prayer_people(
      id, owner_id, name, relationship, cadence, local_time, timezone,
      weekdays_mask, created_at, updated_at, archived_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
    ''',
    [
      'person-1',
      ownerId,
      'Mum',
      'Mother',
      'daily',
      null,
      null,
      null,
      '2026-08-31T00:00:00.000Z',
      '2026-08-31T00:00:00.000Z',
    ],
  );
}

Future<void> _drainCrud(AppDatabase database) async {
  while (true) {
    final transaction = await database.powersync.getNextCrudTransaction();
    if (transaction == null) return;
    await transaction.complete();
  }
}
