import 'dart:async';

import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../../prayers/application/prayer_reminder_scheduler.dart';
import '../data/sacred_hour_repository.dart';
import '../domain/sacred_hour.dart';
import 'sacred_hour_alarm_permission.dart';

class SacredHourOpened {
  const SacredHourOpened({required this.hourId, required this.occurrenceKey});

  final String hourId;
  final String occurrenceKey;
}

class SacredHourReminderCoordinator {
  SacredHourReminderCoordinator({
    required SacredHourRepository repository,
    required PrayerReminderScheduler scheduler,
    required SacredHourAlarmPermission exactAlarmPermission,
    DateTime Function()? clock,
  }) : _repository = repository,
       _scheduler = scheduler,
       _exactAlarmPermission = exactAlarmPermission,
       _clock = clock ?? DateTime.now {
    timezone_data.initializeTimeZones();
  }

  final SacredHourRepository _repository;
  final PrayerReminderScheduler _scheduler;
  bool _initialized = false;
  final SacredHourAlarmPermission _exactAlarmPermission;
  final DateTime Function() _clock;
  late final StreamController<SacredHourOpened> _events =
      StreamController<SacredHourOpened>.broadcast(onListen: _flushEvents);
  final _eventBacklog = <SacredHourOpened>[];
  final _scheduled = <String, Map<int, String>>{};
  final _processedActions = <String>{};
  StreamSubscription<List<SacredHourDelivery>>? _deliveriesSubscription;
  StreamSubscription<PrayerReminderResponse>? _responsesSubscription;
  Timer? _startupRefreshTimer;
  List<SacredHourDelivery> _deliveries = const [];
  Future<void> _serial = Future.value();
  var _notificationsAllowed = false;
  var _started = false;

  Stream<SacredHourOpened> get events => _events.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _responsesSubscription = _scheduler
        .responsesFor(ReminderNotificationKind.sacredHour)
        .where(
          (response) => response.kind == ReminderNotificationKind.sacredHour,
        )
        .listen((response) => _enqueue(() => _handleResponse(response)));
    await _scheduler.initialize();
    _initialized = true;
    _notificationsAllowed =
        !_scheduler.supportsSystemNotifications ||
        await _scheduler.permissionStatus() ==
            NotificationPermissionStatus.granted;
    _deliveries = await _repository.watchDeliveries().first;
    await _enqueue(_reconcile);
    _deliveriesSubscription = _repository.watchDeliveries().listen((
      deliveries,
    ) {
      _deliveries = deliveries;
      _enqueue(_reconcile);
    }, onError: (_) {});
    // Package replacement and database startup can briefly race on Android.
    // Re-read the authoritative delivery rows once startup has settled so an
    // alarm cannot remain absent after an app update.
    _startupRefreshTimer = Timer(const Duration(seconds: 2), () {
      unawaited(
        _enqueue(() async {
          _deliveries = await _repository.watchDeliveries().first;
          await _reconcile();
        }).catchError((_) {}),
      );
    });
  }

  Future<bool> enableOnThisDevice() async {
    if (!_scheduler.supportsSystemNotifications) return true;
    _notificationsAllowed = await _scheduler.requestPermission();
    if (_notificationsAllowed) await _enqueue(_reconcile);
    return _notificationsAllowed;
  }

  Future<bool> requestPreciseReminders() async {
    final allowed = await _exactAlarmPermission.request();
    if (allowed) await _enqueue(_reconcile);
    return allowed;
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
    final hoursById = {
      for (final hour in await _repository.watchActive().first) hour.id: hour,
    };
    final observed = <String>{};
    for (final delivery in _deliveries) {
      observed.add(delivery.sacredHourId);
      final previous = _scheduled[delivery.sacredHourId];
      final hour = hoursById[delivery.sacredHourId];
      final desired = hour == null
          ? const <PrayerScheduledNotification>[]
          : await _desiredNotifications(hour, delivery);
      final desiredById = {
        for (final notification in desired)
          notification.platformNotificationId: _scheduleSignature(notification),
      };

      if (previous == null) {
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

      final scheduledNow = <int, String>{};
      for (final notification in desired) {
        final wantedSignature =
            desiredById[notification.platformNotificationId]!;
        if (!rearm &&
            previous?[notification.platformNotificationId] == wantedSignature) {
          scheduledNow[notification.platformNotificationId] = wantedSignature;
          continue;
        }
        final actual = await _scheduleWithFallback(notification);
        scheduledNow[actual.platformNotificationId] = _scheduleSignature(
          actual,
        );
      }
      _scheduled[delivery.sacredHourId] = scheduledNow;
    }

    for (final hourId in _scheduled.keys.toList(growable: false)) {
      if (observed.contains(hourId)) continue;
      for (final id in _scheduled[hourId]!.keys) {
        await _scheduler.cancel(id);
      }
      _scheduled.remove(hourId);
    }
  }

  Future<List<PrayerScheduledNotification>> _desiredNotifications(
    SacredHour hour,
    SacredHourDelivery delivery,
  ) async {
    final next = delivery.nextOccurrenceAt?.toUtc();
    if (!hour.enabled ||
        hour.archivedAt != null ||
        !delivery.enabledOnDevice ||
        next == null) {
      return const [];
    }
    final precision = await _precisionFor(delivery.reminderMode);
    final occurrenceKey = '${hour.id}@${next.toIso8601String()}';
    final notifications = <PrayerScheduledNotification>[
      _notification(
        hour,
        delivery,
        id: _alarmId(delivery.platformNotificationId),
        atUtc: next,
        occurrenceKey: occurrenceKey,
        recurrence: ReminderNotificationRecurrence.daily,
        precision: precision,
      ),
    ];
    final snoozedUntil = delivery.snoozedUntil?.toUtc();
    if (snoozedUntil != null && snoozedUntil.isAfter(_clock().toUtc())) {
      final snoozedOccurrenceAt = _mostRecentOccurrence(hour, snoozedUntil);
      notifications.add(
        _notification(
          hour,
          delivery,
          id: _snoozeId(delivery.platformNotificationId),
          atUtc: snoozedUntil,
          occurrenceKey: '${hour.id}@${snoozedOccurrenceAt.toIso8601String()}',
          recurrence: ReminderNotificationRecurrence.once,
          precision: precision,
        ),
      );
    }
    return notifications;
  }

  Future<ReminderSchedulePrecision> _precisionFor(
    SacredHourReminderMode mode,
  ) async {
    if (mode != SacredHourReminderMode.precise) {
      return ReminderSchedulePrecision.ordinary;
    }
    return await _exactAlarmPermission.status() ==
            ExactAlarmPermissionStatus.granted
        ? ReminderSchedulePrecision.exact
        : ReminderSchedulePrecision.ordinary;
  }

  PrayerScheduledNotification _notification(
    SacredHour hour,
    SacredHourDelivery delivery, {
    required int id,
    required DateTime atUtc,
    required String occurrenceKey,
    required ReminderNotificationRecurrence recurrence,
    required ReminderSchedulePrecision precision,
  }) => PrayerScheduledNotification(
    platformNotificationId: id,
    reminderId: hour.id,
    occurrenceKey: occurrenceKey,
    scheduledAtUtc: atUtc,
    kind: ReminderNotificationKind.sacredHour,
    recurrence: recurrence,
    timeZoneName: delivery.scheduledTimezone,
    soundKey: _soundKey(hour.sound),
    precision: precision,
  );

  Future<PrayerScheduledNotification> _scheduleWithFallback(
    PrayerScheduledNotification notification,
  ) async {
    try {
      await _scheduler.schedule(notification);
      return notification;
    } catch (_) {
      if (notification.precision != ReminderSchedulePrecision.exact) rethrow;
      final ordinary = _withPrecision(
        notification,
        ReminderSchedulePrecision.ordinary,
      );
      await _scheduler.schedule(ordinary);
      return ordinary;
    }
  }

  Future<void> _handleResponse(PrayerReminderResponse response) async {
    final delivery = _deliveryFor(response.reminderId);
    final hour = await _hourFor(response.reminderId);
    final embeddedDueAt = _dueAt(response.reminderId, response.occurrenceKey);
    if (delivery == null || hour == null || embeddedDueAt == null) return;
    final dueAt = _effectiveDueAt(hour, embeddedDueAt);
    final occurrenceKey = '${response.reminderId}@${dueAt.toIso8601String()}';
    final actionKey =
        '${response.reminderId}:$occurrenceKey:'
        '${response.action.name}';
    if (!_processedActions.add(actionKey)) return;
    final alarmId = _alarmId(delivery.platformNotificationId);
    await _scheduler.cancel(alarmId);
    _scheduled[response.reminderId]?.remove(alarmId);

    switch (response.action) {
      case PrayerReminderAction.open:
      case PrayerReminderAction.begin:
        await _repository.markOccurrence(
          response.reminderId,
          dueAt,
          SacredHourOccurrenceStatus.begun,
        );
        await _updateDelivery(delivery, hour: hour, snoozedUntil: null);
        _emitEvent(
          SacredHourOpened(
            hourId: response.reminderId,
            occurrenceKey: occurrenceKey,
          ),
        );
      case PrayerReminderAction.snoozeTenMinutes:
        await _updateDelivery(
          delivery,
          hour: hour,
          snoozedUntil: _clock().toUtc().add(const Duration(minutes: 10)),
        );
      case PrayerReminderAction.dismiss:
        await _repository.markOccurrence(
          response.reminderId,
          dueAt,
          SacredHourOccurrenceStatus.dismissed,
        );
        await _updateDelivery(
          delivery,
          hour: hour,
          snoozedUntil: null,
          dismissedOccurrenceKey: occurrenceKey,
        );
      case PrayerReminderAction.prayed:
        return;
    }
  }

  Future<void> _updateDelivery(
    SacredHourDelivery delivery, {
    required SacredHour hour,
    required DateTime? snoozedUntil,
    String? dismissedOccurrenceKey,
  }) => _repository.updateDeviceDelivery(
    delivery.sacredHourId,
    SacredHourDeviceDraft(
      enabledOnDevice: delivery.enabledOnDevice,
      reminderMode: delivery.reminderMode,
      nextOccurrenceAt: _nextOccurrence(hour, _clock().toUtc()),
      platformNotificationId: delivery.platformNotificationId,
      scheduledTimezone: delivery.scheduledTimezone,
      snoozedUntil: snoozedUntil,
      dismissedOccurrenceKey: dismissedOccurrenceKey,
    ),
  );

  SacredHourDelivery? _deliveryFor(String hourId) {
    for (final delivery in _deliveries) {
      if (delivery.sacredHourId == hourId) return delivery;
    }
    return null;
  }

  Future<SacredHour?> _hourFor(String hourId) =>
      _repository.watch(hourId).first;

  DateTime _effectiveDueAt(SacredHour hour, DateTime embeddedDueAt) {
    final location = timezone.getLocation(hour.timezone);
    final embeddedLocal = timezone.TZDateTime.from(embeddedDueAt, location);
    final candidate = _mostRecentOccurrence(hour, _clock().toUtc());
    final candidateLocal = timezone.TZDateTime.from(candidate, location);
    if (embeddedLocal.year == candidateLocal.year &&
        embeddedLocal.month == candidateLocal.month &&
        embeddedLocal.day == candidateLocal.day) {
      return embeddedDueAt;
    }
    return candidate;
  }

  DateTime _mostRecentOccurrence(SacredHour hour, DateTime atUtc) {
    final location = timezone.getLocation(hour.timezone);
    final localNow = timezone.TZDateTime.from(atUtc, location);
    var candidate = timezone.TZDateTime(
      location,
      localNow.year,
      localNow.month,
      localNow.day,
      hour.localTime.hour,
      hour.localTime.minute,
    );
    if (candidate.isAfter(localNow)) {
      candidate = timezone.TZDateTime(
        location,
        localNow.year,
        localNow.month,
        localNow.day - 1,
        hour.localTime.hour,
        hour.localTime.minute,
      );
    }
    return candidate.toUtc();
  }

  DateTime _nextOccurrence(SacredHour hour, DateTime afterUtc) {
    final location = timezone.getLocation(hour.timezone);
    final local = timezone.TZDateTime.from(afterUtc, location);
    var candidate = timezone.TZDateTime(
      location,
      local.year,
      local.month,
      local.day,
      hour.localTime.hour,
      hour.localTime.minute,
    );
    if (!candidate.isAfter(local)) {
      candidate = timezone.TZDateTime(
        location,
        local.year,
        local.month,
        local.day + 1,
        hour.localTime.hour,
        hour.localTime.minute,
      );
    }
    return candidate.toUtc();
  }

  DateTime? _dueAt(String hourId, String occurrenceKey) {
    final prefix = '$hourId@';
    if (!occurrenceKey.startsWith(prefix)) return null;
    return DateTime.tryParse(occurrenceKey.substring(prefix.length))?.toUtc();
  }

  Set<int> _allPlatformIds(SacredHourDelivery delivery) => {
    _alarmId(delivery.platformNotificationId),
    _snoozeId(delivery.platformNotificationId),
    // Remove schedules created before reminder IDs were namespaced.
    delivery.platformNotificationId,
    _legacySnoozeId(delivery.platformNotificationId),
  };

  // Sacred Hours have their own negative ranges. Other reminder types use
  // positive IDs or different negative prefixes.
  int _alarmId(int base) => -(0x20000000 | (base & 0x07ffffff));

  int _snoozeId(int base) => -(0x28000000 | (base & 0x07ffffff));

  int _legacySnoozeId(int base) => ((base * 31) + 10) & 0x7fffffff;

  String _scheduleSignature(PrayerScheduledNotification notification) {
    final recurrence = notification.recurrence;
    final when = recurrence == ReminderNotificationRecurrence.once
        ? notification.scheduledAtUtc.toIso8601String()
        : () {
            final local = timezone.TZDateTime.from(
              notification.scheduledAtUtc,
              timezone.getLocation(notification.timeZoneName!),
            );
            return '${local.hour}:${local.minute}';
          }();
    return '${recurrence.name}:${notification.timeZoneName}:$when:'
        '${notification.soundKey}:${notification.precision.name}:'
        '${notification.occurrenceKey}';
  }

  String _soundKey(SacredHourSound sound) => switch (sound) {
    SacredHourSound.gentleChime => 'sacred_gentle_chime',
    SacredHourSound.dawnChime => 'sacred_dawn_chime',
    SacredHourSound.stillBell => 'sacred_still_bell',
    SacredHourSound.eveningChime => 'sacred_evening_chime',
    SacredHourSound.device => 'device',
    SacredHourSound.silent => 'silent',
  };

  PrayerScheduledNotification _withPrecision(
    PrayerScheduledNotification source,
    ReminderSchedulePrecision precision,
  ) => PrayerScheduledNotification(
    platformNotificationId: source.platformNotificationId,
    reminderId: source.reminderId,
    occurrenceKey: source.occurrenceKey,
    scheduledAtUtc: source.scheduledAtUtc,
    kind: source.kind,
    recurrence: source.recurrence,
    timeZoneName: source.timeZoneName,
    title: source.title,
    body: source.body,
    soundKey: source.soundKey,
    precision: precision,
  );

  void _emitEvent(SacredHourOpened event) {
    if (_events.isClosed) return;
    if (_events.hasListener) {
      _events.add(event);
    } else {
      if (_eventBacklog.length == 8) _eventBacklog.removeAt(0);
      _eventBacklog.add(event);
    }
  }

  void _flushEvents() {
    if (_eventBacklog.isEmpty) return;
    final pending = List<SacredHourOpened>.of(_eventBacklog);
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
    _startupRefreshTimer?.cancel();
    await _deliveriesSubscription?.cancel();
    await _responsesSubscription?.cancel();
    await _serial;
    await _events.close();
  }
}
