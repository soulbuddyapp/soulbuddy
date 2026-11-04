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
  PluginSpeechRecognizer buildRecognizer({
    bool? isWeb,
    Future<bool> Function()? requestMicrophone,
  }) => PluginSpeechRecognizer(
    speech: SpeechToText.withMethodChannel(),
    isWeb: isWeb,
    requestMicrophone: requestMicrophone,
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

  test(
    'a listen that cannot start reports failure to the controller',
    () async {
      initializeResult = false;
      final recognizer = buildRecognizer();
      await recognizer.initialize();

      await expectLater(
        recognizer.listen(onWords: (_) {}),
        throwsA(isA<Exception>()),
      );
    },
  );

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
    await deliver('notifyStatus', 'notListening');

    expect(changes, [true, false]);
  });

  test('an error ends the session without retiring the mic', () async {
    // The plugin marks every error permanent, so the flag cannot tell a five
    // second pause apart from a device with no on-device recogniser. A later
    // attempt may still succeed, so none of these may retire the mic.
    for (final message in const [
      'error_speech_timeout',
      'error_no_match',
      'error_network',
      'error_client',
    ]) {
      final recognizer = buildRecognizer();
      var unavailable = false;
      final changes = <bool>[];
      await recognizer.initialize(
        onListeningChanged: changes.add,
        onUnavailable: () => unavailable = true,
      );
      await recognizer.listen(onWords: (_) {});
      await deliver('notifyStatus', 'listening');

      await deliverError(message, permanent: true);

      expect(changes, [true, false], reason: '$message ends the session');
      expect(
        unavailable,
        isFalse,
        reason: '$message says nothing about whether speech can run here',
      );
    }
  });

  test('an error is reported, not only the listening change', () async {
    // On a locale with no offline language pack this is the whole sequence: the
    // session is announced, accepted, and then failed before it heard anything.
    // A seam that answered only with the listening change left the consumer no
    // way to tell that from a pause, so the person saw a microphone open and
    // close and was told nothing.
    final recognizer = buildRecognizer();
    final changes = <bool>[];
    var errors = 0;
    var unavailable = false;
    await recognizer.initialize(
      onListeningChanged: changes.add,
      onUnavailable: () => unavailable = true,
      onError: () => errors++,
    );
    await recognizer.listen(onWords: (_) {});
    await deliver('notifyStatus', 'listening');

    // The platform announces a session before the recogniser has accepted it,
    // which is why the status alone cannot be read as "it started".
    await deliverError('error_language_not_supported', permanent: true);

    expect(errors, 1);
    expect(changes, [true, false]);
    expect(
      unavailable,
      isFalse,
      reason: 'the error is a session failing, not the device failing',
    );
  });

  test('no error is reported while the plugin was never reached', () async {
    // The browser recogniser and a refused microphone are answered before the
    // plugin exists, so nothing there can have failed a session.
    for (final recognizer in [
      buildRecognizer(isWeb: true),
      buildRecognizer(requestMicrophone: () async => false),
    ]) {
      var errors = 0;
      await recognizer.initialize(onError: () => errors++);

      expect(errors, 0);
    }
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

  test('asks for the microphone before initialising speech', () async {
    // Injected rather than reaching for a real recorder, so what is being
    // tested is the order, not the platform.
    final asked = <String>[];
    final recognizer = buildRecognizer(
      requestMicrophone: () async {
        asked.add('request');
        return true;
      },
    );

    expect(await recognizer.initialize(), isTrue);

    expect(
      asked,
      isNotEmpty,
      reason:
          'speech_to_text never prompts, and without the permission the '
          'platform requires, initialisation would fail for no actionable '
          'reason',
    );
    expect(calls.map((call) => call.method), contains('initialize'));
  });

  test(
    'a refused microphone leaves speech unavailable and uninitialised',
    () async {
      // Reported unavailable rather than thrown: the field stays editable, and a
      // person who declined is not asked again by a second signal.
      var unavailable = false;
      final recognizer = buildRecognizer(requestMicrophone: () async => false);

      expect(
        await recognizer.initialize(onUnavailable: () => unavailable = true),
        isFalse,
      );
      expect(unavailable, isTrue);
      expect(
        calls,
        isEmpty,
        reason: 'the recogniser is never started without the microphone',
      );
    },
  );

  test('a microphone request that throws leaves speech unavailable', () async {
    var unavailable = false;
    final recognizer = buildRecognizer(
      requestMicrophone: () async => throw StateError('no permission service'),
    );

    expect(
      await recognizer.initialize(onUnavailable: () => unavailable = true),
      isFalse,
    );
    expect(unavailable, isTrue);
    expect(calls, isEmpty);
  });

  test('the microphone is not asked for in the browser', () async {
    // The browser recogniser sends audio off the device, so it is never used
    // and there is no microphone permission to ask for.
    var asked = false;
    final recognizer = buildRecognizer(
      isWeb: true,
      requestMicrophone: () async {
        asked = true;
        return true;
      },
    );

    expect(await recognizer.initialize(), isFalse);
    expect(asked, isFalse);
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
