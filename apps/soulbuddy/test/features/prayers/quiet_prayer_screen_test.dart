import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/application/meditation_sound_bed_player.dart';
import 'package:soulbuddy/features/prayers/domain/meditation_session.dart';
import 'package:soulbuddy/features/prayers/presentation/quiet_prayer_screen.dart';

void main() {
  testWidgets(
    'quiet prayer starts silent, plays selected sound and stops when hidden',
    (tester) async {
      final player = _Player();
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (_, value, _) => TickerMode(
              enabled: value,
              child: QuietPrayerScreen(soundPlayer: player),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(player.playing, isNull);
      expect(find.text('Be still'), findsOneWidget);
      await tester.tap(find.byKey(const Key('meditation-sound-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flowing water'));
      await tester.pumpAndSettle();
      expect(player.playing, MeditationSoundBed.flowingWater);
      visible.value = false;
      await tester.pump();
      expect(player.playing, isNull);
      visible.value = true;
      await tester.pump();
      expect(player.playing, MeditationSoundBed.flowingWater);
      await tester.pumpWidget(const SizedBox());
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
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> dispose() => stop();
}
