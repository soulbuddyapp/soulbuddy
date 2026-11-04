import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/speech/plugin_speech_recognizer.dart';
import 'package:soulbuddy/core/speech/speech_capture_controller.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('unsupported on-device recognition shows unavailable notice', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'listen') {
        throw PlatformException(code: 'onDeviceUnavailable');
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    var didNotStart = 0;
    var released = 0;
    final controller = SpeechCaptureController(
      recognizer: PluginSpeechRecognizer(
        speech: SpeechToText.withMethodChannel(),
      ),
      beforeListen: () async {},
      afterListen: () => released++,
    );
    addTearDown(controller.dispose);
    final started = await controller.listen(
      onWords: (_) {},
      onDidNotStart: () => didNotStart++,
    );
    expect(started, isFalse);
    expect(controller.notice, speechUnavailableNotice);
    expect(controller.isAvailable, isFalse);
    expect(didNotStart, 0);
    expect(released, 1);
  });
}
