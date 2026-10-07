import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/app/app.dart';
import 'package:soulbuddy/features/onboarding/providers/onboarding_providers.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/core/speech/sayable_field.dart';
import 'package:soulbuddy/core/speech/speech_capture_controller.dart';
import 'package:soulbuddy/core/speech/speech_capture_providers.dart';
import 'package:soulbuddy/core/speech/speech_recognizer.dart';
import 'package:soulbuddy/features/record/presentation/record_screen.dart';
import 'package:soulbuddy/features/record/presentation/encounter_form.dart';
import 'package:soulbuddy/features/record/audio/application/audio_capture_controller.dart';
import 'package:soulbuddy/features/record/audio/application/audio_recorder.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';
import 'package:soulbuddy/features/record/providers/encounter_providers.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/record/domain/encounter_draft.dart';
import 'package:soulbuddy/features/remember/presentation/remember_screen.dart';
import 'package:soulbuddy/features/remember/presentation/memory_detail_screen.dart';

import '../../helpers/in_memory_encounter_repository.dart';
import '../../helpers/no_speech_recognizer.dart';

void main() {
  testWidgets('Record begins with equal Speak and Write paths', (tester) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const MaterialApp(home: Scaffold(body: RecordScreen())),
      ),
    );
    await _settle(tester);

    expect(find.text('Keep what you do not want to forget.'), findsOneWidget);
    expect(find.byKey(const Key('record-speak')), findsOneWidget);
    expect(find.byKey(const Key('record-write')), findsOneWidget);
    expect(find.text('Encounter'), findsNothing);

    await tester.tap(find.byKey(const Key('record-write')));
    await _settle(tester);
    expect(find.text('Encounter'), findsOneWidget);
    expect(find.textContaining('Coming'), findsNothing);
  });

  testWidgets(
    'Speak records, reviews, and saves without requiring typed body',
    (tester) async {
      final repository = InMemoryEncounterRepository();
      final recorder = _RecordFlowRecorder();
      final controller = AudioCaptureController(
        recorder: recorder,
        allocateTemporary: () async =>
            const TemporaryAudio(key: 'take', locator: '/private/take.m4a'),
      );
      addTearDown(() async {
        await controller.close();
        await repository.close();
      });
      Encounter? openedMemory;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            encounterRepositoryProvider.overrideWith((ref) async => repository),
            audioCaptureControllerProvider.overrideWith(
              (ref) async => controller,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RecordScreen(
                onMemorySaved: (memory) => openedMemory = memory,
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      await tester.tap(find.byKey(const Key('record-speak')));
      await _settle(tester);
      await tester.tap(find.text('Start recording'));
      await _settle(tester);
      await tester.tap(find.text('Stop'));
      await _settle(tester);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await _settle(tester);

      expect(find.text('What kind of memory is this?'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Promise'), findsOneWidget);
      final titleField = tester.widget<SayableField>(
        find.byKey(const Key('encounter-title')),
      );
      expect(titleField.controller.text, startsWith('Voice memory ·'));
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await _settle(tester);

      expect(repository.lastDraft!.audio, isNotNull);
      expect(repository.lastDraft!.body, isEmpty);
      expect(openedMemory?.id, isNotEmpty);
    },
  );

  testWidgets('failed voice save keeps the take and offers a retry', (
    tester,
  ) async {
    var attempts = 0;
    final audio = MemoryAudioDraft(
      temporaryKey: '/private/take.m4a',
      mimeType: 'audio/mp4',
      duration: const Duration(seconds: 2),
      waveform: const [0.2, 0.8],
    );
    await tester.pumpWidget(
      // The form's fields now carry dictation, and that controller comes from a
      // provider, so a bare form is no longer pumpable on its own.
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EncounterForm(
              initialTitle: 'Voice memory · 13 Aug',
              audio: audio,
              onCancel: () {},
              onSave: (_) async {
                attempts++;
                throw StateError('disk');
              },
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await _settle(tester);

    expect(attempts, 1);
    expect(
      find.text('The recording is still here. Try saving again or discard it.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.pump();
    expect(find.text('Save').hitTestable(), findsOneWidget);
  });

  testWidgets('gives an empty Remember screen one quiet incised mark', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const MaterialApp(home: Scaffold(body: RememberScreen())),
      ),
    );
    await _settle(tester);

    expect(find.byKey(const Key('remember-living-vine')), findsNothing);
    expect(find.byKey(const Key('remember-incised-mark')), findsOneWidget);
    expect(find.text('We forget quickly'), findsOneWidget);
    expect(find.byKey(const Key('remember-speak')), findsOneWidget);
    expect(find.byKey(const Key('remember-write')), findsOneWidget);
  });

  testWidgets('empty Remember action fits above shell navigation', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: const RememberScreen(),
            bottomNavigationBar: NavigationBar(
              key: const Key('test-shell-navigation'),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  label: 'Remember',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(
      tester.getBottomLeft(find.byKey(const Key('remember-write'))).dy,
      lessThanOrEqualTo(
        tester.getTopLeft(find.byKey(const Key('test-shell-navigation'))).dy,
      ),
    );
    expect(
      find.byKey(const Key('remember-write')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('records an encounter and shows it in Remember immediately', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository(
      now: () => DateTime.utc(2026, 8, 10, 12),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await repository.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingCompleteProvider.overrideWith((ref) => true),
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const SoulBuddyApp(),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Remember').last);
    await _settle(tester);
    await tester.tap(find.byKey(const Key('remember-write')));
    await _settle(tester);
    await tester.tap(find.text('Encounter'));
    await _settle(tester);

    await tester.enterText(
      find.byKey(const Key('encounter-title')),
      'A prayer was answered',
    );
    await tester.enterText(
      find.byKey(const Key('encounter-body')),
      'Help came through a person.',
    );
    await tester.ensureVisible(
      find.widgetWithText(SwitchListTile, 'Keep this as an Altar'),
    );
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Keep this as an Altar'),
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await _settle(tester);

    await tester.tap(find.text('Remember').last);
    await _settle(tester);

    expect(find.text('A prayer was answered'), findsOneWidget);
    expect(find.text('Help came through a person.'), findsOneWidget);
    expect(find.text('Altar'), findsOneWidget);
  });

  testWidgets('keeps guided choices accessible at large text sizes', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(body: RecordScreen()),
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const Key('record-write')));
    await _settle(tester);

    for (final label in [
      'Encounter',
      'Promise',
      'What I left behind',
      'Revelation',
      'Scripture',
      'Person',
      'Family',
      'Lesson',
      'Testimony',
    ]) {
      final target = find.byKey(Key('record-choice-${label.toLowerCase()}'));
      expect(target, findsOneWidget);
    }

    await tester.tap(find.text('Encounter'));
    await _settle(tester);

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('What happened? (optional)'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(
      find.text('Mark an encounter you want to return to and remember.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('every Record choice opens a working typed form', (tester) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const MaterialApp(home: Scaffold(body: RecordScreen())),
      ),
    );
    await _settle(tester);

    for (final label in ['Promise', 'What I left behind', 'Revelation']) {
      await tester.tap(find.byKey(const Key('record-write')));
      await _settle(tester);
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await _settle(tester);
      expect(find.text('Record $label'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      if (label == 'What I left behind') {
        final sensitive = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, 'Sensitive'),
        );
        expect(sensitive.value, isTrue);
      }
      await tester.tap(find.text('Remember').first);
      await _settle(tester);
    }
    expect(find.textContaining('Coming'), findsNothing);
  });

  testWidgets('Sacred Hour remembrance keeps a careful opening prompt', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: RecordScreen(
              startMode: RecordStartMode.write,
              initialBodyPrompt: 'What may God be teaching me here?',
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('Encounter'));
    await _settle(tester);

    expect(find.text('What may God be teaching me here?'), findsOneWidget);
    expect(find.textContaining('God told me'), findsNothing);
  });

  testWidgets('guided reflection opens directly as a private blank journal', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: RecordScreen(
              startMode: RecordStartMode.reflection,
              initialTitle: 'Reflection · Forgiveness',
              initialBodyPrompt: 'Who is God inviting me to forgive?',
              privateReflection: true,
            ),
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Record an encounter'), findsOneWidget);
    expect(find.text('Who is God inviting me to forgive?'), findsOneWidget);
    expect(find.text('Encounter'), findsNothing);
    expect(
      tester
          .widget<SayableField>(find.byKey(const Key('encounter-body')))
          .controller
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Sensitive'),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('Remember filters records and masks sensitive excerpts', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    await repository.create(
      const EncounterDraft(
        title: 'A private freedom',
        body: 'A sensitive detail',
        occurredOn: '2026-08-12',
        isAltar: false,
        memoryType: MemoryType.leftBehind,
        sensitive: true,
      ),
    );
    await repository.create(
      const EncounterDraft(
        title: 'A promise to remember',
        body: 'Return to prayer.',
        occurredOn: '2026-08-12',
        isAltar: true,
        memoryType: MemoryType.promise,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const MaterialApp(home: Scaffold(body: RememberScreen())),
      ),
    );
    await _settle(tester);

    expect(find.text('Private memory'), findsOneWidget);
    expect(find.byKey(const Key('remember-living-vine')), findsNothing);
    expect(find.byKey(const Key('remember-incised-mark')), findsOneWidget);
    expect(find.byKey(const Key('promise-paired-slab-mark')), findsOneWidget);
    expect(find.text('A sensitive detail'), findsNothing);
    expect(find.text('A private freedom'), findsNothing);
    await tester.enterText(find.byKey(const Key('remember-search')), 'promise');
    await _settle(tester);
    expect(find.text('A promise to remember'), findsOneWidget);
    expect(find.text('A private freedom'), findsNothing);
  });

  testWidgets('adds dated understanding without rewriting the memory', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository(
      now: () => DateTime.utc(2026, 8, 12, 12),
    );
    addTearDown(repository.close);
    final memory = await repository.create(
      const EncounterDraft(
        title: 'An encounter to understand',
        body: 'The original record.',
        occurredOn: '2026-08-11',
        isAltar: true,
        memoryType: MemoryType.revelation,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
          // The reflection field now offers the microphone, which resolves
          // availability on mount.
          speechRecognizerProvider.overrideWithValue(NoSpeech()),
        ],
        child: MaterialApp(home: MemoryDetailScreen(memoryId: memory.id)),
      ),
    );
    await _settle(tester);
    await tester.enterText(
      find.byKey(const Key('memory-reflection-body')),
      'I understand more about patience now.',
    );
    final saveReflection = find.byKey(const Key('memory-save-reflection'));
    await tester.ensureVisible(saveReflection);
    await tester.pump();
    await tester.tap(saveReflection);
    await _settle(tester);

    expect(find.text('I understand more about patience now.'), findsOneWidget);
    expect(find.text('The original record.'), findsOneWidget);
  });

  testWidgets('dictation and recording are both reachable from the form', (
    tester,
  ) async {
    // The two capture mechanisms share this sheet and neither may switch the
    // other off. Dictation lives in the field; recording is the button beside
    // it. A dictating form still records, and a recording form still dictates,
    // and the words land in the draft that gets saved.
    final repository = InMemoryEncounterRepository();
    final recorder = _RecordFlowRecorder();
    final controller = AudioCaptureController(
      recorder: recorder,
      allocateTemporary: () async =>
          const TemporaryAudio(key: 'take', locator: '/private/take.m4a'),
    );
    addTearDown(() async {
      await controller.close();
      await repository.close();
    });
    final seam = _RecordingSeam();
    // Built here rather than in the override so the test disposes it: the
    // provider's own container is gone by the time this runs, and a dictation
    // controller that is never disposed is a listener that outlives its test.
    final speech = SpeechCaptureController(recognizer: seam);
    addTearDown(speech.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
          audioCaptureControllerProvider.overrideWith(
            (ref) async => controller,
          ),
          speechCaptureControllerProvider.overrideWithValue(speech),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EncounterForm(
              onSave: (draft) async => repository.create(draft),
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(
      find.byKey(const Key('encounter-add-audio')),
      findsOneWidget,
      reason: 'recording keeps its own button, untouched by dictation',
    );

    // Speak the title into the field.
    final titleMic = find.descendant(
      of: find.byKey(const Key('encounter-title')),
      matching: find.byKey(const Key('sayable-field-mic')),
    );
    expect(titleMic, findsOneWidget);
    await tester.ensureVisible(titleMic);
    await tester.tap(titleMic);
    await tester.pump();
    seam.emit('A quiet afternoon');
    await tester.pump();

    expect(
      tester
          .widget<SayableField>(find.byKey(const Key('encounter-title')))
          .controller
          .text,
      'A quiet afternoon',
    );
    expect(
      find.byKey(const Key('encounter-add-audio')).hitTestable(),
      findsOneWidget,
      reason: 'a live dictation session does not disable recording',
    );

    // And record beside it, without either switching the other off.
    await tester.tap(find.byKey(const Key('encounter-add-audio')));
    await _settle(tester);
    await tester.tap(find.text('Start recording'));
    await _settle(tester);
    await tester.tap(find.text('Stop'));
    await _settle(tester);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await _settle(tester);

    expect(find.text('Voice recording added'), findsOneWidget);
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await _settle(tester);

    expect(repository.lastDraft!.title, 'A quiet afternoon');
    expect(repository.lastDraft!.audio, isNotNull);
    expect(
      seam.stopCalls,
      isZero,
      reason: 'recording did not end the dictation session',
    );
  });

  testWidgets('a dictated title cut by the limit says so', (tester) async {
    // The title's own limit is 120 characters. A sentence that runs past it is
    // kept as far as it goes, and the person is told, rather than being left to
    // believe a shortened title is the one they spoke.
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    final seam = _RecordingSeam();
    final speech = SpeechCaptureController(recognizer: seam);
    addTearDown(speech.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
          speechCaptureControllerProvider.overrideWithValue(speech),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EncounterForm(
              onSave: (draft) async => repository.create(draft),
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    await _settle(tester);

    final titleMic = find.descendant(
      of: find.byKey(const Key('encounter-title')),
      matching: find.byKey(const Key('sayable-field-mic')),
    );
    await tester.ensureVisible(titleMic);
    await tester.tap(titleMic);
    await tester.pump();
    seam.emit(
      'a title that keeps going well past one hundred and twenty '
      'characters so that the field has to cut it somewhere short of the end',
    );
    await tester.pump();

    expect(find.text('Your answer reached the limit.'), findsOneWidget);
    expect(
      tester
          .widget<SayableField>(find.byKey(const Key('encounter-title')))
          .controller
          .text
          .length,
      120,
    );
  });
}

class _RecordFlowRecorder implements AudioRecorderGateway {
  final _amplitudes = StreamController<double>.broadcast();

  @override
  Stream<double> get amplitudes => _amplitudes.stream;

  @override
  bool get canPause => true;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> discard(AudioRecorderResult result) async {}

  @override
  Future<void> dispose() => _amplitudes.close();

  @override
  Future<void> pause() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> resume() async {}

  @override
  Future<void> start(TemporaryAudio temporary) async {}

  @override
  Future<AudioRecorderResult> stop() async => const AudioRecorderResult(
    locator: '/private/take.m4a',
    mimeType: 'audio/mp4',
  );
}

/// The dictation seam, driven by hand.
///
/// Recognition is faked rather than mocked through the plugin, so the words
/// arrive when this test says so and the session state is observable afterwards.
class _RecordingSeam implements SpeechRecognizer {
  int stopCalls = 0;
  void Function(String words)? _onWords;

  @override
  Future<bool> initialize({
    void Function(bool listening)? onListeningChanged,
    VoidCallback? onUnavailable,
    VoidCallback? onError,
  }) async => true;

  @override
  Future<void> listen({required void Function(String words) onWords}) async {
    _onWords = onWords;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  void emit(String words) => _onWords?.call(words);
}

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
