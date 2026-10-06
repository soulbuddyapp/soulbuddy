import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/audio/narration_speed.dart';
import '../domain/affirmation_prayer.dart';

/// Spoken guidance for one phrase. Playback is never an implicit advance.
abstract interface class AffirmationPrayerNarrationPlayer {
  /// Reads the exact phrase once at [speed], then leaves a calm pause.
  Future<void> speak(String phrase, {required double speed});

  /// Repeats the current phrase. This must never advance a count.
  Future<void> repeat(String phrase, {required double speed});

  Future<void> stop();

  void dispose();
}

/// The selected background sound bed, kept low and ducked while the guide reads.
abstract interface class AffirmationPrayerSoundBed {
  Future<void> start({required String soundKey, required double volume});

  /// Lowers rather than silences a chosen bed, for a focused pause.
  Future<void> duck();

  /// Restores the chosen volume.
  Future<void> restore();

  Future<void> stop();

  void dispose();
}

/// The durable terminal record of one session.
abstract interface class AffirmationPrayerSessionRepository {
  Future<void> save(AffirmationPrayerSession session);
}

/// Keeps the device awake while a session is active.
abstract interface class AffirmationPrayerScreenAwake {
  Future<void> setEnabled(bool value);
}

/// The visible moments of a Prayer of attention.
enum AffirmationPrayerPhase {
  /// The skippable guided recollection, before prayer begins.
  recollection,

  /// Set up: sound, level, guide, pace.
  setup,

  /// A phrase is on screen and waiting to be deliberately confirmed.
  praying,

  /// An untimed focused pause between groups of ten.
  groupPause,

  /// Both phrases are complete.
  completed,
}

/// The Godward vocabulary of the practice. These strings are the experience.
abstract final class AffirmationPrayerWords {
  static const entry = 'Be still before God';
  static const setup = 'Speak these words with attention';
  static const beforeRepetition = 'Receive these words before God';
  static const groupPause = 'Gather your thoughts before God';
  /// The primary repetition action.
  static const advance = 'Continue';
  static const hearAgain = 'Hear again';
  static const pause = 'Pause';
  static const resume = 'Resume';
  static const end = 'End';
  static const completion = 'Carry this prayer into love';
  static const pray = 'Pray';
  static const reflect = 'Reflect';
  static const scripture = 'Scripture';
  static const chooseForToday = 'Choose for today';

  /// The guided recollection, in order. Each line fades in and out.
  static const recollectionLines = [
    'Let your body grow still',
    'Let the noise fade away',
    'Lift your heart to God',
    'Recognize God\'s presence and sovereignty',
    'Be still, and know that I am God',
  ];
}

/// The immutable visible state of the session.
@immutable
class AffirmationPrayerState {
  const AffirmationPrayerState({
    this.phase = AffirmationPrayerPhase.recollection,
    this.recollectionIndex = 0,
    this.stepIndex = 0,
    this.stepOneCount = 0,
    this.stepTwoCount = 0,
    this.count = 0,
    this.target = AffirmationPrayerSession.stepOneTarget,
    this.guideEnabled = true,
    this.speed = defaultNarrationSpeed,
    this.soundKey,
    this.soundVolume = .15,
    this.started = false,
    this.groupPauseRequired = false,
    this.saving = false,
    this.saved = false,
    this.saveFailed = false,
    this.session,
  });

  final AffirmationPrayerPhase phase;
  final int recollectionIndex;
  final int stepIndex;
  final int stepOneCount;
  final int stepTwoCount;

  /// The count below the phrase, for example `12 of 50`.
  final int count;
  final int target;
  final bool guideEnabled;
  final double speed;
  final String? soundKey;
  final double soundVolume;
  final bool started;

  /// True when the next group of ten is due.
  final bool groupPauseRequired;
  final bool saving;
  final bool saved;
  final bool saveFailed;
  final AffirmationPrayerSession? session;

  bool get finished =>
      phase == AffirmationPrayerPhase.completed || session != null;

  bool get atStepTwo => stepIndex == 1;

  /// The exact phrase on screen, or an empty string before prayer begins.
  String phraseFor(AffirmationPrayerProfile profile) => switch (stepIndex) {
    0 => profile.stepOnePhrase,
    _ => profile.stepTwoPhrase,
  };

  AffirmationPrayerState copyWith({
    AffirmationPrayerPhase? phase,
    int? recollectionIndex,
    int? stepIndex,
    int? stepOneCount,
    int? stepTwoCount,
    int? count,
    int? target,
    bool? guideEnabled,
    double? speed,
    String? soundKey,
    bool clearSoundKey = false,
    double? soundVolume,
    bool? started,
    bool? groupPauseRequired,
    bool? saving,
    bool? saved,
    bool? saveFailed,
    AffirmationPrayerSession? session,
  }) {
    return AffirmationPrayerState(
      phase: phase ?? this.phase,
      recollectionIndex: recollectionIndex ?? this.recollectionIndex,
      stepIndex: stepIndex ?? this.stepIndex,
      stepOneCount: stepOneCount ?? this.stepOneCount,
      stepTwoCount: stepTwoCount ?? this.stepTwoCount,
      count: count ?? this.count,
      target: target ?? this.target,
      guideEnabled: guideEnabled ?? this.guideEnabled,
      speed: speed ?? this.speed,
      soundKey: clearSoundKey ? null : (soundKey ?? this.soundKey),
      soundVolume: soundVolume ?? this.soundVolume,
      started: started ?? this.started,
      groupPauseRequired: groupPauseRequired ?? this.groupPauseRequired,
      saving: saving ?? this.saving,
      saved: saved ?? this.saved,
      saveFailed: saveFailed ?? this.saveFailed,
      session: session ?? this.session,
    );
  }
}

/// A counted Prayer of attention.
///
/// The count only supports faithful repetition: it advances by exactly one
/// deliberate confirmation, never because audio finished playing.
class AffirmationPrayerSessionController extends ChangeNotifier {
  AffirmationPrayerSessionController({
    required this.profile,
    required this.releaseItemId,
    required this.sessionId,
    required this.narration,
    required this.soundBed,
    required this.awake,
    required this.saveSession,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       assert(profile.stepOneTarget == AffirmationPrayerSession.stepOneTarget),
       assert(profile.stepTwoTarget == AffirmationPrayerSession.stepTwoTarget);

  final AffirmationPrayerProfile profile;
  final String releaseItemId;
  final String sessionId;
  final AffirmationPrayerNarrationPlayer narration;
  final AffirmationPrayerSoundBed soundBed;
  final AffirmationPrayerScreenAwake awake;
  final AffirmationPrayerSessionRepository Function() saveSession;
  final DateTime Function() _now;

  /// The only paces a person may choose.
  static const availableSpeeds = [.70, .85, 1.0, 1.15];

  AffirmationPrayerState _state = const AffirmationPrayerState();
  DateTime? _startedAt;
  var _epoch = 0;
  var _disposed = false;

  /// Whether this route is currently on screen and in the foreground.
  bool get visible => _visible;
  var _visible = true;

  AffirmationPrayerState get state => _state;

  String get currentPhrase => _state.phraseFor(profile);

  /// The count support below the phrase.
  String get countLabel => '${_state.count} of ${_state.target}';

  /// `Continue` advances exactly one repetition.
  Future<void> confirmSpoken() async {
    if (_state.phase != AffirmationPrayerPhase.praying) return;

    final next = _state.count + 1;
    if (next > _state.target) return;

    if (_state.stepIndex == 0) {
      final stepOneCount = next;
      // Every tenth repetition, including the fiftieth, is a group boundary.
      final isGroupBoundary = stepOneCount % 10 == 0;

      _state = _state.copyWith(
        stepOneCount: stepOneCount,
        count: stepOneCount,
        groupPauseRequired: isGroupBoundary,
        phase: isGroupBoundary
            ? AffirmationPrayerPhase.groupPause
            : AffirmationPrayerPhase.praying,
      );
      notifyListeners();

      if (isGroupBoundary) {
        // The guide stops, and the chosen bed is lowered rather than cut.
        await _stopNarration();
        await soundBed.duck();
      }

      return;
    }

    final stepTwoCount = next;
    _state = _state.copyWith(
      stepTwoCount: stepTwoCount,
      count: stepTwoCount,
    );
    notifyListeners();

    if (stepTwoCount >= profile.stepTwoTarget) {
      await _finish(AffirmationPrayerOutcome.completed);
    }
  }

  /// Repeating the phrase must never advance the count.
  Future<void> hearAgain() async {
    if (_state.phase != AffirmationPrayerPhase.praying) return;

    await narration.repeat(currentPhrase, speed: _state.speed);
  }

  /// Moves the recollection on. No sound starts here.
  void advanceRecollection() {
    if (_state.phase != AffirmationPrayerPhase.recollection) return;

    final next = _state.recollectionIndex + 1;
    if (next < AffirmationPrayerWords.recollectionLines.length) {
      _state = _state.copyWith(recollectionIndex: next);
      notifyListeners();

      return;
    }

    _state = _state.copyWith(
      phase: AffirmationPrayerPhase.setup,
      recollectionIndex: AffirmationPrayerWords.recollectionLines.length - 1,
    );
    notifyListeners();
  }

  /// Skips the recollection immediately.
  void skipRecollection() {
    if (_state.phase != AffirmationPrayerPhase.recollection) return;

    _state = _state.copyWith(
      phase: AffirmationPrayerPhase.setup,
      recollectionIndex: AffirmationPrayerWords.recollectionLines.length - 1,
    );
    notifyListeners();
  }

  Future<void> setSound({String? soundKey, required double volume}) async {
    _state = _state.copyWith(
      soundKey: soundKey,
      clearSoundKey: soundKey == null,
      soundVolume: volume,
    );
    notifyListeners();

    if (_state.started && soundKey != null) {
      await soundBed.start(soundKey: soundKey, volume: volume);
    }
  }

  Future<void> setSpeed(double value) async {
    if (!availableSpeeds.any((speed) => (speed - value).abs() < 0.001)) return;

    _state = _state.copyWith(speed: value);
    notifyListeners();
  }

  Future<void> setGuideEnabled(bool value) async {
    _state = _state.copyWith(guideEnabled: value);
    notifyListeners();
    if (!value) await narration.stop();
  }

  /// Begins prayer deliberately. Nothing sounds before this.
  Future<void> begin() async {
    if (_state.started) return;

    final epoch = ++_epoch;
    _startedAt = _now();
    _state = _state.copyWith(
      phase: AffirmationPrayerPhase.praying,
      started: true,
      groupPauseRequired: false,
    );
    notifyListeners();

    await awake.setEnabled(true);

    if (_state.soundKey != null) {
      await soundBed.start(
        soundKey: _state.soundKey!,
        volume: _state.soundVolume,
      );
      if (!_isCurrent(epoch)) return;
    }

    if (_state.guideEnabled) {
      await narration.speak(currentPhrase, speed: _state.speed);
    }
  }

  /// Leaves a focused pause. It is untimed.
  ///
  /// After the fiftieth repetition the second exact phrase begins at zero, with
  /// no completion animation.
  Future<void> leaveGroupPause() async {
    if (_state.phase != AffirmationPrayerPhase.groupPause) return;

    final firstStepComplete = _state.stepOneCount >= profile.stepOneTarget;

    _state = _state.copyWith(
      phase: AffirmationPrayerPhase.praying,
      groupPauseRequired: false,
      stepIndex: firstStepComplete ? 1 : _state.stepIndex,
      count: firstStepComplete ? 0 : _state.count,
      target: firstStepComplete ? profile.stepTwoTarget : _state.target,
    );
    notifyListeners();

    await soundBed.restore();
    if (!_state.guideEnabled) return;
    await narration.speak(currentPhrase, speed: _state.speed);
  }

  /// Pauses deliberately. Sound stops at once.
  Future<void> pause() async {
    await _stopAudio();
    _state = _state.copyWith(phase: AffirmationPrayerPhase.setup);
    notifyListeners();
  }

  /// Resumes after a pause, an interruption, or a return from the background.
  ///
  /// Sound never resumes on its own; this must be called by a deliberate tap.
  Future<void> resume() async {
    if (_state.phase != AffirmationPrayerPhase.setup) return;
    if (!_state.started) {
      await begin();

      return;
    }

    final epoch = ++_epoch;
    _state = _state.copyWith(phase: AffirmationPrayerPhase.praying);
    notifyListeners();

    await awake.setEnabled(true);
    if (_state.soundKey != null) {
      await soundBed.start(
        soundKey: _state.soundKey!,
        volume: _state.soundVolume,
      );
      if (!_isCurrent(epoch)) return;
    }
    if (_state.guideEnabled) {
      await narration.speak(currentPhrase, speed: _state.speed);
    }
  }

  /// Stops sound for an interruption, navigation away, or backgrounding.
  ///
  /// Playback is never resumed automatically afterwards; only an explicit
  /// `resume()` brings it back.
  Future<void> pauseForInterruption() async {
    _visible = false;
    final wasTerminal = _state.session != null;
    if (!wasTerminal) {
      _state = _state.copyWith(phase: AffirmationPrayerPhase.setup);
      notifyListeners();
    }
    await _stopAudio();
  }

  void becameVisible() {
    _visible = true;
  }

  /// Ends the session early, recording the counts actually reached.
  Future<void> end() async {
    await _finish(AffirmationPrayerOutcome.endedEarly);
  }

  Future<void> _finish(AffirmationPrayerOutcome outcome) async {
    if (_state.session != null) return;

    final epoch = ++_epoch;
    final startedAt = _startedAt ?? _now();
    final terminal = AffirmationPrayerSession(
      id: sessionId,
      releaseItemId: releaseItemId,
      localDate: _dateKey(startedAt),
      startedAt: startedAt,
      endedAt: _now(),
      outcome: outcome,
      stepOneCount: _state.stepOneCount,
      stepTwoCount: _state.stepTwoCount,
      soundKey: _state.soundKey,
      narrationSpeed: _state.speed,
    );

    _state = _state.copyWith(
      phase: AffirmationPrayerPhase.completed,
      session: terminal,
    );
    notifyListeners();
    await _stopAudio();
    if (epoch != _epoch) return;

    await _save(terminal);
  }

  Future<void> _save(AffirmationPrayerSession session) async {
    _state = _state.copyWith(saving: true, saveFailed: false, saved: false);
    notifyListeners();
    try {
      await saveSession().save(session);
      if (_disposed) return;
      _state = _state.copyWith(saving: false, saved: true);
    } catch (_) {
      if (_disposed) return;
      _state = _state.copyWith(saving: false, saveFailed: true);
    }
    notifyListeners();
  }

  /// Retries the same terminal record, and only when a save has not landed.
  Future<void> retrySave() async {
    final session = _state.session;
    if (session == null || _state.saved) return;

    await _save(session);
  }

  Future<void> _stopNarration() async {
    await narration.stop();
  }

  Future<void> _stopAudio() async {
    await narration.stop();
    await soundBed.stop();
    await awake.setEnabled(false);
  }

  bool _isCurrent(int epoch) => !_disposed && epoch == _epoch;

  String _dateKey(DateTime moment) {
    final month = moment.month.toString().padLeft(2, '0');
    final day = moment.day.toString().padLeft(2, '0');

    return '${moment.year}-$month-$day';
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    narration.dispose();
    soundBed.dispose();
    unawaited(awake.setEnabled(false));
    super.dispose();
  }
}
