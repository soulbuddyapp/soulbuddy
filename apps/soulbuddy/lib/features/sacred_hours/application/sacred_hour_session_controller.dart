import 'package:flutter/foundation.dart';

enum SacredHourSessionPhase { prayer, work, dismissed }

class SacredHourSessionState {
  const SacredHourSessionState({
    required this.phase,
    required this.prayerRecorded,
    this.prayerStartedAt,
  });

  final SacredHourSessionPhase phase;
  final bool prayerRecorded;
  final DateTime? prayerStartedAt;

  SacredHourSessionState copyWith({
    SacredHourSessionPhase? phase,
    bool? prayerRecorded,
    DateTime? prayerStartedAt,
  }) => SacredHourSessionState(
    phase: phase ?? this.phase,
    prayerRecorded: prayerRecorded ?? this.prayerRecorded,
    prayerStartedAt: prayerStartedAt ?? this.prayerStartedAt,
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
    final remaining =
        Duration(minutes: prayerMinutes) - _clock().difference(started);
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
      _state = _state.copyWith(prayerRecorded: true);
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

  void markDismissed() {
    _state = _state.copyWith(phase: SacredHourSessionPhase.dismissed);
    notifyListeners();
  }
}
