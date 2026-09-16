import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    String? prompt;
    await tester.pumpWidget(
      _subject(
        onRecord: () async => prayed += 1,
        onRemember: (value) => prompt = value,
      ),
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
    expect(prompt, isNotNull);
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
  ValueChanged<String>? onRemember,
  VoidCallback? onPrayer,
  VoidCallback? onSound,
}) => MaterialApp(
  theme: AppTheme.light(),
  home: SacredHourSessionView(
    hour: _hour(),
    controller: SacredHourSessionController(prayerMinutes: 5),
    onRecordPrayer: onRecord ?? () async {},
    onRemember: onRemember ?? (_) {},
    onExit: () {},
    onPrayer: onPrayer ?? () {},
    onSound: onSound ?? () {},
    onSoundPlayback: () {},
    soundLabel: 'Silence',
    soundPlaying: false,
    prayerPlaying: false,
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
