import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/speech/plugin_speech_recognizer.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native listen refusal is reported through recognizer seam', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'initialize'
          ? true
          : call.method == 'listen'
          ? false
          : null,
    );
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final recognizer = PluginSpeechRecognizer(
      speech: SpeechToText.withMethodChannel(),
    );
    expect(await recognizer.initialize(), isTrue);
    await expectLater(
      recognizer.listen(onWords: (_) {}),
      throwsA(isA<Exception>()),
    );
  });
}
