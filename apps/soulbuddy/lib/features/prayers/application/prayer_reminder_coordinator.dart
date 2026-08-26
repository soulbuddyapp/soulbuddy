import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/prayer_practice_repository.dart';
import '../domain/prayer_reminder.dart';
import '../domain/prayer_reference.dart';
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
  late final StreamController<PrayerReminderCoordinatorEvent> _events =
      StreamController<PrayerReminderCoordinatorEvent>.broadcast(
        onListen: _flushEventBacklog,
      );
  late final StreamController<List<DuePrayerOccurrence>> _dueChanges =
      StreamController<List<DuePrayerOccurrence>>.broadcast(
        onListen: _replayCurrentDue,
      );
  final _eventBacklog = <PrayerReminderCoordinatorEvent>[];
  final _processedActions = <String>{};
  final _hiddenOccurrenceKeys = <String>{};
  final _pendingResponses = <PrayerReminderResponse>[];
  final _pendingSchedules = <String, _PendingPrayerSchedule>{};

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
  List<DuePrayerOccurrence> _currentDue = const [];
  Future<void>? _disposeFuture;

  Stream<PrayerReminderCoordinatorEvent> get events => _events.stream;
  Stream<List<DuePrayerOccurrence>> get dueOccurrences => _dueChanges.stream;
  List<DuePrayerOccurrence> get currentDue => _currentDue;

  Future<void> start() async {
    if (_disposed) {
      throw StateError('Prayer reminder coordinator is disposed');
    }
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _occurrencesSubscription = _repository
        .watchDue(_allScheduledBoundary)
        .listen((occurrences) {
          _occurrences = List.unmodifiable(
            occurrences.map(_applyPendingSchedule),
          );
          final keys = {
            for (final occurrence in occurrences)
              if (occurrence.occurrenceAt != null) occurrence.occurrenceKey,
          };
          _hiddenOccurrenceKeys.retainWhere(keys.contains);
          _processedActions.removeWhere(
            (actionKey) => !keys.any(actionKey.endsWith),
          );
          _enqueueReported(() async {
            await _drainPendingResponses();
            await _reconcile();
          });
        }, onError: _reportError);
    _responsesSubscription = _scheduler.responses.listen(
      (response) => _enqueueReported(() async {
        await _handleResponse(response);
      }),
      onError: _reportError,
    );
    await _scheduler.initialize();
    await reconcileNow();
  }

  Future<bool> enableOnThisDevice(String reminderId) async {
    if (_disposed) {
      return false;
    }
    if (!_scheduler.supportsSystemNotifications) {
      await _repository.setDeviceEnabled(reminderId, enabled: true);
      return true;
    }
    if (!_permissionAsked) {
      _permissionAsked = true;
      _permissionGranted = await _scheduler.requestPermission();
    }
    await _repository.setDeviceEnabled(reminderId, enabled: _permissionGranted);
    return _permissionGranted;
  }

  Future<void> reconcileNow() => _enqueue(_reconcile);

  Future<PrayerSession?> performAction(
    DuePrayerOccurrence occurrence,
    PrayerReminderAction action,
  ) async {
    PrayerSession? session;
    await _enqueue(() async {
      session = await _handleResponse(
        PrayerReminderResponse(
          reminderId: occurrence.reminder.id,
          occurrenceKey: occurrence.occurrenceKey,
          action: action,
        ),
      );
    });
    return session;
  }

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
      _emitEvent(
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
    _refreshDue(now);
    _armTimer(now, earliestFuture);
  }

  Future<PrayerSession?> _handleResponse(
    PrayerReminderResponse response,
  ) async {
    if (_disposed) {
      return null;
    }
    if (response.kind != ReminderNotificationKind.prayer) return null;
    final occurrence = _occurrences.cast<DuePrayerOccurrence?>().firstWhere(
      (candidate) =>
          candidate?.reminder.id == response.reminderId &&
          candidate?.occurrenceKey == response.occurrenceKey,
      orElse: () => null,
    );
    if (occurrence == null) {
      final duplicate = _pendingResponses.any(
        (pending) =>
            pending.reminderId == response.reminderId &&
            pending.occurrenceKey == response.occurrenceKey &&
            pending.action == response.action,
      );
      if (!duplicate && _pendingResponses.length < 16) {
        _pendingResponses.add(response);
      }
      return null;
    }
    final actionKey =
        '${response.action.name}:${response.reminderId}:${response.occurrenceKey}';
    if (!_processedActions.add(actionKey)) {
      return null;
    }

    try {
      switch (response.action) {
        case PrayerReminderAction.open:
          _emitEvent(PrayerReminderOpened(occurrence));
          return null;
        case PrayerReminderAction.prayed:
          final session = await _repository.recordSession(
            prayer: PrayerReference.personal(
              occurrence.reminder.personalPrayerId,
            ),
            revisionId: occurrence.prayerRevisionId,
            timezone: await _timezoneName(),
            reminderId: occurrence.reminder.id,
            occurrenceKey: occurrence.occurrenceKey,
          );
          _emitEvent(PrayerReminderPrayed(occurrence, session));
          await _advanceAfterOccurrence(occurrence);
          return session;
        case PrayerReminderAction.snoozeTenMinutes:
          final until = _clock().toUtc().add(const Duration(minutes: 10));
          await _repository.snooze(occurrence.reminder.id, until);
          _hiddenOccurrenceKeys.add(occurrence.occurrenceKey);
          _refreshDue(_clock().toUtc());
          _emitEvent(PrayerReminderSnoozed(occurrence, until));
          return null;
        case PrayerReminderAction.dismiss:
          await _repository.dismiss(
            occurrence.reminder.id,
            occurrence.occurrenceKey,
          );
          _hiddenOccurrenceKeys.add(occurrence.occurrenceKey);
          _refreshDue(_clock().toUtc());
          _emitEvent(PrayerReminderDismissed(occurrence));
          await _advanceAfterOccurrence(occurrence);
          return null;
      }
    } catch (_) {
      _processedActions.remove(actionKey);
      rethrow;
    }
  }

  Future<void> _advanceAfterOccurrence(DuePrayerOccurrence occurrence) async {
    _hiddenOccurrenceKeys.add(occurrence.occurrenceKey);
    _refreshDue(_clock().toUtc());
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

  Future<void> _drainPendingResponses() async {
    if (_pendingResponses.isEmpty) return;
    final pending = List<PrayerReminderResponse>.of(_pendingResponses);
    _pendingResponses.clear();
    for (final response in pending) {
      await _handleResponse(response);
    }
  }

  void _refreshDue(DateTime nowUtc) {
    final due = <DuePrayerOccurrence>[];
    for (final occurrence in _occurrences) {
      final at = occurrence.occurrenceAt;
      if (at == null || at.toUtc().isAfter(nowUtc)) continue;
      final key = occurrence.occurrenceKey;
      if (_hiddenOccurrenceKeys.contains(key) ||
          occurrence.device.dismissedOccurrenceKey == key) {
        continue;
      }
      due.add(occurrence);
    }
    _currentDue = List.unmodifiable(due);
    if (!_disposed && !_dueChanges.isClosed) {
      _dueChanges.add(_currentDue);
    }
  }

  Future<void> _replaceNotification(
    DuePrayerOccurrence occurrence, {
    required DateTime expectedAt,
    required String timezoneName,
  }) async {
    final id = occurrence.device.platformNotificationId;
    await _scheduler.cancel(id);
    _pendingSchedules[occurrence.reminder.id] = _PendingPrayerSchedule(
      nextOccurrenceAt: expectedAt,
      scheduledTimezone: timezoneName,
      reminderUpdatedAt: occurrence.reminder.updatedAt,
    );
    await _repository.updateDeviceSchedule(
      reminderId: occurrence.reminder.id,
      nextOccurrenceAt: expectedAt,
      platformNotificationId: id,
      scheduledTimezone: timezoneName,
    );
    _occurrences = List.unmodifiable(_occurrences.map(_applyPendingSchedule));
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

  DuePrayerOccurrence _applyPendingSchedule(DuePrayerOccurrence occurrence) {
    final pending = _pendingSchedules[occurrence.reminder.id];
    if (pending == null) return occurrence;
    if (occurrence.reminder.updatedAt.isAfter(pending.reminderUpdatedAt)) {
      _pendingSchedules.remove(occurrence.reminder.id);
      return occurrence;
    }
    if (occurrence.device.nextOccurrenceAt?.toUtc() ==
            pending.nextOccurrenceAt.toUtc() &&
        occurrence.device.scheduledTimezone == pending.scheduledTimezone) {
      _pendingSchedules.remove(occurrence.reminder.id);
      return occurrence;
    }
    final device = occurrence.device;
    return DuePrayerOccurrence(
      reminder: occurrence.reminder,
      device: PrayerReminderDevice(
        id: device.id,
        reminderId: device.reminderId,
        deviceId: device.deviceId,
        enabledOnDevice: device.enabledOnDevice,
        nextOccurrenceAt: pending.nextOccurrenceAt,
        platformNotificationId: device.platformNotificationId,
        scheduledTimezone: pending.scheduledTimezone,
        snoozedUntil: device.snoozedUntil,
        dismissedOccurrenceKey: device.dismissedOccurrenceKey,
        updatedAt: device.updatedAt,
      ),
      prayerTitle: occurrence.prayerTitle,
      prayerBody: occurrence.prayerBody,
      prayerRevisionId: occurrence.prayerRevisionId,
      occurrenceAt: pending.nextOccurrenceAt,
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

  void _emitEvent(PrayerReminderCoordinatorEvent event) {
    if (_events.hasListener) {
      _events.add(event);
      return;
    }
    if (_eventBacklog.length == 16) {
      _eventBacklog.removeAt(0);
    }
    _eventBacklog.add(event);
  }

  void _flushEventBacklog() {
    if (_eventBacklog.isEmpty) return;
    final pending = List<PrayerReminderCoordinatorEvent>.of(_eventBacklog);
    _eventBacklog.clear();
    scheduleMicrotask(() {
      if (_disposed || _events.isClosed) return;
      for (final event in pending) {
        _events.add(event);
      }
    });
  }

  void _replayCurrentDue() {
    scheduleMicrotask(() {
      if (!_disposed && !_dueChanges.isClosed) {
        _dueChanges.add(_currentDue);
      }
    });
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await _occurrencesSubscription?.cancel();
    await _responsesSubscription?.cancel();
    await _serial;
    unawaited(_dueChanges.close());
    unawaited(_events.close());
  }
}

class _PendingPrayerSchedule {
  const _PendingPrayerSchedule({
    required this.nextOccurrenceAt,
    required this.scheduledTimezone,
    required this.reminderUpdatedAt,
  });

  final DateTime nextOccurrenceAt;
  final String scheduledTimezone;
  final DateTime reminderUpdatedAt;
}
