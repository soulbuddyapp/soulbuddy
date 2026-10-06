import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/speech/plugin_speech_recognizer.dart';
import 'package:soulbuddy/core/speech/sayable_field.dart';
import 'package:soulbuddy/core/speech/speech_capture_controller.dart';
import 'package:soulbuddy/core/speech/speech_capture_providers.dart';
import 'package:soulbuddy/core/speech/speech_recognizer.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'plugin.csdcorp.com/speech_to_text';
  const channel = MethodChannel(channelName);
  const mic = Key('sayable-field-mic');
  const action = Key('sayable-field-speak-action');

  // Registered per test rather than once, because `SpeechToText` is a
  // singleton whose `initialize` is memoised: a handler left behind by an
  // earlier test would be this one's too. Each test that reaches the plugin
  // builds its own `SpeechToText.withMethodChannel()` for the same reason.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'initialize' => true,
            'listen' => true,
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> deliverWords(String words, {bool finalResult = true}) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channelName,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(
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
              ),
            ),
            null,
          );

  Widget host(
    SpeechCaptureController speech,
    TextEditingController field, {
    SayableEmphasis emphasis = SayableEmphasis.compact,
    int? maxLength,
    VoidCallback? onTruncated,
  }) => ProviderScope(
    overrides: [speechCaptureControllerProvider.overrideWithValue(speech)],
    child: MaterialApp(
      home: Scaffold(
        body: SayableField(
          controller: field,
          emphasis: emphasis,
          maxLength: maxLength,
          onTruncated: onTruncated,
        ),
      ),
    ),
  );

  // The field, and the controller it will dictate into. The seam is a fake so
  // that words can be delivered on demand, in any order, including after a
  // stop. Availability is resolved by the widget on mount, so the pumps below
  // are what let it settle before a test looks at it.
  Future<({TextEditingController field, SpeechCaptureController speech})>
  pumpField(
    WidgetTester tester, {
    required SpeechRecognizer recognizer,
    String text = '',
    int? caret,
    SayableEmphasis emphasis = SayableEmphasis.compact,
    int? maxLength,
    VoidCallback? onTruncated,
  }) async {
    final speech = SpeechCaptureController(recognizer: recognizer);
    addTearDown(speech.dispose);
    final field = TextEditingController(text: text);
    addTearDown(field.dispose);
    if (caret != null) {
      field.selection = TextSelection.collapsed(offset: caret);
    }
    await tester.pumpWidget(
      host(
        speech,
        field,
        emphasis: emphasis,
        maxLength: maxLength,
        onTruncated: onTruncated,
      ),
    );
    await tester.pump();
    return (field: field, speech: speech);
  }

  Future<void> tapMic(WidgetTester tester) async {
    await tester.tap(find.byKey(mic));
    await tester.pump();
  }

  testWidgets('recognised words reach the field', (tester) async {
    final seam = _FakeRecognizer();
    final subject = await pumpField(tester, recognizer: seam);

    await tapMic(tester);
    seam.emit('the morning light');

    expect(subject.field.text, 'the morning light');
    expect(
      subject.field.selection.baseOffset,
      'the morning light'.length,
      reason: 'the caret belongs where the words end',
    );
  });

  testWidgets('text already in the field survives dictation', (tester) async {
    final seam = _FakeRecognizer();
    final subject = await pumpField(
      tester,
      recognizer: seam,
      text: 'Amen ',
      caret: 5,
    );

    await tapMic(tester);
    seam.emit('God is good');

    expect(subject.field.text, 'Amen God is good');
  });

  testWidgets('the field keeps text after the caret', (tester) async {
    final seam = _FakeRecognizer();
    final subject = await pumpField(
      tester,
      recognizer: seam,
      // Nothing is inserted between the dictated words and what was already in
      // the field, so a caret sitting next to a space butts the words against
      // one side of it. What this pins down is that both sides survive.
      text: 'I will pray now',
      caret: 12,
    );

    await tapMic(tester);
    seam.emit('for peace');

    expect(subject.field.text, 'I will pray for peacenow');
  });

  testWidgets('the caret counts code units, not characters', (tester) async {
    // An emoji outside the basic plane is one character and two code units, and
    // a selection is counted in code units, so a rune count would leave the
    // caret between the halves of it.
    final seam = _FakeRecognizer();
    final subject = await pumpField(
      tester,
      recognizer: seam,
      text: 'God, ',
      caret: 5,
    );

    await tapMic(tester);
    seam.emit('🙏');

    expect(subject.field.text, 'God, 🙏');
    expect(subject.field.selection.baseOffset, 7);
  });

  testWidgets(
    'the mic becomes stop while listening and stops on a second tap',
    (tester) async {
      final seam = _FakeRecognizer();
      final subject = await pumpField(tester, recognizer: seam);

      expect(find.byIcon(Icons.mic_none), findsOneWidget);

      await tapMic(tester);

      expect(subject.speech.isListening, isTrue);
      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsNothing);
      expect(find.byTooltip('Stop dictation'), findsOneWidget);

      await tapMic(tester);

      expect(subject.speech.isListening, isFalse);
      expect(seam.stopCalls, 1);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
    },
  );

  testWidgets('a word caught by a stop still reaches the field', (
    tester,
  ) async {
    final seam = _FakeRecognizer();
    final subject = await pumpField(tester, recognizer: seam);

    await tapMic(tester);
    seam.emit('the morning');
    await tapMic(tester);
    expect(subject.speech.isListening, isFalse);

    // The controller lets a stopped session's final result through, so the
    // merge has to survive the stop rather than be cleared by it.
    seam.emit('the morning light');

    expect(subject.field.text, 'the morning light');
  });

  testWidgets(
    'an unavailable device says so, drops the mic, and still writes',
    (tester) async {
      final subject = await pumpField(
        tester,
        recognizer: _FakeRecognizer(available: false),
      );

      expect(find.text(speechUnavailableNotice), findsOneWidget);
      expect(find.byKey(mic), findsNothing);

      await tester.enterText(find.byType(TextField), 'Amen');

      expect(subject.field.text, 'Amen', reason: 'writing is never taken away');
    },
  );

  testWidgets('an unavailable device drops the labelled action too', (
    tester,
  ) async {
    await pumpField(
      tester,
      recognizer: _FakeRecognizer(available: false),
      emphasis: SayableEmphasis.prominent,
    );

    expect(find.text(speechUnavailableNotice), findsOneWidget);
    expect(find.byKey(action), findsNothing);
  });

  testWidgets('a notice retires the mic even where speech said it was available', (
    tester,
  ) async {
    // The one state where the two disagree: the seam answered available and then
    // reported that it could not go on. Nothing re-answers availability after
    // initialisation, so the notice is the only later signal there is, and a mic
    // that cannot work is worse than one hidden for the rest of the session.
    final seam = _FakeRecognizer();
    final subject = await pumpField(tester, recognizer: seam);
    expect(find.byKey(mic), findsOneWidget);

    await tapMic(tester);
    expect(subject.speech.isListening, isTrue);

    seam.reportUnavailable();
    await tester.pump();

    expect(subject.speech.isAvailable, isTrue);
    expect(find.text(speechUnavailableNotice), findsOneWidget);
    expect(find.byKey(mic), findsNothing);
  });

  testWidgets('prominent emphasis offers a labelled action as well', (
    tester,
  ) async {
    final seam = _FakeRecognizer();
    final subject = await pumpField(
      tester,
      recognizer: seam,
      emphasis: SayableEmphasis.prominent,
    );

    expect(find.byKey(mic), findsOneWidget);
    expect(find.text('Speak'), findsOneWidget);

    await tester.tap(find.byKey(action));
    await tester.pump();

    expect(subject.speech.isListening, isTrue);
    expect(find.text('Stop dictation'), findsOneWidget);
    expect(find.byIcon(Icons.stop), findsNWidgets(2));

    seam.emit('God is faithful');

    expect(subject.field.text, 'God is faithful');
  });

  testWidgets('a field that is cut reports the truncation', (tester) async {
    final seam = _FakeRecognizer();
    var truncated = 0;
    await pumpField(
      tester,
      recognizer: seam,
      maxLength: 10,
      onTruncated: () => truncated++,
    );

    await tapMic(tester);
    seam.emit('a very long sentence');

    expect(
      truncated,
      1,
      reason: 'a field that quietly cut a sentence would look saved in full',
    );
  });

  testWidgets('a sentence that fits exactly is not a truncation', (
    tester,
  ) async {
    final seam = _FakeRecognizer();
    var truncated = 0;
    final subject = await pumpField(
      tester,
      recognizer: seam,
      maxLength: 20,
      onTruncated: () => truncated++,
    );

    await tapMic(tester);
    seam.emit('a very long sentence');

    expect(truncated, isZero);
    expect(subject.field.text, 'a very long sentence');
  });

  testWidgets('a truncation is read on every callback, not only the first', (
    tester,
  ) async {
    final seam = _FakeRecognizer();
    var truncated = 0;
    await pumpField(
      tester,
      recognizer: seam,
      maxLength: 20,
      onTruncated: () => truncated++,
    );

    await tapMic(tester);
    seam.emit('short');
    expect(truncated, isZero);

    seam.emit('this is now a very long sentence');

    expect(truncated, 1, reason: 'the cut arrived on the second callback');
  });

  testWidgets('a cut that later fits again is not reported twice', (
    tester,
  ) async {
    final seam = _FakeRecognizer();
    var truncated = 0;
    await pumpField(
      tester,
      recognizer: seam,
      maxLength: 20,
      onTruncated: () => truncated++,
    );

    await tapMic(tester);
    seam.emit('this is now a very long sentence');
    expect(truncated, 1);

    seam.emit('short');

    expect(
      truncated,
      1,
      reason: 'the words fitted again, so there is nothing left to report',
    );
  });

  testWidgets('a cut in a second session is reported again', (tester) async {
    final seam = _FakeRecognizer();
    var truncated = 0;
    await pumpField(
      tester,
      recognizer: seam,
      maxLength: 10,
      onTruncated: () => truncated++,
    );

    await tapMic(tester);
    seam.emit('a very long sentence');
    expect(truncated, 1);

    await tapMic(tester);
    await tapMic(tester);
    // Does not open with the stopped session's words, so the controller lets it
    // through rather than dropping it as a repeat.
    seam.emit('another very long sentence');

    expect(
      truncated,
      2,
      reason: 'a field that can only report one cut stays silent for ever',
    );
  });

  testWidgets('a field that goes away takes its subscription with it', (
    tester,
  ) async {
    // The controller is app-wide and outlives the field, so a subscription left
    // behind would keep the field's State — and the caller's own
    // TextEditingController through it — alive for the rest of the session. The
    // mounted guard in the listener would stop it throwing, which is exactly
    // why the leak has to be counted rather than waited for.
    final speech = _CountingSpeech(recognizer: _FakeRecognizer());
    addTearDown(speech.dispose);
    final field = TextEditingController();
    addTearDown(field.dispose);

    await tester.pumpWidget(host(speech, field));
    await tester.pump();
    expect(speech.listeners, 1);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await tester.pump();

    expect(speech.listeners, 0);
  });

  testWidgets('recognises through the real plugin seam', (tester) async {
    final speech = SpeechToText.withMethodChannel();
    final subject = await pumpField(
      tester,
      recognizer: PluginSpeechRecognizer(speech: speech, isWeb: false),
    );

    await tapMic(tester);
    await deliverWords('the morning light', finalResult: false);

    expect(subject.field.text, 'the morning light');

    // The plugin arms its own pause timer when a session opens, and it
    // outlives the widget. Cancelling is what clears it, so the test does not
    // end with a timer pending.
    await speech.cancel();
  });
}

/// Counts what is subscribed to an app-wide notifier.
///
/// `ChangeNotifier` keeps its listener list to itself, and the widget guards its
/// own callback on `mounted`, so a leaked subscription is invisible unless
/// something counts it.
class _CountingSpeech extends SpeechCaptureController {
  _CountingSpeech({super.recognizer});

  int listeners = 0;

  @override
  void addListener(VoidCallback listener) {
    listeners++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listeners--;
    super.removeListener(listener);
  }
}

/// The seam the widget talks to, driven by hand.
///
/// Words are emitted on demand rather than on a timer, because the interesting
/// ones are the ones that arrive out of order: after a stop, or twice in a
/// session.
class _FakeRecognizer implements SpeechRecognizer {
  _FakeRecognizer({this.available = true});

  final bool available;
  int stopCalls = 0;
  void Function(String words)? _onWords;
  VoidCallback? _onUnavailable;

  @override
  Future<bool> initialize({
    void Function(bool listening)? onListeningChanged,
    VoidCallback? onUnavailable,
  }) async {
    _onUnavailable = onUnavailable;
    if (!available) {
      onUnavailable?.call();
      return false;
    }
    return true;
  }

  @override
  Future<void> listen({required void Function(String words) onWords}) async {
    _onWords = onWords;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  void emit(String words) => _onWords?.call(words);

  /// The seam reporting, part-way through a session, that it cannot continue.
  void reportUnavailable() => _onUnavailable?.call();
}
