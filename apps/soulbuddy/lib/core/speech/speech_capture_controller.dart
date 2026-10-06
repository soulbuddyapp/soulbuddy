import 'dart:async';

import 'package:flutter/foundation.dart';

import 'plugin_speech_recognizer.dart';
import 'speech_recognizer.dart';

/// Shown when speech cannot run on this device.
///
/// The seam passes availability up as a bare signal, so dictation copy lives
/// here rather than below it. [SpeechCaptureController] is the only consumer,
/// and every screen reads this rather than repeating the words.
const String speechUnavailableNotice =
    'Speak is unavailable. You can write instead.';

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
class SpeechCaptureController extends ChangeNotifier {
  SpeechCaptureController({SpeechRecognizer? recognizer})
    : _recognizer = recognizer ?? PluginSpeechRecognizer();

  final SpeechRecognizer _recognizer;

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

  /// Whether speech is available. False until [ensureAvailable] resolves.
  bool get isAvailable => _available ?? false;

  /// Whether a session is believed to be running.
  bool get isListening => _listening;

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
  /// The first callback may be dropped when this session follows a stop; see
  /// the note on this class. A consumer that needs the opening words kept
  /// whatever it is told should not also be updating a field from them, which
  /// is the one shape that would notice.
  Future<bool> listen({required void Function(String words) onWords}) async {
    if (_disposed || _listening) return false;
    if (!await ensureAvailable()) return false;
    // The answer arrives across an await, so this caller may be gone by now,
    // and another caller may have opened the session while it was in flight.
    if (_disposed || _listening) return false;

    final mine = ++_session;
    // The platform has not reported listening yet, and may not report it at
    // all before the first words, so the session is declared open here.
    _setListening(true);
    _sessionWords = null;
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
    } on Exception {
      _setListening(false);
      return false;
    }
    if (_disposed) {
      // Disposal landed while the session was starting, so the microphone has
      // just been opened for a caller that no longer exists.
      await _stopQuietly();
      return false;
    }
    return true;
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
    try {
      await _recognizer.stop();
    } finally {
      _setListening(false);
      _stoppedWords = _sessionWords;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_listening) {
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

  Future<void> _stopQuietly() async {
    try {
      await _recognizer.stop();
    } on Exception {
      // The session is already gone from this side, and a failure while
      // tearing down has nowhere left to be reported.
    }
  }

  void _setListening(bool listening) {
    if (_listening == listening) return;
    _listening = listening;
    _notify();
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
