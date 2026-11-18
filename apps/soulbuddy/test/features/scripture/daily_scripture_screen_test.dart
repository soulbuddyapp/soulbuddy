import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/application/meditation_sound_bed_player.dart';
import 'package:soulbuddy/features/prayers/application/meditation_sound_preferences.dart';
import 'package:soulbuddy/features/prayers/domain/meditation_session.dart';
import 'package:soulbuddy/features/scripture/domain/daily_scripture.dart';
import 'package:soulbuddy/features/scripture/presentation/daily_scripture_screen.dart';
import 'package:soulbuddy/features/scripture/providers/daily_scripture_providers.dart';

void main() {
  final entry =
      (jsonDecode(
                    File(
                      'assets/content/daily_scriptures.json',
                    ).readAsStringSync(),
                  )
                  as List)
              .first
          as Map<String, dynamic>;
  final scripture = DailyScripture.fromJson({...entry, 'date': '2026-09-11'});
  testWidgets('personal prayer opens within daily scripture', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyScriptureProvider.overrideWith((_) async => scripture),
        ],
        child: MaterialApp(home: DailyScriptureScreen(soundPlayer: _Player())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Personal prayer'));
    await tester.tap(find.text('Personal prayer'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scripture-prayer-editor')), findsOneWidget);
    expect(find.byType(DailyScriptureScreen), findsOneWidget);
  });
  testWidgets(
    'reading shows scripture before reflection sound and stops audio when hidden',
    (tester) async {
      final player = _Player();
      String? stored;
      final preferences = MeditationSoundPreferencesRepository(
        read: (_) async => stored,
        write: (_, value) async => stored = value,
      );
      Widget app(bool visible) => ProviderScope(
        overrides: [
          dailyScriptureProvider.overrideWith((_) async => scripture),
          meditationSoundPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          home: TickerMode(
            enabled: visible,
            child: DailyScriptureScreen(soundPlayer: player),
          ),
        ),
      );
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      expect(find.text(scripture.reference), findsOneWidget);
      expect(find.text(scripture.text), findsOneWidget);
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
      expect(tester.takeException(), isNull);
    },
  );
}

class _Player implements MeditationSoundBedPlayer {
  MeditationSoundBed? playing;
  @override
  Future<void> start(MeditationSoundBed sound, {required double volume}) async {
    playing = sound;
  }

  @override
  Future<void> stop() async {
    playing = null;
  }

  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> dispose() async {
    playing = null;
  }
}
