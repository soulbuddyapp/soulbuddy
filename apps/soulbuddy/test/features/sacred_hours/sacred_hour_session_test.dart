import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soulbuddy/features/record/audio/application/audio_capture_controller.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';
import '../../helpers/fake_inline_recorder.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/sacred_hours/application/sacred_hour_session_controller.dart';
import 'package:soulbuddy/features/sacred_hours/domain/sacred_hour.dart';
import 'package:soulbuddy/features/sacred_hours/presentation/sacred_hour_session_screen.dart';

void main() {
  test('moves to meditation only after prayer recording succeeds', () async {
    final controller = SacredHourSessionController(prayerMinutes: 5);
    await controller.recordPrayer(() async {});
    expect(controller.state.prayerRecorded, isTrue);
    expect(controller.state.phase, SacredHourSessionPhase.work);
  });

  testWidgets('shows the selected prayer audio control', (tester) async {
    await tester.pumpWidget(
      _subject(prayerAudio: const Text('Selected prayer audio')),
    );
    expect(find.text('Selected prayer audio'), findsOneWidget);
  });

  testWidgets('keeps the prayer moment quiet and focused', (tester) async {
    var prayerChoices = 0;
    var soundChoices = 0;
    await tester.pumpWidget(
      _subject(
        onPrayer: () => prayerChoices += 1,
        onSound: () => soundChoices += 1,
      ),
    );

    expect(find.byKey(const Key('sacred-hour-portal')), findsOneWidget);
    expect(find.text('We belong to God.'), findsOneWidget);
    expect(find.byKey(const Key('sacred-hour-prayer-choice')), findsOneWidget);
    expect(find.byKey(const Key('sacred-hour-sound-choice')), findsOneWidget);
    expect(find.text("I've prayed"), findsOneWidget);
    expect(find.text('Begin with prayer'), findsNothing);
    expect(find.text('Quiet prayer'), findsNothing);
    expect(find.text('Daily practice'), findsNothing);
    expect(find.text('Open prayer'), findsNothing);

    await tester.tap(find.byKey(const Key('sacred-hour-prayer-choice')));
    await tester.tap(find.byKey(const Key('sacred-hour-sound-choice')));
    expect(prayerChoices, 1);
    expect(soundChoices, 1);
  });

  testWidgets('moves directly into one reflection prompt after prayer', (
    tester,
  ) async {
    var prayed = 0;
    final recorder = FakeInlineRecorder();
    final audio = AudioCaptureController(
      recorder: recorder,
      allocateTemporary: () async =>
          const TemporaryAudio(key: 'take', locator: '/take'),
    );
    addTearDown(audio.close);
    await tester.pumpWidget(
      _subject(onRecord: () async => prayed += 1, audioController: audio),
    );
    await tester.tap(find.text("I've prayed"));
    await tester.pump();

    expect(prayed, 1);
    expect(find.text('God speaks to us in meditation'), findsOneWidget);
    expect(
      find.text('Listen to know if your prayer needs something from you'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('sacred-hour-reflection-prompt')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('sacred-hour-reflection-prompt')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(recorder.started, isFalse);
    await tester.ensureVisible(find.text('Record reflection'));
    await tester.tap(find.text('Record reflection'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(recorder.started, isTrue);
    expect(find.byKey(const Key('audio-live-level')), findsOneWidget);
    await tester.ensureVisible(find.text('Stop'));
    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(
      find.byKey(const Key('recording-soundscape-flowingWater')),
      findsNothing,
    );
    await audio.cancel();
  });

  testWidgets('stays usable at phone width and large text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _subject(),
      ),
    );
    expect(find.byKey(const Key('sacred-hour-prayed')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _subject({
  Future<void> Function()? onRecord,
  VoidCallback? onPrayer,
  VoidCallback? onSound,
  Widget? prayerAudio,
  AudioCaptureController? audioController,
}) => ProviderScope(
  overrides: [
    if (audioController != null)
      inlineAudioCaptureControllerProvider.overrideWith(
        (ref, key) async => audioController,
      ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: SacredHourSessionView(
      hour: _hour(),
      controller: SacredHourSessionController(prayerMinutes: 5),
      onRecordPrayer: onRecord ?? () async {},
      onExit: () {},
      onPrayer: onPrayer ?? () {},
      onSound: onSound ?? () {},
      onSoundPlayback: () {},
      soundLabel: 'Silence',
      soundPlaying: false,
      prayerPlaying: false,
      prayerAudio: prayerAudio,
    ),
  ),
);

SacredHour _hour() => SacredHour(
  id: 'hour-1',
  ownerId: 'owner',
  purpose: SacredHourPurpose.morning,
  name: 'Morning Sacred Hour',
  localTime: PrayerLocalTime(hour: 6, minute: 0),
  timezone: 'Africa/Lagos',
  durationMinutes: 60,
  prayerMinutes: 5,
  enabled: true,
  sound: SacredHourSound.gentleChime,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
