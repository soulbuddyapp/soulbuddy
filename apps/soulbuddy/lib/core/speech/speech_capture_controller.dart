import 'dart:async';

import 'package:flutter/foundation.dart';

import 'plugin_speech_recognizer.dart';
import 'speech_recognizer.dart';

/// Shown when speech cannot run on this device.
///
/// The seam passes availability up as a bare signal, so dictation copy lives
/// here rather than below it. [SpeechCaptureController] is the only consumer,
/// and every screen reads this rather than repeating the words.
const String speechUnavailableNotice = 'Dictation unavailable. Write instead.';

/// Shown when an attempt to speak did not take.
///
/// Not a claim about this device, and deliberately unlike
/// [speechUnavailableNotice]: that one is said where the microphone is gone,
/// and this is said where the microphone is still there. It reports what
/// happened rather than what is possible — nothing came through — and it does
/// not promise that a second attempt will do better, because nothing here
/// knows that. The second sentence is the established one rather than a new
/// promise, because writing is available either way.
const String speechDidNotStartNotice =
    'No speech detected. Try again or write.';

/// Availability and listening state for dictation.
///
/// Availability is resolved once: repeated taps on an unavailable field must
/// not re-prompt or re-notice. Listening state is owned here rather than read
/// back from the recogniser, because the platform reports it late, or not at
/// all after a stop.
///
/// This is also where a session boundary is policed. A stopped session can
/// deliver its final result after its replacement has started, stamped with the
/// replacement's session, so the token in [listen] has already let it through
/// and no consumer downstream can tell it from the new session speaking. The
/// first callback of a session that follows a stop is therefore dropped when it
/// carries the stopped session's words forward, because those words are already
/// in the field. Consumers see this as one callback that never arrives.
///
/// Only [stop] arms that check. A session the platform ends on its own — a
/// pause, a recognition error — is not armed, because nothing asked for it to
/// be and there is no evidence of what it was about to say. A final result
/// arriving after one of those is the case this does not cover.
///
/// That has a cost, and it is a real one: a session whose opening words extend
/// the previous session's last words loses that first callback too, and if
/// nothing follows it the words are gone with no signal to anyone. This is
/// chosen over the alternative — applying the result and saying the sentence
/// twice into a field the person has since typed into — because a duplicate
/// corrupts what gets saved, while a lost opening word is at most a first word,
/// and only in the case where the recogniser reports once and then stops. The
/// dropped callback is bounded to the first one: recognised words grow, so any
/// second callback carries everything the first held.
///
/// This also separates two things one value used to conflate. Speech being
/// unavailable and a session failing to start are different answers, and only
/// the first is permanent: a missing offline language pack leaves a device that
/// reports a recognition service and then cannot use it, which is a failed
/// start rather than an absent capability, and the microphone stays because a
/// retry is not known to be hopeless. So [notice] answers only the permanent
/// question, and a start that did not take is reported to the field that asked
/// for it — one field, one microphone, and only that field's attempt failed.
class SpeechCaptureController extends ChangeNotifier {
  SpeechCaptureController({
    SpeechRecognizer? recognizer,
    this.beforeListen,
    this.afterListen,
  }) : _recognizer = recognizer ?? PluginSpeechRecognizer();

  final SpeechRecognizer _recognizer;
  final Future<void> Function()? beforeListen;
  final VoidCallback? afterListen;
  bool _starting = false;
  Completer<void>? _startDone;
  bool _captureHeld = false;
  Future<void>? _closingCapture;
  Object? _owner;

  bool? _available;
  Future<bool>? _resolving;
  bool _listening = false;
  bool _disposed = false;
  String? _notice;
  int _session = 0;

  /// The words the running session has most recently reported, so a stop can
  /// record what the session ended on.
  String? _sessionWords;

  /// The words the last stopped session most recently reported. A stopped
  /// session can deliver a final result after its replacement has started, so
  /// the next session has to recognise that leftover.
  String? _stoppedWords;

  /// Whether the running session's first callback is still to arrive.
  bool _awaitingFirstWords = false;

  /// Whether the running session has heard anything at all.
  ///
  /// The only evidence here of whether a session ever began. The platform
  /// announces a session as listening before it knows the recogniser accepted
  /// it, so `isListening` cannot answer that, and on a locale with no offline
  /// pack the session is announced, accepted, and then failed before a single
  /// sound. Recorded whatever else happens to the words, because the question
  /// is whether the platform said anything and not whether it was passed on.
  bool _heardAnything = false;

  /// The caller waiting to hear that its attempt did not take.
  ///
  /// Only ever set while a session this class opened is still open: every path
  /// out of a session clears it, so a failure arriving after the microphone is
  /// closed belongs to nobody and is answered with silence rather than blamed
  /// on whoever holds it now.
  VoidCallback? _pendingStart;

  /// Whether speech is available. False until [ensureAvailable] resolves.
  bool get isAvailable => _available ?? false;

  /// Whether a session is believed to be running.
  bool get isListening => _listening;
  bool get isStarting => _starting;

  /// The notice to show, or null when speech is available.
  String? get notice => _notice;

  /// Resolves availability once, however many callers ask at the same time.
  Future<bool> ensureAvailable() {
    final known = _available;
    if (known != null) return Future.value(known);
    return _resolving ??= _resolve();
  }

  Future<bool> _resolve() async {
    try {
      final available = await _recognizer.initialize(
        onListeningChanged: _setListening,
        onUnavailable: _showUnavailableNotice,
        onError: _sessionErrored,
      );
      _available = available;
      if (available) {
        // Only the answer changed here, which no setter reports.
        _notify();
      } else {
        _showUnavailableNotice();
      }
      return isAvailable;
    } finally {
      // Lets a throwing initialisation be retried. Defensive only: the seam
      // answers every failure with `false` rather than an exception.
      _resolving = null;
    }
  }

  /// Starts a session. Returns false when speech is unavailable, a session is
  /// already running, or the start failed, leaving the caller's field
  /// untouched and editable.
  ///
  /// [onDidNotStart] is called when this attempt produced nothing at all, so
  /// the caller can say so without the microphone being taken away. It is not
  /// called when a session was already running: nothing was attempted, so
  /// nothing failed, and a caller that treated that as a failure would report
  /// its own second tap as though the first had gone wrong.
  ///
  /// The first callback may be dropped when this session follows a stop; see
  /// the note on this class. A consumer that needs the opening words kept
  /// whatever it is told should not also be updating a field from them, which
  /// is the one shape that would notice.
  Future<bool> listen({
    required void Function(String words) onWords,
    VoidCallback? onDidNotStart,
    Object? owner,
  }) async {
    if (_disposed ||
        _listening ||
        _starting ||
        _captureHeld ||
        _closingCapture != null) {
      return false;
    }
    _starting = true;
    final startDone = Completer<void>();
    _startDone = startDone;
    final sessionOwner = owner ?? Object();
    var stopAfterStartFailure = false;
    _owner = sessionOwner;
    try {
      if (!await ensureAvailable()) return false;
      // The answer arrives across an await, so this caller may be gone by now,
      // and another caller may have opened the session while it was in flight.
      if (_disposed || _listening || !identical(_owner, sessionOwner)) {
        return false;
      }

      try {
        await beforeListen?.call();
        _captureHeld = beforeListen != null;
      } catch (_) {
        onDidNotStart?.call();
        return false;
      }
      if (_disposed || !identical(_owner, sessionOwner)) {
        _releaseCapture();
        return false;
      }

      final mine = ++_session;
      // The platform has not reported listening yet, and may not report it at
      // all before the first words, so the session is declared open here.
      _setListening(true);
      _sessionWords = null;
      _heardAnything = false;
      _pendingStart = onDidNotStart;
      // The platform hands results to whichever session is listening now, so a
      // stopped session's final result arrives stamped with this one, already
      // past the token that fenced it out. Nothing can tell such a leftover from
      // the new session speaking except that it carries the stopped session's
      // words forward, which is what the first callback is checked for.
      final leftover = _stoppedWords;
      _stoppedWords = null;
      _awaitingFirstWords = leftover != null && leftover.isNotEmpty;
      try {
        await _recognizer.listen(
          // The platform can deliver a final result after a stop, and that
          // result is worth keeping, so words are gated on which session asked
          // for them rather than on whether listening is still set. A later
          // session's words cannot reach this one, nor the reverse.
          onWords: (words) {
            if (_disposed || mine != _session) return;
            // Before the checks below, because what is being asked here is
            // whether the platform heard anything at all, and a dropped first
            // callback is still something it said.
            _heardAnything = true;
            if (_awaitingFirstWords) {
              _awaitingFirstWords = false;
              // Dropped, and not passed on: the words are already in the field,
              // so reaching the consumer would say the sentence twice. Only the
              // first callback is checked, because a session's words then grow
              // into something the leftover could not be.
              if (leftover != null && words.startsWith(leftover)) return;
            }
            // Recorded only once the words are being passed on, so what a stop
            // remembers is what the consumer was told rather than a result it
            // never saw.
            _sessionWords = words;
            onWords(words);
          },
        );
      } on SpeechRecognitionUnavailableException {
        // Native rejected the request before starting capture.
        _available = false;
        _setListening(false);
        _releaseCapture();
        _showUnavailableNotice();
        return false;
      } on SpeechRecognitionStartRejectedException {
        final didNotStart = _pendingStart;
        _setListening(false);
        _releaseCapture();
        didNotStart?.call();
        return false;
      } on Exception {
        // A failed native start may still have opened capture. Close it after
        // startup settles and hold the lease until that stop is confirmed.
        stopAfterStartFailure = true;
        // Take the callback before closing the session disowns it.
        final didNotStart = _pendingStart;
        _setListening(false);
        didNotStart?.call();
        return false;
      }
      if (_disposed || !identical(_owner, sessionOwner)) {
        // Disposal landed while the session was starting, so the microphone has
        // just been opened for a caller that no longer exists.
        await _stopQuietly();
        _setListening(false, confirmStop: false);
        return false;
      }
      return true;
    } finally {
      _starting = false;
      if (stopAfterStartFailure) unawaited(_stopQuietly());
      if (identical(_startDone, startDone)) _startDone = null;
      startDone.complete();
      if (!_listening && identical(_owner, sessionOwner)) _owner = null;
    }
  }

  void stopForOwner(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    if (_listening && !_starting) unawaited(stop().catchError((Object _) {}));
  }

  /// Ends the session. Clears the flag directly because the platform tears
  /// down silently and may send no status change.
  ///
  /// What the session ended on is kept, because its final result can still
  /// arrive afterwards and the next session has to recognise it.
  ///
  /// A caller that is tearing down should dispose this instead: [dispose]
  /// cannot be awaited and never lets a platform failure escape.
  Future<void> stop() async {
    if (_starting) {
      _owner = null;
      await _startDone?.future;
      if (!_listening && !_captureHeld) return;
    }
    try {
      await _confirmStop();
    } finally {
      _setListening(false, confirmStop: false);
      _stoppedWords = _sessionWords;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (!_starting && (_listening || _captureHeld)) {
      // A microphone opened here is closed here. A session starting right now
      // is caught by the check at the end of [listen] instead.
      unawaited(_stopQuietly());
    }
    super.dispose();
  }

  /// Records that this device cannot recognise, without answering the
  /// question: only initialisation can do that.
  ///
  /// A seam that reported unavailability part-way through a session must not
  /// retire the mic, or an ordinary pause would end dictation for the whole
  /// app. Were one ever to, `isAvailable` would stay true beside this notice,
  /// a state nothing here reaches on its own: a screen that keys the mic on
  /// the notice would hide it for the rest of that session.
  void _showUnavailableNotice() => _setNotice(speechUnavailableNotice);

  /// A session the platform ended in an error.
  ///
  /// Ends the session and says nothing more unless the session heard nothing
  /// at all, which is the case where a person tapped a microphone, saw the
  /// platform's own indicator, and got no words and no explanation. That is
  /// what a locale with no offline language pack looks like, and `onDevice`
  /// refuses the network recogniser that would otherwise cover for it.
  ///
  /// Silence is kept for a session that heard anything, including one the pause
  /// timer ended: words are already in the field there, and a session that ran
  /// for its forty-five seconds is not a start that failed. An error therefore
  /// never reaches [notice] and never reaches `_available`, so no error can
  /// retire the microphone — which is the whole reason this is a separate
  /// signal rather than a call to [_showUnavailableNotice].
  void _sessionErrored() {
    if (_disposed) return;
    // Nothing is open, so this failure belongs to a session that has already
    // finished: a stop the person asked for, or a second error for a failure
    // already answered. Reported anyway it would accuse whichever field happens
    // to be open, which is not what went wrong.
    final pending = _pendingStart;
    if (pending == null) return;
    final didNotStart = _heardAnything ? null : pending;
    _setListening(false);
    didNotStart?.call();
  }

  Future<void> _stopQuietly() async {
    try {
      await _confirmStop();
    } on Exception {
      // The session is already gone from this side, and a failure while
      // tearing down has nowhere left to be reported.
    }
  }

  Future<void> _confirmStop() {
    final pending = _closingCapture;
    if (pending != null) return pending;
    final operation = Future<void>.microtask(() async {
      await _recognizer.stop();
      _releaseCapture();
    });
    _closingCapture = operation;
    operation.then<void>(
      (_) {
        if (identical(_closingCapture, operation)) _closingCapture = null;
      },
      onError: (Object _, StackTrace __) {
        if (identical(_closingCapture, operation)) _closingCapture = null;
      },
    );
    return operation;
  }

  void _setListening(bool listening, {bool confirmStop = true}) {
    if (_listening == listening) return;
    _listening = listening;
    if (!listening) {
      _owner = null;
      if (confirmStop && _captureHeld && !_starting) unawaited(_stopQuietly());
      // The session this callback belonged to is over, so a failure arriving
      // afterwards belongs to no one: a second error, or a stop the person
      // asked for, must not be reported as an attempt that did not take.
      _pendingStart = null;
    }
    _notify();
  }

  void _releaseCapture() {
    if (!_captureHeld) return;
    _captureHeld = false;
    afterListen?.call();
  }

  void _setNotice(String? notice) {
    if (_notice == notice) return;
    _notice = notice;
    _notify();
  }

  /// The platform can report a status change after this is disposed, and a
  /// disposed notifier may not notify.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }
}
