import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/application/meditation_sound_preferences.dart';
import 'package:soulbuddy/features/prayers/domain/affirmation_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/worship_sound_bed.dart';
import 'package:soulbuddy/features/prayers/presentation/affirmation_prayer_session_screen.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_release_providers.dart';

import '../../helpers/in_memory_prayer_release_repository.dart';
import '../../helpers/prayer_release_fixtures.dart';
import 'application/affirmation_prayer_session_controller_test.dart'
    show
        FakeNarration,
        FakeScreenAwake,
        FakeSoundBed,
        buildProfile,
        stepOnePhrase;

/// Worship obeys the same audio lifecycle as every other bed, and the practice
/// still never resumes on its own.
void main() {
  final worshipChip = find.byKey(
    const Key('attention-prayer-sound-tenThousandReasons'),
  );

  late FakeNarration narration;
  late FakeSoundBed bed;
  late FakeScreenAwake awake;
  late InMemoryPrayerReleaseRepository repository;
  late MeditationSoundPreferencesRepository soundPreferences;
  late Map<String, String> storage;

  setUp(() {
    narration = FakeNarration();
    bed = FakeSoundBed();
    awake = FakeScreenAwake();
    storage = {};
  });

  /// Builds the release catalogue here rather than in `setUp`, and stores the
  /// sound choice where the screen will actually read it.
  ///
  /// The catalogue owns broadcast stream controllers, and a controller built in
  /// `setUp` binds to the zone `setUp` runs in rather than the one the test
  /// body runs in. A test that then awaits anything before its first `pump`
  /// never sees those streams deliver, and the screen waits forever. Building
  /// them inside the body keeps them in the test's own zone.
  Future<void> pump(
    WidgetTester tester, {
    MeditationSoundPreferences? stored,
  }) async {
    soundPreferences = MeditationSoundPreferencesRepository(
      read: (key) async => storage[key],
      write: (key, value) async => storage[key] = value,
    );
    repository = InMemoryPrayerReleaseRepository(
      releases: [releaseFixture(added: true)],
      content: {releaseSlug: releaseContentFixture()},
    );
    if (stored != null) await soundPreferences.save(stored);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerReleaseRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
          meditationSoundPreferencesProvider.overrideWithValue(
            soundPreferences,
          ),
        ],
        child: MaterialApp(
          home: AffirmationPrayerSessionScreen(
            profile: buildProfile(),
            releaseItemId: 'release-item-3',
            libraryPrayerId: 'release-prayer-3',
            sessionId: 'session-1',
            narration: narration,
            soundBed: bed,
            awake: awake,
            soundPreferences: soundPreferences,
            now: () => DateTime.utc(2026, 10, 6, 9),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseWorshipAndBegin(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('attention-prayer-skip')));
    await tester.pumpAndSettle();
    await reveal(tester, worshipChip);
    await tester.tap(worshipChip);
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const Key('attention-prayer-begin')));
    await tester.tap(find.byKey(const Key('attention-prayer-begin')));
    await tester.pumpAndSettle();
  }

  testWidgets('a deliberate pause stops worship', (tester) async {
    await pump(tester);
    await chooseWorshipAndBegin(tester);
    expect(bed.playing, 'tenThousandReasons');

    await tester.tap(find.byKey(const Key('attention-prayer-pause')));
    await tester.pumpAndSettle();

    expect(bed.playing, isNull);
    expect(bed.stopCount, greaterThan(0));
    expect(awake.states.last, isFalse);
  });

  testWidgets('leaving the screen stops worship', (tester) async {
    await pump(tester);
    await chooseWorshipAndBegin(tester);

    // Replacing the whole app takes the route away, which is what a back
    // gesture or a navigation does.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();

    expect(bed.playing, isNull);
  });

  testWidgets('backgrounding stops worship and returning does not restore it', (
    tester,
  ) async {
    await pump(tester);
    await chooseWorshipAndBegin(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect(bed.playing, isNull);
    expect(awake.states.last, isFalse);

    // Foregrounding alone brings nothing back, for worship as for anything
    // else: the practice never resumes on its own.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(bed.playing, isNull);

    // Only a deliberate tap does.
    await reveal(tester, find.byKey(const Key('attention-prayer-begin')));
    await tester.tap(find.byKey(const Key('attention-prayer-begin')));
    await tester.pumpAndSettle();
    expect(bed.playing, 'tenThousandReasons');
  });

  testWidgets('ending the session stops worship and records the choice', (
    tester,
  ) async {
    await pump(tester);
    await chooseWorshipAndBegin(tester);

    await tester.tap(find.byKey(const Key('attention-prayer-end')));
    await tester.pumpAndSettle();

    expect(bed.playing, isNull);
    expect(repository.savedSessions.single.soundKey, 'tenThousandReasons');
    expect(
      repository.savedSessions.single.outcome,
      AffirmationPrayerOutcome.endedEarly,
    );
  });

  testWidgets('a saved worship choice is restored, and still starts nothing', (
    tester,
  ) async {
    // Someone who chose worship before is not ambushed by it: it is shown as
    // chosen, and it still waits for Begin.
    await pump(
      tester,
      stored: const MeditationSoundPreferences(
        worship: WorshipSoundPreference(
          sound: WorshipSoundBed.animaChristi,
          volume: .1,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('attention-prayer-skip')));
    await tester.pumpAndSettle();
    await reveal(
      tester,
      find.byKey(const Key('attention-prayer-sound-animaChristi')),
    );

    final chip = tester.widget<ChoiceChip>(
      find.byKey(const Key('attention-prayer-sound-animaChristi')),
    );
    expect(chip.selected, isTrue);
    expect(bed.playing, isNull);
  });

  testWidgets('a worship session never counts without a deliberate tap', (
    tester,
  ) async {
    await pump(tester);
    await chooseWorshipAndBegin(tester);

    // Music playing and a guide reading the phrase are not a repetition.
    expect(narration.spoken, [stepOnePhrase]);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('0 of 50'), findsOneWidget);

    await tester.tap(find.byKey(const Key('attention-prayer-continue')));
    await tester.pumpAndSettle();
    expect(find.text('1 of 50'), findsOneWidget);
  });
}
