import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/formation/data/formation_progress_repository.dart';
import 'package:soulbuddy/features/formation/presentation/formation_reading_screen.dart';
import 'package:soulbuddy/features/formation/providers/formation_providers.dart';
import 'package:soulbuddy/features/prayers/application/meditation_sound_bed_player.dart';
import 'package:soulbuddy/features/prayers/application/meditation_sound_preferences.dart';
import 'package:soulbuddy/features/prayers/domain/meditation_session.dart';
import 'package:soulbuddy/features/scripture/data/scripture_repository.dart';
import 'package:soulbuddy/features/scripture/domain/scripture_passage.dart';
import 'package:soulbuddy/features/scripture/providers/scripture_providers.dart';

void main() {
  testWidgets(
    'reflection selection persists, stops on tab switch and restores on return',
    (tester) async {
      String? stored;
      final preferences = MeditationSoundPreferencesRepository(
        read: (_) async => stored,
        write: (_, value) async => stored = value,
      );
      final player = _Player();
      Widget app(bool visible) => ProviderScope(
        overrides: [
          meditationSoundPreferencesProvider.overrideWithValue(preferences),
          formationProgressProvider.overrideWith(
            (_) async => const FormationProgress({}),
          ),
          scriptureRepositoryProvider.overrideWithValue(_Scripture()),
        ],
        child: MaterialApp(
          home: TickerMode(
            enabled: visible,
            child: FormationReadingScreen(soundPlayer: player),
          ),
        ),
      );
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
      find.byKey(const Key('meditation-sound-picker')),
      250,
      scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('meditation-sound-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flowing water'));
      await tester.pumpAndSettle();
      expect((await preferences.load()).sound, MeditationSoundBed.flowingWater);
      expect(player.playing, MeditationSoundBed.flowingWater);
      await tester.pumpWidget(app(false));
      expect(player.playing, isNull);
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      expect(player.playing, MeditationSoundBed.flowingWater);
      await tester.tap(find.byKey(const Key('meditation-sound-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No background sound'));
      await tester.pumpAndSettle();
      expect(player.playing, isNull);
      expect((await preferences.load()).sound, isNull);
    },
  );

  testWidgets(
    'sound preview also stops when a retained reading becomes hidden',
    (tester) async {
      final preferences = MeditationSoundPreferencesRepository(
        read: (_) async => null,
        write: (_, _) async {},
      );
      final player = _Player();
      final active = ValueNotifier(true);
      addTearDown(active.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meditationSoundPreferencesProvider.overrideWithValue(preferences),
            formationProgressProvider.overrideWith(
              (_) async => const FormationProgress({}),
            ),
            scriptureRepositoryProvider.overrideWithValue(_Scripture()),
          ],
          child: MaterialApp(
            home: ValueListenableBuilder<bool>(
              valueListenable: active,
              builder: (_, visible, _) => TickerMode(
                enabled: visible,
                child: FormationReadingScreen(soundPlayer: player),
              ),
            ),
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
      await tester.tap(find.byTooltip('Preview Stillness'));
      await tester.pump();
      expect(player.playing, MeditationSoundBed.stillness);
      active.value = false;
      await tester.pump();
      expect(player.playing, isNull);
    },
  );
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
