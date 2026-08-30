import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/persons/application/person_prayer_reminder_coordinator.dart';
import 'package:soulbuddy/features/persons/data/person_repository.dart';
import 'package:soulbuddy/features/persons/domain/person_prayer_occurrence.dart';
import 'package:soulbuddy/features/persons/domain/prayer_person.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_scheduler.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';

void main() {
  test('schedules daily person reminder with clear private copy', () async {
    final repository = _Repository();
    final scheduler = _Scheduler();
    final coordinator = PersonPrayerReminderCoordinator(
      repository: repository,
      scheduler: scheduler,
      timezoneName: () async => 'UTC',
      clock: () => DateTime.utc(2026, 8, 30, 6),
    );
    addTearDown(coordinator.dispose);
    await coordinator.start();
    repository.people.add([_person()]);
    await pumpEventQueue();

    expect(scheduler.scheduled, hasLength(1));
    expect(scheduler.scheduled.single.kind, ReminderNotificationKind.person);
    expect(
      scheduler.scheduled.single.recurrence,
      ReminderNotificationRecurrence.daily,
    );
    expect(scheduler.scheduled.single.title, 'Remember Mum in prayer');
    expect(
      scheduler.scheduled.single.scheduledAtUtc,
      DateTime.utc(2026, 8, 30, 7),
    );
  });

  test('acknowledgement records prayer and archive cancels reminder', () async {
    final repository = _Repository();
    final scheduler = _Scheduler();
    final now = DateTime.utc(2026, 8, 30, 6);
    final coordinator = PersonPrayerReminderCoordinator(
      repository: repository,
      scheduler: scheduler,
      timezoneName: () async => 'UTC',
      clock: () => now,
    );
    addTearDown(coordinator.dispose);
    await coordinator.start();
    repository.people.add([_person()]);
    await pumpEventQueue();
    final notification = scheduler.scheduled.single;

    scheduler.responsesController.add(
      PrayerReminderResponse(
        reminderId: 'person-1',
        occurrenceKey: notification.occurrenceKey,
        action: PrayerReminderAction.prayed,
        kind: ReminderNotificationKind.person,
      ),
    );
    await pumpEventQueue();
    expect(repository.recorded, ['person-1:2026-08-30']);

    repository.people.add([_person(archivedAt: now)]);
    await pumpEventQueue();
    expect(scheduler.cancelled, contains(notification.platformNotificationId));
  });

  test(
    'invalid stored timezone falls back and later reconciles continue',
    () async {
      final repository = _Repository();
      final scheduler = _Scheduler()..scheduleFailures = 1;
      final coordinator = PersonPrayerReminderCoordinator(
        repository: repository,
        scheduler: scheduler,
        timezoneName: () async => 'UTC',
        clock: () => DateTime.utc(2026, 8, 30, 6),
      );
      addTearDown(coordinator.dispose);
      await coordinator.start();

      repository.people.add([_person(timezoneName: 'Unavailable/Zone')]);
      await pumpEventQueue();
      repository.people.add([_person(timezoneName: 'Unavailable/Zone')]);
      await pumpEventQueue();

      expect(scheduler.scheduled, hasLength(1));
      expect(scheduler.scheduled.single.timeZoneName, 'UTC');
    },
  );

  test('buffers a cold-launch response until its Person is loaded', () async {
    final repository = _Repository();
    final scheduler = _Scheduler()
      ..responseOnInitialize = const PrayerReminderResponse(
        reminderId: 'person-1',
        occurrenceKey: 'person-1@cold-launch',
        action: PrayerReminderAction.open,
        kind: ReminderNotificationKind.person,
      );
    final coordinator = PersonPrayerReminderCoordinator(
      repository: repository,
      scheduler: scheduler,
      timezoneName: () async => 'UTC',
    );
    addTearDown(coordinator.dispose);

    await coordinator.start();
    repository.people.add([_person()]);
    final opened = await coordinator.events.first;

    expect(opened.personId, 'person-1');
  });

  test(
    'enable reports scheduling failure while preserving queue recovery',
    () async {
      final repository = _Repository();
      final scheduler = _Scheduler()
        ..permission = NotificationPermissionStatus.denied
        ..scheduleFailures = 1;
      final coordinator = PersonPrayerReminderCoordinator(
        repository: repository,
        scheduler: scheduler,
        timezoneName: () async => 'UTC',
      );
      addTearDown(coordinator.dispose);
      await coordinator.start();
      repository.people.add([_person()]);
      await pumpEventQueue();

      await expectLater(coordinator.enable(), throwsStateError);
      await coordinator.enable();
      expect(scheduler.scheduled, hasLength(1));
    },
  );
}

PrayerPerson _person({DateTime? archivedAt, String timezoneName = 'UTC'}) =>
    PrayerPerson(
      id: 'person-1',
      ownerId: 'owner-1',
      name: 'Mum',
      cadence: PersonPrayerCadence.daily,
      localTime: '07:00',
      timezone: timezoneName,
      weekdaysMask: 0,
      createdAt: DateTime.utc(2026, 8, 30),
      updatedAt: DateTime.utc(2026, 8, 30),
      archivedAt: archivedAt,
    );

class _Repository implements PersonRepository {
  final people = StreamController<List<PrayerPerson>>.broadcast();
  final recorded = <String>[];

  @override
  Stream<List<PrayerPerson>> watchForReminders() => people.stream;

  @override
  Future<PersonPrayerOccurrence?> recordPrayer(
    String personId, {
    required DateTime localDate,
  }) async {
    final key = personPrayerLocalDateKey(localDate);
    recorded.add('$personId:$key');
    return PersonPrayerOccurrence(
      id: 'occurrence-1',
      personId: personId,
      ownerId: 'owner-1',
      localDate: key,
      occurrenceKey: '$personId:$key',
      prayedAt: localDate,
      deviceId: 'device-1',
    );
  }

  @override
  Future<void> archive(String id) => throw UnimplementedError();

  @override
  Future<PrayerPerson> create(PrayerPersonDraft draft) =>
      throw UnimplementedError();

  @override
  Future<PrayerPerson> update(String id, PrayerPersonDraft draft) =>
      throw UnimplementedError();

  @override
  Stream<PrayerPerson?> watch(String id) => throw UnimplementedError();

  @override
  Stream<List<PrayerPerson>> watchActive() => throw UnimplementedError();

  @override
  Stream<List<DuePersonPrayer>> watchDue(DateTime localDate) =>
      throw UnimplementedError();

  @override
  Stream<List<Encounter>> watchLinkedMemories(String personId) =>
      throw UnimplementedError();
}

class _Scheduler implements PrayerReminderScheduler {
  final responsesController =
      StreamController<PrayerReminderResponse>.broadcast();
  final scheduled = <PrayerScheduledNotification>[];
  final cancelled = <int>[];
  int scheduleFailures = 0;
  NotificationPermissionStatus permission =
      NotificationPermissionStatus.granted;
  PrayerReminderResponse? responseOnInitialize;

  @override
  Stream<PrayerReminderResponse> get responses => responsesController.stream;

  @override
  bool get supportsSystemNotifications => true;

  @override
  Future<void> cancel(int platformNotificationId) async {
    cancelled.add(platformNotificationId);
  }

  @override
  Future<void> initialize() async {
    final response = responseOnInitialize;
    if (response != null) responsesController.add(response);
  }

  @override
  Future<NotificationPermissionStatus> permissionStatus() async => permission;

  @override
  Future<bool> requestPermission() async {
    permission = NotificationPermissionStatus.granted;
    return true;
  }

  @override
  Future<void> schedule(PrayerScheduledNotification notification) async {
    if (scheduleFailures > 0) {
      scheduleFailures--;
      throw StateError('scheduler');
    }
    scheduled.add(notification);
  }

  @override
  Future<void> showTestReminder() async {}
}
