import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/altar/application/altar_reminder_coordinator.dart';
import 'package:soulbuddy/features/altar/data/altar_ritual_repository.dart';
import 'package:soulbuddy/features/altar/domain/altar_ritual.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_scheduler.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';

void main() {
  test('schedules a private Altar notification and reports its open', () async {
    final repository = _Repository();
    final scheduler = _Scheduler();
    final coordinator = AltarReminderCoordinator(
      repository: repository,
      scheduler: scheduler,
      clock: () => DateTime.utc(2026, 8, 26, 6),
    );
    addTearDown(coordinator.dispose);

    await coordinator.start();
    repository.deliveries.add([
      AltarReminderDelivery(
        ritualId: 'ritual-1',
        platformNotificationId: 41,
        nextOccurrenceAt: DateTime.utc(2026, 8, 26, 7),
        enabledOnDevice: true,
        schedule: AltarRitualSchedule.daily(
          localTime: PrayerLocalTime(hour: 7, minute: 0),
          timezone: 'UTC',
        ),
      ),
    ]);
    await pumpEventQueue();

    expect(scheduler.scheduled.single.kind, ReminderNotificationKind.altar);
    expect(scheduler.scheduled.single.reminderId, 'ritual-1');
    expect(
      scheduler.scheduled.single.recurrence,
      ReminderNotificationRecurrence.daily,
    );

    final opened = expectLater(
      coordinator.events,
      emits(
        isA<AltarReminderOpened>().having(
          (event) => event.ritualId,
          'ritualId',
          'ritual-1',
        ),
      ),
    );
    scheduler.responseController.add(
      const PrayerReminderResponse(
        reminderId: 'ritual-1',
        occurrenceKey: 'ritual-1@2026-08-26T07:00:00.000Z',
        action: PrayerReminderAction.open,
        kind: ReminderNotificationKind.altar,
      ),
    );
    await opened;
  });

  test(
    'selected days repeat weekly even when an occurrence is ignored',
    () async {
      final repository = _Repository();
      final scheduler = _Scheduler();
      final coordinator = AltarReminderCoordinator(
        repository: repository,
        scheduler: scheduler,
        clock: () => DateTime.utc(2026, 8, 26, 6),
      );
      addTearDown(coordinator.dispose);

      await coordinator.start();
      repository.deliveries.add([
        AltarReminderDelivery(
          ritualId: 'ritual-weekdays',
          platformNotificationId: 52,
          nextOccurrenceAt: DateTime.utc(2026, 8, 28, 7),
          enabledOnDevice: true,
          schedule: AltarRitualSchedule.weekdays(
            localTime: PrayerLocalTime(hour: 7, minute: 0),
            timezone: 'UTC',
            weekdaysMask: (1 << 0) | (1 << 4),
          ),
        ),
      ]);
      await pumpEventQueue();

      expect(scheduler.scheduled, hasLength(2));
      expect(
        scheduler.scheduled.map((item) => item.recurrence),
        everyElement(ReminderNotificationRecurrence.weekly),
      );
      expect(
        scheduler.scheduled.map((item) => item.scheduledAtUtc.weekday).toSet(),
        {DateTime.monday, DateTime.friday},
      );
    },
  );

  test('selected-day reminders honor the ritual IANA timezone', () async {
    final repository = _Repository();
    final scheduler = _Scheduler();
    final coordinator = AltarReminderCoordinator(
      repository: repository,
      scheduler: scheduler,
      clock: () => DateTime.utc(2026, 8, 26, 12),
    );
    addTearDown(coordinator.dispose);

    await coordinator.start();
    repository.deliveries.add([
      AltarReminderDelivery(
        ritualId: 'ritual-new-york',
        platformNotificationId: 61,
        nextOccurrenceAt: DateTime.utc(2026, 8, 31, 11),
        enabledOnDevice: true,
        schedule: AltarRitualSchedule.weekdays(
          localTime: PrayerLocalTime(hour: 7, minute: 0),
          timezone: 'America/New_York',
          weekdaysMask: 1 << (DateTime.monday - 1),
        ),
      ),
    ]);
    await pumpEventQueue();

    expect(
      scheduler.scheduled.single.scheduledAtUtc,
      DateTime.utc(2026, 8, 31, 11),
    );
  });

  test('cancels platform reminders when a ritual is disabled', () async {
    final repository = _Repository();
    final scheduler = _Scheduler();
    final coordinator = AltarReminderCoordinator(
      repository: repository,
      scheduler: scheduler,
      clock: () => DateTime.utc(2026, 8, 26, 6),
    );
    addTearDown(coordinator.dispose);
    final schedule = AltarRitualSchedule.daily(
      localTime: PrayerLocalTime(hour: 7, minute: 0),
      timezone: 'UTC',
    );

    await coordinator.start();
    repository.deliveries.add([
      AltarReminderDelivery(
        ritualId: 'ritual-1',
        platformNotificationId: 41,
        nextOccurrenceAt: DateTime.utc(2026, 8, 26, 7),
        enabledOnDevice: true,
        schedule: schedule,
      ),
    ]);
    await pumpEventQueue();
    scheduler.cancelled.clear();

    repository.deliveries.add([
      AltarReminderDelivery(
        ritualId: 'ritual-1',
        platformNotificationId: 41,
        nextOccurrenceAt: DateTime.utc(2026, 8, 26, 7),
        enabledOnDevice: false,
        schedule: schedule,
      ),
    ]);
    await pumpEventQueue();

    expect(scheduler.cancelled, contains(41));
  });
}

class _Repository implements AltarRitualRepository {
  final deliveries = StreamController<List<AltarReminderDelivery>>.broadcast();

  @override
  Stream<List<AltarReminderDelivery>> watchReminderDeliveries() =>
      deliveries.stream;

  @override
  Future<DateTime?> advance(String ritualId, {required DateTime afterUtc}) =>
      throw UnimplementedError();

  @override
  Future<void> archive(String ritualId) => throw UnimplementedError();

  @override
  Future<void> markPrayed({
    required String ritualId,
    required DateTime occurrenceAt,
    required DateTime localDate,
    required String prayerSessionId,
  }) => throw UnimplementedError();

  @override
  Future<void> retractPrayer({
    required String ritualId,
    required DateTime occurrenceAt,
  }) => throw UnimplementedError();

  @override
  Future<AltarRitual> save(AltarRitualDraft draft) =>
      throw UnimplementedError();

  @override
  Future<void> setPaused(String ritualId, bool paused) =>
      throw UnimplementedError();

  @override
  Future<void> snooze(String ritualId, DateTime until) =>
      throw UnimplementedError();

  @override
  Stream<AltarRitual?> watchForTarget(AltarTarget target) =>
      throw UnimplementedError();

  @override
  Stream<DueAltarRitual?> watchNextForDate(
    DateTime localDate, {
    DateTime? now,
  }) => throw UnimplementedError();
}

class _Scheduler implements PrayerReminderScheduler {
  final responseController =
      StreamController<PrayerReminderResponse>.broadcast();
  final scheduled = <PrayerScheduledNotification>[];
  final cancelled = <int>[];

  @override
  Stream<PrayerReminderResponse> get responses => responseController.stream;

  @override
  bool get supportsSystemNotifications => true;

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
