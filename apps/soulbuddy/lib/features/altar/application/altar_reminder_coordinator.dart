import 'dart:async';

import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../../prayers/application/prayer_reminder_scheduler.dart';
import '../data/altar_ritual_repository.dart';
import '../domain/altar_ritual.dart';

class AltarReminderOpened {
  const AltarReminderOpened({
    required this.ritualId,
    required this.occurrenceKey,
  });

  final String ritualId;
  final String occurrenceKey;
}

class AltarReminderCoordinator {
  AltarReminderCoordinator({
    required AltarRitualRepository repository,
    required PrayerReminderScheduler scheduler,
    DateTime Function()? clock,
  }) : _repository = repository,
       _scheduler = scheduler,
       _clock = clock ?? DateTime.now {
    timezone_data.initializeTimeZones();
  }

  final AltarRitualRepository _repository;
  final PrayerReminderScheduler _scheduler;
  final DateTime Function() _clock;
  late final StreamController<AltarReminderOpened> _events =
      StreamController<AltarReminderOpened>.broadcast(onListen: _flushEvents);
  final _eventBacklog = <AltarReminderOpened>[];
  final _scheduled = <String, Map<int, String>>{};
  StreamSubscription<List<AltarReminderDelivery>>? _deliveriesSubscription;
  StreamSubscription<PrayerReminderResponse>? _responsesSubscription;
  List<AltarReminderDelivery> _deliveries = const [];
  Future<void> _serial = Future.value();
  var _notificationsAllowed = false;
  var _started = false;

  Stream<AltarReminderOpened> get events => _events.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _responsesSubscription = _scheduler.responses
        .where((response) => response.kind == ReminderNotificationKind.altar)
        .listen(_handleResponse);
    _deliveriesSubscription = _repository.watchReminderDeliveries().listen((
      deliveries,
    ) {
      _deliveries = deliveries;
      _enqueue(_reconcile);
    }, onError: (_) {});
    await _scheduler.initialize();
    _notificationsAllowed =
        !_scheduler.supportsSystemNotifications ||
        await _scheduler.permissionStatus() ==
            NotificationPermissionStatus.granted;
    await _enqueue(_reconcile);
  }

  Future<bool> enableOnThisDevice(String ritualId) async {
    if (!_scheduler.supportsSystemNotifications) return true;
    _notificationsAllowed = await _scheduler.requestPermission();
    if (_notificationsAllowed) await _enqueue(_reconcile);
    return _notificationsAllowed;
  }

  Future<void> _reconcile() async {
    if (!_notificationsAllowed || !_scheduler.supportsSystemNotifications) {
      return;
    }
    final now = _clock().toUtc();
    final observed = <String>{};
    for (final delivery in _deliveries) {
      observed.add(delivery.ritualId);
      final previous = _scheduled[delivery.ritualId];
      final desired = _desiredNotifications(delivery, now);
      final desiredById = {
        for (final notification in desired)
          notification.platformNotificationId: _scheduleSignature(notification),
      };

      if (previous == null) {
        // Reconcile every deterministic slot on first observation so disabled,
        // archived, or edited rituals cannot leave an old OS reminder behind.
        for (final id in _allPlatformIds(delivery)) {
          await _scheduler.cancel(id);
        }
      } else {
        for (final entry in previous.entries) {
          if (desiredById[entry.key] != entry.value) {
            await _scheduler.cancel(entry.key);
          }
        }
      }

      for (final notification in desired) {
        final signature = desiredById[notification.platformNotificationId]!;
        if (previous?[notification.platformNotificationId] == signature) {
          continue;
        }
        await _scheduler.schedule(notification);
      }
      _scheduled[delivery.ritualId] = desiredById;
    }
    for (final ritualId in _scheduled.keys.toList(growable: false)) {
      if (observed.contains(ritualId)) continue;
      for (final id in _scheduled[ritualId]!.keys) {
        await _scheduler.cancel(id);
      }
      _scheduled.remove(ritualId);
    }
  }

  List<PrayerScheduledNotification> _desiredNotifications(
    AltarReminderDelivery delivery,
    DateTime nowUtc,
  ) {
    if (!delivery.enabledOnDevice) return const [];
    final schedule = delivery.schedule;
    if (schedule.type == AltarScheduleType.daily) {
      final next = delivery.nextOccurrenceAt?.toUtc();
      if (next == null) return const [];
      return [
        _notification(
          delivery,
          id: delivery.platformNotificationId,
          atUtc: next,
          recurrence: ReminderNotificationRecurrence.daily,
        ),
      ];
    }

    return [
      for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
        if ((schedule.weekdaysMask! & (1 << (weekday - 1))) != 0)
          _notification(
            delivery,
            id: _weekdayNotificationId(
              delivery.platformNotificationId,
              weekday,
            ),
            atUtc: _nextWeekdayOccurrence(schedule, weekday, nowUtc),
            recurrence: ReminderNotificationRecurrence.weekly,
          ),
    ];
  }

  PrayerScheduledNotification _notification(
    AltarReminderDelivery delivery, {
    required int id,
    required DateTime atUtc,
    required ReminderNotificationRecurrence recurrence,
  }) => PrayerScheduledNotification(
    platformNotificationId: id,
    reminderId: delivery.ritualId,
    occurrenceKey: '${delivery.ritualId}@${atUtc.toIso8601String()}',
    scheduledAtUtc: atUtc,
    kind: ReminderNotificationKind.altar,
    recurrence: recurrence,
    timeZoneName: delivery.schedule.timezone,
  );

  DateTime _nextWeekdayOccurrence(
    AltarRitualSchedule schedule,
    int weekday,
    DateTime nowUtc,
  ) {
    timezone_data.initializeTimeZones();
    final location = timezone.getLocation(schedule.timezone);
    final localNow = timezone.TZDateTime.from(nowUtc, location);
    var candidate = timezone.TZDateTime(
      location,
      localNow.year,
      localNow.month,
      localNow.day,
      schedule.localTime.hour,
      schedule.localTime.minute,
    );
    candidate = candidate.add(
      Duration(days: (weekday - candidate.weekday + 7) % 7),
    );
    if (!candidate.isAfter(localNow)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate.toUtc();
  }

  Set<int> _allPlatformIds(AltarReminderDelivery delivery) => {
    delivery.platformNotificationId,
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
      _weekdayNotificationId(delivery.platformNotificationId, weekday),
  };

  int _weekdayNotificationId(int base, int weekday) =>
      ((base * 31) + weekday) & 0x7fffffff;

  String _scheduleSignature(PrayerScheduledNotification notification) {
    final local = timezone.TZDateTime.from(
      notification.scheduledAtUtc,
      timezone.getLocation(notification.timeZoneName!),
    );
    final weekday =
        notification.recurrence == ReminderNotificationRecurrence.weekly
        ? ':${local.weekday}'
        : '';
    return '${notification.recurrence.name}:${notification.timeZoneName}'
        '$weekday:${local.hour}:${local.minute}';
  }

  void _handleResponse(PrayerReminderResponse response) {
    if (response.action != PrayerReminderAction.open || _events.isClosed) {
      return;
    }
    final event = AltarReminderOpened(
      ritualId: response.reminderId,
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
    final events = List<AltarReminderOpened>.of(_eventBacklog);
    _eventBacklog.clear();
    scheduleMicrotask(() {
      if (_events.isClosed) return;
      for (final event in events) {
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
    await _deliveriesSubscription?.cancel();
    await _responsesSubscription?.cancel();
    await _serial;
    await _events.close();
  }
}
