import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/sacred_hours/application/sacred_hour_prayer_suggestions.dart';
import 'package:soulbuddy/features/sacred_hours/domain/sacred_hour.dart';

void main() {
  test(
    'morning prioritizes personal daily, gratitude, then guidance prayers',
    () {
      final suggestions = SacredHourPrayerSuggestions.forHour(
        _hour(SacredHourPurpose.morning),
        [
          _prayer('library-work', PrayerPurpose.work),
          _prayer('library-guidance', PrayerPurpose.guidance),
          _prayer(
            'personal-gratitude',
            PrayerPurpose.gratitude,
            personal: true,
          ),
          _prayer('personal-daily', PrayerPurpose.daily, personal: true),
        ],
      );

      expect(suggestions.map((prayer) => prayer.id), [
        'personal-daily',
        'personal-gratitude',
        'library-guidance',
        'library-work',
      ]);
    },
  );

  test(
    'evening excludes its existing prayer and brings forgiveness forward',
    () {
      final suggestions = SacredHourPrayerSuggestions.forHour(
        _hour(
          SacredHourPurpose.evening,
          prayer: const PrayerReference.library('daily'),
        ),
        [
          _prayer('daily', PrayerPurpose.daily),
          _prayer('work', PrayerPurpose.work),
          _prayer('forgiveness', PrayerPurpose.forgiveness),
          _prayer('gratitude', PrayerPurpose.gratitude),
        ],
      );

      expect(suggestions.map((prayer) => prayer.id), [
        'gratitude',
        'forgiveness',
        'work',
      ]);
    },
  );

  test('draft from hour changes only the prayer link', () {
    final hour = _hour(
      SacredHourPurpose.custom,
      prayer: const PrayerReference.library('old'),
    );
    final draft = SacredHourDraft.fromHour(
      hour,
      prayer: const PrayerReference.personal('new'),
    );

    expect(draft.name, hour.name);
    expect(draft.localTime, hour.localTime);
    expect(draft.timezone, hour.timezone);
    expect(draft.durationMinutes, hour.durationMinutes);
    expect(draft.prayerMinutes, hour.prayerMinutes);
    expect(draft.enabled, hour.enabled);
    expect(draft.sound, hour.sound);
    expect(draft.purpose, hour.purpose);
    expect(draft.personId, hour.personId);
    expect(draft.prayer, const PrayerReference.personal('new'));
  });
}

SacredHour _hour(SacredHourPurpose purpose, {PrayerReference? prayer}) =>
    SacredHour(
      id: 'hour-1',
      ownerId: 'owner-1',
      purpose: purpose,
      name: 'Sacred Hour',
      localTime: PrayerLocalTime(hour: 6, minute: 0),
      timezone: 'Africa/Lagos',
      durationMinutes: 60,
      prayerMinutes: 15,
      enabled: true,
      sound: SacredHourSound.gentleChime,
      personId: 'person-1',
      prayer: prayer,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

PrayerDisplay _prayer(
  String id,
  PrayerPurpose purpose, {
  bool personal = false,
}) => PrayerDisplayValue(
  reference: personal
      ? PrayerReference.personal(id)
      : PrayerReference.library(id),
  title: id,
  body: 'Prayer',
  grounding: PrayerGrounding.generalChristian,
  purpose: purpose,
);
