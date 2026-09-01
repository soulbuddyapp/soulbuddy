import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/sacred_hours/application/sacred_hour_today_window.dart';
import 'package:soulbuddy/features/sacred_hours/domain/sacred_hour.dart';

void main() {
  test('hides an evening Sacred Hour during the morning', () {
    final window = SacredHourTodayWindow.classify(
      _hour(hour: 22),
      DateTime.utc(2026, 9, 1, 7),
    );

    expect(window.phase, SacredHourTodayPhase.hidden);
  });

  test('reveals an upcoming Sacred Hour during its preparation window', () {
    final window = SacredHourTodayWindow.classify(
      _hour(hour: 22),
      DateTime.utc(2026, 9, 1, 20, 15),
    );

    expect(window.phase, SacredHourTodayPhase.upcoming);
    expect(window.minutesUntil, 45);
    expect(window.startsAtUtc, DateTime.utc(2026, 9, 1, 21));
  });

  test('recognizes an active Sacred Hour', () {
    final window = SacredHourTodayWindow.classify(
      _hour(hour: 22),
      DateTime.utc(2026, 9, 1, 21, 15),
    );

    expect(window.phase, SacredHourTodayPhase.active);
    expect(window.minutesUntil, 0);
  });

  test('recognizes a Sacred Hour that began before midnight', () {
    final window = SacredHourTodayWindow.classify(
      _hour(hour: 23, minute: 30),
      DateTime.utc(2026, 9, 1, 23, 15),
    );

    expect(window.phase, SacredHourTodayPhase.active);
    expect(window.startsAtUtc, DateTime.utc(2026, 9, 1, 22, 30));
  });
}

SacredHour _hour({required int hour, int minute = 0}) => SacredHour(
  id: 'hour-$hour-$minute',
  ownerId: 'owner-1',
  purpose: SacredHourPurpose.evening,
  name: 'Evening Sacred Hour',
  localTime: PrayerLocalTime(hour: hour, minute: minute),
  timezone: 'Africa/Lagos',
  durationMinutes: 60,
  prayerMinutes: 15,
  enabled: true,
  sound: SacredHourSound.gentleChime,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, 1),
);
