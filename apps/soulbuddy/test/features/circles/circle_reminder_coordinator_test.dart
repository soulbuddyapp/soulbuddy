import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/circles/application/circle_reminder_coordinator.dart';
import 'package:soulbuddy/features/circles/data/circle_reminder_repository.dart';
import 'package:soulbuddy/features/circles/domain/circle_reminder.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_scheduler.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';

void main() {
  test('schedules a daily Circle invitation and reports its open', () async {
    final repository = _repository();
    final scheduler = _Scheduler();
    final coordinator = CircleReminderCoordinator(
      repository: repository,
      scheduler: scheduler,
      clock: () => DateTime.utc(2026, 9, 10, 6),
    );
    addTearDown(() async {
      await coordinator.dispose();
      await repository.dispose();
    });
    final reminder = _reminder();
    await repository.save(reminder);

    await coordinator.start();
    await pumpEventQueue();

    expect(scheduler.scheduled, hasLength(1));
    expect(scheduler.scheduled.single.kind, ReminderNotificationKind.circle);
    expect(scheduler.scheduled.single.title, 'Walk together');
    expect(scheduler.scheduled.single.body, 'Circle invitation');
    expect(
      scheduler.scheduled.single.recurrence,
      ReminderNotificationRecurrence.daily,
    );

    final opened = expectLater(
      coordinator.events,
      emits(
        isA<CircleReminderOpened>().having(
          (event) => event.circleId,
          'circleId',
          reminder.circleId,
        ),
      ),
    );
    scheduler.responsesController.add(
      const PrayerReminderResponse(
        reminderId: 'circle-1',
        occurrenceKey: 'circle-1@2026-09-10T07:30:00.000Z',
        action: PrayerReminderAction.open,
        kind: ReminderNotificationKind.circle,
      ),
    );
    await opened;
  });

  test('cancels a Circle notification when its reminder is removed', () async {
    final repository = _repository();
    final scheduler = _Scheduler();
    final coordinator = CircleReminderCoordinator(
      repository: repository,
      scheduler: scheduler,
      clock: () => DateTime.utc(2026, 9, 10, 6),
    );
    addTearDown(() async {
      await coordinator.dispose();
      await repository.dispose();
    });
    final reminder = _reminder();
    await repository.save(reminder);
    await coordinator.start();
    await pumpEventQueue();
    scheduler.cancelled.clear();

    await repository.remove(reminder.circleId);
    await pumpEventQueue();

    expect(scheduler.cancelled, contains(reminder.platformNotificationId));
  });
}

CircleReminderRepository _repository() {
  final storage = <String, String>{};
  return CircleReminderRepository(
    read: (key) async => storage[key],
    write: (key, value) async => storage[key] = value,
  );
}

CircleReminder _reminder() => CircleReminder(
  circleId: 'circle-1',
  circleName: 'Walk together',
  localTime: PrayerLocalTime(hour: 7, minute: 30),
  timezone: 'UTC',
  platformNotificationId: 1400000001,
);

class _Scheduler implements PrayerReminderScheduler {
  final responsesController =
      StreamController<PrayerReminderResponse>.broadcast();
  final scheduled = <PrayerScheduledNotification>[];
  final cancelled = <int>[];

  @override
  bool get supportsSystemNotifications => true;

  @override
  Stream<PrayerReminderResponse> get responses => responsesController.stream;

  @override
  Future<void> cancel(int platformNotificationId) async {
    cancelled.add(platformNotificationId);
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationPermissionStatus> permissionStatus() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule(PrayerScheduledNotification notification) async {
    scheduled.add(notification);
  }

  @override
  Future<void> showTestReminder() async {}
}
