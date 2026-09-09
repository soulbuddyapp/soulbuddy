import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/domain/meditation_session.dart';
import 'package:soulbuddy/features/prayers/domain/voice_tablet.dart';
import 'package:soulbuddy/features/prayers/presentation/meditation_session_sheet.dart';

void main() {
  test('ships a broad set of restrained meditation sound beds', () {
    expect(MeditationSoundBed.values.map((bed) => bed.label), [
      'Stillness',
      'Flowing water',
      'Gentle rain',
      'Ocean waves',
      'Forest morning',
      'Soft wind',
      'Warm fireplace',
      'Night crickets',
      'Hopeful piano',
      'Cinematic rise',
      'Steady resolve',
      'Warm strings',
      'Victorious calm',
    ]);
    expect(
      MeditationSoundBed.values.every(
        (bed) => bed.assetPath.startsWith('audio/meditation/'),
      ),
      isTrue,
    );
    expect(
      MeditationSoundBed.values
          .where((bed) => bed.category == MeditationSoundCategory.motivational)
          .length,
      5,
    );
    expect(
      MeditationSoundBed.cinematicRise.preferredVolume,
      lessThanOrEqualTo(0.22),
    );
  });

  testWidgets('keeps prompts optional and begins with a subtle sound bed', (
    tester,
  ) async {
    MeditationSessionRequest? started;
    await tester.pumpWidget(
      _app(
        MeditationSessionSheet(
          tablet: _tablet(),
          selectedAudio: _tablet().fullAudio!,
          onStart: (request) async => started = request,
        ),
      ),
    );

    expect(find.text('Pray and remain'), findsOneWidget);
    expect(find.text('Remember what God has done.'), findsNothing);
    await tester.tap(find.text('Stillness'));
    await tester.tap(find.text('Add a prompt'));
    await tester.pump();
    await tester.ensureVisible(find.text('Remember what God has done.'));
    await tester.tap(find.text('Remember what God has done.'));
    await tester.ensureVisible(find.byKey(const Key('begin-meditation')));
    await tester.tap(find.byKey(const Key('begin-meditation')));
    await tester.pump();

    expect(started, isNotNull);
    expect(started!.soundBed, MeditationSoundBed.stillness);
    expect(started!.soundVolume, 0.15);
    expect(started!.includeVoice, isTrue);
    expect(started!.repeatRefrain, isFalse);
    expect(started!.prompt, MeditationPrompt.remember);
  });

  testWidgets('can use sound without claiming it is prayer', (tester) async {
    MeditationSessionRequest? started;
    await tester.pumpWidget(
      _app(
        MeditationSessionSheet(
          tablet: _tablet(),
          selectedAudio: _tablet().fullAudio!,
          onStart: (request) async => started = request,
        ),
      ),
    );

    await tester.drag(
      find.byKey(const Key('meditation-sound-list')),
      const Offset(-220, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flowing water'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('meditation-include-voice')));
    await tester.ensureVisible(find.byKey(const Key('begin-meditation')));
    await tester.tap(find.byKey(const Key('begin-meditation')));
    await tester.pump();

    expect(started!.includeVoice, isFalse);
    expect(started!.voiceAudio, isNull);
    expect(find.textContaining('healing frequency'), findsNothing);
    expect(find.text('I prayed'), findsNothing);
  });
}

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 390, child: child)),
  ),
);

VoiceTablet _tablet() => VoiceTablet(
  id: 'tablet-1',
  ownerId: 'owner-1',
  source: VoiceTabletSource.personal(
    prayerId: 'prayer-1',
    revisionId: 'revision-1',
  ),
  title: 'Morning prayer',
  fullAudio: _audio(VoiceTabletAudioKind.fullPrayer, 'full'),
  refrainAudio: _audio(VoiceTabletAudioKind.refrain, 'refrain'),
  createdAt: DateTime.utc(2026, 8, 26),
  updatedAt: DateTime.utc(2026, 8, 26),
);

VoiceTabletAudio _audio(VoiceTabletAudioKind kind, String id) =>
    VoiceTabletAudio(
      id: id,
      kind: kind,
      storageKey: 'private/$id.m4a',
      mimeType: 'audio/mp4',
      duration: const Duration(seconds: 12),
      byteSize: 1200,
      waveform: const [0.2, 0.7, 0.4],
      createdAt: DateTime.utc(2026, 8, 26),
    );
