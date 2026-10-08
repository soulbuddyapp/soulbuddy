import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/speech/speech_capture_providers.dart';
import 'package:soulbuddy/features/formation/data/formation_progress_repository.dart';
import 'package:soulbuddy/features/formation/presentation/formation_reading_screen.dart';
import 'package:soulbuddy/features/formation/providers/formation_providers.dart';
import 'package:soulbuddy/features/goals/data/goal_meditation_repository.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/presentation/goal_meditation_screen.dart';
import 'package:soulbuddy/features/goals/providers/goal_meditation_providers.dart';
import 'package:soulbuddy/features/goals/providers/goal_providers.dart';
import 'package:soulbuddy/features/kingdom/providers/kingdom_course_providers.dart';
import 'package:soulbuddy/features/prayers/application/meditation_sound_bed_player.dart';
import 'package:soulbuddy/features/prayers/application/meditation_sound_preferences.dart';
import 'package:soulbuddy/features/prayers/domain/meditation_session.dart';
import 'package:soulbuddy/features/prayers/domain/worship_sound_bed.dart';
import 'package:soulbuddy/features/scripture/data/scripture_repository.dart';
import 'package:soulbuddy/features/scripture/domain/scripture_passage.dart';
import 'package:soulbuddy/features/scripture/providers/scripture_providers.dart';

import '../../helpers/no_speech_recognizer.dart';

/// Worship is unreachable from the shared picker, checked at the surfaces that
/// use it rather than only at the widget.
///
/// `goal_meditation_screen` and `formation_reading_screen` are driven for real:
/// their pickers are opened, scrolled to the end, and every visible label is
/// collected. A worship label appearing on either is the failure this file
/// exists to prevent. The source guard at the end is what keeps the other
/// surfaces honest without standing up every one of them.
void main() {
  const labels = [
    'Stillness',
    'Flowing water',
    'Gentle rain',
    'Ocean waves',
    'Forest morning',
    'Soft wind',
    'Warm fireplace',
    'Night crickets',
    'Resolutions',
    'Aurora',
    'Affirmations',
    'First Snow',
    'A Kind Of Hope',
  ];

  late String? stored;

  setUp(() => stored = null);

  MeditationSoundPreferencesRepository preferences() =>
      MeditationSoundPreferencesRepository(
        read: (_) async => stored,
        write: (_, value) async => stored = value,
      );

  /// Scrolls a picker sheet from end to end and collects every label in it.
  Future<Set<String>> readWholeSheet(WidgetTester tester) async {
    final seen = <String>{};
    for (var scroll = 0; scroll < 8; scroll++) {
      seen.addAll(
        tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data)
            .whereType<String>(),
      );
      await tester.drag(find.byType(ListView).last, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    return seen;
  }

  testWidgets(
    'formation reading offers the ambient catalogue and nothing else',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meditationSoundPreferencesProvider.overrideWithValue(preferences()),
            formationProgressProvider.overrideWith(
              (_) async => const FormationProgress({}),
            ),
            scriptureRepositoryProvider.overrideWithValue(_Scripture()),
          ],
          child: MaterialApp(
            home: FormationReadingScreen(soundPlayer: _Player()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('meditation-sound-picker')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('meditation-sound-picker')));
      await tester.pumpAndSettle();

      final seen = await readWholeSheet(tester);

      for (final label in labels) {
        expect(seen, contains(label));
      }
      for (final bed in WorshipSoundBed.values) {
        expect(
          seen,
          isNot(contains(bed.label)),
          reason: 'worship must not reach formation reading',
        );
      }
    },
  );

  testWidgets('goal meditation offers the ambient catalogue and nothing else', (
    tester,
  ) async {
    const goalId = 'meditation-goal';
    final goal = Goal(
      id: goalId,
      ownerId: 'owner',
      mode: GoalMode.mixed,
      status: GoalStatus.active,
      currentRevisionId: 'revision',
      position: 0,
      title: 'Practice patience',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kingdomMeditationReadyProvider.overrideWith((ref) async => true),
          goalProvider(goalId).overrideWith((ref) => Stream.value(goal)),
          goalMeditationPlanProvider(goalId).overrideWith((ref) async => null),
          goalMeditationEntriesProvider(goalId).overrideWith((ref) async => []),
          goalMeditationRepositoryProvider.overrideWithValue(
            GoalMeditationRepository(
              read: (_) async => null,
              write: (_, _) async {},
            ),
          ),
          speechRecognizerProvider.overrideWithValue(NoSpeech()),
          meditationSoundPreferencesProvider.overrideWithValue(preferences()),
        ],
        child: const MaterialApp(home: GoalMeditationScreen(goalId: goalId)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('meditation-sound-picker')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('meditation-sound-picker')));
    await tester.pumpAndSettle();

    final seen = await readWholeSheet(tester);

    for (final bed in WorshipSoundBed.values) {
      expect(
        seen,
        isNot(contains(bed.label)),
        reason: 'worship must not reach goal meditation',
      );
    }
    expect(seen, contains('Quiet ambience'));
  });

  group('no other surface mentions worship', () {
    // The picker is shared by seven surfaces. Standing each one up to prove the
    // same thing would be seven near-identical tests, so instead the shared
    // widget and the ambient catalogue are proved above, and here every file
    // that offers a background sound is checked for the one thing that would
    // let worship through: a reference to the worship enum.
    const surfaces = {
      'lib/features/prayers/presentation/meditation_sound_picker.dart',
      'lib/features/prayers/presentation/meditation_session_sheet.dart',
      'lib/features/formation/presentation/formation_reading_screen.dart',
      'lib/features/goals/presentation/goal_meditation_screen.dart',
      'lib/features/commitments/presentation/commitment_meditation_screen.dart',
      'lib/features/sacred_hours/presentation/sacred_hour_session_screen.dart',
      'lib/features/sacred_hours/presentation/sacred_hour_today_card.dart',
      'lib/features/scripture/presentation/daily_scripture_screen.dart',
    };

    test('the picker is the only file that lists ambient beds by hand', () {
      for (final path in surfaces) {
        final source = File(path).readAsStringSync();
        expect(
          source.contains('WorshipSoundBed'),
          isFalse,
          reason: '$path must not reference worship; it has no way to play it',
        );
      }
    });

    test('the picker builds its list from the ambient enum alone', () {
      final picker = File(
        'lib/features/prayers/presentation/meditation_sound_picker.dart',
      ).readAsStringSync();
      expect(picker, contains('MeditationSoundBed.values'));
      expect(picker, isNot(contains('WorshipSoundBed')));
    });

    test('only the prayers feature names the worship enum at all', () {
      // The prayers feature owns worship end to end: the catalogue, the
      // preference slot, the player that plays it, and the one screen that
      // offers it. A file in any other feature naming it is a leak into a
      // surface that has no business offering music, so the boundary is
      // asserted rather than a file list maintained by hand.
      final outside = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => file.readAsStringSync().contains('WorshipSoundBed'))
          .map((file) => file.path.replaceAll(r'\', '/'))
          .where((path) => !path.startsWith('lib/features/prayers/'))
          .toList();

      expect(outside, isEmpty);
    });

    test('and within prayers, only the flow that may offer it names it', () {
      // Even inside the feature the catalogue is not a licence: the collector
      // and the player are allowed to know it, and no presentation file other
      // than the Prayer of attention's is.
      final presenting = Directory('lib/features/prayers/presentation')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => file.readAsStringSync().contains('WorshipSoundBed'))
          .map((file) => file.path.replaceAll(r'\', '/'))
          .toList();

      expect(presenting, [
        'lib/features/prayers/presentation/affirmation_prayer_session_screen.dart',
      ]);
    });

    test('the meditation bed player takes only an ambient bed', () {
      final player = File(
        'lib/features/prayers/application/meditation_sound_bed_player.dart',
      ).readAsStringSync();
      expect(player, contains('Future<void> start(MeditationSoundBed bed'));
      expect(player, isNot(contains('WorshipSoundBed')));
    });
  });
}

class _Player implements MeditationSoundBedPlayer {
  MeditationSoundBed? playing;
  @override
  Future<void> start(MeditationSoundBed bed, {required double volume}) async {
    playing = bed;
  }

  @override
  Future<void> stop() async {
    playing = null;
  }

  @override
  Future<void> dispose() => stop();
  @override
  Future<void> setVolume(double volume) async {}
}

class _Scripture implements ScriptureRepository {
  @override
  Future<ScripturePassage> verses({
    required String book,
    required int chapter,
    required int firstVerse,
    required int lastVerse,
  }) async => const ScripturePassage(
    reference: 'Romans 6:12–14',
    verses: [ScriptureVerse(number: 12, text: 'Let not sin therefore reign.')],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
