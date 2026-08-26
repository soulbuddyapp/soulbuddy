import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/database/app_database.dart';
import 'package:soulbuddy/features/altar/data/powersync_altar_ritual_repository.dart';
import 'package:soulbuddy/features/altar/domain/altar_ritual.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;
  late AppDatabase database;
  late PowerSyncAltarRitualRepository repository;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-altar-ritual-',
    );
    database = await openTestDatabase('${temporaryDirectory.path}/app.db');
    repository = PowerSyncAltarRitualRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      now: () => DateTime.utc(2026, 8, 26, 6, 5),
    );
    await _seedVoiceTablet(database, 'tablet-1', 'audio-1');
    await _seedVoiceTablet(database, 'tablet-2', 'audio-2');
  });

  tearDown(() async {
    await database.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('validates daily and selected-weekday schedules', () {
    final daily = AltarRitualSchedule.daily(
      localTime: PrayerLocalTime(hour: 7, minute: 0),
      timezone: 'Africa/Lagos',
    );
    final weekdays = AltarRitualSchedule.weekdays(
      localTime: PrayerLocalTime(hour: 7, minute: 0),
      timezone: 'Africa/Lagos',
      weekdaysMask: 1 | 4,
    );

    expect(daily.weekdaysMask, isNull);
    expect(weekdays.weekdaysMask, 5);
    expect(
      () => AltarRitualSchedule.weekdays(
        localTime: PrayerLocalTime(hour: 7, minute: 0),
        timezone: 'Africa/Lagos',
        weekdaysMask: 0,
      ),
      throwsArgumentError,
    );
  });

  test('returns only the next due enabled altar ritual', () async {
    final first = await repository.save(_dailyAt(7, 'tablet-1'));
    await repository.save(_dailyAt(8, 'tablet-2'));

    final due = await repository
        .watchNextForDate(
          DateTime(2026, 8, 26),
          now: DateTime.utc(2026, 8, 26, 6, 5),
        )
        .first;

    expect(due?.item.target.targetId, 'tablet-1');
    expect(due?.ritual.id, first.id);
    expect(due?.localStatus, AltarRitualLocalStatus.due);
    expect(due?.occurrenceAt, DateTime.utc(2026, 8, 26, 6));
    expect(due?.hasLocalAudio, isTrue);
  });

  test(
    'persists reminder delivery and advances after explicit prayer',
    () async {
      final ritual = await repository.save(_dailyAt(7, 'tablet-1'));

      final delivery =
          (await repository.watchReminderDeliveries().first).single;
      expect(delivery.ritualId, ritual.id);
      expect(delivery.platformNotificationId, greaterThan(0));
      expect(delivery.nextOccurrenceAt, DateTime.utc(2026, 8, 27, 6));

      final next = await repository.advance(
        ritual.id,
        afterUtc: DateTime.utc(2026, 8, 27, 6),
      );
      expect(next, DateTime.utc(2026, 8, 28, 6));
    },
  );

  test(
    'persists and retracts the prayed state for one Altar occurrence',
    () async {
      final ritual = await repository.save(_dailyAt(7, 'tablet-1'));
      final occurrence = DateTime.utc(2026, 8, 26, 6);

      await repository.markPrayed(
        ritualId: ritual.id,
        occurrenceAt: occurrence,
        localDate: DateTime(2026, 8, 26),
        prayerSessionId: 'session-1',
      );

      expect(
        await repository
            .watchNextForDate(
              DateTime(2026, 8, 26),
              now: DateTime.utc(2026, 8, 26, 6, 5),
            )
            .first,
        isNull,
      );

      await repository.retractPrayer(
        ritualId: ritual.id,
        occurrenceAt: occurrence,
      );

      expect(
        (await repository
                .watchNextForDate(
                  DateTime(2026, 8, 26),
                  now: DateTime.utc(2026, 8, 26, 6, 5),
                )
                .first)
            ?.ritual
            .id,
        ritual.id,
      );
    },
  );

  test(
    'pause, snooze, and archive stay local-first and owner scoped',
    () async {
      final first = await repository.save(_dailyAt(7, 'tablet-1'));
      await repository.save(_dailyAt(8, 'tablet-2'));

      await repository.setPaused(first.id, true);
      var next = await repository
          .watchNextForDate(
            DateTime(2026, 8, 26),
            now: DateTime.utc(2026, 8, 26, 6, 5),
          )
          .first;
      expect(next?.item.target.targetId, 'tablet-2');

      await repository.setPaused(first.id, false);
      await repository.snooze(first.id, DateTime.utc(2026, 8, 26, 8, 30));
      next = await repository
          .watchNextForDate(
            DateTime(2026, 8, 26),
            now: DateTime.utc(2026, 8, 26, 6, 5),
          )
          .first;
      expect(next?.item.target.targetId, 'tablet-2');

      await repository.archive(first.id);
      expect(
        await repository
            .watchForTarget(const AltarTarget.voiceTablet('tablet-1'))
            .first,
        isNull,
      );
    },
  );

  test(
    'projects missing local prayer audio without losing the ritual',
    () async {
      await _seedVoiceTablet(database, 'tablet-3', null);
      await repository.save(_dailyAt(7, 'tablet-3'));

      final due = await repository
          .watchNextForDate(
            DateTime(2026, 8, 26),
            now: DateTime.utc(2026, 8, 26, 6, 5),
          )
          .first;

      expect(due?.item.target.targetId, 'tablet-3');
      expect(due?.hasLocalAudio, isFalse);
      expect(due?.localStatus, AltarRitualLocalStatus.missingAudio);
    },
  );
}

AltarRitualDraft _dailyAt(int hour, String tabletId) => AltarRitualDraft(
  target: AltarTarget.voiceTablet(tabletId),
  schedule: AltarRitualSchedule.daily(
    localTime: PrayerLocalTime(hour: hour, minute: 0),
    timezone: 'Africa/Lagos',
  ),
  playbackMode: AltarPlaybackMode.fullPrayer,
  enableOnThisDevice: true,
  autoplayWhenOpened: false,
);

Future<void> _seedVoiceTablet(
  AppDatabase database,
  String tabletId,
  String? audioId,
) async {
  const createdAt = '2026-08-26T05:00:00.000Z';
  await database.powersync.execute(
    '''
    INSERT INTO voice_tablets(
      id, owner_id, source_type, personal_prayer_id, library_prayer_id,
      prayer_revision_id, title, full_audio_id, refrain_audio_id,
      recording_device_id, created_at, updated_at, archived_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
    ''',
    [
      tabletId,
      'owner-1',
      'personal_prayer',
      'prayer-1',
      null,
      'revision-1',
      'Morning surrender',
      audioId,
      null,
      'device-1',
      createdAt,
      createdAt,
    ],
  );
  if (audioId == null) return;
  await database.powersync.execute(
    '''
    INSERT INTO voice_tablet_audio_assets(
      id, owner_id, voice_tablet_id, audio_kind, storage_key, mime_type,
      duration_ms, byte_size, waveform_json, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      audioId,
      'owner-1',
      tabletId,
      'full_prayer',
      'voice/$audioId.m4a',
      'audio/mp4',
      30000,
      1024,
      '[0.1,0.5]',
      createdAt,
    ],
  );
}
