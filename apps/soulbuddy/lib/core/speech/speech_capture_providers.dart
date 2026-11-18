import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/record/audio/application/record_plugin_driver.dart';
import '../../features/record/audio/data/audio_asset_store.dart';
import '../../features/record/audio/providers/memory_audio_providers.dart';
import '../playback/spiritual_session_providers.dart';
import 'plugin_speech_recognizer.dart';
import 'speech_capture_controller.dart';
import 'speech_recognizer.dart';

/// The one recogniser for the whole app.
///
/// It owns asking for the microphone, because that is the one thing dictation
/// needs that nothing else has already arranged. `speech_to_text` expects the
/// app to hold `RECORD_AUDIO` and never prompts for it, so without this a
/// person who opened a prayer field before ever recording a memory would find
/// the microphone simply did not work.
///
/// The permission goes through the `record` plugin the app already depends on,
/// rather than a new dependency. Only the permission is asked for here; the
/// recorder this builds is closed again straight away, so dictation never holds
/// one.
final speechRecognizerProvider = Provider<SpeechRecognizer>((ref) {
  return PluginSpeechRecognizer(
    requestMicrophone: () async {
      final AudioAssetStore assetStore = await ref.read(
        audioAssetStoreProvider.future,
      );
      final recorder = createRecordPluginAudioRecorder(assetStore);
      try {
        return await recorder.requestPermission();
      } finally {
        await recorder.dispose();
      }
    },
  );
});

/// The one dictation controller for the whole app.
///
/// There is one microphone and one session, and only one field can usefully
/// be dictating at a time, so every field shares this. A controller per field
/// would mean an initialisation each, with whichever registered last taking
/// the seam's callbacks, and any field's teardown ending another field's
/// session.
final speechCaptureControllerProvider = Provider<SpeechCaptureController>((
  ref,
) {
  final owner = Object();
  final lock = ref.read(microphoneCaptureLockProvider);
  final session = ref.read(spiritualSessionControllerProvider);
  final controller = SpeechCaptureController(
    recognizer: ref.read(speechRecognizerProvider),
    beforeListen: () async {
      lock.acquire(owner);
      try {
        await session.acquireCapture(owner);
        await pauseAudioForCapture(ref);
      } catch (_) {
        session.releaseCapture(owner);
        lock.release(owner);
        rethrow;
      }
    },
    afterListen: () {
      session.releaseCapture(owner);
      lock.release(owner);
    },
  );
  ref.onDispose(controller.dispose);
  return controller;
});
