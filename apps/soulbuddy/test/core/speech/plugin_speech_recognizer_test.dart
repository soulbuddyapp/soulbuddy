import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/speech/plugin_speech_recognizer.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'plugin.csdcorp.com/speech_to_text';
  const channel = MethodChannel(channelName);
  final calls = <MethodCall>[];
  var initializeResult = true;

  setUp(() {
    calls.clear();
    initializeResult = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'initialize' => initializeResult,
            'listen' => true,
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // `SpeechToText()` is a singleton that caches its own initialisation, so
  // each test is given a fresh instance instead of inheriting the last one's.
  PluginSpeechRecognizer buildRecognizer({bool? isWeb}) =>
      PluginSpeechRecognizer(
        speech: SpeechToText.withMethodChannel(),
        isWeb: isWeb,
      );

  Future<void> deliver(String method, Object? arguments) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channelName,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(method, arguments),
            ),
            null,
          );

  // `recognizedWords` is the whole session so far, not a delta, so partials are
  // delivered with `resultType` 0 and the last one with `resultType` 2.
  Future<void> deliverWords(String words, {bool finalResult = true}) => deliver(
    'textRecognition',
    jsonEncode({
      'alternates': [
        {
          'recognizedWords': words,
          'recognizedPhrases': null,
          'confidence': 0.9,
        },
      ],
      'resultType': finalResult ? 2 : 0,
    }),
  );

  // The plugin delivers errors as a JSON string and decodes them itself.
  Future<void> deliverError(String message, {bool permanent = false}) =>
      deliver(
        'notifyError',
        jsonEncode({'errorMsg': message, 'permanent': permanent}),
      );

  test('recognises only on this device', () async {
    final recognizer = buildRecognizer();

    expect(await recognizer.initialize(), isTrue);
    await recognizer.listen(onWords: (_) {});

    // The only observable proof the privacy flag reaches the native side. The
    // plugin flattens it onto the channel in `MethodChannelSpeechToText.listen`;
    // the timings beside it are its encoding, not this app's policy.
    final listen = calls.firstWhere((call) => call.method == 'listen');
    expect((listen.arguments as Map)['onDevice'], isTrue);
  });

  test('reports unavailable when initialisation fails', () async {
    initializeResult = false;
    final recognizer = buildRecognizer();
    var unavailable = false;

    expect(
      await recognizer.initialize(onUnavailable: () => unavailable = true),
      isFalse,
    );
    expect(unavailable, isTrue);
  });

  test('a listen that cannot start does not throw', () async {
    initializeResult = false;
    final recognizer = buildRecognizer();
    await recognizer.initialize();

    await expectLater(recognizer.listen(onWords: (_) {}), completes);
  });

  test('delivers recognised words and ignores empty results', () async {
    final recognizer = buildRecognizer();
    await recognizer.initialize();
    final heard = <String>[];
    await recognizer.listen(onWords: heard.add);

    await deliverWords('', finalResult: false);
    await deliverWords('the morning', finalResult: false);
    await deliverWords('the morning light');

    expect(heard, ['the morning', 'the morning light']);
  });

  test('reports when listening starts and when it ends', () async {
    final recognizer = buildRecognizer();
    final changes = <bool>[];
    await recognizer.initialize(onListeningChanged: changes.add);
    await recognizer.listen(onWords: (_) {});

    await deliver('notifyStatus', 'listening');
    expect(recognizer.isListening, isTrue);
    await deliver('notifyStatus', 'notListening');

    expect(changes, [true, false]);
    expect(recognizer.isListening, isFalse);
  });

  test('a transient error ends the session but keeps the mic', () async {
    final recognizer = buildRecognizer();
    var unavailable = false;
    final changes = <bool>[];
    await recognizer.initialize(
      onListeningChanged: changes.add,
      onUnavailable: () => unavailable = true,
    );
    await recognizer.listen(onWords: (_) {});
    await deliver('notifyStatus', 'listening');

    await deliverError('error_no_match');

    expect(changes, [true, false], reason: 'the session ends');
    expect(
      unavailable,
      isFalse,
      reason: 'a later attempt may still succeed, so the mic stays',
    );
  });

  test('a permanent error ends the session and reports unavailable', () async {
    final recognizer = buildRecognizer();
    var unavailable = false;
    final changes = <bool>[];
    await recognizer.initialize(
      onListeningChanged: changes.add,
      onUnavailable: () => unavailable = true,
    );
    await recognizer.listen(onWords: (_) {});
    await deliver('notifyStatus', 'listening');

    await deliverError('error_client', permanent: true);

    expect(changes, [true, false]);
    expect(
      recognizer.isListening,
      isFalse,
      reason: 'the plugin tears the session down without saying so',
    );
    expect(unavailable, isTrue);
  });

  test('stop ends the session on the platform', () async {
    final recognizer = buildRecognizer();
    await recognizer.initialize();
    await recognizer.listen(onWords: (_) {});

    await recognizer.stop();

    expect(
      calls.map((call) => call.method),
      containsAllInOrder(['initialize', 'listen', 'stop']),
    );
  });

  test('never starts browser speech recognition', () async {
    final recognizer = buildRecognizer(isWeb: true);
    var unavailable = false;

    expect(
      await recognizer.initialize(onUnavailable: () => unavailable = true),
      isFalse,
    );
    expect(unavailable, isTrue);
    expect(calls, isEmpty, reason: 'the plugin is never reached');
  });
}
