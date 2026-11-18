import 'dart:async';

import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../../prayers/application/prayer_reminder_scheduler.dart';
import '../data/circle_reminder_repository.dart';
import '../domain/circle_reminder.dart';

class CircleReminderOpened {
  const CircleReminderOpened({
    required this.circleId,
    required this.occurrenceKey,
  });

  final String circleId;
  final String occurrenceKey;
}

class CircleReminderCoordinator {
  CircleReminderCoordinator({
    required CircleReminderRepository repository,
    required PrayerReminderScheduler scheduler,
    DateTime Function()? clock,
  }) : _repository = repository,
       _scheduler = scheduler,
       _clock = clock ?? DateTime.now {
    timezone_data.initializeTimeZones();
  }

  final CircleReminderRepository _repository;
  final PrayerReminderScheduler _scheduler;
  bool _initialized = false;
  final DateTime Function() _clock;
  late final StreamController<CircleReminderOpened> _events =
      StreamController<CircleReminderOpened>.broadcast(onListen: _flushEvents);
  final _eventBacklog = <CircleReminderOpened>[];
  final _scheduled = <String, ({int id, String signature})>{};
  List<CircleReminder> _reminders = const [];
  StreamSubscription<List<CircleReminder>>? _remindersSubscription;
  StreamSubscription<PrayerReminderResponse>? _responsesSubscription;
  Future<void> _serial = Future.value();
  var _notificationsAllowed = false;
  var _started = false;

  Stream<CircleReminderOpened> get events => _events.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _responsesSubscription = _scheduler
        .responsesFor(ReminderNotificationKind.circle)
        .where((response) => response.kind == ReminderNotificationKind.circle)
        .listen(_handleResponse);
    await _scheduler.initialize();
    _initialized = true;
    _notificationsAllowed =
        !_scheduler.supportsSystemNotifications ||
        await _scheduler.permissionStatus() ==
            NotificationPermissionStatus.granted;
    _remindersSubscription = _repository.watch().listen((reminders) {
      _reminders = reminders;
      unawaited(_enqueue(_reconcile).catchError((_) {}));
    }, onError: (_) {});
  }

  Future<bool> enableOnThisDevice() async {
    if (!_scheduler.supportsSystemNotifications) return true;
    _notificationsAllowed = await _scheduler.requestPermission();
    if (_notificationsAllowed) await _enqueue(_reconcile);
    return _notificationsAllowed;
  }

  // Permission and platform alarms may change independently of saved rows.
  Future<void> refresh() => _enqueue(() => _reconcile(rearm: true));

  Future<void> _reconcile({bool rearm = false}) async {
    if (!_initialized) return;
    _notificationsAllowed =
        !_scheduler.supportsSystemNotifications ||
        await _scheduler.permissionStatus() ==
            NotificationPermissionStatus.granted;
    if (!_notificationsAllowed || !_scheduler.supportsSystemNotifications) {
      return;
    }
    final next = <String, PrayerScheduledNotification>{
      for (final reminder in _reminders)
        if (_notificationFor(reminder) case final notification?)
          reminder.circleId: notification,
    };
    for (final entry in _scheduled.entries.toList(growable: false)) {
      final desired = next[entry.key];
      if (desired == null || _signature(desired) != entry.value.signature) {
        await _scheduler.cancel(entry.value.id);
        _scheduled.remove(entry.key);
      }
    }
    for (final entry in next.entries) {
      final signature = _signature(entry.value);
      if (!rearm && _scheduled[entry.key]?.signature == signature) continue;
      await _scheduler.schedule(entry.value);
      _scheduled[entry.key] = (
        id: entry.value.platformNotificationId,
        signature: signature,
      );
    }
  }

  PrayerScheduledNotification? _notificationFor(CircleReminder reminder) {
    final next = _nextOccurrence(reminder);
    if (next == null) return null;
    return PrayerScheduledNotification(
      platformNotificationId: reminder.platformNotificationId,
      reminderId: reminder.circleId,
      occurrenceKey: '${reminder.circleId}@${next.toIso8601String()}',
      scheduledAtUtc: next,
      kind: ReminderNotificationKind.circle,
      recurrence: ReminderNotificationRecurrence.daily,
      timeZoneName: reminder.timezone,
      title: reminder.circleName,
      body: 'Circle invitation',
    );
  }

  DateTime? _nextOccurrence(CircleReminder reminder) {
    try {
      final location = timezone.getLocation(reminder.timezone);
      final localNow = timezone.TZDateTime.from(_clock().toUtc(), location);
      var candidate = timezone.TZDateTime(
        location,
        localNow.year,
        localNow.month,
        localNow.day,
        reminder.localTime.hour,
        reminder.localTime.minute,
      );
      if (!candidate.isAfter(localNow)) {
        candidate = timezone.TZDateTime(
          location,
          localNow.year,
          localNow.month,
          localNow.day + 1,
          reminder.localTime.hour,
          reminder.localTime.minute,
        );
      }
      return candidate.toUtc();
    } on ArgumentError {
      return null;
    }
  }

  String _signature(PrayerScheduledNotification notification) {
    final local = timezone.TZDateTime.from(
      notification.scheduledAtUtc,
      timezone.getLocation(notification.timeZoneName!),
    );
    return '${notification.recurrence.name}:${notification.timeZoneName}:'
        '${local.hour}:${local.minute}:${notification.title}';
  }

  void _handleResponse(PrayerReminderResponse response) {
    if (response.action != PrayerReminderAction.open || _events.isClosed) {
      return;
    }
    final event = CircleReminderOpened(
      circleId: response.reminderId,
      occurrenceKey: response.occurrenceKey,
    );
    if (_events.hasListener) {
      _events.add(event);
    } else {
      if (_eventBacklog.length == 8) _eventBacklog.removeAt(0);
      _eventBacklog.add(event);
    }
  }

  void _flushEvents() {
    if (_eventBacklog.isEmpty) return;
    final pending = List<CircleReminderOpened>.of(_eventBacklog);
    _eventBacklog.clear();
    scheduleMicrotask(() {
      if (_events.isClosed) return;
      for (final event in pending) {
        _events.add(event);
      }
    });
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _serial.then((_) => operation());
    _serial = next.then<void>((_) {}, onError: (_, _) {});
    return next;
  }

  Future<void> dispose() async {
    await _remindersSubscription?.cancel();
    await _responsesSubscription?.cancel();
    await _serial;
    await _events.close();
  }
}
