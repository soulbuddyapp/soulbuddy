import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/sacred_hours/application/sacred_hour_session_controller.dart';
import 'package:soulbuddy/features/sacred_hours/domain/sacred_hour.dart';
import 'package:soulbuddy/features/sacred_hours/presentation/sacred_hour_session_screen.dart';

void main() {
  test(
    'derives prayer time from timestamps and never completes it silently',
    () {
      var now = DateTime.utc(2026, 8, 31, 5);
      final controller = SacredHourSessionController(
        prayerMinutes: 5,
        clock: () => now,
      );
      controller.beginPrayer();
      expect(controller.remaining, const Duration(minutes: 5));
      now = now.add(const Duration(minutes: 6));
      expect(controller.remaining, Duration.zero);
      expect(controller.state.prayerRecorded, isFalse);
      controller.continueToWork();
      expect(controller.state.phase, SacredHourSessionPhase.work);
    },
  );

  test('moves to meditation only after prayer recording succeeds', () async {
    final controller = SacredHourSessionController(prayerMinutes: 5);

    await controller.recordPrayer(() async {});

    expect(controller.state.prayerRecorded, isTrue);
    expect(controller.state.phase, SacredHourSessionPhase.work);
  });

  testWidgets('moves from prayer into work without shame or scoring', (
    tester,
  ) async {
    var prayed = 0;
    String? remembranceMode;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SacredHourSessionView(
          hour: _hour(),
          controller: SacredHourSessionController(prayerMinutes: 5),
          onRecordPrayer: () async => prayed += 1,
          onRemember: (mode) => remembranceMode = mode,
        ),
      ),
    );

    expect(find.text('Begin with prayer'), findsOneWidget);
    expect(find.text('5:00'), findsOneWidget);
    expect(find.text('Quiet prayer'), findsOneWidget);
    expect(find.text('I prayed'), findsOneWidget);
    await tester.tap(find.text('I prayed'));
    await tester.pump();
    expect(prayed, 1);
    expect(find.text('Continue to work'), findsNothing);
    expect(find.text('God speaks to us in meditation'), findsOneWidget);
    expect(
      find.text('Listen to know if your prayer needs something from you'),
      findsOneWidget,
    );
    for (final prompt in const [
      'Why might God have placed me in this work?',
      'Who can I serve through it today?',
      'What needs patience, courage, honesty, or care?',
      'What may God be teaching me here?',
    ]) {
      expect(find.text(prompt), findsOneWidget);
    }
    expect(find.textContaining('missed'), findsNothing);
    expect(find.textContaining('streak'), findsNothing);
    await tester.tap(find.text('Speak'));
    expect(remembranceMode, 'speak');
  });

  testWidgets('wraps long work prompts on a phone-width screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = SacredHourSessionController(prayerMinutes: 5)
      ..continueToWork();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SacredHourSessionView(
          hour: _hour(),
          controller: controller,
          onRecordPrayer: () async {},
          onRemember: (_) {},
        ),
      ),
    );

    const prompt = 'What needs patience, courage, honesty, or care?';
    final paragraph = tester.renderObject<RenderParagraph>(find.text(prompt));
    final boxes = paragraph.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: prompt.length),
    );
    expect(boxes.map((box) => box.top.round()).toSet().length, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens prayer and music from the prayer phase', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SacredHourSessionView(
          hour: _hour(),
          controller: SacredHourSessionController(prayerMinutes: 5),
          onRecordPrayer: () async {},
          onRemember: (_) {},
          onPrayerMusic: () => opened += 1,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('sacred-hour-prayer-music')));
    expect(opened, 1);
  });
}

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
