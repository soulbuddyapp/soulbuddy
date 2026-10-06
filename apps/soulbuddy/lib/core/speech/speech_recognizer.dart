import 'package:flutter/foundation.dart';

/// Recognition of speech into words.
///
/// An interface so the plugin can be faked. [initialize] must never accept a
/// network recogniser: spoken words stay on this device. Availability is a
/// signal; the notice shown to a person belongs to the caller.
abstract interface class SpeechRecognizer {
  /// Whether speech is available on this device. Reports the listening
  /// transitions [onListeningChanged] describes and calls [onUnavailable] when
  /// it is not. Does not throw: every failure is an answer of `false`.
  ///
  /// [onUnavailable] means speech cannot run here at all, so it arrives only
  /// from a failed initialisation. A failure part-way through a session ends
  /// that session and nothing more, because the platform reports those the
  /// same way it reports an absent recogniser.
  Future<bool> initialize({
    void Function(bool listening)? onListeningChanged,
    VoidCallback? onUnavailable,
  });

  /// Starts recognising. [onWords] receives the whole session's words on every
  /// callback, partials included, so it grows rather than accumulates. Does not
  /// throw if recognition could not be started.
  ///
  /// May complete before the platform reports listening, and [onWords] may
  /// still be called after [stop], so a consumer keeps its own session state.
  Future<void> listen({required void Function(String words) onWords});

  /// Ends the session, keeping whatever was recognised.
  Future<void> stop();
}
