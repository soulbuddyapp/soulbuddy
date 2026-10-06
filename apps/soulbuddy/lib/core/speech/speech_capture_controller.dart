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
    try {
      await _recognizer.listen(
        // The platform can deliver a final result after a stop, and that
        // result is worth keeping, so words are gated on which session asked
        // for them rather than on whether listening is still set. A later
        // session's words cannot reach this one, nor the reverse.
        onWords: (words) {
          if (_disposed || mine != _session) return;
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
  /// A caller that is tearing down should dispose this instead: [dispose]
  /// cannot be awaited and never lets a platform failure escape.
  Future<void> stop() async {
    try {
      await _recognizer.stop();
    } finally {
      _setListening(false);
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
