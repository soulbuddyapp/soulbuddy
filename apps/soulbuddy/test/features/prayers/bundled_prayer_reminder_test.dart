import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:soulbuddy/features/prayers/application/bundled_prayer_reminder.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_scheduler.dart';

class Scheduler implements PrayerReminderScheduler {
  final requests = <PrayerScheduledNotification>[];
  final cancelled = <int>[];
  final controller = StreamController<PrayerReminderResponse>.broadcast(
    sync: true,
  );
  PrayerReminderResponse? initial;
  @override
  bool get supportsSystemNotifications => true;
  @override
  Stream<PrayerReminderResponse> get responses => controller.stream;
  @override
  Future<void> initialize() async {
    if (initial != null) controller.add(initial!);
  }

  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<NotificationPermissionStatus> permissionStatus() async =>
      NotificationPermissionStatus.granted;
  @override
  Future<void> schedule(PrayerScheduledNotification n) async {
    requests.add(n);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }

  @override
  Future<void> showTestReminder() async {}
}

void main() {
  setUpAll(tzdata.initializeTimeZones);
  test(
    'schedules and restores the selected built-in prayer with voice',
    () async {
      String? saved;
      final scheduler = Scheduler();
      final service = BundledPrayerReminder(
        scheduler: scheduler,
        read: () async => saved,
        write: (v) async {
          saved = v;
        },
        timezoneName: () async => 'UTC',
        clock: () => DateTime.utc(2026, 11, 18, 7),
      );
      await service.start();
      await service.setDaily('0198a100-0000-7000-8000-000000000001', 8, 30);
      final request = scheduler.requests.single;
      expect(request.soundKey, 'builtin_prayer_01');
      expect(request.kind.name, 'builtInPrayer');
      expect(request.recurrence, ReminderNotificationRecurrence.daily);
      expect(request.scheduledAtUtc, DateTime.utc(2026, 11, 18, 8, 30));
      expect(await service.timeFor('0198a100-0000-7000-8000-000000000001'), (
        8,
        30,
      ));
      await service.remove('0198a100-0000-7000-8000-000000000001');
      expect(scheduler.cancelled, contains(request.platformNotificationId));
      await service.close();
    },
  );
  test('restores a saved reminder using the current timezone', () async {
    final scheduler = Scheduler();
    const id = '0198a100-0000-7000-8000-000000000001';
    final service = BundledPrayerReminder(
      scheduler: scheduler,
      read: () async => '{"$id":[8,30]}',
      write: (_) async {},
      timezoneName: () async => 'UTC',
      clock: () => DateTime.utc(2026, 11, 18, 9),
    );
    await service.start();
    expect(
      scheduler.requests.single.scheduledAtUtc,
      DateTime.utc(2026, 11, 19, 8, 30),
    );
    await service.close();
  });
  test(
    'retains a notification opened during startup until the app listens',
    () async {
      const id = '0198a100-0000-7000-8000-000000000001';
      final scheduler = Scheduler()
        ..initial = const PrayerReminderResponse(
          reminderId: id,
          occurrenceKey: 'daily',
          action: PrayerReminderAction.open,
          kind: ReminderNotificationKind.builtInPrayer,
        );
      final service = BundledPrayerReminder(
        scheduler: scheduler,
        read: () async => null,
        write: (_) async {},
        timezoneName: () async => 'UTC',
        clock: DateTime.now,
      );
      await service.start();
      expect(await service.events.first, id);
      await service.close();
      await scheduler.controller.close();
    },
  );
  test('cancels the new alarm when saving its preference fails', () async {
    final scheduler = Scheduler();
    final service = BundledPrayerReminder(
      scheduler: scheduler,
      read: () async => null,
      write: (_) async => throw StateError('failed'),
      timezoneName: () async => 'UTC',
      clock: DateTime.now,
    );
    await service.start();
    await expectLater(
      service.setDaily('0198a100-0000-7000-8000-000000000001', 8, 0),
      throwsStateError,
    );
    expect(scheduler.cancelled, [
      scheduler.requests.single.platformNotificationId,
    ]);
    await service.close();
    await scheduler.controller.close();
  });
  test(
    'reminder audio can be turned off without removing its schedule',
    () async {
      String? saved;
      final scheduler = Scheduler();
      final service = BundledPrayerReminder(
        scheduler: scheduler,
        read: () async => saved,
        write: (v) async {
          saved = v;
        },
        timezoneName: () async => 'UTC',
        clock: () => DateTime.utc(2026, 11, 18, 7),
      );
      await service.start();
      const id = '0198a100-0000-7000-8000-000000000001';
      await service.setDaily(id, 8, 30, audioEnabled: false);
      expect(scheduler.requests.single.soundKey, 'silent');
      expect(await service.audioEnabledFor(id), isFalse);
      expect(await service.timeFor(id), (8, 30));
      await service.close();
      await scheduler.controller.close();
    },
  );
  test('stale narration is cancelled instead of scheduled', () async {
    const id = '0198a100-0000-7000-8000-000000000001';
    final scheduler = Scheduler();
    final service = BundledPrayerReminder(
      scheduler: scheduler,
      read: () async => '{"$id":[8,30]}',
      write: (_) async {},
      timezoneName: () async => 'UTC',
      clock: DateTime.now,
      isEligible: (_) async => false,
    );
    await service.start();
    expect(scheduler.requests, isEmpty);
    expect(scheduler.cancelled, [-(0x40000000 + 1)]);
    await expectLater(service.setDaily(id, 9, 0), throwsStateError);
    await service.close();
    await scheduler.controller.close();
  });
  test('starting a reminder does not reset the app timezone', () async {
    tz.setLocalLocation(tz.getLocation('Africa/Lagos'));
    final scheduler = Scheduler();
    final service = BundledPrayerReminder(
      scheduler: scheduler,
      read: () async => null,
      write: (_) async {},
      timezoneName: () async => 'Africa/Lagos',
      clock: DateTime.now,
    );
    await service.start();
    expect(tz.local.name, 'Africa/Lagos');
    await service.close();
    await scheduler.controller.close();
  });
  test('reconciles reminders after a timezone change', () async {
    const id = '0198a100-0000-7000-8000-000000000001';
    var zone = 'UTC';
    final scheduler = Scheduler();
    final service = BundledPrayerReminder(
      scheduler: scheduler,
      read: () async => '{"$id":[8,30]}',
      write: (_) async {},
      timezoneName: () async => zone,
      clock: () => DateTime.utc(2026, 11, 18, 6),
    );
    await service.start();
    zone = 'Africa/Lagos';
    await service.reconcile();
    expect(
      scheduler.requests.last.scheduledAtUtc,
      DateTime.utc(2026, 11, 18, 7, 30),
    );
    await service.close();
    await scheduler.controller.close();
  });
}
