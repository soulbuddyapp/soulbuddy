import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'speech_recognizer.dart';

/// Adapts the `speech_to_text` plugin to [SpeechRecognizer].
///
/// The single place that asks for on-device recognition. `onDevice: true` is
/// not configurable, so no caller can widen it.
///
/// [requestMicrophone] is asked before the recogniser is initialised, because
/// `speech_to_text` never asks itself: Android's `SpeechRecognizer` requires
/// `RECORD_AUDIO`, and this app otherwise only comes to hold it as a side
/// effect of someone recording a memory. It is injected rather than reached for
/// here so this stays free of `ref` and of the `record` plugin's wiring. A null
/// requester means the caller has arranged permission some other way.
class PluginSpeechRecognizer implements SpeechRecognizer {
  PluginSpeechRecognizer({
    SpeechToText? speech,
    bool? isWeb,
    Future<bool> Function()? requestMicrophone,
  }) : _speech = speech ?? SpeechToText(),
       // Only tests pass [isWeb]. The app reads the compile-time constant,
       // which no caller can turn off.
       _isWeb = isWeb ?? kIsWeb,
       _requestMicrophone = requestMicrophone;

  final SpeechToText _speech;
  final bool _isWeb;
  final Future<bool> Function()? _requestMicrophone;

  @override
  Future<bool> initialize({
    void Function(bool listening)? onListeningChanged,
    VoidCallback? onUnavailable,
  }) async {
    // Browser speech recognition sends audio off the device and is not used.
    if (_isWeb) {
      return _unavailable(onUnavailable);
    }
    try {
      // Asked first, because initialising without the permission the platform
      // requires answers `false` for a reason nobody can act on. A refusal is
      // not a temporary failure, so it is the same unavailable answer as an
      // absent recogniser: the field stays editable.
      final granted = await _requestMicrophone?.call() ?? true;
      if (!granted) {
        return _unavailable(onUnavailable);
      }
      final available = await _speech.initialize(
        onStatus: (status) {
          switch (status) {
            case SpeechToText.listeningStatus:
              onListeningChanged?.call(true);
            case SpeechToText.notListeningStatus:
            case SpeechToText.doneStatus:
              onListeningChanged?.call(false);
          }
        },
        // The plugin reports every error here, and because `cancelOnError` is
        // set it tears the session down itself without a status notification.
        // So the listening transition is reported here, or a consumer would
        // believe it were still listening.
        //
        // It marks every error permanent, so `error.permanent` says nothing
        // about whether speech can run here: a five second pause alone is
        // enough to end dictation for good if it is believed. Whether this
        // device can recognise at all is answered by initialisation alone.
        onError: (SpeechRecognitionError _) {
          onListeningChanged?.call(false);
        },
      );
      if (!available) {
        return _unavailable(onUnavailable);
      }
      return true;
    } on Object {
      return _unavailable(onUnavailable);
    }
  }

  @override
  Future<void> listen({required void Function(String words) onWords}) async {
    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          if (result.recognizedWords.isNotEmpty) {
            onWords(result.recognizedWords);
          }
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 5),
          onDevice: true,
          cancelOnError: true,
          partialResults: true,
        ),
      );
    } on Object {
      // The plugin throws when [initialize] did not succeed, and remembers
      // that, so every later attempt throws too. A caller has already been
      // told speech is unavailable; it gets no second, unanswerable signal.
    }
  }

  @override
  Future<void> stop() => _speech.stop();

  /// Every route to speech being unavailable on this device ends here, so the
  /// consumer hears about it once and gets `false` instead of an exception.
  static bool _unavailable(VoidCallback? onUnavailable) {
    onUnavailable?.call();
    return false;
  }
}
