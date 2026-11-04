# Voice capture consistency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Offer dictation at every field where a person is expected to say something in their own words, through one shared widget, with recognised text merging into the field rather than replacing it.

**Architecture:** A `SpeechRecognizer` interface isolates the `speech_to_text` plugin so it can be faked in tests. A `SpeechCaptureController` owns availability, listening state, and the degradation notice, and is the only place that requests on-device recognition. A `SayableField` widget wraps a `TextField` with a mic affordance in its `suffixIcon`; a pure `DictationEdit` value handles merging prefix, recognised words, and suffix. Recording is untouched and stays with Memory/Encounters.

**Tech Stack:** Flutter, Riverpod, `speech_to_text: 7.4.0`, `flutter_test`. Existing app root is `apps/soulbuddy/`; all paths below are relative to it.

**Design source:** `docs/superpowers/specs/2026-10-06-voice-capture-consistency-design.md`

---

## Scope check

One subsystem. The spec's decisions are interdependent — on-device-only enforcement, text reconciliation, and the emphasis rule all belong to the same capture affordance. Nothing here should be split.

Recording audio is explicitly out of scope. No task adds an audio store, changes `AudioCapturePanel`, or alters how Memory/Encounters record.

## Field counts, measured

Measured on this branch. The guard test in Task 10 encodes these, so drift is caught.

| File | `TextField(` before | In scope | Stays bare |
|---|---|---|---|
| `lib/features/daily_formation/presentation/daily_formation_card.dart` | 2 | 2 | 0 |
| `lib/features/prayers/presentation/prayer_create_screen.dart` | 1 | 1 | 0 |
| `lib/features/onboarding/presentation/first_prayer_detail_page.dart` | 1 | 1 | 0 |
| `lib/features/goals/presentation/first_goal_screen.dart` | 1 | 1 | 0 |
| `lib/features/goals/presentation/goal_detail_screen.dart` | 3 | 2 | 1 (Goal label) |
| `lib/features/goals/presentation/goal_meditation_screen.dart` | 1 | 1 | 0 |
| `lib/features/goals/presentation/daily_practice_sheet.dart` | 1 | 1 | 0 |
| `lib/features/remember/presentation/daily_remembrance_screen.dart` | 1 | 1 | 0 |
| `lib/features/remember/presentation/memory_detail_screen.dart` | 1 | 1 | 0 |
| `lib/features/onboarding/presentation/first_remembrance_page.dart` | 1 | 1 | 0 |
| `lib/features/record/presentation/encounter_form.dart` | 3 | 2 | 1 (Date) |
| `lib/features/commitments/presentation/commitment_journey_screen.dart` | 2 | 1 | 1 |
| `lib/features/onboarding/presentation/first_prayer_speech_page.dart` | 1 | 1 | 0 |
| `lib/features/guards/presentation/guard_configuration_sheet.dart` | 1 | 1 | 0 |
| `lib/features/goals/presentation/today_prayer_goal_migration_card.dart` | 1 | 1 | 0 |
| `lib/features/circles/presentation/create_circle_sheet.dart` | 3 | 1 | 2 (name, group link) |

`first_goal_screen.dart` declares **one** field component but passes it six different `hintText` values (lines 152, 174, 212, 232, 246, 297: today's action, door to close, action prompt, a few words, prayer title, prayer body). Converting that single component converts all six. Do not rewrite it as six fields.

`goal_meditation_screen.dart` has exactly one field, keyed `goal-meditation-notebook` (line 722). Day and Minutes are steppers, not fields.

---

### Task 1: Isolate the recogniser behind an interface

**Files:**
- Create: `lib/core/speech/speech_recognizer.dart`
- Create: `lib/core/speech/plugin_speech_recognizer.dart`
- Test: `test/core/speech/plugin_speech_recognizer_test.dart`

Why first: every later task needs to fake speech. The plugin's concrete class cannot be faked, so this boundary is what makes Tasks 2–4 testable without a device.

- [ ] **Step 1: Write the failing test**

Create `test/core/speech/plugin_speech_recognizer_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/speech/plugin_speech_recognizer.dart';
import 'package:soulbuddy/core/speech/speech_recognizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
  final calls = <MethodCall>[];
  Object? initializeResult;

  setUp(() {
    calls.clear();
    initializeResult = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'initialize') return initializeResult;
      if (call.method == 'listen') return ' listening';
      if (call.method == 'listenForResult') return ' listening';
      return null;
    });
  });

  test('recognises only on this device', () async {
    final recognizer = PluginSpeechRecognizer();

    expect(await recognizer.initialize(), isTrue);
    await recognizer.listen(onWords: (_, _) {});

    final listen = calls.firstWhere((c) => c.method.startsWith('listen'));
    final options = listen.arguments['listenOptions'] as Map;
    expect(options['onDevice'], isTrue);
  });

  test('reports unavailable when initialisation fails', () async {
    initializeResult = false;
    final recognizer = PluginSpeechRecognizer();

    expect(await recognizer.initialize(), isFalse);
  });

  test('never starts browser speech recognition', () {
    // kIsWeb must short-circuit before the plugin is touched.
    final source = File(
      'lib/core/speech/plugin_speech_recognizer.dart',
    ).readAsStringSync();
    expect(source, contains('if (kIsWeb)'));
  });
}
```

Add `import 'dart:io';` to the top of that file, above the other imports.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/speech/plugin_speech_recognizer_test.dart`
Expected: FAIL — `plugin_speech_recognizer.dart` does not exist.

- [ ] **Step 3: Create the interface**

Create `lib/core/speech/speech_recognizer.dart`:

```dart
/// Recognition of speech into words.
///
/// An interface so the plugin can be faked. [initialize] must never accept a
/// network recogniser: spoken words stay on this device.
abstract interface class SpeechRecognizer {
  bool get isListening;

  Future<bool> initialize({
    void Function(bool listening)? onListeningChanged,
    void Function(String message)? onUnavailable,
  });

  Future<void> listen({required void Function(String words) onWords});

  Future<void> stop();

  Future<void> cancel();
}
```

- [ ] **Step 4: Create the plugin adapter**

Create `lib/core/speech/plugin_speech_recognizer.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'speech_recognizer.dart';

/// Adapts the `speech_to_text` plugin to [SpeechRecognizer].
///
/// The single place that asks for on-device recognition. `onDevice: true` is
/// not configurable, so no caller can widen it.
class PluginSpeechRecognizer implements SpeechRecognizer {
  PluginSpeechRecognizer({SpeechToText? speech})
      : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> initialize({
    void Function(bool listening)? onListeningChanged,
    void Function(String message)? onUnavailable,
  }) async {
    // Browser speech recognition sends audio off the device and is not used.
    if (kIsWeb) {
      onUnavailable?.call('Speak is unavailable. You can write instead.');
      return false;
    }
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'listening' || status == 'done') {
            onListeningChanged?.call(status == 'listening');
          }
        },
        onError: (_) => onUnavailable?.call(
          'Speak is unavailable. You can write instead.',
        ),
      );
      if (!available) {
        onUnavailable?.call('Speak is unavailable. You can write instead.');
      }
      return available;
    } on Object {
      onUnavailable?.call('Speak is unavailable. You can write instead.');
      return false;
    }
  }

  @override
  Future<void> listen({required void Function(String words) onWords}) async {
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.recognizedWords.isNotEmpty) onWords(result.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 5),
        onDevice: true,
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/core/speech/plugin_speech_recognizer_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/core/speech test/core/speech
git commit -m "feat: isolate speech recognition behind an interface

The plugin's concrete class cannot be faked, so dictation could not be
tested without a device. The adapter fixes onDevice: true so no caller
can widen it, and short-circuits on web where recognition leaves the
device."
```

---

### Task 2: Own availability and listening state

**Files:**
- Create: `lib/core/speech/speech_capture_controller.dart`
- Test: `test/core/speech/speech_capture_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/core/speech/speech_capture_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/speech/speech_capture_controller.dart';
import 'package:soulbuddy/core/speech/speech_recognizer.dart';

void main() {
  test('reports unavailable once, not per tap', () async {
    final recognizer = _FakeRecognizer(available: false);
    final controller = SpeechCaptureController(recognizer: recognizer);

    expect(await controller.ensureAvailable(), isFalse);
    expect(await controller.ensureAvailable(), isFalse);
    expect(recognizer.initializeCalls, 1);
    expect(controller.notice, 'Speak is unavailable. You can write instead.');
  });

  test('stays available without a notice', () async {
    final controller = SpeechCaptureController(
      recognizer: _FakeRecognizer(available: true),
    );

    expect(await controller.ensureAvailable(), isTrue);
    expect(controller.notice, isNull);
  });

  test('reports listening while words arrive', () async {
    final recognizer = _FakeRecognizer(available: true);
    final controller = SpeechCaptureController(recognizer: recognizer);
    await controller.ensureAvailable();

    final seen = <String>[];
    unawaited(controller.listen(onWords: seen.add));

    expect(controller.isListening, isTrue);
    recognizer.emit('first words');
    expect(seen, ['first words']);
  });

  test('stops and reports no longer listening', () async {
    final recognizer = _FakeRecognizer(available: true);
    final controller = SpeechCaptureController(recognizer: recognizer);
    await controller.ensureAvailable();
    unawaited(controller.listen(onWords: (_) {}));

    await controller.stop();

    expect(controller.isListening, isFalse);
    expect(recognizer.stopCalls, 1);
  });
}

class _FakeRecognizer implements SpeechRecognizer {
  _FakeRecognizer({required this.available});

  final bool available;
  var initializeCalls = 0;
  var stopCalls = 0;
  var _listening = false;
  void Function(String)? _onWords;

  @override
  bool get isListening => _listening;

  void emit(String words) => _onWords?.call(words);

  @override
  Future<bool> initialize({
    void Function(bool listening)? onListeningChanged,
    void Function(String message)? onUnavailable,
  }) async {
    initializeCalls++;
    if (!available) {
      onUnavailable?.call('Speak is unavailable. You can write instead.');
    }
    return available;
  }

  @override
  Future<void> listen({required void Function(String words) onWords}) async {
    _listening = true;
    _onWords = onWords;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _listening = false;
  }

  @override
  Future<void> cancel() async => _listening = false;
}
```

Add `import 'dart:async';` at the top of that file.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/speech/speech_capture_controller_test.dart`
Expected: FAIL — `speech_capture_controller.dart` does not exist.

- [ ] **Step 3: Write the controller**

Create `lib/core/speech/speech_capture_controller.dart`:

```dart
import 'package:flutter/foundation.dart';

import 'plugin_speech_recognizer.dart';
import 'speech_recognizer.dart';

/// Availability and listening state for dictation.
///
/// Availability is resolved once. Repeated taps on an unavailable field must
/// not re-prompt or re-notice.
class SpeechCaptureController extends ChangeNotifier {
  SpeechCaptureController({SpeechRecognizer? recognizer})
      : _recognizer = recognizer ?? PluginSpeechRecognizer();

  final SpeechRecognizer _recognizer;

  bool? _available;
  bool _listening = false;
  String? _notice;

  bool get isAvailable => _available ?? false;
  bool get isListening => _listening;
  String? get notice => _notice;

  Future<bool> ensureAvailable() async {
    final known = _available;
    if (known != null) return known;

    final available = await _recognizer.initialize(
      onListeningChanged: (listening) {
        if (_listening == listening) return;
        _listening = listening;
        notifyListeners();
      },
      onUnavailable: (message) {
        if (_notice == message) return;
        _notice = message;
        notifyListeners();
      },
    );
    _available = available;
    if (!available) {
      _notice ??= 'Speak is unavailable. You can write instead.';
    }
    notifyListeners();
    return available;
  }

  /// Starts dictation. Returns false when speech is unavailable, leaving the
  /// caller's field untouched and editable.
  Future<bool> listen({required void Function(String words) onWords}) async {
    if (!await ensureAvailable()) return false;
    _notice = null;
    _listening = true;
    notifyListeners();
    unawaited(_recognizer.listen(onWords: onWords));
    return true;
  }

  Future<void> stop() async {
    await _recognizer.stop();
    _listening = false;
    notifyListeners();
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/speech/speech_capture_controller_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/speech test/core/speech
git commit -m "feat: resolve speech availability once

Repeated taps on an unavailable field must not re-prompt or re-notice,
so availability is resolved once and cached."
```

---

### Task 3: Merge dictated words into existing text

**Files:**
- Create: `lib/core/speech/dictation_edit.dart`
- Test: `test/core/speech/dictation_edit_test.dart`

Why: this is the defect in both existing call sites. One replaces the whole field; the other drops the suffix, inserts a space, and truncates by rune mid-word. Pure value type so it is tested without a widget.

- [ ] **Step 1: Write the failing test**

Create `test/core/speech/dictation_edit_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/speech/dictation_edit.dart';

void main() {
  test('keeps text typed before dictation started', () {
    final edit = DictationEdit.begin('I am grateful', caret: 12);

    expect(edit.apply(' for today'), 'I am grateful for today');
  });

  test('keeps text after the caret', () {
    final edit = DictationEdit.begin('beforeafter', caret: 6);

    expect(edit.apply('middle'), 'beforemiddleafter');
  });

  test('inserts no space the recogniser did not say', () {
    final edit = DictationEdit.begin('', caret: 0);

    expect(edit.apply('Amen.'), 'Amen.');
    expect(DictationEdit.begin('', caret: 0).apply('one two'), 'one two');
  });

  test('replaces partial results rather than appending them', () {
    final edit = DictationEdit.begin('', caret: 0);

    expect(edit.apply('I pr'), 'I pr');
    expect(edit.apply('I pray'), 'I pray');
  });

  test('starts again from the caret on a second session', () {
    final text = 'Grace';
    final first = DictationEdit.begin(text, caret: 5)..apply(' and peace');
    final second = DictationEdit.begin(
      first.value,
      caret: first.value.length,
    )..apply(' Amen');

    expect(second.value, 'Grace and peace Amen');
  });

  test('truncates on a rune boundary without splitting a character', () {
    final edit = DictationEdit.begin('', caret: 0, maxLength: 3);

    final value = edit.apply('naïve prayer');

    expect(value.runes.length, lessThanOrEqualTo(3));
    expect(value, 'naï');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/speech/dictation_edit_test.dart`
Expected: FAIL — `dictation_edit.dart` does not exist.

- [ ] **Step 3: Write the value type**

Create `lib/core/speech/dictation_edit.dart`:

```dart
/// A dictation in progress against a field's existing text.
///
/// `SpeechRecognitionResult.recognizedWords` is the whole session, not a
/// delta, so each callback replaces the previous words rather than appending.
/// The text around the caret is captured once and restored every time, which
/// is what makes dictating into a pre-filled or mid-sentence field safe.
class DictationEdit {
  DictationEdit._({required this._prefix, required this._suffix, this.maxLength});

  factory DictationEdit.begin(
    String text,
    int caret, {
    int? maxLength,
  }) {
    final offset = caret.clamp(0, text.length);
    return DictationEdit._(
      _prefix: text.substring(0, offset),
      _suffix: text.substring(offset),
      maxLength: maxLength,
    );
  }

  final String _prefix;
  final String _suffix;
  final int? maxLength;

  String get value => _value;
  String _value = '';

  /// Replaces the dictated words and returns the whole field text.
  String apply(String words) {
    var merged = '$_prefix$words$_suffix';
    final limit = maxLength;
    if (limit != null && merged.runes.length > limit) {
      merged = String.fromCharCodes(merged.runes.take(limit));
    }
    _value = merged;
    return merged;
  }

  /// True when the limit stopped the recognised text from fitting whole.
  bool get truncated => maxLength != null && _value.runes.length == maxLength!;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/speech/dictation_edit_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/speech test/core/speech
git commit -m "feat: merge dictated words into existing field text

Recognised words are the whole session, not a delta, so each callback
replaces the previous words. Text either side of the caret is captured
once and restored, so dictating into a pre-filled field keeps what was
already typed. No separator is inserted, because the recogniser's own
words carry their spacing."
```

---

### Task 4: The field with a mic

**Files:**
- Create: `lib/core/speech/sayable_field.dart`
- Test: `test/core/speech/sayable_field_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/core/speech/sayable_field_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/speech/sayable_field.dart';
import 'package:soulbuddy/core/speech/speech_recognizer.dart';

void main() {
  Future<void> pumpField(
    WidgetTester tester, {
    required SpeechRecognizer recognizer,
    TextEditingController? controller,
    SayableEmphasis emphasis = SayableEmphasis.compact,
    VoidCallback? onTruncated,
  }) async {
    final text = controller ?? TextEditingController();
    addTearDown(text.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [speechRecognizerProvider.overrideWithValue(recognizer)],
        child: MaterialApp(
          home: Scaffold(
            body: SayableField(
              controller: text,
              labelText: 'Reflection',
              recognizer: recognizer,
              emphasis: emphasis,
              onTruncated: onTruncated,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('writes recognised words into the field', (tester) async {
    final recognizer = _FakeRecognizer(available: true);
    final text = TextEditingController();
    await pumpField(tester, recognizer: recognizer, controller: text);

    await tester.tap(find.byKey(const Key('sayable-field-mic')));
    await tester.pump();
    recognizer.emit('Amen');
    await tester.pump();

    expect(text.text, 'Amen');
  });

  testWidgets('keeps text already in the field', (tester) async {
    final recognizer = _FakeRecognizer(available: true);
    final text = TextEditingController(text: 'Grace');
    await pumpField(tester, recognizer: recognizer, controller: text);
    text.selection = const TextSelection.collapsed(offset: 5);

    await tester.tap(find.byKey(const Key('sayable-field-mic')));
    await tester.pump();
    recognizer.emit(' and peace');
    await tester.pump();

    expect(text.text, 'Grace and peace');
  });

  testWidgets('offers stop while listening', (tester) async {
    final recognizer = _FakeRecognizer(available: true);
    await pumpField(tester, recognizer: recognizer);

    await tester.tap(find.byKey(const Key('sayable-field-mic')));
    await tester.pump();

    expect(find.byKey(const Key('sayable-field-mic')), findsOneWidget);
    expect(recognizer.stopCalls, 0);
    await tester.tap(find.byKey(const Key('sayable-field-mic')));
    await tester.pump();
    expect(recognizer.stopCalls, 1);
  });

  testWidgets('stays editable and explains when speech is unavailable', (
    tester,
  ) async {
    final recognizer = _FakeRecognizer(available: false);
    final text = TextEditingController();
    await pumpField(tester, recognizer: recognizer, controller: text);

    expect(find.text('Speak is unavailable. You can write instead.'),
        findsOneWidget);
    expect(find.byKey(const Key('sayable-field-mic')), findsNothing);

    await tester.enterText(find.byType(TextField), 'typed instead');
    expect(text.text, 'typed instead');
  });

  testWidgets('prominent emphasis offers a labelled affordance', (
    tester,
  ) async {
    await pumpField(
      tester,
      recognizer: _FakeRecognizer(available: true),
      emphasis: SayableEmphasis.prominent,
    );

    expect(find.text('Speak'), findsOneWidget);
    expect(find.byKey(const Key('sayable-field-mic')), findsOneWidget);
  });
}

class _FakeRecognizer implements SpeechRecognizer {
  _FakeRecognizer({required this.available});

  final bool available;
  var stopCalls = 0;
  var _listening = false;
  void Function(String)? _onWords;

  @override
  bool get isListening => _listening;

  void emit(String words) => _onWords?.call(words);

  @override
  Future<bool> initialize({
    void Function(bool listening)? onListeningChanged,
    void Function(String message)? onUnavailable,
  }) async {
    if (!available) {
      onUnavailable?.call('Speak is unavailable. You can write instead.');
    }
    return available;
  }

  @override
  Future<void> listen({required void Function(String words) onWords}) async {
    _listening = true;
    _onWords = onWords;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _listening = false;
  }

  @override
  Future<void> cancel() async => _listening = false;
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/speech/sayable_field_test.dart`
Expected: FAIL — `sayable_field.dart` does not exist.

- [ ] **Step 3: Write the field**

Create `lib/core/speech/sayable_field.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dictation_edit.dart';
import 'plugin_speech_recognizer.dart';
import 'speech_capture_controller.dart';
import 'speech_recognizer.dart';

/// How loudly the affordance presents itself.
enum SayableEmphasis {
  /// A mic in the field's suffix. Every in-scope surface but the first.
  compact,

  /// A labelled action under the field. The first say-something surface met.
  prominent,
}

/// Overridable recogniser, so tests and previews inject a fake.
final speechRecognizerProvider = Provider<SpeechRecognizer>(
  (ref) => PluginSpeechRecognizer(),
);

/// A text field that also accepts speech.
///
/// Dictation only ever adds to the field. Typing stays available at all times,
/// and when speech is unavailable the field is unchanged and still editable.
class SayableField extends ConsumerStatefulWidget {
  const SayableField({
    required this.controller,
    this.labelText,
    this.hintText,
    this.maxLines = 2,
    this.textInputAction,
    this.emphasis = SayableEmphasis.compact,
    this.maxLength,
    this.onTruncated,
    super.key,
  });

  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final int maxLines;
  final TextInputAction? textInputAction;
  final SayableEmphasis emphasis;
  final int? maxLength;

  /// Called when the limit stopped the recognised text from fitting whole, so
  /// a person is never left believing a sentence was saved in full.
  final VoidCallback? onTruncated;

  @override
  ConsumerState<SayableField> createState() => _SayableFieldState();
}

class _SayableFieldState extends ConsumerState<SayableField> {
  SpeechCaptureController? _controller;
  DictationEdit? _edit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final controller = SpeechCaptureController(
      recognizer: ref.read(speechRecognizerProvider),
    )..addListener(_onChanged);
    _controller = controller;
    unawaited(controller.ensureAvailable());
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onChanged);
      unawaited(controller.stop());
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _toggle() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.isListening) {
      await controller.stop();
      _edit = null;
      return;
    }
    final selection = widget.controller.selection;
    final caret = selection.isValid
        ? selection.baseOffset
        : widget.controller.text.length;
    final edit = DictationEdit.begin(
      widget.controller.text,
      caret,
      maxLength: widget.maxLength,
    );
    _edit = edit;
    await controller.listen(
      onWords: (words) {
        if (!mounted || _edit == null) return;
        final merged = edit.apply(words);
        widget.controller.value = TextEditingValue(
          text: merged,
          selection: TextSelection.collapsed(
            offset: edit.prefixLength + words.runes.length,
          ),
        );
        if (edit.truncated) widget.onTruncated?.call();
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final listening = controller?.isListening ?? false;
    final unavailable = controller?.notice != null;

    final field = TextField(
      controller: widget.controller,
      maxLines: widget.maxLines,
      textInputAction: widget.textInputAction,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        filled: listening,
        fillColor: listening
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : null,
        suffixIcon: unavailable
            ? null
            : IconButton(
                key: const Key('sayable-field-mic'),
                onPressed: _toggle,
                icon: Icon(listening ? Icons.stop : Icons.mic_none),
                tooltip: listening ? 'Stop dictation' : 'Speak',
              ),
      ),
    );

    final children = <Widget>[field];

    if (widget.emphasis == SayableEmphasis.prominent) {
      children.add(
        const SizedBox(height: 8),
        TextButton.icon(
          key: const Key('sayable-field-speak'),
          onPressed: unavailable ? null : _toggle,
          icon: Icon(listening ? Icons.stop : Icons.mic_none),
          label: Text(listening ? 'Stop dictation' : 'Speak'),
        ),
      );
    }

    if (unavailable) {
      children.add(
        const SizedBox(height: 8),
        Text(
          controller!.notice!,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
```

The class declaration must also change to `ConsumerStatefulWidget`, and
`dictation_edit.dart` needs the caret offset exposed rather than read from
outside its own library. Add this getter beside `value`:

```dart
  /// Offset in [value] where dictated words begin.
  int get prefixLength => _prefix.length;
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/speech/sayable_field_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Run the whole core suite**

Run: `flutter test test/core/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/speech test/core/speech
git commit -m "feat: add SayableField with a mic affordance

Typing stays available at all times and speech only ever adds to the
field. When speech is unavailable the field is unchanged and still
editable, and the notice is the string already in the app."
```

---

### Task 5: Verify microphone permission and correct the consent copy

**Files:**
- Modify: `ios/Runner/Info.plist`
- Modify: `test/core/security/android_manifest_test.dart:30`
- Modify: `docs/architecture/local-first.md` (add a note under the audio clause)

This task exists because the design flagged microphone permission as unverified, and because the existing iOS usage description understates what the app now does.

- [ ] **Step 1: Run the app on a device and confirm dictation works**

```bash
flutter build apk --debug --dart-define=SOULBUDDY_API_URL=http://127.0.0.1:8099
adb install -r -d build/app/outputs/flutter-apk/app-debug.apk
```

Open any `SayableField`, tap the mic, speak, and confirm words appear.

If the recogniser reports insufficient permission, request it before
`_speech.initialize`, reusing the `record` plugin's existing path rather than
adding a dependency. There is no gateway provider: `memory_audio_providers.dart`
builds the recorder inside `audioCaptureControllerProvider` via
`createRecordPluginAudioRecorder`. Add a `Future<bool> Function()?` constructor
parameter to `PluginSpeechRecognizer` so it stays free of `ref`, and supply the
call from the provider:

```dart
final speechRecognizerProvider = Provider<SpeechRecognizer>(
  (ref) => PluginSpeechRecognizer(
    requestMicrophone: () async {
      final assetStore = await ref.read(audioAssetStoreProvider.future);
      return createRecordPluginAudioRecorder(assetStore).requestPermission();
    },
  ),
);
```

and at the top of `PluginSpeechRecognizer.initialize`:

```dart
final granted = await _requestMicrophone?.call() ?? true;
if (!granted) {
  onUnavailable?.call('Speak is unavailable. You can write instead.');
  return false;
}
```

Record which branch was taken in the commit message.

- [ ] **Step 2: Update the iOS usage description**

In `ios/Runner/Info.plist`, replace the existing `NSMicrophoneUsageDescription`
string value with:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>SoulBuddy uses the microphone only when you choose to speak, and never sends your voice anywhere.</string>
```

Update `NSSpeechRecognitionUsageDescription` to the same sentence. The previous
text named only prayer details and private memories, which no longer describes
where speech is offered.

- [ ] **Step 3: Update the manifest guard test**

In `test/core/security/android_manifest_test.dart`, replace the assertion on
lines 27–32 with:

```dart
    expect(
      infoPlist,
      contains(
        '<string>SoulBuddy uses the microphone only when you choose to speak, and never sends your voice anywhere.</string>',
      ),
    );
```

- [ ] **Step 4: Run the security tests**

Run: `flutter test test/core/security/`
Expected: PASS.

- [ ] **Step 5: Note the boundary in the architecture doc**

In `docs/architecture/local-first.md`, extend the clause containing
`User-recorded memory audio remains device-local` with one sentence:

```markdown
Dictation is on-device only. When no on-device recogniser exists the field stays
editable and speech is unavailable; the app never falls back to a network
recogniser, because that would send spoken words off the device.
```

- [ ] **Step 6: Commit**

```bash
git add ios/Runner/Info.plist test/core/security/android_manifest_test.dart docs/architecture/local-first.md
git commit -m "fix: state accurately where speech is offered and where it goes

The iOS usage description named only prayer details and private memories,
which no longer describes where speech is offered. It also now says the
voice is never sent anywhere, which is the guarantee the code enforces."
```

---

### Task 6: Convert the two surfaces that already have speech, and start the guard

**Files:**
- Modify: `lib/features/commitments/presentation/commitment_journey_screen.dart`
- Modify: `lib/features/onboarding/presentation/first_prayer_speech_page.dart`
- Create: `test/core/speech/sayable_surfaces_guard_test.dart`
- Test: `test/features/commitments/commitment_journey_integration_test.dart`

Done first on purpose: these are the only callers with divergent behaviour, so
converting them proves the shared component against real code.

The guard test is created **here**, not at the end, so the sweep cannot
half-finish. Each later conversion adds its own rows to the same table.

- [ ] **Step 1: Replace the inline speech block in the commitment screen**

In `commitment_journey_screen.dart`, remove the `_speech` field, the
`SpeechToText` import, the `_initialize`/`_toggle` speech helpers, and the
mic `TextButton` at line 447. Replace the reflection `TextField` with:

```dart
SayableField(
  controller: _calling,
  labelText: label,
  emphasis: SayableEmphasis.compact,
  maxLength: CommitmentTextLimits.calling,
  onTruncated: () => setState(() => _error = 'Your note reached its limit.'),
)
```

The `String.fromCharCodes(take(...))` truncation moves into `DictationEdit`, so
the field is no longer cut mid-word silently, and `onTruncated` tells the person.

- [ ] **Step 2: Replace the onboarding page with a prominent field**

In `first_prayer_speech_page.dart`, remove the `SpeechToText` instance, the
`firstPrayerSpeechProvider`, the `_initialize`/`_toggle` helpers, and the
`kIsWeb` guard now owned by `PluginSpeechRecognizer`. Keep the existing
`_words` controller and render:

```dart
SayableField(
  controller: _words,
  hintText: widget.hintText,
  emphasis: SayableEmphasis.prominent,
  maxLines: 4,
)
```

Keep the `Write your prayer in your own words.` lead-in text and the existing
keyboard-microphone behaviour untouched; the field remains a normal text field.

- [ ] **Step 3: Create the guard test with the first two rows**

Create `test/core/speech/sayable_surfaces_guard_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Counts occurrences of a constructor call in a source file.
int _calls(String path, String needle) {
  final source = File(path).readAsStringSync();
  var count = 0;
  var index = source.indexOf(needle);
  while (index != -1) {
    count++;
    index = source.indexOf(needle, index + needle.length);
  }
  return count;
}

/// Every converted say-something surface, with how many sayable and how many
/// bare text fields it should still hold. A bare count that grows means a
/// sentence field has lost its affordance.
const _expected = <String, (int sayable, int bare)>{
  'lib/features/commitments/presentation/commitment_journey_screen.dart': (1, 1),
  'lib/features/onboarding/presentation/first_prayer_speech_page.dart': (1, 0),
};

void main() {
  _expected.forEach((path, expected) {
    test('$path keeps ${expected.$1} sayable and ${expected.$2} bare fields', () {
      expect(
        _calls(path, 'SayableField('),
        expected.$1,
        reason: '$path should hold ${expected.$1} sayable fields',
      );
      expect(
        _calls(path, 'TextField('),
        expected.$2,
        reason: '$path should hold ${expected.$2} bare text fields',
      );
    });
  });
}
```

Later tasks append rows to `_expected`. Do not add a row before its surface is
converted, or the test fails for the wrong reason.

- [ ] **Step 4: Run the guard test**

Run: `flutter test test/core/speech/sayable_surfaces_guard_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Run the affected tests**

Run: `flutter test test/features/commitments/ test/core/security/`
Expected: PASS.

- [ ] **Step 6: Analyse**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/commitments/presentation/commitment_journey_screen.dart lib/features/onboarding/presentation/first_prayer_speech_page.dart test/core/speech/sayable_surfaces_guard_test.dart test/features/commitments
git commit -m "refactor: move both speech call sites onto SayableField

The two implementations corrupted text in opposite ways: one replaced the
whole field, the other dropped the suffix, inserted a space and truncated
by rune. Both now share one path. The onboarding page keeps its emphasis
but loses the separate Speak/Write screen.

The guard test starts here rather than at the end, so the remaining sweep
cannot half-finish unnoticed."
```

---

### Task 7: Convert the two motivating surfaces

**Files:**
- Modify: `lib/features/daily_formation/presentation/daily_formation_card.dart`
- Modify: `lib/features/record/presentation/encounter_form.dart`

- [ ] **Step 1: Convert the formation completion sheet**

In `_CompletionSheet.build` (line 482), replace both `TextField`s at lines 500
and 507 with:

```dart
SayableField(
  controller: _reflection,
  labelText: 'Reflection',
  textInputAction: TextInputAction.next,
),
const SizedBox(height: 8),
SayableField(controller: _action, labelText: widget.day.action),
```

Both fields stay inside the existing sheet and the sheet still returns
`({String reflection, String action})`, so `completeDailyFormation` needs no
change. The action field's label is `widget.day.action`, which is the day's
"Write the trigger + first escape …" prompt.

- [ ] **Step 2: Convert the encounter title and body, leaving the date alone**

In `encounter_form.dart`, replace the `Title` and body `TextField`s with
`SayableField`. Leave the `Date` field as a `TextField`. Do not change
`AudioCapturePanel` usage: recording and dictation must coexist in this sheet,
with neither disabling the other.

- [ ] **Step 3: Add both surfaces to the guard table**

In `test/core/speech/sayable_surfaces_guard_test.dart`, add these two rows to
`_expected`:

```dart
  'lib/features/daily_formation/presentation/daily_formation_card.dart': (2, 0),
  'lib/features/record/presentation/encounter_form.dart': (2, 1),
```

- [ ] **Step 4: Run the guard and encounter tests**

Run: `flutter test test/core/speech/sayable_surfaces_guard_test.dart test/features/record/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/daily_formation lib/features/record test/core/speech/sayable_surfaces_guard_test.dart
git commit -m "feat: accept speech in the formation reflection and trigger fields

This was the motivating case. The encounter sheet gains dictation beside
its existing recording; the date field is untouched."
```

---

### Task 8: Convert the single-field surfaces

**Files:**
- Modify: `lib/features/prayers/presentation/prayer_create_screen.dart`
- Modify: `lib/features/onboarding/presentation/first_prayer_detail_page.dart`
- Modify: `lib/features/goals/presentation/goal_meditation_screen.dart`
- Modify: `lib/features/goals/presentation/daily_practice_sheet.dart`
- Modify: `lib/features/remember/presentation/daily_remembrance_screen.dart`
- Modify: `lib/features/remember/presentation/memory_detail_screen.dart`
- Modify: `lib/features/onboarding/presentation/first_remembrance_page.dart`
- Modify: `lib/features/guards/presentation/guard_configuration_sheet.dart`
- Modify: `lib/features/goals/presentation/today_prayer_goal_migration_card.dart`

Each file has exactly one in-scope field, so each is one substitution. Keep each
field's existing `labelText`, `hintText`, `maxLines`, `key`, and controller.

- [ ] **Step 1: Convert all nine files**

For each file, swap the `TextField` for `SayableField` preserving its
properties. Where a field carries a `key`, keep it on `SayableField` so
existing tests that find fields by key keep working.

`goal_meditation_screen.dart` has one field, keyed
`goal-meditation-notebook` (line 722). Convert that one; Day and Minutes are
steppers and stay as they are.

- [ ] **Step 2: Add these nine surfaces to the guard table**

In `test/core/speech/sayable_surfaces_guard_test.dart`, add:

```dart
  'lib/features/prayers/presentation/prayer_create_screen.dart': (1, 0),
  'lib/features/onboarding/presentation/first_prayer_detail_page.dart': (1, 0),
  'lib/features/goals/presentation/goal_meditation_screen.dart': (1, 0),
  'lib/features/goals/presentation/daily_practice_sheet.dart': (1, 0),
  'lib/features/remember/presentation/daily_remembrance_screen.dart': (1, 0),
  'lib/features/remember/presentation/memory_detail_screen.dart': (1, 0),
  'lib/features/onboarding/presentation/first_remembrance_page.dart': (1, 0),
  'lib/features/guards/presentation/guard_configuration_sheet.dart': (1, 0),
  'lib/features/goals/presentation/today_prayer_goal_migration_card.dart': (1, 0),
```

- [ ] **Step 3: Run the affected tests**

Run: `flutter test test/core/speech/sayable_surfaces_guard_test.dart test/features/prayers test/features/remember test/features/guards test/features/goals test/features/onboarding`
Expected: PASS. If a test cannot find a field by key, the key moved off the
`TextField`; move it onto `SayableField` rather than editing the test's target.

- [ ] **Step 4: Analyse**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features test/core/speech/sayable_surfaces_guard_test.dart
git commit -m "feat: accept speech where a sentence is expected

Nine single-field surfaces converted, each keeping its own labels, hints,
keys and controllers."
```

---

### Task 9: Convert the mixed surfaces

**Files:**
- Modify: `lib/features/goals/presentation/first_goal_screen.dart`
- Modify: `lib/features/goals/presentation/goal_detail_screen.dart`
- Modify: `lib/features/circles/presentation/create_circle_sheet.dart`

These have fields that stay bare alongside fields that become sayable.

- [ ] **Step 1: Convert the shared goal field, which covers six labels**

`first_goal_screen.dart` declares one field component but passes it six
`hintText` values (lines 152, 174, 212, 232, 246, 297). Convert that single
component to `SayableField` and all six become sayable at once:

```dart
SayableField(
  controller: controller,
  hintText: widget.hintText,
  maxLines: widget.maxLines,
)
```

Use the component's real property names as they exist. Do not expand it into
six separate fields.

- [ ] **Step 2: Convert two of the three goal detail fields**

In `goal_detail_screen.dart`, convert `What is happening now` and
`Why this matters`. Leave the `Goal` field a bare `TextField`: there it labels
a list row, not a sentence.

- [ ] **Step 3: Convert Purpose only in the circle sheet**

In `create_circle_sheet.dart`, convert the `Purpose` field. Leave `Circle
name` bare — it is a slot, and speaking a name is worse than typing it — and
leave `Category`, `Visibility`, and the provider group link unchanged.

- [ ] **Step 4: Add these three surfaces to the guard table**

In `test/core/speech/sayable_surfaces_guard_test.dart`, add:

```dart
  'lib/features/goals/presentation/first_goal_screen.dart': (1, 0),
  'lib/features/goals/presentation/goal_detail_screen.dart': (2, 1),
  'lib/features/circles/presentation/create_circle_sheet.dart': (1, 2),
```

- [ ] **Step 5: Run the affected tests**

Run: `flutter test test/core/speech/sayable_surfaces_guard_test.dart test/features/goals test/features/circles`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/goals lib/features/circles test/core/speech/sayable_surfaces_guard_test.dart
git commit -m "feat: accept speech on sayable fields, leaving labels bare

Purpose invites a sentence; a circle name does not. Goal title is sayable
on onboarding and a label in the list, so it is converted in one place
and left bare in the other."
```

---

### Task 10: Close the guard and run everything

**Files:**
- Modify: `test/core/speech/sayable_surfaces_guard_test.dart`

The guard was created in Task 6 and grew with each conversion. This task adds
the last check and verifies the whole thing.

- [ ] **Step 1: Add the no-plumbing check**

Append to `test/core/speech/sayable_surfaces_guard_test.dart`, inside `main()`:

```dart
  test('no sayable surface still spells its own speech plumbing', () {
    for (final path in _expected.keys) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('SpeechToText') || source.contains('onDevice'),
        isFalse,
        reason: '$path must go through SayableField, not its own recogniser',
      );
    }
  });
```

- [ ] **Step 2: Confirm the table is complete**

Run: `flutter test test/core/speech/sayable_surfaces_guard_test.dart`
Expected: PASS, 16 tests — 15 surfaces plus the plumbing check.

If a count is off, fix the screen rather than the expectation, unless the
screen genuinely disagrees with the table at the top of this plan. In that case
update both tables and say why in the commit.

- [ ] **Step 3: Run the whole Flutter suite**

Run: `flutter test`
Expected: all pass. Pre-existing failures, verified earlier on `d6197ec` and not
caused by this work: 4 in
`test/features/settings/sound_touch_settings_test.dart`.

- [ ] **Step 4: Analyse and format**

```bash
flutter analyze
dart format --line-length 80 lib test
flutter analyze
```

Expected: `No issues found!` both times. Revert any unrelated file `dart format`
touches that this plan did not edit.

- [ ] **Step 5: Run the API suite**

Run: `cd services/api && php artisan test`
Expected: all pass except the pre-existing failure in
`tests/Feature/Companions/TelegramCompanionCadenceTest.php`.

- [ ] **Step 6: Verify on the device**

Install and open each converted surface. For one field, confirm: text already
in the field survives dictation, the mic becomes stop while listening, and
typing works with speech unavailable. For `encounter_form`, confirm recording
still works alongside dictation.

- [ ] **Step 7: Commit**

```bash
git add test/core/speech/sayable_surfaces_guard_test.dart
git commit -m "test: close the guard against a surface reimplementing speech

The consistency this work establishes is otherwise one refactor away from
being lost, since each surface is edited independently."
```

---

## Not in this plan

- Any change to `AudioCapturePanel`, or how Memory/Encounters record.
- Any audio store for surfaces outside Memory/Encounters.
- Any server-side handling of dictated text beyond the sync each surface
  already performs.
- Engagement instrumentation. Tracked separately: production has zero rows in
  `formation_activity_events` because no shipped build ever had
  `SOULBUDDY_API_URL` compiled in, and `FormationActivityClient._record` returns
  false silently when it is absent. The smallest fix is to make that state
  visible at startup and to ensure the build passes both dart-defines; it shares
  a root cause with the sync gate already fixed and belongs in that commit.