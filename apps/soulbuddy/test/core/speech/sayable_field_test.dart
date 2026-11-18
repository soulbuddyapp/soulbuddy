import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
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

  Widget host(SpeechCaptureController speech, Widget child) => ProviderScope(
    overrides: [speechCaptureControllerProvider.overrideWithValue(speech)],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
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
    String? labelText,
    String? hintText,
    int minLines = 1,
    int maxLines = 2,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool autofocus = false,
    bool enabled = true,
    InputDecoration? decoration,
    String? Function(String?)? validator,
    SayableEmphasis emphasis = SayableEmphasis.compact,
    int? maxLength,
    ValueChanged<String>? onChanged,
    VoidCallback? onTruncated,
    bool showUnavailableNotice = true,
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
        SayableField(
          controller: field,
          labelText: labelText,
          hintText: hintText,
          minLines: minLines,
          maxLines: maxLines,
          textCapitalization: textCapitalization,
          autofocus: autofocus,
          enabled: enabled,
          decoration: decoration,
          validator: validator,
          emphasis: emphasis,
          maxLength: maxLength,
          onChanged: onChanged,
          onTruncated: onTruncated,
          showUnavailableNotice: showUnavailableNotice,
        ),
      ),
    );
    await tester.pump();
    return (field: field, speech: speech);
  }

  TextField fieldUnderTest(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField));

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
    // Nothing is inserted between the dictated words and what was already in
    // the field, so a caret sitting next to a space butts the words against one
    // side of it. Dictation into an empty field, or onto the end of saved text,
    // is the case the merge is built for and reads correctly; a caret placed
    // inside a sentence moves the space that was already there rather than
    // adding one, which is what `prefix + words + suffix` means. Kept as
    // written so a change here is a decision rather than an accident.
    final seam = _FakeRecognizer();
    final subject = await pumpField(
      tester,
      recognizer: seam,
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

  testWidgets('a dictated change reaches onChanged', (tester) async {
    // A field's own `onChanged` fires for typing only. A caller that reads its
    // controller in `build` and refreshes from `onChanged` would otherwise hold
    // a disabled button while the words are plainly on screen.
    final seam = _FakeRecognizer();
    final changed = <String>[];
    final subject = await pumpField(
      tester,
      recognizer: seam,
      onChanged: changed.add,
    );

    await tapMic(tester);
    seam.emit('the morning light');

    expect(changed, ['the morning light']);
    expect(subject.field.text, changed.single);
  });

  testWidgets('typing still reaches onChanged', (tester) async {
    final seam = _FakeRecognizer();
    final changed = <String>[];
    await pumpField(tester, recognizer: seam, onChanged: changed.add);

    await tester.enterText(find.byType(TextField), 'Amen');

    expect(changed, [
      'Amen',
    ], reason: 'typing was the reason onChanged existed');
  });

  testWidgets('opening a field does not request microphone permission', (
    tester,
  ) async {
    final seam = _FakeRecognizer();
    await pumpField(tester, recognizer: seam);
    expect(seam.initializeCalls, 0);
    await tapMic(tester);
    expect(seam.initializeCalls, 1);
  });

  testWidgets(
    'an unavailable device says so, drops the mic, and still writes',
    (tester) async {
      final subject = await pumpField(
        tester,
        recognizer: _FakeRecognizer(available: false),
      );

      await tapMic(tester);

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

    await tapMic(tester);

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

  testWidgets('the prominent action is spaced off the field', (tester) async {
    await pumpField(
      tester,
      recognizer: _FakeRecognizer(),
      emphasis: SayableEmphasis.prominent,
    );

    // `TextButton.icon` carries its own padding, so without a gap of its own the
    // label sits flush against the field's underline.
    expect(
      tester.getTopLeft(find.byKey(action)).dy -
          tester.getBottomLeft(find.byType(TextField)).dy,
      greaterThan(0),
    );
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

    await tester.pumpWidget(host(speech, SayableField(controller: field)));
    await tester.pump();
    expect(speech.listeners, 1);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await tester.pump();

    expect(speech.listeners, 0);
  });

  testWidgets('the field is tinted while listening', (tester) async {
    final seam = _FakeRecognizer();
    await pumpField(tester, recognizer: seam);

    final idle = fieldUnderTest(tester).decoration?.fillColor;

    await tapMic(tester);

    final listening = fieldUnderTest(tester).decoration?.fillColor;

    // The state belongs on the field being dictated into, not in a banner
    // elsewhere, so that whoever is looking at it can see it is open.
    expect(listening, isNotNull);
    expect(listening, isNot(idle));

    await tapMic(tester);

    expect(fieldUnderTest(tester).decoration?.fillColor, idle);
  });

  testWidgets('a second tap while availability resolves keeps the session', (
    tester,
  ) async {
    // The mic is up from the first frame, and availability resolves behind it.
    // Both taps take the start branch; the first opens the session and is told
    // yes, the second is refused because one is already running. Refusing the
    // second must not cost the first its merge, or the person is left with a
    // stop button, an open microphone, and no words ever arriving.
    final gate = Completer<void>();
    final seam = _FakeRecognizer(gate: gate);
    final subject = await pumpField(tester, recognizer: seam);

    await tester.tap(find.byKey(mic));
    await tester.pump();
    await tester.tap(find.byKey(mic));
    await tester.pump();

    gate.complete();
    await tester.pump();
    await tester.pump();

    expect(subject.speech.isListening, isTrue);

    seam.emit('the morning light');

    expect(
      subject.field.text,
      'the morning light',
      reason: 'the session that is running is the one writing the words',
    );
  });

  testWidgets('the field can be typed into while listening', (tester) async {
    final seam = _FakeRecognizer();
    final subject = await pumpField(tester, recognizer: seam);

    await tapMic(tester);

    expect(
      fieldUnderTest(tester).readOnly,
      isFalse,
      reason: 'dictation is an addition, never a mode',
    );

    await tester.enterText(find.byType(TextField), 'typed while listening');

    expect(subject.field.text, 'typed while listening');
    expect(subject.speech.isListening, isTrue);
  });

  testWidgets('text typed during a session is overwritten by the next callback', (
    tester,
  ) async {
    final seam = _FakeRecognizer();
    final subject = await pumpField(tester, recognizer: seam);

    await tapMic(tester);
    seam.emit('the morning');
    await tester.enterText(find.byType(TextField), 'typed instead');
    expect(subject.field.text, 'typed instead');

    seam.emit('the morning light');

    // The merge is rebuilt from what the field held when dictation began, so a
    // keystroke mid-session does not survive to be mixed into it. Documented
    // rather than fixed: the session took the caret, and the listening state is
    // visible on the field while it has it.
    expect(subject.field.text, 'the morning light');
  });

  testWidgets('a session that would not open leaves the field alone', (
    tester,
  ) async {
    final subject = await pumpField(
      tester,
      recognizer: _FakeRecognizer(failsToListen: true),
      text: 'Amen',
      caret: 4,
    );

    await tapMic(tester);

    expect(subject.speech.isListening, isFalse);
    expect(
      subject.field.text,
      'Amen',
      reason: 'a start that failed is not a change to the field',
    );
    expect(
      subject.speech.notice,
      isNull,
      reason: 'only initialisation can say the device cannot recognise',
    );
    expect(find.text(speechUnavailableNotice), findsNothing);
    expect(find.byKey(mic), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Amen, in patience');

    expect(subject.field.text, 'Amen, in patience');
  });

  // Found on a phone whose locale has no offline language pack. The device
  // reports a recognition service, so the microphone is offered and initialising
  // succeeds; the session is then accepted and fails before it hears anything.
  // `onDevice` refuses the network recogniser that would cover for it, which is
  // the trade this app made on purpose. What was missing was saying so.
  testWidgets('a session that never begins says so and keeps the microphone', (
    tester,
  ) async {
    final seam = _FakeRecognizer();
    final subject = await pumpField(tester, recognizer: seam, text: 'Amen');

    await tapMic(tester);
    expect(subject.speech.isListening, isTrue, reason: 'it was accepted');

    seam.failSession();
    await tester.pump();

    expect(find.text(speechDidNotStartNotice), findsOneWidget);
    expect(
      find.text(speechUnavailableNotice),
      findsNothing,
      reason: 'the device can still recognise, so the mic must not be retired',
    );
    expect(find.byKey(mic), findsOneWidget, reason: 'a retry may work');
    expect(find.byIcon(Icons.stop), findsNothing);
    expect(
      subject.field.text,
      'Amen',
      reason: 'a start that failed is not a change to the field',
    );

    // A genuine second tap, rather than a word from the session that failed: what
    // is being checked is that a working microphone is left working and is no
    // longer described as having failed.
    await tapMic(tester);
    expect(subject.speech.isListening, isTrue);
    seam.emit('God is good');
    await tester.pump();

    expect(
      subject.field.text,
      'AmenGod is good',
      reason: 'the microphone still works, so a retry must reach the field',
    );
    expect(
      find.text(speechDidNotStartNotice),
      findsNothing,
      reason: 'the attempt worked, so it must stop being called a failed one',
    );
  });

  testWidgets('a start the platform refuses outright says so too', (
    tester,
  ) async {
    await pumpField(tester, recognizer: _FakeRecognizer(failsToListen: true));

    await tapMic(tester);

    expect(find.text(speechDidNotStartNotice), findsOneWidget);
    expect(find.text(speechUnavailableNotice), findsNothing);
    expect(find.byKey(mic), findsOneWidget);
  });

  testWidgets('a session that ended with words in the field says nothing', (
    tester,
  ) async {
    final seam = _FakeRecognizer();
    final subject = await pumpField(tester, recognizer: seam);

    await tapMic(tester);
    seam.emit('the morning');
    seam.failSession();
    await tester.pump();

    expect(subject.field.text, 'the morning');
    expect(
      find.text(speechDidNotStartNotice),
      findsNothing,
      reason: 'a pause after a word is an ordinary ending',
    );
    expect(find.byKey(mic), findsOneWidget);
  });

  testWidgets('a second tap refused while a session is opening says nothing', (
    tester,
  ) async {
    // Nothing was attempted the second time, so nothing failed. Called a
    // failure it would tell a person the microphone is broken for doing the one
    // thing that might have helped.
    final gate = Completer<void>();
    final seam = _FakeRecognizer(gate: gate);
    await pumpField(tester, recognizer: seam);

    await tester.tap(find.byKey(mic));
    await tester.pump();
    await tester.tap(find.byKey(mic));
    await tester.pump();

    gate.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text(speechDidNotStartNotice), findsNothing);
    expect(find.byIcon(Icons.stop), findsOneWidget, reason: 'it did begin');
  });

  group('a screen with two fields', () {
    // Sixteen surfaces use this widget and three hold more than one field. Said
    // by both it is the same sentence twice on one screen, which is noise on a
    // form that has already said it.
    Future<(SpeechCaptureController, List<TextEditingController>)> pumpPair(
      WidgetTester tester, {
      required SpeechRecognizer recognizer,
    }) async {
      final speech = SpeechCaptureController(recognizer: recognizer);
      addTearDown(speech.dispose);
      final fields = [TextEditingController(), TextEditingController()];
      addTearDown(fields.first.dispose);
      addTearDown(fields.last.dispose);
      await tester.pumpWidget(
        host(
          speech,
          Column(
            children: [
              SayableField(controller: fields.first, labelText: 'Reflection'),
              SayableField(
                controller: fields.last,
                labelText: 'One thing to do',
                showUnavailableNotice: false,
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      return (speech, fields);
    }

    testWidgets('says the unavailable notice once', (tester) async {
      await pumpPair(tester, recognizer: _FakeRecognizer(available: false));

      await tester.tap(find.byKey(mic).first);
      await tester.pump();

      expect(find.text(speechUnavailableNotice), findsOneWidget);
      expect(
        find.byKey(mic),
        findsNothing,
        reason: 'an opted-out field still loses the microphone',
      );
    });

    testWidgets('still offers a microphone on every field', (tester) async {
      await pumpPair(tester, recognizer: _FakeRecognizer());

      expect(find.byKey(mic), findsNWidgets(2));
      expect(find.text(speechUnavailableNotice), findsNothing);
    });

    testWidgets('tells only the field that was tried', (tester) async {
      // The notice belongs where the failure happened. Said by both fields it
      // would be the duplicate this whole opt-out exists to prevent, arriving
      // by the other route.
      final seam = _FakeRecognizer();
      await pumpPair(tester, recognizer: seam);

      await tester.tap(find.byKey(mic).last);
      await tester.pump();
      seam.failSession();
      await tester.pump();

      expect(find.text(speechDidNotStartNotice), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(speechDidNotStartNotice)).dy,
        greaterThan(tester.getTopLeft(find.byKey(mic).first).dy),
        reason: 'and it is under the field that was tried, not the first',
      );
    });
  });

  testWidgets('a validator runs and blocks saving', (tester) async {
    final seam = _FakeRecognizer();
    final speech = SpeechCaptureController(recognizer: seam);
    addTearDown(speech.dispose);
    final field = TextEditingController();
    addTearDown(field.dispose);
    final form = GlobalKey<FormState>();

    await tester.pumpWidget(
      host(
        speech,
        Form(
          key: form,
          child: SayableField(
            controller: field,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Add a short title.'
                : null,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TextFormField), findsOneWidget);
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Add a short title.'), findsOneWidget);

    await tapMic(tester);
    seam.emit('A quiet afternoon');

    expect(
      form.currentState!.validate(),
      isTrue,
      reason: 'a dictated sentence is held to the same rule as a typed one',
    );
    await tester.pump();
    expect(find.text('Add a short title.'), findsNothing);
  });

  testWidgets('a field with no validator is not a form field', (tester) async {
    await pumpField(tester, recognizer: _FakeRecognizer());

    expect(
      find.byType(TextFormField),
      findsNothing,
      reason: 'being a form field for nothing makes every validate() costly',
    );
  });

  testWidgets("the field's own properties are passed through", (tester) async {
    await pumpField(
      tester,
      recognizer: _FakeRecognizer(),
      labelText: 'Calling',
      hintText: 'In your own words',
      minLines: 5,
      maxLines: 12,
      maxLength: 1500,
      textCapitalization: TextCapitalization.sentences,
      autofocus: true,
      decoration: const InputDecoration(border: OutlineInputBorder()),
    );

    final field = fieldUnderTest(tester);

    expect(field.minLines, 5);
    expect(field.maxLines, 12);
    expect(field.maxLength, 1500);
    expect(field.textCapitalization, TextCapitalization.sentences);
    expect(field.autofocus, isTrue);
    expect(field.decoration?.labelText, 'Calling');
    expect(field.decoration?.hintText, 'In your own words');
    expect(
      field.decoration?.border,
      isA<OutlineInputBorder>(),
      reason: 'a caller that set a border of its own still has it',
    );
    expect(
      find.byKey(mic),
      findsOneWidget,
      reason: 'the caller decoration is the base, not a replacement',
    );
  });

  testWidgets('a field that cannot be edited loses the mic with it', (
    tester,
  ) async {
    final seam = _FakeRecognizer();
    final subject = await pumpField(tester, recognizer: seam, enabled: false);

    expect(fieldUnderTest(tester).enabled, isFalse);
    expect(tester.widget<IconButton>(find.byKey(mic)).onPressed, isNull);

    await tester.tap(find.byKey(mic));
    await tester.pump();

    expect(
      subject.speech.isListening,
      isFalse,
      reason: 'words appearing in a locked field would be nobody\'s to correct',
    );
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
    await subject.speech.stop();
    await speech.cancel();
    await tester.pump(const Duration(seconds: 3));
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
  _FakeRecognizer({
    this.available = true,
    this.failsToListen = false,
    this.gate,
  });

  final bool available;

  /// A session that cannot start, which the seam answers by throwing rather
  /// than by refusing.
  final bool failsToListen;

  /// Held open so a test can act while availability is still resolving.
  Completer<void>? gate;

  int stopCalls = 0;
  int initializeCalls = 0;
  void Function(String words)? _onWords;
  VoidCallback? _onUnavailable;
  VoidCallback? _onError;

  @override
  Future<bool> initialize({
    void Function(bool listening)? onListeningChanged,
    VoidCallback? onUnavailable,
    VoidCallback? onError,
  }) async {
    initializeCalls++;
    _onUnavailable = onUnavailable;
    _onError = onError;
    await gate?.future;
    if (!available) {
      onUnavailable?.call();
      return false;
    }
    return true;
  }

  @override
  Future<void> listen({required void Function(String words) onWords}) async {
    if (failsToListen) throw Exception('no session');
    _onWords = onWords;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  void emit(String words) => _onWords?.call(words);

  /// The seam reporting, part-way through a session, that it cannot continue.
  void reportUnavailable() => _onUnavailable?.call();

  /// The platform failing a session that never heard anything, which is what a
  /// locale with no offline language pack looks like from here.
  void failSession() => _onError?.call();
}
