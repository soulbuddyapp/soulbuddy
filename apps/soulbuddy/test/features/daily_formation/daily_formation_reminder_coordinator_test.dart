import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/daily_formation/application/daily_formation_reminder_coordinator.dart';
import 'package:soulbuddy/features/daily_formation/data/daily_formation_repository.dart';
import 'package:soulbuddy/features/daily_formation/domain/formation_profile.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_scheduler.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

void main() {
  setUpAll(() {
    timezone_data.initializeTimeZones();
    timezone.setLocalLocation(timezone.getLocation('Africa/Lagos'));
  });

  test('schedules the chosen daily formation time', () async {
    final values = <String, String>{};
    final repository = DailyFormationRepository(
      read: (key) async => values[key],
      write: (key, value) async => values[key] = value,
    );
    await repository.saveProfile(
      const FormationProfile(
        ready: true,
        minutes: 10,
        reminderHour: 6,
        reminderMinute: 30,
      ),
    );
    final scheduler = _Scheduler();
    final coordinator = DailyFormationReminderCoordinator(
      repository: repository,
      scheduler: scheduler,
      clock: () => DateTime.utc(2026, 9, 16, 4),
    );

    await coordinator.start();

    final notification = scheduler.scheduled.single;
    expect(notification.kind, ReminderNotificationKind.dailyFormation);
    expect(notification.recurrence, ReminderNotificationRecurrence.daily);
    expect(notification.scheduledAtUtc, DateTime.utc(2026, 9, 16, 5, 30));
    await coordinator.dispose();
  });
}

class _Scheduler implements PrayerReminderScheduler {
  final _events = StreamController<PrayerReminderResponse>.broadcast();
  final scheduled = <PrayerScheduledNotification>[];

  @override
  bool get supportsSystemNotifications => true;

  @override
  Stream<PrayerReminderResponse> get responses => _events.stream;

  @override
  Future<void> cancel(int platformNotificationId) async {}

  @override
  Future<void> initialize() async {
    timezone.setLocalLocation(timezone.getLocation('Africa/Lagos'));
  }

  @override
  Future<NotificationPermissionStatus> permissionStatus() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule(PrayerScheduledNotification notification) async =>
      scheduled.add(notification);

  @override
  Future<void> showTestReminder() async {}
}
