import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/domain/meditation_session.dart';
import 'package:soulbuddy/features/prayers/presentation/meditation_sound_picker.dart';

void main() {
  testWidgets('uses one compact picker and groups motivational music', (
    tester,
  ) async {
    MeditationSoundBed? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MeditationSoundPicker(
            selected: null,
            onSelected: (value) async => selected = value,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('meditation-sound-picker')), findsOneWidget);
    expect(find.text('No background sound'), findsOneWidget);
    expect(find.text('Aurora'), findsNothing);

    await tester.tap(find.byKey(const Key('meditation-sound-picker')));
    await tester.pumpAndSettle();
    expect(find.text('Quiet ambience'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -480));
    await tester.pumpAndSettle();
    expect(find.text('Motivational music'), findsOneWidget);

    await tester.ensureVisible(find.text('Aurora'));
    await tester.tap(find.text('Aurora'));
    await tester.pumpAndSettle();
    expect(selected, MeditationSoundBed.cinematicRise);
  });

  testWidgets('choosing the current option stops any preview', (tester) async {
    final selections = <MeditationSoundBed?>[];
    final previews = <MeditationSoundBed>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MeditationSoundPicker(
            selected: null,
            onSelected: (value) async => selections.add(value),
            onPreview: (value) async => previews.add(value),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('meditation-sound-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Preview Stillness'));
    await tester.pump();
    await tester.tap(find.text('No background sound').last);
    await tester.pumpAndSettle();

    expect(previews, [MeditationSoundBed.stillness]);
    expect(selections, [null]);
  });
}
