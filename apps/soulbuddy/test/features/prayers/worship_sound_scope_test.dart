import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/application/affirmation_prayer_audio.dart';
import 'package:soulbuddy/features/prayers/domain/meditation_session.dart';
import 'package:soulbuddy/features/prayers/domain/worship_sound_bed.dart';
import 'package:soulbuddy/features/prayers/presentation/meditation_sound_picker.dart';

/// Worship music is offered in the Prayer of attention and nowhere else.
///
/// The two enums are separate types, so this is not a matter of a filter
/// holding: `MeditationSoundPicker` renders `MeditationSoundBed` values and has
/// no way to reach a worship bed at all. These tests are the standing evidence
/// of that, so a later change that widens the shared picker to include worship
/// fails here rather than quietly offering music on seven other surfaces.
void main() {
  group('the two kinds of bed are separate types', () {
    test('no ambient bed is a worship bed', () {
      for (final bed in MeditationSoundBed.values) {
        expect(bed, isNot(isA<WorshipSoundBed>()));
      }
      expect(WorshipSoundBed.values, isNotEmpty);
    });

    test('no ambient bed points into the worship asset directory', () {
      // A worship bed that joined the ambient enum would keep working and only
      // lose its separate identity. Its directory is the visible tell.
      for (final bed in MeditationSoundBed.values) {
        expect(bed.assetPath, isNot(startsWith('audio/worship/')));
      }
    });

    test('every worship bed points into the worship asset directory', () {
      for (final bed in WorshipSoundBed.values) {
        expect(bed.assetPath, startsWith('audio/worship/'));
      }
    });

    test('the shared ambient catalogue is unchanged', () {
      // Adding worship must not push a bed out of the shared picker, so the
      // catalogue is pinned rather than merely checked for size.
      expect(MeditationSoundBed.values.map((bed) => bed.name), [
        'stillness',
        'flowingWater',
        'gentleRain',
        'oceanWaves',
        'forestMorning',
        'softWind',
        'warmFireplace',
        'nightCrickets',
        'hopefulPiano',
        'cinematicRise',
        'steadyResolve',
        'warmStrings',
        'victoriousCalm',
      ]);
    });
  });

  group('the shared picker cannot offer worship', () {
    Future<void> openPicker(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MeditationSoundPicker(
              selected: null,
              onSelected: (_) async {},
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('meditation-sound-picker')));
      await tester.pumpAndSettle();
    }

    testWidgets('offers every ambient bed and no worship bed', (tester) async {
      await openPicker(tester);

      // The sheet builds only what is on screen, so the whole sheet is walked
      // and every label that appears is collected. A worship label appearing
      // anywhere is the failure.
      final seen = <String>{};
      for (var scroll = 0; scroll < 6; scroll++) {
        seen.addAll(
          tester
              .widgetList<Text>(find.byType(Text))
              .map((text) => text.data)
              .whereType<String>(),
        );
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
      }

      for (final bed in MeditationSoundBed.values) {
        expect(seen, contains(bed.label));
      }
      for (final bed in WorshipSoundBed.values) {
        expect(seen, isNot(contains(bed.label)));
      }
    });

    testWidgets('does not show a worship grouping', (tester) async {
      await openPicker(tester);

      // The sheet scrolls, so every family heading is checked by dragging to
      // the end rather than only the ones that happen to be on screen.
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      for (final family in AffirmationPrayerSoundFamily.values) {
        if (family.sounds.any((sound) => sound is WorshipSoundBed)) continue;
        expect(find.text(family.label), findsNothing);
      }
      expect(find.text('Quiet worship music'), findsNothing);
    });

    testWidgets('choosing anything never yields a worship bed', (tester) async {
      final chosen = <MeditationSoundBed?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MeditationSoundPicker(
              selected: null,
              onSelected: (value) async => chosen.add(value),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('meditation-sound-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flowing water'));
      await tester.pumpAndSettle();

      expect(chosen, [MeditationSoundBed.flowingWater]);
      expect(chosen.whereType<WorshipSoundBed>(), isEmpty);
    });
  });

  group('resolving a saved key', () {
    test('finds each family by its own key', () {
      expect(
        prayerSoundBedFor('tenThousandReasons'),
        WorshipSoundBed.tenThousandReasons,
      );
      expect(prayerSoundBedFor('oceanWaves'), MeditationSoundBed.oceanWaves);
    });

    test('an unknown key is silence rather than a guess', () {
      expect(prayerSoundBedFor('beStillMySoul'), isNull);
      expect(prayerSoundBedFor(''), isNull);
    });
  });
}
