import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/altar/application/altar_reminder_coordinator.dart';
import 'package:soulbuddy/features/altar/data/altar_ritual_repository.dart';
import 'package:soulbuddy/features/altar/domain/altar_ritual.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_scheduler.dart';

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
      ),
    ]);
    await pumpEventQueue();

    expect(scheduler.scheduled.single.kind, ReminderNotificationKind.altar);
    expect(scheduler.scheduled.single.reminderId, 'ritual-1');

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

  @override
  Stream<PrayerReminderResponse> get responses => responseController.stream;

  @override
  bool get supportsSystemNotifications => true;

  @override
  Future<void> cancel(int platformNotificationId) async {}

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
