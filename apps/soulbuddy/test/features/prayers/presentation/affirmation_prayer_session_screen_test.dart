import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/application/meditation_sound_preferences.dart';
import 'package:soulbuddy/features/prayers/domain/affirmation_prayer.dart';
import 'package:soulbuddy/features/prayers/presentation/affirmation_prayer_session_screen.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_release_providers.dart';

import '../../../helpers/in_memory_prayer_release_repository.dart';
import '../../../helpers/prayer_release_fixtures.dart';
import '../application/affirmation_prayer_session_controller_test.dart'
    show
        FakeNarration,
        FakeScreenAwake,
        FakeSoundBed,
        buildProfile,
        stepOnePhrase,
        stepTwoPhrase;

void main() {
  late FakeNarration narration;
  late FakeSoundBed bed;
  late FakeScreenAwake awake;
  late InMemoryPrayerReleaseRepository repository;
  late MeditationSoundPreferencesRepository soundPreferences;

  setUp(() {
    narration = FakeNarration();
    bed = FakeSoundBed();
    awake = FakeScreenAwake();
    soundPreferences = MeditationSoundPreferencesRepository(
      read: (_) async => null,
      write: (_, value) async {},
    );
    repository = InMemoryPrayerReleaseRepository(
      releases: [releaseFixture(added: true)],
      content: {releaseSlug: releaseContentFixture()},
    );
  });

  Future<InMemoryPrayerReleaseRepository> pumpSession(
    WidgetTester tester, {
    required Widget child,
    double textScale = 1,
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerReleaseRepositoryProvider.overrideWith((ref) async => repository),
          meditationSoundPreferencesProvider.overrideWithValue(soundPreferences),
        ],
        child: MaterialApp(
          home: child,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: disableAnimations,
            ),
            child: child!,
          ),
        ),
      ),
    );
    // A fixed pump rather than `pumpAndSettle`: the session shows a progress
    // indicator while it restores the saved sound preference.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    return repository;
  }

  Widget buildScreen() {
    return AffirmationPrayerSessionScreen(
      profile: buildProfile(),
      releaseItemId: 'release-item-3',
      sessionId: 'session-1',
      narration: narration,
      soundBed: bed,
      awake: awake,
      soundPreferences: soundPreferences,
      now: () => DateTime.utc(2026, 10, 6, 9),
    );
  }

  Future<void> skipToSetup(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('attention-prayer-skip')));
    await tester.pumpAndSettle();
  }

  /// Scrolls until [finder] is on screen, so off-screen controls can be driven.
  Future<void> reveal(
    WidgetTester tester,
    Finder finder, {
    double delta = 200,
  }) async {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> beginPrayer(WidgetTester tester) async {
    await reveal(tester, find.byKey(const Key('attention-prayer-begin')));
    await tester.tap(find.byKey(const Key('attention-prayer-begin')));
    await tester.pumpAndSettle();
  }

  group('recollection', () {
    testWidgets('shows the five lines in order and can be skipped', (
      tester,
    ) async {
      await pumpSession(tester, child: buildScreen());

      expect(find.text('Be still before God'), findsOneWidget);
      expect(find.text('Let your body grow still'), findsOneWidget);
      // Nothing sounds during the recollection.
      expect(narration.spoken, isEmpty);
      expect(bed.playing, isNull);

      for (final line in [
        'Let the noise fade away',
        'Lift your heart to God',
        "Recognize God's presence and sovereignty",
      ]) {
        await tester.tap(find.byKey(const Key('attention-prayer-advance-recollection')));
        await tester.pumpAndSettle();
        expect(find.text(line), findsOneWidget);
      }

      await tester.tap(find.byKey(const Key('attention-prayer-advance-recollection')));
      await tester.pumpAndSettle();
      expect(find.text('Be still, and know that I am God'), findsOneWidget);

      // The last line advances into setup, where nothing has sounded.
      await tester.tap(find.byKey(const Key('attention-prayer-advance-recollection')));
      await tester.pumpAndSettle();
      expect(find.text('Speak these words with attention'), findsOneWidget);
      expect(narration.spoken, isEmpty);
      expect(bed.playing, isNull);
    });

    testWidgets('skip moves straight to setup', (tester) async {
      await pumpSession(tester, child: buildScreen());
      await skipToSetup(tester);

      expect(find.text('Speak these words with attention'), findsOneWidget);
      expect(find.text('Let your body grow still'), findsNothing);
      expect(narration.spoken, isEmpty);
    });
  });

  group('setup', () {
    testWidgets('presents both sound families as a quiet choice', (
      tester,
    ) async {
      await pumpSession(tester, child: buildScreen());
      await skipToSetup(tester);

      expect(find.text('Creation sounds'), findsOneWidget);
      expect(find.text('Quiet instrumental music'), findsOneWidget);
      expect(
        find.textContaining('help you settle into quiet attention'),
        findsOneWidget,
      );

      for (final label in [
        'Ocean waves',
        'Flowing water',
        'Gentle rain',
        'Soft wind',
        'Forest morning',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('offers only the four approved paces, defaulting to 0.85x', (
      tester,
    ) async {
      await pumpSession(tester, child: buildScreen());
      await skipToSetup(tester);
      await reveal(tester, find.text('Voice speed'));

      expect(find.text('0.7x'), findsOneWidget);
      expect(find.text('0.85x'), findsOneWidget);
      expect(find.text('1.0x'), findsOneWidget);
      expect(find.text('1.15x'), findsOneWidget);
      expect(find.text('1.25x'), findsNothing);
      expect(find.text('0.5x'), findsNothing);

      final chip = tester.widget<ChoiceChip>(
        find.byKey(const Key('attention-prayer-speed-0.85')),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('starts no sound until prayer is deliberately begun', (
      tester,
    ) async {
      await pumpSession(tester, child: buildScreen());
      await skipToSetup(tester);
      await reveal(tester, find.byKey(const Key('attention-prayer-sound-oceanWaves')));
      await tester.tap(find.byKey(const Key('attention-prayer-sound-oceanWaves')));
      await tester.pumpAndSettle();

      expect(bed.playing, isNull);

      await beginPrayer(tester);
      expect(bed.playing, 'oceanWaves');
    });
  });

  group('praying', () {
    testWidgets('centers one exact phrase with the count below it', (
      tester,
    ) async {
      await pumpSession(tester, child: buildScreen());
      await skipToSetup(tester);
      await beginPrayer(tester);

      expect(find.text(stepOnePhrase), findsOneWidget);
      expect(find.text('0 of 50'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Hear again'), findsOneWidget);
      // The source line suffix is not shown while counting.
      expect(find.textContaining('(x50)'), findsNothing);
    });

    testWidgets('advances one repetition per tap and never on replay', (
      tester,
    ) async {
      await pumpSession(tester, child: buildScreen());
      await skipToSetup(tester);
      await beginPrayer(tester);

      await tester.tap(find.byKey(const Key('attention-prayer-hear-again')));
      await tester.pumpAndSettle();
      expect(find.text('0 of 50'), findsOneWidget);

      await tester.tap(find.byKey(const Key('attention-prayer-continue')));
      await tester.pumpAndSettle();
      expect(find.text('1 of 50'), findsOneWidget);

      await tester.tap(find.byKey(const Key('attention-prayer-hear-again')));
      await tester.pumpAndSettle();
      expect(find.text('1 of 50'), findsOneWidget);
    });

    testWidgets('offers an untimed focused pause after each group of ten', (
      tester,
    ) async {
      await pumpSession(tester, child: buildScreen());
      await skipToSetup(tester);
      await reveal(tester, find.byKey(const Key('attention-prayer-sound-gentleRain')));
      await tester.tap(find.byKey(const Key('attention-prayer-sound-gentleRain')));
      await tester.pumpAndSettle();
      await beginPrayer(tester);

      for (var index = 0; index < 10; index++) {
        await tester.tap(find.byKey(const Key('attention-prayer-continue')));
        await tester.pumpAndSettle();
      }

      expect(find.text('Gather your thoughts before God'), findsOneWidget);
      expect(find.text('10 of 50'), findsOneWidget);
      expect(bed.duckCount, 1);
      // The chosen bed is lowered, never gone.
      expect(bed.playing, 'gentleRain');

      await tester.tap(find.byKey(const Key('attention-prayer-group-resume')));
      await tester.pumpAndSettle();
      expect(find.text(stepOnePhrase), findsOneWidget);
      expect(bed.restoreCount, 1);
    });

    testWidgets('moves to the second phrase after fifty repetitions', (
      tester,
    ) async {
      await pumpSession(tester, child: buildScreen());
      await skipToSetup(tester);
      await beginPrayer(tester);

      for (var index = 0; index < 50; index++) {
        final resume = find.byKey(const Key('attention-prayer-group-resume'));
        if (resume.evaluate().isNotEmpty) {
          await tester.tap(resume);
          await tester.pumpAndSettle();
        }
        final advance = find.byKey(const Key('attention-prayer-continue'));
        if (advance.evaluate().isEmpty) break;
        await tester.tap(advance);
        await tester.pumpAndSettle();
      }

      // The fiftieth repetition leaves a focused pause before the second phrase.
      final resume = find.byKey(const Key('attention-prayer-group-resume'));
      expect(resume, findsOneWidget);
      await tester.tap(resume);
      await tester.pumpAndSettle();

      expect(find.text(stepTwoPhrase), findsOneWidget);
      expect(find.text('0 of 10'), findsOneWidget);
    });
  });

  group('lifecycle', () {
    testWidgets('stops sound when the app is backgrounded', (tester) async {
      await pumpSession(tester, child: buildScreen());
      await skipToSetup(tester);
      await tester.tap(find.byKey(const Key('attention-prayer-sound-forestMorning')));
      await beginPrayer(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      expect(bed.playing, isNull);
      expect(awake.states.last, isFalse);

      // Foregrounding alone must not restore sound.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(bed.playing, isNull);

      // Only an explicit action resumes.
      await reveal(tester, find.byKey(const Key('attention-prayer-begin')));
      await tester.tap(find.byKey(const Key('attention-prayer-begin')));
      await tester.pumpAndSettle();
      expect(bed.playing, 'forestMorning');
    });

    testWidgets('keeps the device awake while the session runs', (
      tester,
    ) async {
      await pumpSession(tester, child: buildScreen());
      await skipToSetup(tester);
      await beginPrayer(tester);

      expect(awake.states, contains(true));
    });

    testWidgets('a deliberate pause stops the sound', (tester) async {
      await pumpSession(tester, child: buildScreen());
      await skipToSetup(tester);
      await tester.tap(find.byKey(const Key('attention-prayer-sound-softWind')));
      await beginPrayer(tester);

      await tester.tap(find.byKey(const Key('attention-prayer-pause')));
      await tester.pumpAndSettle();

      expect(bed.playing, isNull);
      expect(find.text('Speak these words with attention'), findsOneWidget);
    });
  });

  group('completion', () {
    testWidgets('leads with one quiet line and offers optional responses', (
      tester,
    ) async {
      await pumpSession(tester, child: buildScreen());
      await skipToSetup(tester);
      await beginPrayer(tester);

      await tester.tap(find.byKey(const Key('attention-prayer-end')));
      await tester.pumpAndSettle();

      expect(find.text('Carry this prayer into love'), findsOneWidget);
      expect(find.text('Pray'), findsOneWidget);
      expect(find.text('Reflect'), findsOneWidget);
      expect(find.text('Scripture'), findsOneWidget);
      expect(find.text('Choose for today'), findsOneWidget);

      expect(repository.savedSessions, hasLength(1));
      expect(
        repository.savedSessions.single.outcome,
        AffirmationPrayerOutcome.endedEarly,
      );
    });

    testWidgets('avoids scoring, streak, and comparison language', (
      tester,
    ) async {
      await pumpSession(tester, child: buildScreen());
      await skipToSetup(tester);
      await beginPrayer(tester);

      for (final forbidden in [
        'affirmation',
        'subconscious',
        'theta',
        'program',
        'rewire',
        'habit score',
        'streak',
        'level',
        'achievement',
        'success',
        'failure',
      ]) {
        expect(find.textContaining(forbidden, findRichText: true), findsNothing);
      }
    });

    testWidgets('records a completed session after fifty and ten', (
      tester,
    ) async {
      await pumpSession(tester, child: buildScreen());
      await skipToSetup(tester);
      await beginPrayer(tester);

      for (var index = 0; index < 60; index++) {
        final resume = find.byKey(const Key('attention-prayer-group-resume'));
        if (resume.evaluate().isNotEmpty) {
          await tester.tap(resume);
          await tester.pumpAndSettle();
        }
        final advance = find.byKey(const Key('attention-prayer-continue'));
        if (advance.evaluate().isEmpty) break;
        await tester.tap(advance);
        await tester.pumpAndSettle();
      }

      final resume = find.byKey(const Key('attention-prayer-group-resume'));
      if (resume.evaluate().isNotEmpty) {
        await tester.tap(resume);
        await tester.pumpAndSettle();
      }

      expect(repository.savedSessions, hasLength(1));
      expect(
        repository.savedSessions.single.outcome,
        AffirmationPrayerOutcome.completed,
      );
      expect(repository.savedSessions.single.stepOneCount, 50);
      expect(repository.savedSessions.single.stepTwoCount, 10);
    });
  });

  group('accessibility and motion', () {
    testWidgets('respects reduced motion without changing the wording', (
      tester,
    ) async {
      await pumpSession(
        tester,
        child: buildScreen(),
        disableAnimations: true,
      );

      expect(find.text('Let your body grow still'), findsOneWidget);

      await skipToSetup(tester);
      await beginPrayer(tester);

      expect(find.text(stepOnePhrase), findsOneWidget);
      expect(find.text('0 of 50'), findsOneWidget);
    });

    testWidgets('renders without overflow at two times text scale', (
      tester,
    ) async {
      await pumpSession(tester, child: buildScreen(), textScale: 2);
      await skipToSetup(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Speak these words with attention'), findsOneWidget);

      await beginPrayer(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(stepOnePhrase), findsOneWidget);

      await reveal(tester, find.byKey(const Key('attention-prayer-count')));
      expect(find.text('0 of 50'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });
  });
}
