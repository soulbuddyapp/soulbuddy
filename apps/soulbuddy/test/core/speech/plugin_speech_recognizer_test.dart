import 'dart:convert';
import 'dart:io';

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

  // `SpeechToText()` is a singleton that caches its own initialisation, so
  // each test is given a fresh instance instead of inheriting the last one's.
  PluginSpeechRecognizer buildRecognizer() =>
      PluginSpeechRecognizer(speech: SpeechToText.withMethodChannel());

  // The plugin flattens [SpeechListenOptions] onto the channel in
  // `MethodChannelSpeechToText.listen`, so this is what the native side reads.
  Map<Object?, Object?> listenArguments() =>
      calls.firstWhere((call) => call.method == 'listen').arguments!
          as Map<Object?, Object?>;

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

    final arguments = listenArguments();
    expect(arguments['onDevice'], isTrue);
    expect(arguments['listenFor'], 45000);
    expect(arguments['pauseFor'], 5000);
    expect(arguments['partialResults'], isTrue);
  });

  test('reports unavailable when initialisation fails', () async {
    initializeResult = false;
    final recognizer = buildRecognizer();
    String? notice;

    expect(
      await recognizer.initialize(onUnavailable: (m) => notice = m),
      isFalse,
    );
    expect(notice, 'Speak is unavailable. You can write instead.');
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
    String? notice;
    final changes = <bool>[];
    await recognizer.initialize(
      onListeningChanged: changes.add,
      onUnavailable: (m) => notice = m,
    );
    await recognizer.listen(onWords: (_) {});
    await deliver('notifyStatus', 'listening');

    await deliverError('error_no_match');

    expect(changes, [true, false], reason: 'the session ends');
    expect(
      notice,
      isNull,
      reason: 'a later attempt may still succeed, so the mic stays',
    );
  });

  test('a permanent error means speech is unavailable', () async {
    final recognizer = buildRecognizer();
    String? notice;
    await recognizer.initialize(onUnavailable: (m) => notice = m);
    await recognizer.listen(onWords: (_) {});

    await deliverError('error_client', permanent: true);

    expect(notice, 'Speak is unavailable. You can write instead.');
  });

  test('never starts browser speech recognition', () {
    final source = File(
      'lib/core/speech/plugin_speech_recognizer.dart',
    ).readAsStringSync();

    expect(source, contains('if (kIsWeb)'));
    expect(
      source.indexOf('if (kIsWeb)'),
      lessThan(source.indexOf('_speech.initialize')),
    );
  });
}
