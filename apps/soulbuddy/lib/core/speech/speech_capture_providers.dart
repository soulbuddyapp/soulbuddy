import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'speech_capture_controller.dart';

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
  final controller = SpeechCaptureController();
  ref.onDispose(controller.dispose);
  return controller;
});
