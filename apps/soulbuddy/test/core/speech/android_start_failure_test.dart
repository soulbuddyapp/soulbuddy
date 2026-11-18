import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/speech/plugin_speech_recognizer.dart';
import 'package:soulbuddy/core/speech/speech_capture_controller.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final confirmed in [true, false]) {
    test(
      'native ${confirmed ? 'pre-start' : 'uncertain'} failure preserves lease contract',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final stop = Completer<bool>();
        var stopCalls = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize') return true;
          if (call.method == 'listen') {
            throw PlatformException(
              code: confirmed ? 'startRejected' : 'unknown',
            );
          }
          if (call.method == 'stop') {
            stopCalls++;
            return stop.future;
          }
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        var releases = 0;
        final controller = SpeechCaptureController(
          recognizer: PluginSpeechRecognizer(
            speech: SpeechToText.withMethodChannel(),
          ),
          beforeListen: () async {},
          afterListen: () => releases++,
        );
        addTearDown(controller.dispose);
        expect(await controller.listen(onWords: (_) {}), isFalse);
        await pumpEventQueue();
        expect(stopCalls, confirmed ? 0 : 1);
        expect(releases, confirmed ? 1 : 0);
        if (!confirmed) {
          stop.complete(true);
          await pumpEventQueue();
          expect(releases, 1);
        }
        expect(controller.notice, isNull);
      },
    );
  }
}
