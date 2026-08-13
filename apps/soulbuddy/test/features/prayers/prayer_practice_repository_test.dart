import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';
import 'package:soulbuddy/core/database/app_database.dart';
import 'package:soulbuddy/features/prayers/data/powersync_prayer_practice_repository.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/powersync_test_database.dart';

const prayerId = '0198a900-0000-7000-8000-000000000001';
const revisionId = '0198a900-0000-7000-8000-000000000002';
const libraryPrayerId = '0198a100-0000-7000-8000-000000000001';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-prayer-practice-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('persists one synchronized reminder and local device opt-in', () async {
    final database = await _openSeededDatabase(temporaryDirectory, 'save');
    addTearDown(database.close);
    final repository = _repository(database);

    final reminder = await repository.saveReminder(
      personalPrayerId: prayerId,
      schedule: PrayerReminderSchedule.daily(
        localTime: PrayerLocalTime(hour: 7, minute: 30),
        timezone: 'Africa/Lagos',
      ),
      enableOnThisDevice: true,
    );

    final saved = await repository.watchReminder(prayerId).first;
    final device = await repository.watchDevice(reminder.id).first;
    expect(saved?.schedule.type, PrayerScheduleType.daily);
    expect(saved?.schedule.localTime.wireValue, '07:30');
    expect(saved?.schedule.timezone, 'Africa/Lagos');
    expect(device?.enabledOnDevice, isTrue);
    expect(device?.deviceId, 'device-1');
    expect(
      await database.powersync.getAll('SELECT id FROM prayer_reminders'),
      hasLength(1),
    );
    expect(
      await database.powersync.getAll('SELECT id FROM prayer_reminder_devices'),
      hasLength(1),
    );
    final upload = await database.powersync.getNextCrudTransaction();
    expect(upload?.crud.map((entry) => entry.table), ['prayer_reminders']);
  });

  test('surfaces a newly enabled device before its first schedule', () async {
    final database = await _openSeededDatabase(temporaryDirectory, 'pending');
    addTearDown(database.close);
    final repository = _repository(database);

    final reminder = await repository.saveReminder(
      personalPrayerId: prayerId,
      schedule: PrayerReminderSchedule.daily(
        localTime: PrayerLocalTime(hour: 7, minute: 30),
        timezone: 'Africa/Lagos',
      ),
      enableOnThisDevice: true,
    );

    final scheduled = await repository
        .watchDue(DateTime.utc(9999, 12, 31))
        .first;
    expect(scheduled.single.reminder.id, reminder.id);
    expect(scheduled.single.device.nextOccurrenceAt, isNull);
    expect(scheduled.single.occurrenceAt, isNull);
  });

  test('keeps notification enablement isolated to each device', () async {
    final database = await _openSeededDatabase(temporaryDirectory, 'devices');
    addTearDown(database.close);
    final first = _repository(database);
    final reminder = await first.saveReminder(
      personalPrayerId: prayerId,
      schedule: PrayerReminderSchedule.daily(
        localTime: PrayerLocalTime(hour: 8, minute: 0),
        timezone: 'Africa/Lagos',
      ),
      enableOnThisDevice: true,
    );
    final second = _repository(database, deviceId: 'device-2');

    await second.setDeviceEnabled(reminder.id, enabled: false);

    expect(
      (await first.watchDevice(reminder.id).first)?.enabledOnDevice,
      isTrue,
    );
    expect(
      (await second.watchDevice(reminder.id).first)?.enabledOnDevice,
      isFalse,
    );
    expect(await second.watchDue(DateTime.utc(9999, 12, 31)).first, isEmpty);
    expect(
      await database.powersync.getAll('SELECT id FROM prayer_reminders'),
      hasLength(1),
    );
  });

  test(
    'keeps narration consent cache and autoplay local to one device',
    () async {
      final database = await _openSeededDatabase(
        temporaryDirectory,
        'narration',
      );
      addTearDown(database.close);
      final first = _repository(database);
      final reminder = await first.saveReminder(
        personalPrayerId: prayerId,
        schedule: PrayerReminderSchedule.daily(
          localTime: PrayerLocalTime(hour: 8, minute: 0),
          timezone: 'Africa/Lagos',
        ),
        enableOnThisDevice: true,
      );

      await first.saveNarrationPreference(
        reminderId: reminder.id,
        consentAccepted: true,
        autoplayWhenOpened: true,
        revisionId: revisionId,
        bytes: [1, 2, 3],
        contentType: 'audio/mpeg',
      );

      final saved = await first.watchDevice(reminder.id).first;
      expect(saved?.narrationConsentAccepted, isTrue);
      expect(saved?.autoplayWhenOpened, isTrue);
      expect(saved?.narrationRevisionId, revisionId);
      expect(saved?.narrationBytes, [1, 2, 3]);
      final second = _repository(database, deviceId: 'device-2');
      await second.setDeviceEnabled(reminder.id, enabled: true);
      expect(
        (await second.watchDevice(reminder.id).first)?.autoplayWhenOpened,
        isFalse,
      );
      await _drainCrud(database.powersync);
      expect(await database.powersync.getNextCrudTransaction(), isNull);
    },
  );

  test('narration preference never resumes a paused reminder', () async {
    final database = await _openSeededDatabase(
      temporaryDirectory,
      'narration-paused',
    );
    addTearDown(database.close);
    final repository = _repository(database);
    final reminder = await repository.saveReminder(
      personalPrayerId: prayerId,
      schedule: PrayerReminderSchedule.daily(
        localTime: PrayerLocalTime(hour: 8, minute: 0),
        timezone: 'Africa/Lagos',
      ),
      enableOnThisDevice: true,
    );
    await repository.setDeviceEnabled(reminder.id, enabled: false);

    await repository.saveNarrationPreference(
      reminderId: reminder.id,
      consentAccepted: true,
      autoplayWhenOpened: true,
      revisionId: revisionId,
      bytes: [1, 2, 3],
      contentType: 'audio/mpeg',
    );

    expect(
      (await repository.watchDevice(reminder.id).first)?.enabledOnDevice,
      isFalse,
    );
  });

  test(
    'narration initializes a synced reminder as paused on this device',
    () async {
      final database = await _openSeededDatabase(
        temporaryDirectory,
        'narration-new-device',
      );
      addTearDown(database.close);
      final first = _repository(database);
      final reminder = await first.saveReminder(
        personalPrayerId: prayerId,
        schedule: PrayerReminderSchedule.daily(
          localTime: PrayerLocalTime(hour: 8, minute: 0),
          timezone: 'Africa/Lagos',
        ),
        enableOnThisDevice: true,
      );
      final second = _repository(database, deviceId: 'device-2');

      await second.saveNarrationPreference(
        reminderId: reminder.id,
        consentAccepted: true,
        autoplayWhenOpened: true,
        revisionId: revisionId,
        bytes: [1, 2, 3],
        contentType: 'audio/mpeg',
      );

      final device = await second.watchDevice(reminder.id).first;
      expect(device?.enabledOnDevice, isFalse);
      expect(device?.autoplayWhenOpened, isTrue);
      expect(device?.narrationBytes, [1, 2, 3]);
    },
  );

  test('refuses autoplay without consent and exact cached narration', () async {
    final database = await _openSeededDatabase(
      temporaryDirectory,
      'narration-invalid',
    );
    addTearDown(database.close);
    final repository = _repository(database);
    final reminder = await repository.saveReminder(
      personalPrayerId: prayerId,
      schedule: PrayerReminderSchedule.daily(
        localTime: PrayerLocalTime(hour: 8, minute: 0),
        timezone: 'Africa/Lagos',
      ),
      enableOnThisDevice: true,
    );
    await _drainCrud(database.powersync);

    expect(
      () => repository.saveNarrationPreference(
        reminderId: reminder.id,
        consentAccepted: false,
        autoplayWhenOpened: true,
      ),
      throwsArgumentError,
    );
  });

  test(
    'updates and archives the existing reminder without adding rows',
    () async {
      final database = await _openSeededDatabase(temporaryDirectory, 'replace');
      addTearDown(database.close);
      final repository = _repository(database);
      final original = await repository.saveReminder(
        personalPrayerId: prayerId,
        schedule: PrayerReminderSchedule.daily(
          localTime: PrayerLocalTime(hour: 7, minute: 0),
          timezone: 'Africa/Lagos',
        ),
        enableOnThisDevice: true,
      );

      final updated = await repository.saveReminder(
        personalPrayerId: prayerId,
        schedule: PrayerReminderSchedule.weekdays(
          localTime: PrayerLocalTime(hour: 18, minute: 15),
          timezone: 'Africa/Lagos',
          weekdaysMask: 21,
        ),
        enableOnThisDevice: true,
      );

      expect(updated.id, original.id);
      expect(updated.schedule.type, PrayerScheduleType.weekdays);
      expect(updated.schedule.weekdaysMask, 21);
      expect(
        await database.powersync.getAll('SELECT id FROM prayer_reminders'),
        hasLength(1),
      );

      await repository.archiveReminder(original.id);

      expect(await repository.watchReminder(prayerId).first, isNull);
      expect(
        (await repository.watchDevice(original.id).first)?.enabledOnDevice,
        isFalse,
      );
    },
  );

  test(
    'rejects malformed schedules and foreign prayers before a write',
    () async {
      final database = await _openSeededDatabase(temporaryDirectory, 'invalid');
      addTearDown(database.close);
      final repository = _repository(database, ownerId: 'owner-2');

      expect(
        () => PrayerReminderSchedule.weekdays(
          localTime: PrayerLocalTime(hour: 7, minute: 0),
          timezone: 'Africa/Lagos',
          weekdaysMask: 0,
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.saveReminder(
          personalPrayerId: prayerId,
          schedule: PrayerReminderSchedule.daily(
            localTime: PrayerLocalTime(hour: 7, minute: 0),
            timezone: 'Africa/Lagos',
          ),
          enableOnThisDevice: true,
        ),
        throwsStateError,
      );
      expect(
        await database.powersync.getAll('SELECT id FROM prayer_reminders'),
        isEmpty,
      );
    },
  );

  test(
    'records one exact-revision session for a reminder occurrence',
    () async {
      final database = await _openSeededDatabase(temporaryDirectory, 'session');
      addTearDown(database.close);
      final repository = _repository(database);
      final reminder = await repository.saveReminder(
        personalPrayerId: prayerId,
        schedule: PrayerReminderSchedule.daily(
          localTime: PrayerLocalTime(hour: 7, minute: 30),
          timezone: 'Africa/Lagos',
        ),
        enableOnThisDevice: true,
      );
      const occurrenceKey = '$prayerId@2026-08-11T06:30:00.000Z';

      final first = await repository.recordSession(
        prayer: const PrayerReference.personal(prayerId),
        revisionId: revisionId,
        timezone: 'Africa/Lagos',
        reminderId: reminder.id,
        occurrenceKey: occurrenceKey,
      );
      final replay = await repository.recordSession(
        prayer: const PrayerReference.personal(prayerId),
        revisionId: revisionId,
        timezone: 'Africa/Lagos',
        reminderId: reminder.id,
        occurrenceKey: occurrenceKey,
      );

      expect(replay.id, first.id);
      expect(first.prayerRevisionId, revisionId);
      expect(first.reminderOccurrenceKey, occurrenceKey);
      expect(await repository.watchSessionCount(revisionId).first, 1);
      expect(
        await database.powersync.getAll('SELECT id FROM prayer_sessions'),
        hasLength(1),
      );
    },
  );

  test(
    'records and watches a factual library prayer session by date',
    () async {
      final database = await _openSeededDatabase(temporaryDirectory, 'library');
      addTearDown(database.close);
      await _seedBundledLibraryPrayer(database.powersync);
      await _drainCrud(database.powersync);
      final repository = _repository(database);
      const reference = PrayerReference.library(libraryPrayerId);

      final session = await repository.recordSession(
        prayer: reference,
        timezone: 'Africa/Lagos',
      );

      expect(session.prayer, reference);
      expect(session.prayerRevisionId, isNull);
      expect(
        await repository
            .watchSessionForDate(reference, DateTime(2026, 8, 11))
            .first,
        isTrue,
      );
      expect(
        await repository
            .watchSessionForDate(reference, DateTime(2026, 8, 12))
            .first,
        isFalse,
      );
    },
  );

  test('matches a personal session by its exact immutable revision', () async {
    final database = await _openSeededDatabase(temporaryDirectory, 'revision');
    addTearDown(database.close);
    final repository = _repository(database);
    const reference = PrayerReference.personal(prayerId);

    await repository.recordSession(
      prayer: reference,
      revisionId: revisionId,
      timezone: 'Africa/Lagos',
    );

    expect(
      await repository
          .watchSessionForDate(
            reference,
            DateTime(2026, 8, 11),
            revisionId: revisionId,
          )
          .first,
      isTrue,
    );
    expect(
      await repository
          .watchSessionForDate(
            reference,
            DateTime(2026, 8, 11),
            revisionId: '0198a900-0000-7000-8000-000000000099',
          )
          .first,
      isFalse,
    );
  });

  test('enforces revision shape before writing either prayer source', () async {
    final database = await _openSeededDatabase(temporaryDirectory, 'shape');
    addTearDown(database.close);
    await _seedBundledLibraryPrayer(database.powersync);
    await _drainCrud(database.powersync);
    final repository = _repository(database);

    expect(
      () => repository.recordSession(
        prayer: const PrayerReference.library(libraryPrayerId),
        revisionId: revisionId,
        timezone: 'Africa/Lagos',
      ),
      throwsArgumentError,
    );
    expect(
      () => repository.recordSession(
        prayer: const PrayerReference.personal(prayerId),
        timezone: 'Africa/Lagos',
      ),
      throwsArgumentError,
    );
    expect(
      await database.powersync.getAll('SELECT id FROM prayer_sessions'),
      isEmpty,
    );
  });

  test('rejects invalid local times in release-safe constructors', () {
    expect(() => PrayerLocalTime(hour: 24, minute: 0), throwsArgumentError);
    expect(() => PrayerLocalTime(hour: 7, minute: 60), throwsArgumentError);
    expect(
      () => PrayerReminderSchedule.daily(
        localTime: PrayerLocalTime(hour: 7, minute: 0),
        timezone: ' ',
      ),
      throwsArgumentError,
    );
  });

  test('binds manual sessions to the currently displayed revision', () async {
    final database = await _openSeededDatabase(temporaryDirectory, 'stale');
    addTearDown(database.close);
    final repository = _repository(database);
    await database.powersync.execute(
      'UPDATE personal_prayers SET current_revision_id = ? WHERE id = ?',
      ['0198a900-0000-7000-8000-000000000099', prayerId],
    );

    await expectLater(
      repository.recordSession(
        prayer: const PrayerReference.personal(prayerId),
        revisionId: revisionId,
        timezone: 'Africa/Lagos',
      ),
      throwsStateError,
    );
    expect(
      await database.powersync.getAll('SELECT id FROM prayer_sessions'),
      isEmpty,
    );
  });

  test(
    'retracts within five minutes and excludes the session from count',
    () async {
      var now = DateTime(2026, 8, 11, 8, 0);
      final database = await _openSeededDatabase(temporaryDirectory, 'undo');
      addTearDown(database.close);
      final repository = _repository(database, now: () => now);
      final session = await repository.recordSession(
        prayer: const PrayerReference.personal(prayerId),
        revisionId: revisionId,
        timezone: 'Africa/Lagos',
      );
      now = DateTime(2026, 8, 11, 8, 4, 59);

      await repository.retractSession(session.id);

      expect(await repository.watchSessionCount(revisionId).first, 0);
      final row = await database.powersync.get(
        'SELECT retracted_at FROM prayer_sessions WHERE id = ?',
        [session.id],
      );
      expect(row['retracted_at'], isNotNull);
    },
  );

  test('refuses retraction after five minutes', () async {
    var now = DateTime(2026, 8, 11, 8, 0);
    final database = await _openSeededDatabase(temporaryDirectory, 'late');
    addTearDown(database.close);
    final repository = _repository(database, now: () => now);
    final session = await repository.recordSession(
      prayer: const PrayerReference.personal(prayerId),
      revisionId: revisionId,
      timezone: 'Africa/Lagos',
    );
    now = DateTime(2026, 8, 11, 8, 5, 1);

    await expectLater(repository.retractSession(session.id), throwsStateError);
    expect(await repository.watchSessionCount(revisionId).first, 1);
  });

  test('stores the session date in the selected IANA timezone', () async {
    final database = await _openSeededDatabase(temporaryDirectory, 'date');
    addTearDown(database.close);
    final repository = _repository(
      database,
      now: () => DateTime.utc(2026, 8, 11, 23, 30),
    );

    final session = await repository.recordSession(
      prayer: const PrayerReference.personal(prayerId),
      revisionId: revisionId,
      timezone: 'Africa/Lagos',
    );

    expect(session.localDate, DateTime(2026, 8, 12));
  });
}

PowerSyncPrayerPracticeRepository _repository(
  AppDatabase database, {
  String ownerId = 'owner-1',
  String deviceId = 'device-1',
  DateTime Function()? now,
}) {
  return PowerSyncPrayerPracticeRepository(
    database: database.powersync,
    ownerId: ownerId,
    deviceId: deviceId,
    now: now ?? () => DateTime(2026, 8, 11, 8),
    uuid: const Uuid(),
  );
}

Future<AppDatabase> _openSeededDatabase(
  Directory directory,
  String name,
) async {
  final database = await openTestDatabase('${directory.path}/$name.db');
  await _seedPersonalPrayer(database.powersync);
  await _drainCrud(database.powersync);
  return database;
}

Future<void> _drainCrud(PowerSyncDatabase database) async {
  while (true) {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;
    await transaction.complete();
  }
}

Future<void> _seedPersonalPrayer(PowerSyncDatabase database) async {
  await database.execute(
    '''
    INSERT INTO personal_prayers(
      id, owner_id, title, style, reach, grounding, purpose,
      current_revision_id, created_at, updated_at, archived_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
    ''',
    [
      prayerId,
      'owner-1',
      'A prayer I saved',
      'daily',
      'personal',
      'general_christian',
      'daily',
      revisionId,
      '2026-08-11T07:00:00.000Z',
      '2026-08-11T07:00:00.000Z',
    ],
  );
  await database.execute(
    '''
    INSERT INTO personal_prayer_revisions(
      id, prayer_id, owner_id, body, action, created_at, device_id
    ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      revisionId,
      prayerId,
      'owner-1',
      'Father, keep me near you today. Amen.',
      null,
      '2026-08-11T07:00:00.000Z',
      'device-1',
    ],
  );
}

Future<void> _seedBundledLibraryPrayer(PowerSyncDatabase database) {
  return database.execute(
    '''
    INSERT INTO bundled_prayers(
      id, title, body, grounding, purpose, action, helpful_count,
      content_version, archived_at
    ) VALUES (?, ?, ?, ?, ?, ?, 0, 1, NULL)
    ''',
    [
      libraryPrayerId,
      'For this day',
      'Father, keep me near you through this day. Amen.',
      'general_christian',
      'daily',
      null,
    ],
  );
}
