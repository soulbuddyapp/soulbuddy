import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:soulbuddy/features/sacred_hours/domain/sacred_hour.dart';

void main() {
  const ownerId = '0198aa00-0000-7000-8000-000000000001';

  test(
    'defaults are stable sixty-minute hours with fifteen minutes of prayer',
    () {
      final first = SacredHour.defaultMorning(
        ownerId: ownerId,
        timezone: 'Africa/Lagos',
      );
      final replay = SacredHour.defaultMorning(
        ownerId: ownerId,
        timezone: 'Africa/Lagos',
      );
      final evening = SacredHour.defaultEvening(
        ownerId: ownerId,
        timezone: 'Africa/Lagos',
      );

      expect(first.id, replay.id);
      expect(first.purpose, SacredHourPurpose.morning);
      expect(first.localTime, PrayerLocalTime(hour: 6, minute: 0));
      expect(first.durationMinutes, 60);
      expect(first.prayerMinutes, 15);
      expect(first.sound, SacredHourSound.gentleChime);
      expect(first.enabled, isTrue);
      expect(evening.localTime, PrayerLocalTime(hour: 22, minute: 0));
      expect(evening.endLocalTime, PrayerLocalTime(hour: 23, minute: 0));
    },
  );

  test('a supported draft can attach a prayer and a person', () {
    final draft = SacredHourDraft(
      name: 'Before work',
      localTime: PrayerLocalTime(hour: 7, minute: 30),
      timezone: 'Africa/Lagos',
      prayerMinutes: 5,
      sound: SacredHourSound.dawnChime,
      prayer: const PrayerReference.library('library-prayer-1'),
      personId: 'person-1',
    );

    expect(draft.durationMinutes, 60);
    expect(draft.prayerMinutes, 5);
    expect(draft.prayer, const PrayerReference.library('library-prayer-1'));
    expect(draft.personId, 'person-1');
  });

  test('rejects unsupported prayer duration', () {
    expect(
      () => SacredHourDraft(
        name: 'Morning',
        localTime: PrayerLocalTime(hour: 6, minute: 0),
        timezone: 'UTC',
        prayerMinutes: 20,
      ),
      throwsArgumentError,
    );
  });

  test('rejects a row with a prayer type but no prayer id', () {
    expect(
      () => SacredHour.fromRow({
        'id': 'hour-1',
        'owner_id': ownerId,
        'purpose_key': 'morning',
        'name': 'Morning',
        'local_time': '06:00',
        'timezone': 'Africa/Lagos',
        'duration_minutes': 60,
        'prayer_minutes': 15,
        'enabled': 1,
        'sound_key': 'gentle_chime',
        'prayer_type': 'library',
        'prayer_id': null,
        'person_id': null,
        'created_at': '2026-08-31T05:00:00.000Z',
        'updated_at': '2026-08-31T05:00:00.000Z',
        'archived_at': null,
      }),
      throwsFormatException,
    );
  });

  test(
    'parses a personal prayer reference and wraps an hour past midnight',
    () {
      final hour = SacredHour.fromRow({
        'id': 'hour-2',
        'owner_id': ownerId,
        'purpose_key': null,
        'name': 'Night watch',
        'local_time': '23:30',
        'timezone': 'Africa/Lagos',
        'duration_minutes': 60,
        'prayer_minutes': 30,
        'enabled': 1,
        'sound_key': 'still_bell',
        'prayer_type': 'personal',
        'prayer_id': 'personal-prayer-1',
        'person_id': null,
        'created_at': '2026-08-31T05:00:00.000Z',
        'updated_at': '2026-08-31T05:00:00.000Z',
        'archived_at': null,
      });

      expect(hour.purpose, SacredHourPurpose.custom);
      expect(hour.prayer, const PrayerReference.personal('personal-prayer-1'));
      expect(hour.endLocalTime, PrayerLocalTime(hour: 0, minute: 30));
    },
  );
}
