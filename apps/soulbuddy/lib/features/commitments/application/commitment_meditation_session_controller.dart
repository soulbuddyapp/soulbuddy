import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/commitment.dart';
import 'commitment_audio.dart';
import 'commitment_session_clock.dart';

enum CommitmentSessionPhase {
  preparation,
  guiding,
  bell,
  silence,
  timing,
  paused,
  completed,
  endedEarly,
}

abstract interface class CommitmentSessionAudio implements Listenable {
  bool get complete;
  bool get unavailable;
  Duration get position;
  CommitmentAudioAsset? get asset;
  Future<void> playGuide(String id);
  Future<void> playPath(String path, {double volume = 1, bool loop = false});
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> setSpeed(double speed);
  void dispose();
}

/// All session transitions are foreground-only. A terminal draft is immutable,
/// and its stable ID is retained across retries after an uncertain local write.
class CommitmentMeditationSessionController extends ChangeNotifier {
  CommitmentMeditationSessionController({
    required this.commitmentId,
    required this.sessionId,
    required this.deviceId,
    required this.kind,
    required this.guideId,
    required Duration plannedDuration,
    required this.guide,
    required this.bell,
    required this.bed,
    required this.saveSession,
    Duration Function()? elapsed,
    DateTime Function()? now,
    this.autoTick = true,
  }) : _elapsed = elapsed ?? (Stopwatch()..start()).readElapsed,
       _now = now ?? DateTime.now {
    _clock = CommitmentSessionClock(
      planned: plannedDuration,
      elapsed: _elapsed,
    );
    _silence = CommitmentSessionClock(
      planned: const Duration(seconds: 2),
      elapsed: _elapsed,
    );
    guide.addListener(_guideChanged);
    bell.addListener(_bellChanged);
  }

  static const stillBell = 'assets/audio/sacred_hours/sacred_still_bell.wav';
  final String commitmentId, sessionId, deviceId, guideId;
  final CommitmentSessionKind kind;
  final CommitmentSessionAudio guide, bell, bed;
  final Future<void> Function(CommitmentMeditationSessionDraft) saveSession;
  final Duration Function() _elapsed;
  final DateTime Function() _now;
  final bool autoTick;
  late CommitmentSessionClock _clock;
  late final CommitmentSessionClock _silence;
  Timer? _ticker;
  bool _disposed = false;
  bool _visible = true;
  int _epoch = 0;
  DateTime? _startedAt;
  CommitmentMeditationSessionDraft? _terminalDraft;
  CommitmentSessionPhase phase = CommitmentSessionPhase.preparation;
  CommitmentSessionPhase? _resumePhase;
  bool guideUnavailable = false;
  bool includePersonalPrayer = false;
  Future<void> Function()? playPersonalPrayer;
  bool personalPrayerPlaying = false;
  bool _startingGuide = false;
  bool _genericPending = false;
  bool _guideRequested = false;
  bool _bellRequested = false;
  bool saving = false;
  bool saved = false;
  bool saveFailed = false;
  double speed = .85;
  String? soundPath;
  double soundVolume = .15;

  bool get terminal =>
      phase == CommitmentSessionPhase.completed ||
      phase == CommitmentSessionPhase.endedEarly;
  bool get started => _startedAt != null;
  Duration get remaining => _clock.remaining;
  Duration get plannedDuration => _clock.planned;
  Duration get actual => _clock.actual;
  CommitmentMeditationSessionDraft? get terminalDraft => _terminalDraft;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setDuration(Duration value) {
    if (phase != CommitmentSessionPhase.preparation) return;
    final allowed = kind == CommitmentSessionKind.listening
        ? {5, 10, 15}
        : {5, 10, 15, 20, 30};
    if (!allowed.contains(value.inMinutes) ||
        value.inSeconds != value.inMinutes * 60) {
      return;
    }
    _clock = CommitmentSessionClock(planned: value, elapsed: _elapsed);
    _notify();
  }

  Future<void> setSpeed(double value) async {
    if (![.7, .85, 1.0, 1.15].contains(value)) return;
    speed = value;
    _notify();
    await guide.setSpeed(value);
  }

  Future<void> begin() async {
    if (_disposed || phase != CommitmentSessionPhase.preparation || !_visible) {
      return;
    }
    final epoch = ++_epoch;
    _startedAt = _now();
    phase = CommitmentSessionPhase.guiding;
    _notify();
    if (autoTick) {
      _ticker = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) => tick(),
      );
    }
    await guide.setSpeed(speed);
    if (_disposed ||
        epoch != _epoch ||
        phase != CommitmentSessionPhase.guiding) {
      return;
    }
    await _beginNarration();
  }

  Future<void> _beginNarration() async {
    _guideRequested = true;
    if (includePersonalPrayer && playPersonalPrayer != null) {
      _startingGuide = true;
      personalPrayerPlaying = true;
      try {
        await playPersonalPrayer!();
      } catch (_) {
        _genericPending = true;
      } finally {
        _startingGuide = false;
      }
      if (_genericPending) {
        await _playGenericGuide();
      } else {
        _guideChanged();
      }
    } else {
      await _playGenericGuide();
    }
  }

  Future<void> _playGenericGuide() async {
    if (_disposed) return;
    if (phase != CommitmentSessionPhase.guiding || !_visible) {
      _genericPending = true;
      return;
    }
    _genericPending = false;
    personalPrayerPlaying = false;
    _startingGuide = true;
    guideUnavailable = false;
    try {
      await guide.playGuide(guideId);
    } catch (_) {
      guideUnavailable = true;
    } finally {
      _startingGuide = false;
    }
    _guideChanged();
  }

  void _guideChanged() {
    if (_disposed) return;
    if (phase == CommitmentSessionPhase.guiding && !_startingGuide) {
      if (personalPrayerPlaying && (guide.complete || guide.unavailable)) {
        unawaited(_playGenericGuide());
        return;
      }
      if (guide.unavailable) guideUnavailable = true;
      if (guide.complete) unawaited(continueAfterGuide());
    }
    _notify();
  }

  Future<void> continueAfterGuide() async {
    if (_disposed || phase != CommitmentSessionPhase.guiding || !_visible) {
      return;
    }
    final epoch = ++_epoch;
    phase = CommitmentSessionPhase.bell;
    _notify();
    await guide.stop();
    if (_disposed || epoch != _epoch || phase != CommitmentSessionPhase.bell) {
      return;
    }
    await _playOpeningBell();
  }

  Future<void> _playOpeningBell() async {
    final epoch = _epoch;
    await bell.setSpeed(1);
    if (_disposed || epoch != _epoch || phase != CommitmentSessionPhase.bell) {
      return;
    }
    try {
      _bellRequested = true;
      await bell.playPath(stillBell, volume: .65);
    } catch (_) {
      _beginSilence();
    }
    if (bell.unavailable) _beginSilence();
  }

  void _bellChanged() {
    if (!_disposed &&
        phase == CommitmentSessionPhase.bell &&
        (bell.complete || bell.unavailable)) {
      _beginSilence();
    }
  }

  void _beginSilence() {
    if (_disposed || phase != CommitmentSessionPhase.bell || !_visible) return;
    phase = CommitmentSessionPhase.silence;
    _silence.start();
    _notify();
  }

  void tick() {
    if (_disposed || !_visible) return;
    if (phase == CommitmentSessionPhase.silence && _silence.completed) {
      _silence.pause();
      phase = CommitmentSessionPhase.timing;
      _clock.start();
      unawaited(_startBed());
      _notify();
    } else if (phase == CommitmentSessionPhase.timing) {
      if (_clock.completed) {
        unawaited(_finish(CommitmentMeditationSessionOutcome.completed));
      } else {
        _notify();
      }
    }
  }

  Future<void> _startBed() async {
    final path = soundPath;
    if (path == null ||
        _disposed ||
        !_visible ||
        phase != CommitmentSessionPhase.timing) {
      return;
    }
    final epoch = _epoch;
    try {
      await bed.setSpeed(1);
      if (_disposed ||
          epoch != _epoch ||
          phase != CommitmentSessionPhase.timing) {
        return;
      }
      await bed.playPath(path, volume: soundVolume, loop: true);
    } catch (_) {
      /* Optional sound failure leaves quiet timing intact. */
    }
  }

  Future<void> pause() async {
    if (_disposed ||
        terminal ||
        phase == CommitmentSessionPhase.preparation ||
        phase == CommitmentSessionPhase.paused) {
      return;
    }
    ++_epoch;
    _resumePhase = phase;
    _clock.pause();
    _silence.pause();
    phase = CommitmentSessionPhase.paused;
    _notify();
    await Future.wait([guide.pause(), bell.pause(), bed.stop()]);
  }

  Future<void> pauseForInterruption() async {
    _visible = false;
    if (terminal) {
      ++_epoch;
      await _stopAudio();
      return;
    }
    await pause();
  }

  /// Visibility never resumes playback. Only an explicit Resume can do so.
  void becameVisible() {
    _visible = true;
  }

  Future<void> resume() async {
    if (_disposed || phase != CommitmentSessionPhase.paused) return;
    // Resume is a deliberate foreground user action, also useful to embedders.
    _visible = true;
    ++_epoch;
    phase = _resumePhase ?? CommitmentSessionPhase.guiding;
    _notify();
    switch (phase) {
      case CommitmentSessionPhase.guiding:
        if (!_guideRequested) {
          await _beginNarration();
        } else if (_genericPending ||
            (personalPrayerPlaying && (guide.complete || guide.unavailable))) {
          await _playGenericGuide();
        } else if (guide.complete) {
          await continueAfterGuide();
        } else if (!guideUnavailable) {
          await guide.resume();
        }
      case CommitmentSessionPhase.bell:
        if (!_bellRequested) {
          await _playOpeningBell();
        } else if (bell.complete || bell.unavailable) {
          _beginSilence();
        } else {
          await bell.resume();
        }
      case CommitmentSessionPhase.silence:
        _silence.start();
      case CommitmentSessionPhase.timing:
        _clock.start();
        await _startBed();
      default:
        break;
    }
  }

  Future<void> end() async {
    if (_disposed || !started || terminal) return;
    await _finish(
      _clock.completed
          ? CommitmentMeditationSessionOutcome.completed
          : CommitmentMeditationSessionOutcome.endedEarly,
    );
  }

  Future<void> _finish(CommitmentMeditationSessionOutcome outcome) async {
    if (_disposed || terminal || _terminalDraft != null) return;
    final epoch = ++_epoch;
    _clock.pause();
    _silence.pause();
    _ticker?.cancel();
    phase = outcome == CommitmentMeditationSessionOutcome.completed
        ? CommitmentSessionPhase.completed
        : CommitmentSessionPhase.endedEarly;
    final ended = _now();
    _terminalDraft = CommitmentMeditationSessionDraft(
      id: sessionId,
      commitmentId: commitmentId,
      sessionKind: kind,
      startedAt: _startedAt!,
      endedAt: ended.isBefore(_startedAt!) ? _startedAt! : ended,
      localDate: commitmentLocalDate(_startedAt!),
      plannedDurationSeconds: _clock.planned.inSeconds,
      actualDurationSeconds: _clock.actual.inSeconds,
      outcome: outcome,
      deviceId: deviceId,
    );
    _notify();
    // Begin the durable write even if navigation follows immediately afterward.
    final writing = retrySave();
    await _stopAudio();
    if (!_disposed &&
        _visible &&
        epoch == _epoch &&
        outcome == CommitmentMeditationSessionOutcome.completed) {
      try {
        await bell.setSpeed(1);
        if (!_disposed && _visible && epoch == _epoch) {
          await bell.playPath(stillBell, volume: .65);
        }
      } catch (_) {}
    }
    await writing;
  }

  Future<void> retrySave() async {
    final draft = _terminalDraft;
    if (draft == null || saving || saved) return;
    saving = true;
    saveFailed = false;
    _notify();
    try {
      await saveSession(draft);
      saved = true;
    } catch (_) {
      saveFailed = true;
    } finally {
      saving = false;
      _notify();
    }
  }

  Future<void> _stopAudio() =>
      Future.wait([guide.stop(), bell.stop(), bed.stop()]);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_epoch;
    _clock.pause();
    _silence.pause();
    _ticker?.cancel();
    guide.removeListener(_guideChanged);
    bell.removeListener(_bellChanged);
    guide.dispose();
    bell.dispose();
    bed.dispose();
    super.dispose();
  }
}

extension on Stopwatch {
  Duration readElapsed() => elapsed;
}
