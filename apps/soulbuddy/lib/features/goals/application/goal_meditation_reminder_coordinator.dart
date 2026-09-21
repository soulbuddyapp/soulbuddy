import 'dart:async';

import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../../prayers/application/prayer_reminder_scheduler.dart';
import '../data/goal_meditation_repository.dart';
import '../domain/goal_meditation_plan.dart';

class GoalMeditationOpened {
  const GoalMeditationOpened(this.goalId);
  final String goalId;
}

class GoalMeditationReminderCoordinator {
  GoalMeditationReminderCoordinator({
    required GoalMeditationRepository repository,
    required PrayerReminderScheduler scheduler,
    DateTime Function()? clock,
  }) : _repository = repository,
       _scheduler = scheduler,
       _clock = clock ?? DateTime.now {
    timezone_data.initializeTimeZones();
  }

  final GoalMeditationRepository _repository;
  final PrayerReminderScheduler _scheduler;
  final DateTime Function() _clock;
  // Keep a cold-start open until the app subscribes, while allowing disposal
  // when no screen has listened to the stream yet.
  late final _events = StreamController<GoalMeditationOpened>.broadcast(
    onListen: _flushPendingOpen,
  );
  GoalMeditationOpened? _pendingOpen;
  StreamSubscription<PrayerReminderResponse>? _responses;
  bool _started = false;

  Stream<GoalMeditationOpened> get events => _events.stream;

  void _flushPendingOpen() {
    final pending = _pendingOpen;
    _pendingOpen = null;
    if (pending != null) {
      scheduleMicrotask(() {
        if (!_events.isClosed) _events.add(pending);
      });
    }
  }

  static int notificationId(String goalId) {
    var hash = 2166136261;
    for (final unit in goalId.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0xffffffff;
    }
    return 0x3b000000 | (hash & 0x00ffffff);
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _responses = _scheduler.responses
        .where((event) => event.kind == ReminderNotificationKind.goalMeditation)
        .listen((event) {
          if (event.action == PrayerReminderAction.open ||
              event.action == PrayerReminderAction.begin) {
            final opened = GoalMeditationOpened(event.reminderId);
            if (_events.hasListener) {
              _events.add(opened);
            } else {
              _pendingOpen = opened;
            }
          }
        });
    await _scheduler.initialize();
    await reconcile();
  }

  Future<bool> enableOnThisDevice() async {
    final allowed =
        !_scheduler.supportsSystemNotifications ||
        await _scheduler.requestPermission();
    if (allowed) await reconcile();
    return allowed;
  }

  Future<void> reconcile() async {
    if (_scheduler.supportsSystemNotifications &&
        await _scheduler.permissionStatus() !=
            NotificationPermissionStatus.granted) {
      return;
    }
    for (final plan in await _repository.loadPlans()) {
      await schedule(plan);
    }
  }

  Future<void> schedule(GoalMeditationPlan plan) async {
    if (!_scheduler.supportsSystemNotifications) return;
    if (await _scheduler.permissionStatus() !=
        NotificationPermissionStatus.granted) {
      return;
    }
    final now = timezone.TZDateTime.from(_clock(), timezone.local);
    var next = timezone.TZDateTime(
      timezone.local,
      now.year,
      now.month,
      now.day,
      plan.hour,
      plan.minute,
    );
    if (plan.frequency == GoalMeditationFrequency.weekly) {
      next = timezone.TZDateTime(
        timezone.local,
        now.year,
        now.month,
        now.day + (plan.weekday - now.weekday + 7) % 7,
        plan.hour,
        plan.minute,
      );
    }
    if (!next.isAfter(now)) {
      next = timezone.TZDateTime(
        timezone.local,
        next.year,
        next.month,
        next.day + (plan.frequency == GoalMeditationFrequency.daily ? 1 : 7),
        plan.hour,
        plan.minute,
      );
    }
    await _scheduler.schedule(
      PrayerScheduledNotification(
        platformNotificationId: notificationId(plan.goalId),
        reminderId: plan.goalId,
        occurrenceKey: 'goal-meditation:${plan.goalId}',
        scheduledAtUtc: next.toUtc(),
        kind: ReminderNotificationKind.goalMeditation,
        recurrence: plan.frequency == GoalMeditationFrequency.daily
            ? ReminderNotificationRecurrence.daily
            : ReminderNotificationRecurrence.weekly,
        timeZoneName: timezone.local.name,
        title: 'Goal meditation',
        body: 'Commit this time to God. Listen and write.',
      ),
    );
  }

  Future<void> cancel(String goalId) =>
      _scheduler.cancel(notificationId(goalId));

  Future<void> dispose() async {
    await _responses?.cancel();
    await _events.close();
  }
}
