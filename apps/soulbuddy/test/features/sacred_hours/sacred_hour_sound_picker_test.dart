import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/sacred_hours/application/sacred_hour_sound_player.dart';
import 'package:soulbuddy/features/sacred_hours/domain/sacred_hour.dart';
import 'package:soulbuddy/features/sacred_hours/presentation/sacred_hour_sound_picker.dart';

void main() {
  testWidgets('offers the four original chimes, device sound, and silent', (
    tester,
  ) async {
    final player = _Player();
    var selected = SacredHourSound.gentleChime;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SacredHourSoundPicker(
            selected: selected,
            soundsEnabled: true,
            player: player,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    for (final label in const [
      'Gentle Chime',
      'Dawn',
      'Still Bell',
      'Evening',
      'Device sound',
      'Silent',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byTooltip('Play'), findsNWidgets(4));
    await tester.tap(find.byKey(const Key('sound-preview-dawn_chime')));
    await tester.pump();
    expect(player.played, [SacredHourSound.dawnChime]);
    expect(find.byTooltip('Stop'), findsOneWidget);
    await tester.tap(find.byTooltip('Stop'));
    expect(player.stops, 2);
  });

  testWidgets('does not preview when in-app sounds are off', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SacredHourSoundPicker(
            selected: SacredHourSound.gentleChime,
            soundsEnabled: false,
            player: _Player(),
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.textContaining('Turn on in-app sounds'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('sound-preview-gentle_chime')),
          )
          .onPressed,
      isNull,
    );
  });
}

class _Player implements SacredHourSoundPlayer {
  final played = <SacredHourSound>[];
  var stops = 0;

  @override
  Future<void> play(SacredHourSound sound) async => played.add(sound);
  @override
  Future<void> stop() async => stops += 1;
  @override
  Future<void> dispose() async {}
}
