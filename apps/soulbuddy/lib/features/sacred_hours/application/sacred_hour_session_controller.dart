import 'package:flutter/foundation.dart';

enum SacredHourSessionPhase { prayer, work, dismissed }

class SacredHourSessionState {
  const SacredHourSessionState({
    required this.phase,
    required this.prayerRecorded,
    this.prayerStartedAt,
    this.pausedAt,
    this.pausedDuration = Duration.zero,
  });

  final SacredHourSessionPhase phase;
  final bool prayerRecorded;
  final DateTime? prayerStartedAt;
  final DateTime? pausedAt;
  final Duration pausedDuration;

  bool get isPaused => pausedAt != null;

  SacredHourSessionState copyWith({
    SacredHourSessionPhase? phase,
    bool? prayerRecorded,
    DateTime? prayerStartedAt,
    DateTime? pausedAt,
    Duration? pausedDuration,
  }) => SacredHourSessionState(
    phase: phase ?? this.phase,
    prayerRecorded: prayerRecorded ?? this.prayerRecorded,
    prayerStartedAt: prayerStartedAt ?? this.prayerStartedAt,
    pausedAt: pausedAt ?? this.pausedAt,
    pausedDuration: pausedDuration ?? this.pausedDuration,
  );
}

class SacredHourSessionController extends ChangeNotifier {
  SacredHourSessionController({
    required this.prayerMinutes,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _state = const SacredHourSessionState(
         phase: SacredHourSessionPhase.prayer,
         prayerRecorded: false,
       );

  final int prayerMinutes;
  final DateTime Function() _clock;
  SacredHourSessionState _state;
  bool _recording = false;

  SacredHourSessionState get state => _state;

  Duration get remaining {
    final started = _state.prayerStartedAt;
    if (started == null) return Duration(minutes: prayerMinutes);
    final endingAt = _state.pausedAt ?? _clock();
    final elapsed = endingAt.difference(started) - _state.pausedDuration;
    final remaining = Duration(minutes: prayerMinutes) - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void beginPrayer() {
    if (_state.prayerStartedAt != null) return;
    _state = _state.copyWith(prayerStartedAt: _clock());
    notifyListeners();
  }

  Future<void> recordPrayer(Future<void> Function() record) async {
    if (_state.prayerRecorded || _recording) return;
    _recording = true;
    try {
      await record();
      _state = _state.copyWith(
        prayerRecorded: true,
        phase: SacredHourSessionPhase.work,
      );
      notifyListeners();
    } finally {
      _recording = false;
    }
  }

  void continueToWork() {
    if (_state.phase == SacredHourSessionPhase.work) return;
    _state = _state.copyWith(phase: SacredHourSessionPhase.work);
    notifyListeners();
  }

  void pause() {
    if (_state.prayerStartedAt == null || _state.isPaused) return;
    _state = _state.copyWith(pausedAt: _clock());
    notifyListeners();
  }

  void resume() {
    final pausedAt = _state.pausedAt;
    if (pausedAt == null) return;
    _state = SacredHourSessionState(
      phase: _state.phase,
      prayerRecorded: _state.prayerRecorded,
      prayerStartedAt: _state.prayerStartedAt,
      pausedDuration: _state.pausedDuration + _clock().difference(pausedAt),
    );
    notifyListeners();
  }

  void markDismissed() {
    _state = _state.copyWith(phase: SacredHourSessionPhase.dismissed);
    notifyListeners();
  }
}
