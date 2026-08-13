import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/application/prayer_occurrence_calculator.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_coordinator.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_scheduler.dart';
import 'package:soulbuddy/features/prayers/data/prayer_practice_repository.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 8, 11, 5);

  test(
    'device opt-in requests permission once and schedules only when granted',
    () async {
      final repository = _FakePrayerPracticeRepository();
      final scheduler = _FakePrayerReminderScheduler(permissionGranted: true);
      final coordinator = _coordinator(repository, scheduler, now: now);
      addTearDown(coordinator.dispose);
      await coordinator.start();

      expect(await coordinator.enableOnThisDevice('reminder-1'), isTrue);
      expect(await coordinator.enableOnThisDevice('reminder-1'), isTrue);
      expect(scheduler.permissionCalls, 1);
      expect(repository.deviceChanges, [
        ('reminder-1', true),
        ('reminder-1', true),
      ]);

      repository.emit([_occurrence(nextAt: DateTime.utc(2026, 8, 11, 7, 30))]);
      await pumpEventQueue();
      expect(
        scheduler.scheduled.single.scheduledAtUtc,
        DateTime.utc(2026, 8, 11, 6, 30),
      );
    },
  );

  test('denial keeps the synced reminder but disables this device', () async {
    final repository = _FakePrayerPracticeRepository();
    final scheduler = _FakePrayerReminderScheduler(permissionGranted: false);
    final coordinator = _coordinator(repository, scheduler, now: now);
    addTearDown(coordinator.dispose);
    await coordinator.start();

    expect(await coordinator.enableOnThisDevice('reminder-1'), isFalse);
    expect(repository.deviceChanges, [('reminder-1', false)]);
    expect(scheduler.scheduled, isEmpty);
  });

  test(
    'browser fallback enables the in-app card without an OS prompt',
    () async {
      final repository = _FakePrayerPracticeRepository();
      final scheduler = _FakePrayerReminderScheduler(
        permissionGranted: false,
        supportsSystemNotifications: false,
      );
      final coordinator = _coordinator(repository, scheduler, now: now);
      addTearDown(coordinator.dispose);
      await coordinator.start();

      expect(await coordinator.enableOnThisDevice('reminder-1'), isTrue);
      expect(scheduler.permissionCalls, 0);
      expect(repository.deviceChanges, [('reminder-1', true)]);
    },
  );

  test(
    'schedule and timezone changes cancel before replacing notification',
    () async {
      final repository = _FakePrayerPracticeRepository();
      final scheduler = _FakePrayerReminderScheduler();
      var zone = 'UTC';
      final coordinator = _coordinator(
        repository,
        scheduler,
        now: now,
        timezoneName: () async => zone,
      );
      addTearDown(coordinator.dispose);
      await coordinator.start();

      repository.emit([
        _occurrence(
          nextAt: DateTime.utc(2026, 8, 11, 7, 30),
          scheduledTimezone: 'UTC',
        ),
      ]);
      await pumpEventQueue();
      expect(scheduler.callOrder.take(2), ['cancel:77', 'schedule:77']);
      expect(
        repository.scheduleChanges.last.nextOccurrenceAt,
        DateTime.utc(2026, 8, 11, 6, 30),
      );

      final timezoneEvent = coordinator.events.first;
      zone = 'Africa/Lagos';
      TestWidgetsFlutterBinding.ensureInitialized()
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(
        repository.scheduleChanges.last.nextOccurrenceAt,
        DateTime.utc(2026, 8, 11, 5, 30),
      );
      expect(repository.scheduleChanges.last.scheduledTimezone, 'Africa/Lagos');
      expect(await timezoneEvent, isA<PrayerReminderTimezoneChanged>());
    },
  );

  test(
    'notification actions are occurrence-idempotent and once disables locally',
    () async {
      final repository = _FakePrayerPracticeRepository();
      final scheduler = _FakePrayerReminderScheduler();
      final coordinator = _coordinator(repository, scheduler, now: now);
      addTearDown(coordinator.dispose);
      await coordinator.start();
      final occurrence = _occurrence(
        nextAt: DateTime.utc(2026, 8, 11, 4, 59),
        once: true,
      );
      repository.emit([occurrence]);
      await pumpEventQueue();

      final response = PrayerReminderResponse(
        reminderId: occurrence.reminder.id,
        occurrenceKey: occurrence.occurrenceKey,
        action: PrayerReminderAction.prayed,
      );
      scheduler.emit(response);
      scheduler.emit(response);
      await pumpEventQueue(times: 30);

      expect(repository.sessionRecords, hasLength(1));
      expect(repository.deviceChanges.last, ('reminder-1', false));
      expect(scheduler.cancelled, contains(77));
    },
  );

  test(
    'snooze, dismiss, open, and dispose stop work at the lifecycle boundary',
    () async {
      final repository = _FakePrayerPracticeRepository();
      final scheduler = _FakePrayerReminderScheduler();
      final coordinator = _coordinator(repository, scheduler, now: now);
      await coordinator.start();
      final occurrence = _occurrence(nextAt: DateTime.utc(2026, 8, 11, 4, 59));
      repository.emit([occurrence]);
      await pumpEventQueue();

      scheduler.emit(_response(occurrence, PrayerReminderAction.open));
      scheduler.emit(
        _response(occurrence, PrayerReminderAction.snoozeTenMinutes),
      );
      scheduler.emit(
        _response(occurrence, PrayerReminderAction.snoozeTenMinutes),
      );
      await pumpEventQueue(times: 30);
      expect(repository.snoozes, [
        ('reminder-1', DateTime.utc(2026, 8, 11, 5, 10)),
      ]);

      scheduler.emit(_response(occurrence, PrayerReminderAction.dismiss));
      scheduler.emit(_response(occurrence, PrayerReminderAction.dismiss));
      await pumpEventQueue(times: 30);
      expect(repository.dismissals, [('reminder-1', occurrence.occurrenceKey)]);

      await coordinator.dispose();
      scheduler.emit(_response(occurrence, PrayerReminderAction.prayed));
      repository.emit([occurrence]);
      await pumpEventQueue();
      expect(repository.sessionRecords, isEmpty);
    },
  );

  test('a transient action failure is reported and can be retried', () async {
    final repository = _FakePrayerPracticeRepository()
      ..recordFailuresRemaining = 1;
    final scheduler = _FakePrayerReminderScheduler();
    final coordinator = _coordinator(repository, scheduler, now: now);
    addTearDown(coordinator.dispose);
    await coordinator.start();
    final occurrence = _occurrence(nextAt: DateTime.utc(2026, 8, 11, 4, 59));
    repository.emit([occurrence]);
    await pumpEventQueue();
    final response = _response(occurrence, PrayerReminderAction.prayed);
    final error = expectLater(
      coordinator.events,
      emitsError(isA<StateError>()),
    );

    scheduler.emit(response);
    await error;
    scheduler.emit(response);
    await pumpEventQueue(times: 30);

    expect(repository.recordAttempts, 2);
    expect(repository.sessionRecords, hasLength(1));
  });

  test(
    'buffers a cold-start action until its owned occurrence is loaded',
    () async {
      final occurrence = _occurrence(nextAt: DateTime.utc(2026, 8, 11, 4, 59));
      final repository = _FakePrayerPracticeRepository();
      final scheduler = _FakePrayerReminderScheduler(
        initializeResponse: _response(occurrence, PrayerReminderAction.prayed),
      );
      final coordinator = _coordinator(repository, scheduler, now: now);
      addTearDown(coordinator.dispose);

      await coordinator.start();
      expect(repository.sessionRecords, isEmpty);
      repository.emit([occurrence]);
      await pumpEventQueue(times: 30);

      expect(repository.sessionRecords, hasLength(1));
    },
  );

  test('publishes only currently due private occurrences', () async {
    final repository = _FakePrayerPracticeRepository();
    final scheduler = _FakePrayerReminderScheduler();
    final coordinator = _coordinator(repository, scheduler, now: now);
    addTearDown(coordinator.dispose);
    await coordinator.start();
    final due = coordinator.dueOccurrences.firstWhere(
      (items) => items.isNotEmpty,
    );

    repository.emit([
      _occurrence(nextAt: DateTime.utc(2026, 8, 11, 4, 59)),
      _occurrence(
        reminderId: 'reminder-2',
        nextAt: DateTime.utc(2026, 8, 11, 7),
      ),
    ]);

    expect((await due).map((item) => item.reminder.id), ['reminder-1']);
  });

  test(
    'a reconcile before the schedule watch catches up does not skip today',
    () async {
      var current = DateTime.utc(2026, 8, 11, 5);
      final repository = _FakePrayerPracticeRepository();
      final scheduler = _FakePrayerReminderScheduler();
      final coordinator = PrayerReminderCoordinator(
        repository: repository,
        scheduler: scheduler,
        calculator: TimezonePrayerOccurrenceCalculator.initialize(),
        clock: () => current,
        timezoneName: () async => 'UTC',
      );
      addTearDown(coordinator.dispose);
      await coordinator.start();

      final stale = _occurrence(nextAt: null);
      repository.emit([stale]);
      await pumpEventQueue(times: 20);
      expect(
        repository.scheduleChanges.last.nextOccurrenceAt,
        DateTime.utc(2026, 8, 11, 6, 30),
      );

      current = DateTime.utc(2026, 8, 11, 6, 31);
      await coordinator.reconcileNow();

      expect(coordinator.currentDue, hasLength(1));
      expect(
        repository.scheduleChanges.last.nextOccurrenceAt,
        DateTime.utc(2026, 8, 11, 6, 30),
      );
    },
  );

  test('a newer reminder edit supersedes a pending device schedule', () async {
    var current = DateTime.utc(2026, 8, 11, 5);
    final repository = _FakePrayerPracticeRepository();
    final scheduler = _FakePrayerReminderScheduler();
    final coordinator = PrayerReminderCoordinator(
      repository: repository,
      scheduler: scheduler,
      calculator: TimezonePrayerOccurrenceCalculator.initialize(),
      clock: () => current,
      timezoneName: () async => 'UTC',
    );
    addTearDown(coordinator.dispose);
    await coordinator.start();

    repository.emit([_occurrence(nextAt: null)]);
    await pumpEventQueue(times: 20);
    current = DateTime.utc(2026, 8, 11, 6, 31);
    repository.emit([
      _occurrence(
        nextAt: null,
        localHour: 8,
        reminderUpdatedAt: DateTime.utc(2026, 8, 11, 6, 31),
      ),
    ]);
    await pumpEventQueue(times: 20);

    expect(coordinator.currentDue, isEmpty);
    expect(
      repository.scheduleChanges.last.nextOccurrenceAt,
      DateTime.utc(2026, 8, 11, 8),
    );
  });

  test(
    'dispose waits for the database watch to release before completing',
    () async {
      final repository = _FakePrayerPracticeRepository(
        stallDueCancellation: true,
      );
      final scheduler = _FakePrayerReminderScheduler();
      final coordinator = _coordinator(repository, scheduler, now: now);
      await coordinator.start();

      var completed = false;
      final disposal = coordinator.dispose().then((_) => completed = true);
      await pumpEventQueue();
      expect(repository.dueCancellationStarted, isTrue);
      expect(completed, isFalse);
      repository.releaseDueCancellation();
      await disposal.timeout(const Duration(seconds: 1));
      repository.emit([_occurrence(nextAt: DateTime.utc(2026, 8, 11, 4, 59))]);
      scheduler.emit(
        _response(
          _occurrence(nextAt: DateTime.utc(2026, 8, 11, 4, 59)),
          PrayerReminderAction.prayed,
        ),
      );
      await pumpEventQueue();
      expect(repository.sessionRecords, isEmpty);
    },
  );

  test(
    'concurrent dispose calls await the same reconciliation drain',
    () async {
      final repository = _FakePrayerPracticeRepository();
      final scheduler = _FakePrayerReminderScheduler()..stallCancel = true;
      final coordinator = _coordinator(repository, scheduler, now: now);
      await coordinator.start();
      repository.emit([_occurrence(nextAt: DateTime.utc(2026, 8, 11, 7, 30))]);
      await pumpEventQueue();
      expect(scheduler.cancelCallsStarted, 1);

      var firstCompleted = false;
      var secondCompleted = false;
      final firstDispose = coordinator.dispose().then(
        (_) => firstCompleted = true,
      );
      final secondDispose = coordinator.dispose().then(
        (_) => secondCompleted = true,
      );
      await pumpEventQueue();
      expect(firstCompleted, isFalse);
      expect(secondCompleted, isFalse);
      scheduler.releaseCancel();
      await Future.wait([firstDispose, secondDispose]);
      scheduler.emit(
        _response(
          _occurrence(nextAt: DateTime.utc(2026, 8, 11, 4, 59)),
          PrayerReminderAction.prayed,
        ),
      );
      await pumpEventQueue();
      expect(repository.sessionRecords, isEmpty);
    },
  );

  test('dispose is not held open by a paused public stream listener', () async {
    final repository = _FakePrayerPracticeRepository();
    final scheduler = _FakePrayerReminderScheduler();
    final coordinator = _coordinator(repository, scheduler, now: now);
    await coordinator.start();
    final dueSubscription = coordinator.dueOccurrences.listen((_) {});
    dueSubscription.pause();
    addTearDown(() async {
      dueSubscription.resume();
      await dueSubscription.cancel();
    });

    await coordinator.dispose().timeout(const Duration(seconds: 1));
  });
}

PrayerReminderCoordinator _coordinator(
  _FakePrayerPracticeRepository repository,
  _FakePrayerReminderScheduler scheduler, {
  required DateTime now,
  Future<String> Function()? timezoneName,
}) => PrayerReminderCoordinator(
  repository: repository,
  scheduler: scheduler,
  calculator: TimezonePrayerOccurrenceCalculator.initialize(),
  clock: () => now,
  timezoneName: timezoneName ?? () async => 'UTC',
);

PrayerReminderResponse _response(
  DuePrayerOccurrence occurrence,
  PrayerReminderAction action,
) => PrayerReminderResponse(
  reminderId: occurrence.reminder.id,
  occurrenceKey: occurrence.occurrenceKey,
  action: action,
);

DuePrayerOccurrence _occurrence({
  String reminderId = 'reminder-1',
  required DateTime? nextAt,
  bool once = false,
  String scheduledTimezone = 'UTC',
  int localHour = 6,
  DateTime? reminderUpdatedAt,
}) {
  final schedule = once
      ? PrayerReminderSchedule.once(
          localTime: PrayerLocalTime(hour: 4, minute: 59),
          timezone: 'UTC',
          onceAt: nextAt ?? DateTime.utc(2026, 8, 11, 4, 59),
        )
      : PrayerReminderSchedule.daily(
          localTime: PrayerLocalTime(
            hour: localHour,
            minute: localHour == 6 ? 30 : 0,
          ),
          timezone: 'UTC',
        );
  return DuePrayerOccurrence(
    reminder: PrayerReminder(
      id: reminderId,
      ownerId: 'owner-1',
      personalPrayerId: 'prayer-1',
      schedule: schedule,
      enabled: true,
      createdAt: DateTime.utc(2026),
      updatedAt: reminderUpdatedAt ?? DateTime.utc(2026),
    ),
    device: PrayerReminderDevice(
      id: 'device-row-1',
      reminderId: reminderId,
      deviceId: 'device-1',
      enabledOnDevice: true,
      nextOccurrenceAt: nextAt,
      platformNotificationId: 77,
      scheduledTimezone: scheduledTimezone,
      updatedAt: DateTime.utc(2026),
    ),
    prayerTitle: 'Morning prayer',
    prayerBody: 'Father, guide me today.',
    prayerRevisionId: 'revision-1',
    occurrenceAt: nextAt,
  );
}

class _ScheduleChange {
  const _ScheduleChange(this.nextOccurrenceAt, this.scheduledTimezone);
  final DateTime? nextOccurrenceAt;
  final String scheduledTimezone;
}

class _SessionRecord {
  const _SessionRecord(this.prayerId, this.revisionId, this.occurrenceKey);
  final String prayerId;
  final String revisionId;
  final String? occurrenceKey;
}

class _FakePrayerPracticeRepository implements PrayerPracticeRepository {
  _FakePrayerPracticeRepository({this.stallDueCancellation = false});

  final bool stallDueCancellation;
  final _due = StreamController<List<DuePrayerOccurrence>>.broadcast();
  final deviceChanges = <(String, bool)>[];
  final scheduleChanges = <_ScheduleChange>[];
  final sessionRecords = <_SessionRecord>[];
  final snoozes = <(String, DateTime)>[];
  final dismissals = <(String, String)>[];
  int recordFailuresRemaining = 0;
  int recordAttempts = 0;
  bool dueCancellationStarted = false;
  Completer<void>? _dueCancellationBlocker;

  void emit(List<DuePrayerOccurrence> value) => _due.add(value);

  @override
  Stream<List<DuePrayerOccurrence>> watchDue(DateTime atUtc) =>
      stallDueCancellation ? _stallingDueStream() : _due.stream;

  Stream<List<DuePrayerOccurrence>> _stallingDueStream() async* {
    try {
      yield* _due.stream;
    } finally {
      dueCancellationStarted = true;
      _dueCancellationBlocker ??= Completer<void>();
      await _dueCancellationBlocker!.future;
    }
  }

  void releaseDueCancellation() => _dueCancellationBlocker?.complete();

  @override
  Future<void> setDeviceEnabled(
    String reminderId, {
    required bool enabled,
  }) async {
    deviceChanges.add((reminderId, enabled));
  }

  @override
  Future<void> updateDeviceSchedule({
    required String reminderId,
    required DateTime? nextOccurrenceAt,
    required int platformNotificationId,
    required String scheduledTimezone,
  }) async {
    scheduleChanges.add(_ScheduleChange(nextOccurrenceAt, scheduledTimezone));
  }

  @override
  Future<void> snooze(String reminderId, DateTime untilUtc) async {
    snoozes.add((reminderId, untilUtc));
  }

  @override
  Future<void> dismiss(String reminderId, String occurrenceKey) async {
    dismissals.add((reminderId, occurrenceKey));
  }

  @override
  Future<PrayerSession> recordSession({
    required PrayerReference prayer,
    required String timezone,
    String? revisionId,
    String? reminderId,
    String? occurrenceKey,
  }) async {
    recordAttempts++;
    if (recordFailuresRemaining > 0) {
      recordFailuresRemaining--;
      throw StateError('temporary write failure');
    }
    expect(prayer.source, PrayerSource.personal);
    expect(revisionId, isNotNull);
    sessionRecords.add(_SessionRecord(prayer.id, revisionId!, occurrenceKey));
    return PrayerSession(
      id: 'session-${sessionRecords.length}',
      ownerId: 'owner-1',
      prayer: prayer,
      prayerRevisionId: revisionId,
      reminderId: reminderId,
      reminderOccurrenceKey: occurrenceKey,
      source: reminderId == null
          ? PrayerSessionSource.manual
          : PrayerSessionSource.reminder,
      occurredAt: DateTime.utc(2026, 8, 11, 5),
      localDate: DateTime.utc(2026, 8, 11),
      timezone: timezone,
      deviceId: 'device-1',
    );
  }

  @override
  Stream<PrayerReminder?> watchReminder(String personalPrayerId) =>
      const Stream.empty();

  @override
  Stream<PrayerReminderDevice?> watchDevice(String reminderId) =>
      const Stream.empty();

  @override
  Stream<int> watchSessionCount(String revisionId) => const Stream.empty();

  @override
  Stream<bool> watchSessionForDate(
    PrayerReference prayer,
    DateTime localDate, {
    String? revisionId,
  }) => const Stream.empty();

  @override
  Future<int> getSessionCount(String revisionId) async => 0;

  @override
  Future<PrayerReminder> saveReminder({
    required String personalPrayerId,
    required PrayerReminderSchedule schedule,
    required bool enableOnThisDevice,
  }) => throw UnimplementedError();

  @override
  Future<void> archiveReminder(String reminderId) async {}

  @override
  Future<void> retractSession(String sessionId) async {}
}

class _FakePrayerReminderScheduler implements PrayerReminderScheduler {
  _FakePrayerReminderScheduler({
    this.permissionGranted = true,
    this.initializeResponse,
    this.supportsSystemNotifications = true,
  });
  final bool permissionGranted;
  final PrayerReminderResponse? initializeResponse;
  @override
  final bool supportsSystemNotifications;
  final _responses = StreamController<PrayerReminderResponse>.broadcast();
  final scheduled = <PrayerScheduledNotification>[];
  final cancelled = <int>[];
  final callOrder = <String>[];
  int permissionCalls = 0;
  int cancelCallsStarted = 0;
  bool stallCancel = false;
  Completer<void>? _cancelBlocker;

  @override
  Stream<PrayerReminderResponse> get responses => _responses.stream;

  @override
  Future<void> initialize() async {
    final response = initializeResponse;
    if (response != null) _responses.add(response);
  }

  @override
  Future<bool> requestPermission() async {
    permissionCalls++;
    return permissionGranted;
  }

  @override
  Future<NotificationPermissionStatus> permissionStatus() async =>
      permissionGranted
      ? NotificationPermissionStatus.granted
      : NotificationPermissionStatus.denied;

  @override
  Future<void> showTestReminder() async {}

  @override
  Future<void> schedule(PrayerScheduledNotification notification) async {
    scheduled.add(notification);
    callOrder.add('schedule:${notification.platformNotificationId}');
  }

  @override
  Future<void> cancel(int platformNotificationId) async {
    cancelCallsStarted++;
    if (stallCancel) {
      _cancelBlocker ??= Completer<void>();
      await _cancelBlocker!.future;
    }
    cancelled.add(platformNotificationId);
    callOrder.add('cancel:$platformNotificationId');
  }

  void emit(PrayerReminderResponse response) => _responses.add(response);

  void releaseCancel() => _cancelBlocker?.complete();
}
