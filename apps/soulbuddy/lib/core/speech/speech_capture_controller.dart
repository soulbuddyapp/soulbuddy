import 'dart:async';

import 'package:flutter/foundation.dart';

import 'plugin_speech_recognizer.dart';
import 'speech_recognizer.dart';

/// Shown when speech cannot run on this device.
///
/// The seam reports availability as a signal; the wording belongs here, so
/// there is exactly one copy of this string in the app.
const String speechUnavailableNotice =
    'Speak is unavailable. You can write instead.';

/// Availability and listening state for dictation.
///
/// Availability is resolved once: repeated taps on an unavailable field must
/// not re-prompt or re-notice. Listening state is owned here rather than read
/// back from the recogniser, because the plugin reports it late, or not at
/// all after a stop.
class SpeechCaptureController extends ChangeNotifier {
  SpeechCaptureController({SpeechRecognizer? recognizer})
    : _recognizer = recognizer ?? PluginSpeechRecognizer();

  final SpeechRecognizer _recognizer;

  bool? _available;
  bool _listening = false;
  bool _disposed = false;
  String? _notice;

  /// Whether speech is available. False until [ensureAvailable] resolves.
  bool get isAvailable => _available ?? false;

  /// Whether a session is believed to be running.
  bool get isListening => _listening;

  /// The notice to show, or null when speech is available.
  String? get notice => _notice;

  /// Resolves availability once and caches it.
  Future<bool> ensureAvailable() async {
    final known = _available;
    if (known != null) return known;

    final available = await _recognizer.initialize(
      onListeningChanged: _setListening,
      onUnavailable: _markUnavailable,
    );
    _available = available;
    if (available) {
      // Only the answer changed here, which no setter reports.
      _notify();
    } else {
      _markUnavailable();
    }
    return available;
  }

  /// Starts a session. Returns false when speech is unavailable or could not
  /// start, leaving the caller's field untouched and editable.
  Future<bool> listen({required void Function(String words) onWords}) async {
    if (!await ensureAvailable()) return false;
    _setNotice(null);
    // The plugin has not reported listening yet, and may not report it at all
    // before the first words, so the session is declared open here.
    _setListening(true);
    try {
      await _recognizer.listen(onWords: onWords);
      return true;
    } on Object {
      _setListening(false);
      return false;
    }
  }

  /// Ends the session. Clears the flag directly because the plugin tears
  /// down silently and may send no status change.
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
      // A microphone must not outlive the controller that opened it.
      unawaited(_stopQuietly());
    }
    super.dispose();
  }

  /// Records the answer once. A permanent failure ends the question, so a
  /// later tap reads this rather than asking the platform again.
  void _markUnavailable() {
    _available = false;
    _setNotice(speechUnavailableNotice);
  }

  Future<void> _stopQuietly() async {
    try {
      await _recognizer.stop();
    } on Object {
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
