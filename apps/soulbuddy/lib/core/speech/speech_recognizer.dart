import 'package:flutter/foundation.dart';

/// Recognition of speech into words.
///
/// An interface so the plugin can be faked. [initialize] must never accept a
/// network recogniser: spoken words stay on this device. Availability is a
/// signal; the notice shown to a person belongs to the caller.
abstract interface class SpeechRecognizer {
  bool get isListening;

  /// Whether speech is available on this device. Reports the listening
  /// transitions [onListeningChanged] describes and calls [onUnavailable] when
  /// it is not. Does not throw: every failure is an answer of `false`.
  Future<bool> initialize({
    void Function(bool listening)? onListeningChanged,
    VoidCallback? onUnavailable,
  });

  /// Starts recognising. [onWords] receives the whole session's words on every
  /// callback, partials included, so it grows rather than accumulates. Does not
  /// throw if recognition could not be started.
  Future<void> listen({required void Function(String words) onWords});

  /// Ends the session, keeping whatever was recognised.
  Future<void> stop();
}
