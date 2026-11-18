import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Android terminal error never schedules a late cancel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const name = 'plugin.csdcorp.com/speech_to_text';
    const channel = MethodChannel(name);
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method == 'initialize' || call.method == 'listen'
          ? true
          : null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final speech = SpeechToText.withMethodChannel();
    await speech.initialize();
    await speech.listen(
      listenOptions: SpeechListenOptions(cancelOnError: true),
    );
    await messenger.handlePlatformMessage(
      name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(
          'notifyError',
          jsonEncode({'errorMsg': 'error_no_match', 'permanent': true}),
        ),
      ),
      null,
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((call) => call == 'cancel'), isEmpty);
  });
}
