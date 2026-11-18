import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/core/speech/speech_capture_providers.dart';
import 'package:soulbuddy/features/onboarding/presentation/first_prayer_screen.dart';
import 'package:soulbuddy/features/onboarding/providers/first_prayer_providers.dart';
import 'package:soulbuddy/features/onboarding/domain/first_prayer_progress.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/record/audio/application/audio_capture_controller.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';
import '../../helpers/fake_inline_recorder.dart';
import 'package:soulbuddy/features/record/providers/voice_note_providers.dart';
import 'package:soulbuddy/features/record/data/voice_note_repository.dart';

import '../../helpers/no_speech_recognizer.dart';

void main() {
  testWidgets('legacy prayer detail records on its current step', (
    tester,
  ) async {
    final recorder = FakeInlineRecorder();
    final audio = AudioCaptureController(
      recorder: recorder,
      allocateTemporary: () async =>
          const TemporaryAudio(key: 'take', locator: '/take'),
    );
    addTearDown(audio.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firstPrayerControllerProvider.overrideWith(_DetailController.new),
          inlineAudioCaptureControllerProvider.overrideWith(
            (ref, key) async => audio,
          ),
          voiceNotesProvider.overrideWith(
            (ref, scope) => Stream<List<VoiceNoteLink>>.value([]),
          ),
        ],
        child: const MaterialApp(home: FirstPrayerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Add anything?'), findsOneWidget);
    expect(recorder.started, isTrue);
    expect(find.byKey(const Key('audio-live-level')), findsOneWidget);
    await audio.cancel();
  });
  testWidgets('legacy remembrance records on its current step', (tester) async {
    final recorder = FakeInlineRecorder();
    final audio = AudioCaptureController(
      recorder: recorder,
      allocateTemporary: () async =>
          const TemporaryAudio(key: 'take', locator: '/take'),
    );
    addTearDown(audio.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firstPrayerControllerProvider.overrideWith(
            _RemembranceController.new,
          ),
          audioCaptureControllerProvider.overrideWith((ref) async => audio),
        ],
        child: const MaterialApp(home: FirstPrayerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(recorder.started, isFalse);
    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(recorder.started, isTrue);
    expect(find.byKey(const Key('audio-live-level')), findsOneWidget);
    await audio.cancel();
  });
  testWidgets('guides one short prayer choice at a time', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const FirstPrayerScreen.preview(),
        ),
      ),
    );

    expect(find.text('What are you bringing to God?'), findsOneWidget);
    expect(find.text('Guidance'), findsOneWidget);

    await tester.tap(find.text('Guidance'));
    await tester.pumpAndSettle();
    expect(find.text('How often?'), findsOneWidget);
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('Once'), findsOneWidget);

    await tester.tap(find.text('Daily'));
    await tester.pumpAndSettle();
    expect(find.text('Who is this for?'), findsOneWidget);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    expect(find.text('Which feels more natural to you?'), findsOneWidget);
    expect(find.text('Christian'), findsOneWidget);
    expect(find.text('Catholic'), findsOneWidget);
    expect(find.text('Jesus'), findsOneWidget);
    expect(find.text('All of the above'), findsOneWidget);

    await tester.tap(find.text('Jesus'));
    await tester.pumpAndSettle();
    expect(find.text('Add anything?'), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Write'), findsNothing);
    expect(find.text('Not now'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.textContaining('external prayer-writing service'),
      findsNothing,
    );
    expect(find.textContaining('DeepSeek'), findsNothing);
    expect(find.text('Preparing your prayer…'), findsOneWidget);
    expect(find.text('Choose a prepared prayer'), findsOneWidget);
  });

  testWidgets('optional detail offers a recording without a text form', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // The written detail page now offers the microphone, which resolves
        // availability on mount. Answering here rather than through the plugin
        // leaves the page as it was: writable, with speech unavailable.
        overrides: [speechRecognizerProvider.overrideWithValue(NoSpeech())],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const FirstPrayerScreen.preview(
            initialStep: FirstPrayerPreviewStep.detailChoice,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
    expect(find.text('Record your words'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Prepare prayer'), findsNothing);
    expect(find.text('Not now'), findsOneWidget);
  });
}

class _RemembranceController extends FirstPrayerController {
  @override
  Future<FirstPrayerState> build() async => const FirstPrayerState(
    progress: FirstPrayerProgress(stage: FirstPrayerStage.remembranceMode),
    remembranceType: MemoryType.encounter,
  );
}

class _DetailController extends FirstPrayerController {
  @override
  Future<FirstPrayerState> build() async => const FirstPrayerState(
    progress: FirstPrayerProgress(stage: FirstPrayerStage.detailChoice),
  );
}
