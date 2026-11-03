import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/sacred_hours/domain/sacred_hour.dart';
import 'package:soulbuddy/features/sacred_hours/presentation/sacred_hour_prayer_music_sheet.dart';

void main() {
  testWidgets('prayer creation control stays in the picker while recording', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SacredHourPrayerPickerSheet(
            hour: _hour(),
            suggestions: [_prayer('Morning gratitude')],
            onChoosePrayer: (_) async {
              selected++;
            },
            onAddPrayer: (_) {},
            enabled: false,
            addPrayerControl: const Text('Recording prayer'),
            onClose: () {},
          ),
        ),
      ),
    );
    expect(find.text('Recording prayer'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Choose'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Close'))
          .onPressed,
      isNull,
    );
    expect(selected, 0);
  });
  testWidgets('chooses a suggested prayer without mixing sound controls', (
    tester,
  ) async {
    PrayerReference? selectedPrayer;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SacredHourPrayerPickerSheet(
            hour: _hour(),
            suggestions: [_prayer('Morning gratitude')],
            onChoosePrayer: (prayer) async => selectedPrayer = prayer.reference,
            onAddPrayer: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Choose prayer'), findsOneWidget);
    expect(find.text('Suggested prayers'), findsOneWidget);
    await tester.tap(find.text('Choose'));
    await tester.pump();
    expect(selectedPrayer, const PrayerReference.personal('morning-gratitude'));
    expect(find.text('Background sound'), findsNothing);
  });

  testWidgets('offers a new prayer with the sacred hour purpose', (
    tester,
  ) async {
    PrayerPurpose? addedFor;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SacredHourPrayerPickerSheet(
            hour: _hour(),
            suggestions: const [],
            onChoosePrayer: (_) async {},
            onAddPrayer: (purpose) => addedFor = purpose,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add a prayer'));
    expect(addedFor, PrayerPurpose.daily);
  });
}

SacredHour _hour() => SacredHour(
  id: 'hour-1',
  ownerId: 'owner-1',
  purpose: SacredHourPurpose.morning,
  name: 'Morning Sacred Hour',
  localTime: PrayerLocalTime(hour: 6, minute: 0),
  timezone: 'Africa/Lagos',
  durationMinutes: 60,
  prayerMinutes: 15,
  enabled: true,
  sound: SacredHourSound.gentleChime,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

PrayerDisplay _prayer(String title) => PrayerDisplayValue(
  reference: const PrayerReference.personal('morning-gratitude'),
  title: title,
  body: 'Thank you.',
  grounding: PrayerGrounding.generalChristian,
  purpose: PrayerPurpose.gratitude,
);
