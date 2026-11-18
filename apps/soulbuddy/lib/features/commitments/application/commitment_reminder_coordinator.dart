import 'dart:async';

import '../../prayers/application/prayer_reminder_scheduler.dart';
import '../data/commitment_reminder_device_repository.dart';
import '../data/commitment_repository.dart';
import '../domain/commitment.dart';
import 'commitment_occurrence_calculator.dart';

class CommitmentReminderOpened {
  const CommitmentReminderOpened(this.commitmentId);
  final String commitmentId;
}

class CommitmentReminderCoordinator {
  CommitmentReminderCoordinator({
    required CommitmentRepository repository,
    required CommitmentReminderDeviceRepository devices,
    required PrayerReminderScheduler scheduler,
    required this.ownerId,
    required this.deviceId,
    DateTime Function()? clock,
    Future<String> Function()? timezoneName,
  }) : _repository = repository,
       _devices = devices,
       _scheduler = scheduler,
       _clock = clock ?? DateTime.now,
       _timezoneName = timezoneName;

  final CommitmentRepository _repository;
  final CommitmentReminderDeviceRepository _devices;
  final PrayerReminderScheduler _scheduler;
  final String ownerId, deviceId;
  final DateTime Function() _clock;
  final Future<String> Function()? _timezoneName;
  final _calculator = CommitmentOccurrenceCalculator();
  late final _events = StreamController<CommitmentReminderOpened>.broadcast(
    onListen: _flushOpen,
  );
  CommitmentReminderOpened? _pendingOpen;
  StreamSubscription<PrayerReminderResponse>? _responses;
  StreamSubscription<Commitment?>? _primary;
  StreamSubscription<CommitmentDetails?>? _details;
  Future<void> _serial = Future.value();
  String? _commitmentId;
  bool _started = false, _disposed = false;
  String? lastIssue;

  Stream<CommitmentReminderOpened> get events => _events.stream;

  /// Negative IDs in a separate namespace from prayers, Sacred Hours and Goals.
  static int notificationId(String ownerId, String commitmentId, int weekday) {
    var hash = 2166136261;
    for (final unit in '$ownerId/$commitmentId'.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0xffffffff;
    }
    return -(0x30000000 | ((hash & 0x00ffffff) << 3) | weekday);
  }

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    _responses = _scheduler
        .responsesFor(ReminderNotificationKind.commitment)
        .where((e) => e.kind == ReminderNotificationKind.commitment)
        .listen(
          (event) {
            unawaited(_enqueue(() => _handleResponse(event)));
          },
          onError: (_) {
            lastIssue = 'reminder_unavailable';
          },
        );
    await _scheduler.initialize();
    await refresh();
    _primary = _repository.watchPrimary().listen(
      (primary) {
        if (primary?.id != _commitmentId) unawaited(refresh());
      },
      onError: (_) {
        lastIssue = 'reminder_unavailable';
      },
    );
  }

  Future<void> refresh() => _enqueue(_refresh);

  Future<void> _refresh() async {
    final primary = await _repository.watchPrimary().first;
    final id = primary?.ownerId == ownerId ? primary?.id : null;
    if (_commitmentId != id) {
      await _details?.cancel();
      final previous = _commitmentId;
      if (previous != null) await _cancel(previous);
      _commitmentId = id;
      if (id != null) {
        _details = _repository
            .watchDetails(id)
            .listen(
              (_) {
                unawaited(_enqueue(() => _reconcile(id)));
              },
              onError: (_) {
                lastIssue = 'reminder_unavailable';
              },
            );
      }
    }
    if (id != null) await _reconcile(id);
  }

  Future<bool> enableOnThisDevice(
    String commitmentId,
    CommitmentReminderMode mode,
  ) async {
    final details = await _repository.watchDetails(commitmentId).first;
    if (details?.commitment.ownerId != ownerId) return false;
    final existing = await _devices.load(commitmentId, deviceId);
    await _devices.save(
      CommitmentReminderDeviceState(
        commitmentId: commitmentId,
        deviceId: deviceId,
        mode: mode,
        notificationIds: existing?.notificationIds ?? [],
        updatedAt: _clock().toUtc(),
      ),
    );
    final allowed =
        mode == CommitmentReminderMode.off ||
        (_scheduler.supportsSystemNotifications &&
            await _scheduler.requestPermission());
    await _enqueue(() => _reconcile(commitmentId));
    return allowed;
  }

  Future<void> _reconcile(String id) async {
    if (_disposed) return;
    final details = await _repository.watchDetails(id).first;
    final state = await _devices.load(id, deviceId);
    if (details?.commitment.ownerId != ownerId || state == null) return;
    final plan = details!.plan;
    await _cancel(id);
    final canSchedule =
        _scheduler.supportsSystemNotifications &&
        plan != null &&
        plan.enabled &&
        state.mode != CommitmentReminderMode.off &&
        await _scheduler.permissionStatus() ==
            NotificationPermissionStatus.granted;
    if (!canSchedule) {
      await _devices.save(
        CommitmentReminderDeviceState(
          commitmentId: id,
          deviceId: deviceId,
          mode: state.mode,
          updatedAt: _clock().toUtc(),
        ),
      );
      return;
    }
    String zone = plan.timezone;
    try {
      zone = await _timezoneName?.call() ?? zone;
      commitmentTimezone(zone);
    } catch (_) {
      zone = plan.timezone;
    }
    final weekdays = plan.frequency == CommitmentMeditationFrequency.daily
        ? [0]
        : [
            for (var day = 1; day <= 7; day++)
              if ((plan.weekdaysMask! & (1 << (day - 1))) != 0) day,
          ];
    final notifications = <PrayerScheduledNotification>[];
    for (final weekday in weekdays) {
      final next = _calculator.next(
        plan,
        after: _clock().toUtc(),
        timezoneName: zone,
        weekday: weekday == 0 ? null : weekday,
      );
      if (next == null) continue;
      notifications.add(
        PrayerScheduledNotification(
          platformNotificationId: notificationId(ownerId, id, weekday),
          reminderId: id,
          occurrenceKey: '$id@${next.toIso8601String()}',
          scheduledAtUtc: next,
          kind: ReminderNotificationKind.commitment,
          recurrence: weekday == 0
              ? ReminderNotificationRecurrence.daily
              : ReminderNotificationRecurrence.weekly,
          timeZoneName: zone,
          title: 'Time with God',
          body: 'A quiet invitation to prayer.',
          soundKey: state.mode == CommitmentReminderMode.voice
              ? 'commitment_invitation_v1'
              : 'silent',
        ),
      );
    }
    notifications.sort((a, b) => a.scheduledAtUtc.compareTo(b.scheduledAtUtc));
    // Persist IDs before OS writes so an interrupted replacement is recoverable.
    await _devices.save(
      CommitmentReminderDeviceState(
        commitmentId: id,
        deviceId: deviceId,
        mode: state.mode,
        nextOccurrence: notifications.firstOrNull?.scheduledAtUtc,
        scheduledTimezone: zone,
        notificationIds: notifications
            .map((n) => n.platformNotificationId)
            .toList(),
        updatedAt: _clock().toUtc(),
      ),
    );
    for (final notification in notifications) {
      try {
        await _scheduler.schedule(notification);
      } catch (_) {
        if (notification.soundKey == 'silent') rethrow;
        await _scheduler.schedule(
          PrayerScheduledNotification(
            platformNotificationId: notification.platformNotificationId,
            reminderId: id,
            occurrenceKey: notification.occurrenceKey,
            scheduledAtUtc: notification.scheduledAtUtc,
            kind: ReminderNotificationKind.commitment,
            recurrence: notification.recurrence,
            timeZoneName: zone,
            title: notification.title,
            body: notification.body,
            soundKey: 'silent',
          ),
        );
      }
    }
    lastIssue = null;
  }

  Future<void> _cancel(String id) async {
    if (!_scheduler.supportsSystemNotifications) return;
    for (var day = 0; day <= 7; day++) {
      await _scheduler.cancel(notificationId(ownerId, id, day));
    }
  }

  Future<void> _handleResponse(PrayerReminderResponse response) async {
    if (_disposed ||
        (response.action != PrayerReminderAction.open &&
            response.action != PrayerReminderAction.begin)) {
      return;
    }
    final details = await _repository.watchDetails(response.reminderId).first;
    if (details?.commitment.ownerId != ownerId) return;
    final event = CommitmentReminderOpened(response.reminderId);
    if (_events.hasListener) {
      _events.add(event);
    } else {
      _pendingOpen = event;
    }
  }

  void _flushOpen() {
    final pending = _pendingOpen;
    _pendingOpen = null;
    if (pending != null) {
      scheduleMicrotask(() {
        if (!_events.isClosed) _events.add(pending);
      });
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    _serial = _serial
        .then((_) async {
          if (!_disposed) await action();
        })
        .catchError((_) {
          lastIssue = 'reminder_unavailable';
        });
    return _serial;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _responses?.cancel();
    await _primary?.cancel();
    await _details?.cancel();
    await _serial;
    final id = _commitmentId;
    if (id != null) await _cancel(id);
    await _events.close();
  }
}
