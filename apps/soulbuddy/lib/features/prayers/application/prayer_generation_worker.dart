import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/prayer_generation_repository.dart';
import '../domain/prayer_generation_request.dart';
import 'prayer_generation_dispatcher.dart';

class PrayerGenerationWorker extends WidgetsBindingObserver {
  PrayerGenerationWorker({
    required this.repository,
    required this.dispatcher,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final PrayerGenerationRepository repository;
  final PrayerGenerationDispatcher dispatcher;
  final DateTime Function() _now;
  StreamSubscription<List<PrayerGenerationRequest>>? _subscription;
  Timer? _timer;
  bool _running = false;
  bool _disposed = false;

  void start() {
    if (_subscription != null) return;
    WidgetsBinding.instance.addObserver(this);
    _subscription = repository.watchPending().listen(_schedule);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(resample());
  }

  Future<void> resample() async {
    if (_disposed) return;
    _schedule(await repository.watchPending().first);
  }

  void _schedule(List<PrayerGenerationRequest> requests) {
    if (_disposed) return;
    _timer?.cancel();
    final now = _now().toUtc();
    DateTime? earliest;
    var hasDue = false;
    for (final request in requests) {
      final dueAt = switch (request.status) {
        PrayerGenerationStatus.queued => request.nextAttemptAt ?? now,
        PrayerGenerationStatus.generating =>
          request.attemptStartedAt?.add(const Duration(seconds: 20)) ?? now,
        _ => null,
      };
      if (dueAt == null) continue;
      if (!dueAt.isAfter(now)) {
        hasDue = true;
      } else if (earliest == null || dueAt.isBefore(earliest)) {
        earliest = dueAt;
      }
    }
    if (hasDue) {
      unawaited(_run());
      return;
    }
    if (earliest != null) {
      final untilDue = earliest.difference(now);
      final bounded = untilDue > const Duration(minutes: 10)
          ? const Duration(minutes: 10)
          : untilDue;
      _timer = Timer(bounded, () => unawaited(resample()));
    }
  }

  Future<void> _run() async {
    if (_running || _disposed) return;
    _running = true;
    try {
      await dispatcher.dispatchPending();
    } on Object {
      // Repository and API layers expose only content-free failures. A stale
      // claim is resampled below instead of surfacing an unhandled app error.
    } finally {
      _running = false;
      if (!_disposed) await resample();
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    await _subscription?.cancel();
  }
}
