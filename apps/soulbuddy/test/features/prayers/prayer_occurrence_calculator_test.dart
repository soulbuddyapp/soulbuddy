import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/application/prayer_occurrence_calculator.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';

void main() {
  late PrayerOccurrenceCalculator calculator;

  setUpAll(() {
    calculator = TimezonePrayerOccurrenceCalculator.initialize();
  });

  test('returns the next daily wall time in UTC', () {
    expect(
      calculator.next(
        PrayerReminderSchedule.daily(
          localTime: PrayerLocalTime(hour: 7, minute: 30),
          timezone: 'Africa/Lagos',
        ),
        afterUtc: DateTime.utc(2026, 8, 11, 6, 29),
      ),
      DateTime.utc(2026, 8, 11, 6, 30),
    );
  });

  test('requires an occurrence to be strictly after the boundary', () {
    expect(
      calculator.next(
        PrayerReminderSchedule.daily(
          localTime: PrayerLocalTime(hour: 7, minute: 30),
          timezone: 'Africa/Lagos',
        ),
        afterUtc: DateTime.utc(2026, 8, 11, 6, 30),
      ),
      DateTime.utc(2026, 8, 12, 6, 30),
    );
  });

  test('crosses a week boundary for selected weekdays', () {
    final mondayAndWednesday = (1 << 0) | (1 << 2);
    expect(
      calculator.next(
        PrayerReminderSchedule.weekdays(
          localTime: PrayerLocalTime(hour: 8, minute: 0),
          timezone: 'Africa/Lagos',
          weekdaysMask: mondayAndWednesday,
        ),
        afterUtc: DateTime.utc(2026, 8, 12, 8),
      ),
      DateTime.utc(2026, 8, 17, 7),
    );
  });

  test('returns a once occurrence only while it is future', () {
    final schedule = PrayerReminderSchedule.once(
      localTime: PrayerLocalTime(hour: 7, minute: 30),
      timezone: 'Africa/Lagos',
      onceAt: DateTime.utc(2026, 8, 11, 6, 30),
    );

    expect(
      calculator.next(schedule, afterUtc: DateTime.utc(2026, 8, 11, 6, 29)),
      DateTime.utc(2026, 8, 11, 6, 30),
    );
    expect(
      calculator.next(schedule, afterUtc: DateTime.utc(2026, 8, 11, 6, 30)),
      isNull,
    );
  });

  test('normalizes a spring-forward gap to the next valid wall time', () {
    expect(
      calculator.next(
        PrayerReminderSchedule.daily(
          localTime: PrayerLocalTime(hour: 2, minute: 30),
          timezone: 'America/New_York',
        ),
        afterUtc: DateTime.utc(2026, 3, 8, 0),
      ),
      DateTime.utc(2026, 3, 8, 7, 30),
    );
  });

  test('chooses the first future instant in a repeated fall-back hour', () {
    expect(
      calculator.next(
        PrayerReminderSchedule.daily(
          localTime: PrayerLocalTime(hour: 1, minute: 30),
          timezone: 'America/New_York',
        ),
        afterUtc: DateTime.utc(2026, 11, 1, 4),
      ),
      DateTime.utc(2026, 11, 1, 5, 30),
    );
  });

  test('a timezone change preserves local time instead of old UTC time', () {
    final lagos = calculator.next(
      PrayerReminderSchedule.daily(
        localTime: PrayerLocalTime(hour: 7, minute: 30),
        timezone: 'Africa/Lagos',
      ),
      afterUtc: DateTime.utc(2026, 8, 11),
    );
    final newYork = calculator.next(
      PrayerReminderSchedule.daily(
        localTime: PrayerLocalTime(hour: 7, minute: 30),
        timezone: 'America/New_York',
      ),
      afterUtc: DateTime.utc(2026, 8, 11),
    );

    expect(lagos, DateTime.utc(2026, 8, 11, 6, 30));
    expect(newYork, DateTime.utc(2026, 8, 11, 11, 30));
  });
}
