import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'speech_recognizer.dart';

const String _unavailableNotice =
    'Speak is unavailable. You can write instead.';

/// Adapts the `speech_to_text` plugin to [SpeechRecognizer].
///
/// The single place that asks for on-device recognition. `onDevice: true` is
/// not configurable, so no caller can widen it.
class PluginSpeechRecognizer implements SpeechRecognizer {
  PluginSpeechRecognizer({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> initialize({
    void Function(bool listening)? onListeningChanged,
    void Function(String message)? onUnavailable,
  }) async {
    // Browser speech recognition sends audio off the device and is not used.
    if (kIsWeb) {
      onUnavailable?.call(_unavailableNotice);
      return false;
    }
    try {
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
        onError: (_) => onUnavailable?.call(_unavailableNotice),
      );
      if (!available) {
        onUnavailable?.call(_unavailableNotice);
      }
      return available;
    } on Object {
      onUnavailable?.call(_unavailableNotice);
      return false;
    }
  }

  @override
  Future<void> listen({required void Function(String words) onWords}) async {
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.recognizedWords.isNotEmpty) onWords(result.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 5),
        onDevice: true,
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}
