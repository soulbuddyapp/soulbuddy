import 'dart:async';

import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../../prayers/application/prayer_reminder_scheduler.dart';
import '../data/daily_formation_repository.dart';

class DailyFormationReminderOpened {
  const DailyFormationReminderOpened();
}

class DailyFormationReminderCoordinator {
  DailyFormationReminderCoordinator({
    required DailyFormationRepository repository,
    required PrayerReminderScheduler scheduler,
    DateTime Function()? clock,
  }) : _repository = repository,
       _scheduler = scheduler,
       _clock = clock ?? DateTime.now {
    timezone_data.initializeTimeZones();
  }

  static const notificationId = 1460327;
  static const reminderId = 'daily-formation';

  final DailyFormationRepository _repository;
  final PrayerReminderScheduler _scheduler;
  bool _initialized = false;
  final DateTime Function() _clock;
  bool _pendingOpen = false;
  late final StreamController<DailyFormationReminderOpened> _events = StreamController<DailyFormationReminderOpened>.broadcast(
    onListen: () {
      if (_pendingOpen) {
        _pendingOpen = false;
        _events.add(const DailyFormationReminderOpened());
      }
    },
  );
  StreamSubscription<PrayerReminderResponse>? _responses;
  bool _started = false;
  bool _allowed = false;

  Stream<DailyFormationReminderOpened> get events => _events.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _responses = _scheduler
        .responsesFor(ReminderNotificationKind.dailyFormation)
        .where((event) => event.kind == ReminderNotificationKind.dailyFormation)
        .listen((event) {
          if (event.action == PrayerReminderAction.open ||
              event.action == PrayerReminderAction.begin) {
            if (_events.hasListener) {
              _events.add(const DailyFormationReminderOpened());
            } else {
              _pendingOpen = true;
            }
          }
        });
    await _scheduler.initialize();
    _initialized = true;
    _allowed =
        !_scheduler.supportsSystemNotifications ||
        await _scheduler.permissionStatus() ==
            NotificationPermissionStatus.granted;
    await reconcile();
  }

  Future<bool> enableOnThisDevice() async {
    _allowed =
        !_scheduler.supportsSystemNotifications ||
        await _scheduler.requestPermission();
    if (_allowed) await reconcile();
    return _allowed;
  }

  Future<void> reconcile() async {
    if (!_initialized) return;
    _allowed =
        !_scheduler.supportsSystemNotifications ||
        await _scheduler.permissionStatus() ==
            NotificationPermissionStatus.granted;
    if (!_allowed || !_scheduler.supportsSystemNotifications) return;
    final profile = await _repository.loadProfile();
    if (!profile.ready || !profile.hasReminder) {
      await _scheduler.cancel(notificationId);
      return;
    }
    final local = timezone.TZDateTime.from(_clock(), timezone.local);
    var next = timezone.TZDateTime(
      timezone.local,
      local.year,
      local.month,
      local.day,
      profile.reminderHour!,
      profile.reminderMinute!,
    );
    if (!next.isAfter(local)) {
      next = timezone.TZDateTime(
        timezone.local,
        local.year,
        local.month,
        local.day + 1,
        profile.reminderHour!,
        profile.reminderMinute!,
      );
    }
    await _scheduler.schedule(
      PrayerScheduledNotification(
        platformNotificationId: notificationId,
        reminderId: reminderId,
        occurrenceKey: 'daily-formation@${next.toUtc().toIso8601String()}',
        scheduledAtUtc: next.toUtc(),
        kind: ReminderNotificationKind.dailyFormation,
        recurrence: ReminderNotificationRecurrence.daily,
        timeZoneName: timezone.local.name,
        title: 'Daily formation',
        body: 'Today’s video is ready.',
      ),
    );
  }

  Future<void> dispose() async {
    await _responses?.cancel();
    await _events.close();
  }
}
