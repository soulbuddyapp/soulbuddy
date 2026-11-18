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
  bool _initialized = false;
  final _nativeSchedules = <String, ({int base, String signature})>{};
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
          _enqueueReported(() async {
            await _drainPendingResponses();
            await _reconcile();
          });
        }, onError: _reportError);
    _responsesSubscription = _scheduler
        .responsesFor(ReminderNotificationKind.prayer)
        .listen(
          (response) => _enqueueReported(() async {
            await _handleResponse(response);
          }),
          onError: _reportError,
        );
    await _scheduler.initialize();
    _initialized = true;
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
    } else {
      _permissionGranted =
          await _scheduler.permissionStatus() ==
          NotificationPermissionStatus.granted;
    }
    await _repository.setDeviceEnabled(reminderId, enabled: _permissionGranted);
    return _permissionGranted;
  }

  Future<void> reconcileNow() => _enqueue(() => _reconcile(rearm: true));

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
      _enqueueReported(() => _reconcile(rearm: true));
    }
  }

  Future<void> _reconcile({bool rearm = false}) async {
    if (_disposed || !_initialized) {
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
    final active = {
      for (final occurrence in _occurrences)
        if (occurrence.reminder.enabled && occurrence.device.enabledOnDevice)
          occurrence.reminder.id,
    };
    for (final id in _nativeSchedules.keys.toList()) {
      if (!active.contains(id)) {
        await _cancelPlatformNotifications(_nativeSchedules[id]!.base);
        _nativeSchedules.remove(id);
      }
    }
    for (final occurrence in _occurrences) {
      if (!occurrence.reminder.enabled || !occurrence.device.enabledOnDevice) {
        continue;
      }
      // Keep the outstanding occurrence available for acknowledgement while
      // independently maintaining the next native recurring alarm.
      final outstandingAt =
          occurrence.device.snoozedUntil ?? occurrence.device.nextOccurrenceAt;
      if (outstandingAt != null && !outstandingAt.toUtc().isAfter(now)) {
        await _ensureNativeNotifications(
          occurrence,
          currentTimezone,
          rearm: rearm,
        );
        continue;
      }
      if (occurrence.device.snoozedUntil case final snooze?) {
        await _ensureNativeNotifications(
          occurrence,
          currentTimezone,
          rearm: rearm,
        );
        if (earliestFuture == null || snooze.isBefore(earliestFuture)) {
          earliestFuture = snooze;
        }
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
        await _ensureNativeNotifications(
          occurrence,
          currentTimezone,
          rearm: rearm,
        );
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
    final occurrence = _occurrenceFor(response);
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
        '${response.action.name}:${response.reminderId}:${occurrence.occurrenceKey}';
    if (_processedActions.contains(actionKey)) return null;
    // Database advancement must not make a repeated tap actionable again.
    if (_processedActions.length == 128) {
      _processedActions.remove(_processedActions.first);
    }
    _processedActions.add(actionKey);

    try {
      switch (response.action) {
        case PrayerReminderAction.open:
        case PrayerReminderAction.begin:
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

  DuePrayerOccurrence? _occurrenceFor(PrayerReminderResponse response) {
    final exact = _occurrences.cast<DuePrayerOccurrence?>().firstWhere(
      (candidate) =>
          candidate?.reminder.id == response.reminderId &&
          candidate?.occurrenceKey == response.occurrenceKey,
      orElse: () => null,
    );
    if (exact?.reminder.schedule.type == PrayerScheduleType.once) {
      return exact;
    }
    final recurring = _occurrences.cast<DuePrayerOccurrence?>().firstWhere(
      (candidate) =>
          candidate?.reminder.id == response.reminderId &&
          candidate?.reminder.schedule.type != PrayerScheduleType.once,
      orElse: () => null,
    );
    if (recurring == null) return exact;
    final occurrenceAt = _latestRecurringOccurrenceAt(
      _scheduleInTimezone(
        recurring.reminder.schedule,
        _lastTimezone ??
            recurring.device.scheduledTimezone ??
            recurring.reminder.schedule.timezone,
      ),
      _clock().toUtc(),
    );
    if (occurrenceAt == null) return exact ?? recurring;
    return DuePrayerOccurrence(
      reminder: recurring.reminder,
      device: recurring.device,
      prayerTitle: recurring.prayerTitle,
      prayerBody: recurring.prayerBody,
      prayerRevisionId: recurring.prayerRevisionId,
      occurrenceAt: occurrenceAt,
    );
  }

  DateTime? _latestRecurringOccurrenceAt(
    PrayerReminderSchedule schedule,
    DateTime nowUtc,
  ) {
    var candidate = _calculator.next(
      schedule,
      afterUtc: nowUtc.subtract(const Duration(days: 8)),
    );
    DateTime? latest;
    while (candidate != null && !candidate.isAfter(nowUtc)) {
      latest = candidate;
      candidate = _calculator.next(schedule, afterUtc: candidate);
    }
    return latest;
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
    await _ensureNativeNotifications(
      occurrence,
      timezoneName,
      rearm: true,
      includeSnooze: false,
    );
  }

  // Separate negative slots cannot replace another reminder family's alarms.
  static int _slotId(int base, int slot) =>
      -(0x38000000 | (((base * 31) + slot) & 0x07ffffff));

  static Iterable<int> platformNotificationIds(int base) sync* {
    yield base;
    for (var slot = 0; slot <= 7; slot++) {
      yield _slotId(base, slot);
    }
  }

  Future<void> _cancelPlatformNotifications(int base) async {
    for (final id in platformNotificationIds(base)) {
      await _scheduler.cancel(id);
    }
  }

  Future<void> _ensureNativeNotifications(
    DuePrayerOccurrence occurrence,
    String timezoneName, {
    bool rearm = false,
    bool includeSnooze = true,
  }) async {
    if (!_scheduler.supportsSystemNotifications ||
        await _scheduler.permissionStatus() !=
            NotificationPermissionStatus.granted) {
      return;
    }
    final schedule = _scheduleInTimezone(
      occurrence.reminder.schedule,
      timezoneName,
    );
    final now = _clock().toUtc();
    final snooze = includeSnooze ? occurrence.device.snoozedUntil : null;
    final activeSnooze = snooze != null && snooze.isAfter(now) ? snooze : null;
    final signature =
        '${schedule.type.name}:${schedule.localTime.wireValue}:'
        '$timezoneName:${schedule.weekdaysMask}:${schedule.onceAt}:$activeSnooze';
    final reminderId = occurrence.reminder.id;
    if (!rearm && _nativeSchedules[reminderId]?.signature == signature) return;
    final base = occurrence.device.platformNotificationId;
    await _cancelPlatformNotifications(base);
    _nativeSchedules.remove(reminderId);
    final notifications = <PrayerScheduledNotification>[];
    void add(int id, DateTime at, ReminderNotificationRecurrence recurrence) {
      notifications.add(
        PrayerScheduledNotification(
          platformNotificationId: id,
          reminderId: reminderId,
          occurrenceKey: '$reminderId@${at.toUtc().toIso8601String()}',
          scheduledAtUtc: at.toUtc(),
          timeZoneName: timezoneName,
          recurrence: recurrence,
        ),
      );
    }

    if (schedule.type == PrayerScheduleType.weekdays) {
      for (var weekday = 1; weekday <= 7; weekday++) {
        if (schedule.weekdaysMask! & (1 << (weekday - 1)) == 0) continue;
        final day = PrayerReminderSchedule.weekdays(
          localTime: schedule.localTime,
          timezone: timezoneName,
          weekdaysMask: 1 << (weekday - 1),
        );
        final next = _calculator.next(day, afterUtc: now);
        if (next != null) {
          add(
            _slotId(base, weekday),
            next,
            ReminderNotificationRecurrence.weekly,
          );
        }
      }
    } else {
      final next = _calculator.next(schedule, afterUtc: now);
      if (next != null) {
        add(
          base,
          next,
          schedule.type == PrayerScheduleType.daily
              ? ReminderNotificationRecurrence.daily
              : ReminderNotificationRecurrence.once,
        );
      }
    }
    if (activeSnooze != null) {
      add(_slotId(base, 0), activeSnooze, ReminderNotificationRecurrence.once);
    }
    for (final notification in notifications) {
      await _scheduler.schedule(notification);
    }
    _nativeSchedules[reminderId] = (base: base, signature: signature);
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
        snoozedUntil: null,
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
    await _cancelPlatformNotifications(
      occurrence.device.platformNotificationId,
    );
    _nativeSchedules.remove(occurrence.reminder.id);
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
