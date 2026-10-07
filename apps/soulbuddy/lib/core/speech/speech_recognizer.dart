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
  ///
  /// [onError] is that middle case, named separately so a consumer can tell it
  /// from both of the others: the platform has failed the running session and
  /// ended it. It says nothing about whether speech can run here. The plugin
  /// marks every error permanent, so a five second pause arrives here beside a
  /// locale with no offline language pack, and only the return of this method
  /// can answer the question. Nor can it say whether the session had begun —
  /// the platform announces a session as listening before it knows the
  /// recogniser accepted it — so a consumer that must tell a start that never
  /// took from a session that ran has to weigh it against what it heard.
  Future<bool> initialize({
    void Function(bool listening)? onListeningChanged,
    VoidCallback? onUnavailable,
    VoidCallback? onError,
  });

  /// Starts recognising. [onWords] receives the whole session's words on every
  /// callback, partials included, so it grows rather than accumulates. Does not
  /// throw if recognition could not be started.
  ///
  /// Completing says the platform accepted the request, not that recognition
  /// began: a locale with no offline pack is accepted and then fails, and that
  /// arrives through [initialize]'s [onError].
  ///
  /// May complete before the platform reports listening, and [onWords] may
  /// still be called after [stop], so a consumer keeps its own session state.
  Future<void> listen({required void Function(String words) onWords});

  /// Ends the session, keeping whatever was recognised.
  Future<void> stop();
}
