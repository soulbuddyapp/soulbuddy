import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/circles/data/circle_reminder_repository.dart';
import 'package:soulbuddy/features/circles/domain/circle_reminder.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';

void main() {
  test('persists a Circle reminder and removes it', () async {
    final storage = <String, String>{};
    CircleReminderRepository repository() => CircleReminderRepository(
      read: (key) async => storage[key],
      write: (key, value) async => storage[key] = value,
    );
    final reminder = CircleReminder(
      circleId: 'circle-1',
      circleName: 'Walk together',
      localTime: PrayerLocalTime(hour: 7, minute: 30),
      timezone: 'Africa/Lagos',
      platformNotificationId: 1400000001,
    );

    await repository().save(reminder);

    expect(await repository().load(), [reminder]);

    await repository().remove(reminder.circleId);

    expect(await repository().load(), isEmpty);
  });
}
