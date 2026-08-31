import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_scheduler.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/sacred_hours/application/sacred_hour_alarm_permission.dart';
import 'package:soulbuddy/features/sacred_hours/application/sacred_hour_reminder_coordinator.dart';
import 'package:soulbuddy/features/sacred_hours/data/sacred_hour_repository.dart';
import 'package:soulbuddy/features/sacred_hours/domain/sacred_hour.dart';

void main() {
  test(
    'schedules one daily wall-time reminder with the chosen sound',
    () async {
      final repository = _Repository();
      final scheduler = _Scheduler();
      final coordinator = SacredHourReminderCoordinator(
        repository: repository,
        scheduler: scheduler,
        exactAlarmPermission: _ExactPermission(
          ExactAlarmPermissionStatus.denied,
        ),
        clock: () => DateTime.utc(2026, 10, 31, 12),
      );
      addTearDown(coordinator.dispose);
      repository.hours['hour-1'] = _hour(
        timezone: 'America/New_York',
        localTime: PrayerLocalTime(hour: 7, minute: 0),
        sound: SacredHourSound.dawnChime,
      );

      await coordinator.start();
      repository.deliveries.add([
        _delivery(
          next: DateTime.utc(2026, 11, 2, 12),
          timezone: 'America/New_York',
        ),
      ]);
      await pumpEventQueue();

      final notification = scheduler.scheduled.single;
      expect(notification.kind, ReminderNotificationKind.sacredHour);
      expect(notification.recurrence, ReminderNotificationRecurrence.daily);
      expect(notification.scheduledAtUtc, DateTime.utc(2026, 11, 2, 12));
      expect(notification.timeZoneName, 'America/New_York');
      expect(notification.soundKey, 'sacred_dawn_chime');
      expect(notification.precision, ReminderSchedulePrecision.ordinary);
      expect(scheduler.cancelled, containsAll([101, _snoozeId(101)]));
    },
  );

  test(
    'uses exact only when granted and falls back if scheduling fails',
    () async {
      final repository = _Repository();
      final scheduler = _Scheduler()..throwOnFirstExact = true;
      final coordinator = SacredHourReminderCoordinator(
        repository: repository,
        scheduler: scheduler,
        exactAlarmPermission: _ExactPermission(
          ExactAlarmPermissionStatus.granted,
        ),
        clock: () => DateTime.utc(2026, 8, 31),
      );
      addTearDown(coordinator.dispose);
      repository.hours['hour-1'] = _hour();

      await coordinator.start();
      repository.deliveries.add([
        _delivery(
          next: DateTime.utc(2026, 8, 31, 5),
          mode: SacredHourReminderMode.precise,
        ),
      ]);
      await pumpEventQueue();

      expect(scheduler.attempted.map((item) => item.precision), [
        ReminderSchedulePrecision.exact,
        ReminderSchedulePrecision.ordinary,
      ]);
      expect(
        scheduler.scheduled.single.precision,
        ReminderSchedulePrecision.ordinary,
      );
    },
  );

  test('cancels a paused or archived delivery', () async {
    final repository = _Repository();
    final scheduler = _Scheduler();
    final coordinator = SacredHourReminderCoordinator(
      repository: repository,
      scheduler: scheduler,
      exactAlarmPermission: _ExactPermission(ExactAlarmPermissionStatus.denied),
    );
    addTearDown(coordinator.dispose);
    repository.hours['hour-1'] = _hour();
    await coordinator.start();
    repository.deliveries.add([_delivery(next: DateTime.utc(2026, 8, 31, 5))]);
    await pumpEventQueue();
    scheduler.cancelled.clear();

    repository.deliveries.add([_delivery(next: null, enabled: false)]);
    await pumpEventQueue();

    expect(scheduler.cancelled, contains(101));
  });

  test('handles Begin, snooze, and Not now once per occurrence', () async {
    final now = DateTime.utc(2026, 8, 31, 5, 1);
    final repository = _Repository();
    final scheduler = _Scheduler();
    final coordinator = SacredHourReminderCoordinator(
      repository: repository,
      scheduler: scheduler,
      exactAlarmPermission: _ExactPermission(ExactAlarmPermissionStatus.denied),
      clock: () => now,
    );
    addTearDown(coordinator.dispose);
    repository.hours['hour-1'] = _hour();
    repository.currentDeliveries = [
      _delivery(next: DateTime.utc(2026, 8, 31, 5)),
    ];
    await coordinator.start();
    repository.deliveries.add(repository.currentDeliveries);
    await pumpEventQueue();
    const occurrenceKey = 'hour-1@2026-08-31T05:00:00.000Z';

    final opened = expectLater(
      coordinator.events,
      emits(
        isA<SacredHourOpened>()
            .having((event) => event.hourId, 'hourId', 'hour-1')
            .having(
              (event) => event.occurrenceKey,
              'occurrenceKey',
              occurrenceKey,
            ),
      ),
    );
    scheduler.emit(
      const PrayerReminderResponse(
        reminderId: 'hour-1',
        occurrenceKey: occurrenceKey,
        action: PrayerReminderAction.begin,
        kind: ReminderNotificationKind.sacredHour,
      ),
    );
    scheduler.emit(
      const PrayerReminderResponse(
        reminderId: 'hour-1',
        occurrenceKey: occurrenceKey,
        action: PrayerReminderAction.begin,
        kind: ReminderNotificationKind.sacredHour,
      ),
    );
    await opened;
    await pumpEventQueue();
    expect(repository.occurrences, [SacredHourOccurrenceStatus.begun]);

    scheduler.emit(
      const PrayerReminderResponse(
        reminderId: 'hour-1',
        occurrenceKey: occurrenceKey,
        action: PrayerReminderAction.snoozeTenMinutes,
        kind: ReminderNotificationKind.sacredHour,
      ),
    );
    await pumpEventQueue();
    expect(
      repository.deviceUpdates.last.snoozedUntil,
      now.add(const Duration(minutes: 10)),
    );

    scheduler.emit(
      const PrayerReminderResponse(
        reminderId: 'hour-1',
        occurrenceKey: occurrenceKey,
        action: PrayerReminderAction.dismiss,
        kind: ReminderNotificationKind.sacredHour,
      ),
    );
    await pumpEventQueue();
    expect(repository.occurrences.last, SacredHourOccurrenceStatus.dismissed);
    expect(repository.deviceUpdates.last.dismissedOccurrenceKey, occurrenceKey);
  });
}

SacredHour _hour({
  String timezone = 'Africa/Lagos',
  PrayerLocalTime? localTime,
  SacredHourSound sound = SacredHourSound.gentleChime,
}) => SacredHour(
  id: 'hour-1',
  ownerId: 'owner-1',
  purpose: SacredHourPurpose.morning,
  name: 'Morning Sacred Hour',
  localTime: localTime ?? PrayerLocalTime(hour: 6, minute: 0),
  timezone: timezone,
  durationMinutes: 60,
  prayerMinutes: 15,
  enabled: true,
  sound: sound,
  createdAt: DateTime.utc(2026, 8, 31),
  updatedAt: DateTime.utc(2026, 8, 31),
);

SacredHourDelivery _delivery({
  required DateTime? next,
  String timezone = 'Africa/Lagos',
  bool enabled = true,
  SacredHourReminderMode mode = SacredHourReminderMode.ordinary,
}) => SacredHourDelivery(
  sacredHourId: 'hour-1',
  enabledOnDevice: enabled,
  reminderMode: mode,
  nextOccurrenceAt: next,
  platformNotificationId: 101,
  scheduledTimezone: timezone,
  updatedAt: DateTime.utc(2026, 8, 31),
);

int _snoozeId(int base) => ((base * 31) + 10) & 0x7fffffff;

class _Repository implements SacredHourRepository {
  final deliveries = StreamController<List<SacredHourDelivery>>.broadcast();
  final hours = <String, SacredHour>{};
  var currentDeliveries = <SacredHourDelivery>[];
  final occurrences = <SacredHourOccurrenceStatus>[];
  final deviceUpdates = <SacredHourDeviceDraft>[];

  @override
  Stream<List<SacredHourDelivery>> watchDeliveries() => deliveries.stream;

  @override
  Stream<SacredHour?> watch(String id) => Stream.value(hours[id]);

  @override
  Future<void> markOccurrence(
    String id,
    DateTime dueAt,
    SacredHourOccurrenceStatus status,
  ) async {
    occurrences.add(status);
  }

  @override
  Future<void> updateDeviceDelivery(
    String id,
    SacredHourDeviceDraft draft,
  ) async {
    deviceUpdates.add(draft);
  }

  @override
  Future<void> archive(String id) => throw UnimplementedError();

  @override
  Future<List<SacredHour>> ensureDefaults({required String timezone}) =>
      throw UnimplementedError();

  @override
  Future<SacredHour> save(SacredHourDraft draft, {String? id}) =>
      throw UnimplementedError();

  @override
  Future<void> setEnabled(String id, bool enabled) =>
      throw UnimplementedError();

  @override
  Stream<List<SacredHour>> watchActive() => throw UnimplementedError();

  @override
  Stream<List<SacredHour>> watchAll() => throw UnimplementedError();

  @override
  Stream<SacredHour?> watchCurrentOrNext(DateTime nowUtc) =>
      throw UnimplementedError();
}

class _Scheduler implements PrayerReminderScheduler {
  final responsesController =
      StreamController<PrayerReminderResponse>.broadcast();
  final attempted = <PrayerScheduledNotification>[];
  final scheduled = <PrayerScheduledNotification>[];
  final cancelled = <int>[];
  var throwOnFirstExact = false;

  @override
  Stream<PrayerReminderResponse> get responses => responsesController.stream;

  @override
  bool get supportsSystemNotifications => true;

  @override
  Future<void> schedule(PrayerScheduledNotification notification) async {
    attempted.add(notification);
    if (throwOnFirstExact &&
        notification.precision == ReminderSchedulePrecision.exact) {
      throwOnFirstExact = false;
      throw StateError('exact alarms unavailable');
    }
    scheduled.add(notification);
  }

  @override
  Future<void> cancel(int platformNotificationId) async {
    cancelled.add(platformNotificationId);
  }

  void emit(PrayerReminderResponse response) =>
      responsesController.add(response);

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationPermissionStatus> permissionStatus() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> showTestReminder() async {}
}

class _ExactPermission implements SacredHourAlarmPermission {
  _ExactPermission(this.value);
  final ExactAlarmPermissionStatus value;

  @override
  Future<bool> request() async => value == ExactAlarmPermissionStatus.granted;

  @override
  Future<ExactAlarmPermissionStatus> status() async => value;
}
