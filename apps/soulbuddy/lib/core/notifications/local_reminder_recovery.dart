import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../features/prayers/application/prayer_reminder_scheduler.dart';

/// Repairs OS schedules after settings changes; native repeating alarms deliver
/// reminders while the app is closed. This timer runs only in the foreground.
class LocalReminderRecovery with WidgetsBindingObserver {
  LocalReminderRecovery({
    required Future<void> Function() initialize,
    required Future<NotificationPermissionStatus> Function() permissionStatus,
    required List<Future<void> Function()> recover,
    Duration interval = const Duration(seconds: 15),
  }) : _initialize = initialize,
       _permissionStatus = permissionStatus,
       _recover = recover,
       _interval = interval;

  final Future<void> Function() _initialize;
  final Future<NotificationPermissionStatus> Function() _permissionStatus;
  final List<Future<void> Function()> _recover;
  final Duration _interval;
  NotificationPermissionStatus? _permission;
  Timer? _timer;
  bool _started = false;
  bool _disposed = false;
  bool _foreground = false;
  bool _checking = false;
  bool _needsRecovery = true;
  bool _rearmRequested = false;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) _resume();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else {
      _foreground = false;
      _timer?.cancel();
      _timer = null;
    }
  }

  void _resume() {
    _foreground = true;
    _rearmRequested = true;
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => unawaited(_check()));
    unawaited(_check());
  }

  Future<void> _check() async {
    if (_disposed || !_foreground || _checking) return;
    _checking = true;
    final rearm = _rearmRequested;
    _rearmRequested = false;
    try {
      await _initialize();
      final permission = await _permissionStatus();
      if (_disposed || !_foreground) {
        _needsRecovery = true;
        return;
      }
      final changed = permission != _permission;
      _permission = permission;
      if (!rearm && !changed && !_needsRecovery) return;
      _needsRecovery = false;
      // A failure in one reminder family must not block the others.
      await Future.wait(
        _recover.map((recover) async {
          try {
            await recover();
          } catch (_) {
            _needsRecovery = true;
          }
        }),
      );
    } catch (_) {
      _needsRecovery = true;
    } finally {
      _checking = false;
      if (_rearmRequested && _foreground && !_disposed) unawaited(_check());
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
