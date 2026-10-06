/// Recognition of speech into words.
///
/// An interface so the plugin can be faked. [initialize] must never accept a
/// network recogniser: spoken words stay on this device.
abstract interface class SpeechRecognizer {
  bool get isListening;

  Future<bool> initialize({
    void Function(bool listening)? onListeningChanged,
    void Function(String message)? onUnavailable,
  });

  Future<void> listen({required void Function(String words) onWords});

  Future<void> stop();

  Future<void> cancel();
}
