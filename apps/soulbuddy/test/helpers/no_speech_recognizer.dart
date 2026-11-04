import 'package:flutter/foundation.dart';
import 'package:soulbuddy/core/speech/speech_recognizer.dart';

/// Speech that cannot run, answered without reaching a plugin.
///
/// A screen carrying a [SayableField] resolves availability on mount, and the
/// real seam asks the `record` plugin for the microphone first. In a widget test
/// neither plugin is registered, so that request walks into the recorder and
/// leaves a periodic amplitude timer pending — which fails the test as "a Timer
/// is still pending" rather than as anything to do with the screen. Answering
/// directly leaves the screen in the state it was in before: speech
/// unavailable, the field writable and the notice shown.
///
/// Override it into a scope that renders a sayable field:
///
/// ```dart
/// ProviderScope(
///   overrides: [speechRecognizerProvider.overrideWithValue(NoSpeech())],
///   child: app,
/// )
/// ```
class NoSpeech implements SpeechRecognizer {
  @override
  Future<bool> initialize({
    void Function(bool listening)? onListeningChanged,
    VoidCallback? onUnavailable,
    VoidCallback? onError,
  }) async => false;

  @override
  Future<void> listen({required void Function(String words) onWords}) async {}

  @override
  Future<void> stop() async {}
}
