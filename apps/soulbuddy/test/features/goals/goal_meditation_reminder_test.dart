import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/goals/application/goal_meditation_reminder_coordinator.dart';
import 'package:soulbuddy/features/goals/data/goal_meditation_repository.dart';
import 'package:soulbuddy/features/goals/domain/goal_meditation_plan.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_scheduler.dart';

void main() {
  test('weekly goal practice receives a repeating device reminder', () async {
    final values = <String, String>{};
    final repository = GoalMeditationRepository(
      read: (key) async => values[key],
      write: (key, value) async => values[key] = value,
    );
    const plan = GoalMeditationPlan(
      goalId: 'goal-1',
      frequency: GoalMeditationFrequency.weekly,
      weekday: DateTime.friday,
      hour: 8,
      minute: 15,
      durationMinutes: 15,
    );
    await repository.savePlan(plan);
    final scheduler = _Scheduler();
    final coordinator = GoalMeditationReminderCoordinator(
      repository: repository,
      scheduler: scheduler,
      clock: () => DateTime(2026, 9, 21, 9),
    );
    await coordinator.start();
    final reminder = scheduler.scheduled.single;
    expect(reminder.kind, ReminderNotificationKind.goalMeditation);
    expect(reminder.reminderId, 'goal-1');
    expect(reminder.recurrence, ReminderNotificationRecurrence.weekly);
    expect(reminder.scheduledAtUtc.toLocal().weekday, DateTime.friday);
    await coordinator.dispose();
    await scheduler.close();
  });

  test(
    'a cold-start reminder opening survives until the app subscribes',
    () async {
      final repository = GoalMeditationRepository(
        read: (_) async => null,
        write: (_, _) async {},
      );
      final scheduler = _Scheduler();
      final coordinator = GoalMeditationReminderCoordinator(
        repository: repository,
        scheduler: scheduler,
      );
      await coordinator.start();
      scheduler.controller.add(
        const PrayerReminderResponse(
          reminderId: 'goal-1',
          occurrenceKey: 'goal-meditation:goal-1',
          action: PrayerReminderAction.begin,
          kind: ReminderNotificationKind.goalMeditation,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect((await coordinator.events.first).goalId, 'goal-1');
      await coordinator.dispose();
      await scheduler.close();
    },
  );
}

class _Scheduler implements PrayerReminderScheduler {
  final controller = StreamController<PrayerReminderResponse>.broadcast();
  final scheduled = <PrayerScheduledNotification>[];
  @override
  bool get supportsSystemNotifications => true;
  @override
  Stream<PrayerReminderResponse> get responses => controller.stream;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<NotificationPermissionStatus> permissionStatus() async =>
      NotificationPermissionStatus.granted;
  @override
  Future<void> showTestReminder() async {}
  @override
  Future<void> schedule(PrayerScheduledNotification notification) async =>
      scheduled.add(notification);
  @override
  Future<void> cancel(int platformNotificationId) async {}
  Future<void> close() => controller.close();
}
