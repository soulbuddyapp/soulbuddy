import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/prayer_practice_repository.dart';
import '../domain/prayer_reminder.dart';
import '../domain/prayer_session.dart';
import 'prayer_occurrence_calculator.dart';
import 'prayer_reminder_scheduler.dart';

sealed class PrayerReminderCoordinatorEvent {
  const PrayerReminderCoordinatorEvent(this.occurrence);

  final DuePrayerOccurrence? occurrence;
}

final class PrayerReminderOpened extends PrayerReminderCoordinatorEvent {
  const PrayerReminderOpened(super.occurrence);
}

final class PrayerReminderPrayed extends PrayerReminderCoordinatorEvent {
  const PrayerReminderPrayed(super.occurrence, this.session);

  final PrayerSession session;
}

final class PrayerReminderSnoozed extends PrayerReminderCoordinatorEvent {
  const PrayerReminderSnoozed(super.occurrence, this.untilUtc);

  final DateTime untilUtc;
}

final class PrayerReminderDismissed extends PrayerReminderCoordinatorEvent {
  const PrayerReminderDismissed(super.occurrence);
}

final class PrayerReminderTimezoneChanged
    extends PrayerReminderCoordinatorEvent {
  const PrayerReminderTimezoneChanged({
    required this.previousTimezone,
    required this.currentTimezone,
  }) : super(null);

  final String previousTimezone;
  final String currentTimezone;
}

class PrayerReminderCoordinator with WidgetsBindingObserver {
  PrayerReminderCoordinator({
    required PrayerPracticeRepository repository,
    required PrayerReminderScheduler scheduler,
    required PrayerOccurrenceCalculator calculator,
    required DateTime Function() clock,
    required Future<String> Function() timezoneName,
  }) : _repository = repository,
       _scheduler = scheduler,
       _calculator = calculator,
       _clock = clock,
       _timezoneName = timezoneName;

  static final DateTime _allScheduledBoundary = DateTime.utc(9999, 12, 31);
  static const Duration _maximumTimerWait = Duration(minutes: 15);

  final PrayerPracticeRepository _repository;
  final PrayerReminderScheduler _scheduler;
  final PrayerOccurrenceCalculator _calculator;
  final DateTime Function() _clock;
  final Future<String> Function() _timezoneName;
  final _events = StreamController<PrayerReminderCoordinatorEvent>.broadcast();
  final _processedActions = <String>{};

  StreamSubscription<List<DuePrayerOccurrence>>? _occurrencesSubscription;
  StreamSubscription<PrayerReminderResponse>? _responsesSubscription;
  List<DuePrayerOccurrence> _occurrences = const [];
  Future<void> _serial = Future<void>.value();
  Timer? _timer;
  String? _lastTimezone;
  bool _started = false;
  bool _disposed = false;
  bool _permissionAsked = false;
  bool _permissionGranted = false;

  Stream<PrayerReminderCoordinatorEvent> get events => _events.stream;

  Future<void> start() async {
    if (_disposed) {
      throw StateError('Prayer reminder coordinator is disposed');
    }
    if (_started) {
      return;
    }
    _started = true;
    await _scheduler.initialize();
    WidgetsBinding.instance.addObserver(this);
    _occurrencesSubscription = _repository
        .watchDue(_allScheduledBoundary)
        .listen((occurrences) {
          _occurrences = List.unmodifiable(occurrences);
          _enqueueReported(_reconcile);
        }, onError: _reportError);
    _responsesSubscription = _scheduler.responses.listen(
      (response) => _enqueueReported(() => _handleResponse(response)),
      onError: _reportError,
    );
    await reconcileNow();
  }

  Future<bool> enableOnThisDevice(String reminderId) async {
    if (_disposed) {
      return false;
    }
    if (!_permissionAsked) {
      _permissionAsked = true;
      _permissionGranted = await _scheduler.requestPermission();
    }
    await _repository.setDeviceEnabled(reminderId, enabled: _permissionGranted);
    return _permissionGranted;
  }

  Future<void> reconcileNow() => _enqueue(_reconcile);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_disposed) {
      _enqueueReported(_reconcile);
    }
  }

  Future<void> _reconcile() async {
    if (_disposed) {
      return;
    }
    final currentTimezone = (await _timezoneName()).trim();
    if (currentTimezone.isEmpty || currentTimezone.length > 64) {
      throw StateError('Device timezone is unavailable');
    }
    final previousTimezone = _lastTimezone;
    _lastTimezone = currentTimezone;
    if (previousTimezone != null && previousTimezone != currentTimezone) {
      _events.add(
        PrayerReminderTimezoneChanged(
          previousTimezone: previousTimezone,
          currentTimezone: currentTimezone,
        ),
      );
    }

    final now = _clock().toUtc();
    DateTime? earliestFuture;
    for (final occurrence in _occurrences) {
      if (!occurrence.reminder.enabled || !occurrence.device.enabledOnDevice) {
        continue;
      }
      final outstandingAt =
          occurrence.device.snoozedUntil ?? occurrence.device.nextOccurrenceAt;
      if (outstandingAt != null && !outstandingAt.toUtc().isAfter(now)) {
        continue;
      }
      final schedule = _scheduleInTimezone(
        occurrence.reminder.schedule,
        currentTimezone,
      );
      final expectedAt =
          occurrence.device.snoozedUntil?.toUtc() ??
          _calculator.next(schedule, afterUtc: now);
      if (expectedAt == null) {
        await _cancelAndDisable(occurrence);
        continue;
      }
      if (earliestFuture == null || expectedAt.isBefore(earliestFuture)) {
        earliestFuture = expectedAt;
      }
      final unchanged =
          occurrence.device.nextOccurrenceAt?.toUtc() == expectedAt &&
          occurrence.device.scheduledTimezone == currentTimezone;
      if (unchanged) {
        continue;
      }
      await _replaceNotification(
        occurrence,
        expectedAt: expectedAt,
        timezoneName: currentTimezone,
      );
    }
    _armTimer(now, earliestFuture);
  }

  Future<void> _handleResponse(PrayerReminderResponse response) async {
    if (_disposed) {
      return;
    }
    final occurrence = _occurrences.cast<DuePrayerOccurrence?>().firstWhere(
      (candidate) =>
          candidate?.reminder.id == response.reminderId &&
          candidate?.occurrenceKey == response.occurrenceKey,
      orElse: () => null,
    );
    if (occurrence == null) {
      return;
    }
    final actionKey =
        '${response.action.name}:${response.reminderId}:${response.occurrenceKey}';
    if (!_processedActions.add(actionKey)) {
      return;
    }

    try {
      switch (response.action) {
        case PrayerReminderAction.open:
          _events.add(PrayerReminderOpened(occurrence));
        case PrayerReminderAction.prayed:
          final session = await _repository.recordSession(
            personalPrayerId: occurrence.reminder.personalPrayerId,
            revisionId: occurrence.prayerRevisionId,
            timezone: await _timezoneName(),
            reminderId: occurrence.reminder.id,
            occurrenceKey: occurrence.occurrenceKey,
          );
          _events.add(PrayerReminderPrayed(occurrence, session));
          await _advanceAfterOccurrence(occurrence);
        case PrayerReminderAction.snoozeTenMinutes:
          final until = _clock().toUtc().add(const Duration(minutes: 10));
          await _repository.snooze(occurrence.reminder.id, until);
          _events.add(PrayerReminderSnoozed(occurrence, until));
        case PrayerReminderAction.dismiss:
          await _repository.dismiss(
            occurrence.reminder.id,
            occurrence.occurrenceKey,
          );
          _events.add(PrayerReminderDismissed(occurrence));
          await _advanceAfterOccurrence(occurrence);
      }
    } catch (_) {
      _processedActions.remove(actionKey);
      rethrow;
    }
  }

  Future<void> _advanceAfterOccurrence(DuePrayerOccurrence occurrence) async {
    if (occurrence.reminder.schedule.type == PrayerScheduleType.once) {
      await _cancelAndDisable(occurrence);
      return;
    }
    final timezoneName = await _timezoneName();
    final schedule = _scheduleInTimezone(
      occurrence.reminder.schedule,
      timezoneName,
    );
    final next = _calculator.next(
      schedule,
      afterUtc: occurrence.occurrenceAt!.toUtc(),
    );
    if (next == null) {
      await _cancelAndDisable(occurrence);
      return;
    }
    await _replaceNotification(
      occurrence,
      expectedAt: next,
      timezoneName: timezoneName,
    );
  }

  Future<void> _replaceNotification(
    DuePrayerOccurrence occurrence, {
    required DateTime expectedAt,
    required String timezoneName,
  }) async {
    final id = occurrence.device.platformNotificationId;
    await _scheduler.cancel(id);
    await _repository.updateDeviceSchedule(
      reminderId: occurrence.reminder.id,
      nextOccurrenceAt: expectedAt,
      platformNotificationId: id,
      scheduledTimezone: timezoneName,
    );
    await _scheduler.schedule(
      PrayerScheduledNotification(
        platformNotificationId: id,
        reminderId: occurrence.reminder.id,
        occurrenceKey:
            '${occurrence.reminder.id}@${expectedAt.toUtc().toIso8601String()}',
        scheduledAtUtc: expectedAt.toUtc(),
      ),
    );
  }

  Future<void> _cancelAndDisable(DuePrayerOccurrence occurrence) async {
    await _scheduler.cancel(occurrence.device.platformNotificationId);
    await _repository.setDeviceEnabled(occurrence.reminder.id, enabled: false);
  }

  PrayerReminderSchedule _scheduleInTimezone(
    PrayerReminderSchedule schedule,
    String timezoneName,
  ) => switch (schedule.type) {
    PrayerScheduleType.once => PrayerReminderSchedule.once(
      localTime: schedule.localTime,
      timezone: timezoneName,
      onceAt: schedule.onceAt!,
    ),
    PrayerScheduleType.daily => PrayerReminderSchedule.daily(
      localTime: schedule.localTime,
      timezone: timezoneName,
    ),
    PrayerScheduleType.weekdays => PrayerReminderSchedule.weekdays(
      localTime: schedule.localTime,
      timezone: timezoneName,
      weekdaysMask: schedule.weekdaysMask!,
    ),
  };

  void _armTimer(DateTime now, DateTime? earliestFuture) {
    _timer?.cancel();
    if (_disposed) {
      return;
    }
    var wait = _maximumTimerWait;
    if (earliestFuture != null) {
      final until = earliestFuture.difference(now);
      if (until > Duration.zero && until < wait) {
        wait = until;
      }
    }
    _timer = Timer(wait, () => _enqueueReported(_reconcile));
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _serial.then((_) => operation());
    _serial = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  void _enqueueReported(Future<void> Function() operation) {
    unawaited(_enqueue(operation).catchError(_reportError));
  }

  void _reportError(Object error, [StackTrace? stackTrace]) {
    if (!_disposed && !_events.isClosed) {
      _events.addError(error, stackTrace);
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await _occurrencesSubscription?.cancel();
    await _responsesSubscription?.cancel();
    await _serial;
    await _events.close();
  }
}
