import 'dart:async';

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
       _clock = clock ?? DateTime.now;

  final AltarRitualRepository _repository;
  final PrayerReminderScheduler _scheduler;
  final DateTime Function() _clock;
  late final StreamController<AltarReminderOpened> _events =
      StreamController<AltarReminderOpened>.broadcast(onListen: _flushEvents);
  final _eventBacklog = <AltarReminderOpened>[];
  final _scheduled = <String, DateTime>{};
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
    final active = <String>{};
    for (final delivery in _deliveries) {
      final next = delivery.nextOccurrenceAt?.toUtc();
      if (!delivery.enabledOnDevice || next == null || !next.isAfter(now)) {
        continue;
      }
      active.add(delivery.ritualId);
      if (_scheduled[delivery.ritualId] == next) continue;
      await _scheduler.cancel(delivery.platformNotificationId);
      await _scheduler.schedule(
        PrayerScheduledNotification(
          platformNotificationId: delivery.platformNotificationId,
          reminderId: delivery.ritualId,
          occurrenceKey: '${delivery.ritualId}@${next.toIso8601String()}',
          scheduledAtUtc: next,
          kind: ReminderNotificationKind.altar,
        ),
      );
      _scheduled[delivery.ritualId] = next;
    }
    _scheduled.removeWhere((ritualId, _) => !active.contains(ritualId));
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
