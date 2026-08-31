import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/sacred_hours/domain/sacred_hour.dart';
import 'package:soulbuddy/features/sacred_hours/presentation/sacred_hour_today_card.dart';

void main() {
  testWidgets('shows the next hour as a compact preparation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SacredHourTodayCard(
            hour: _hour(),
            nowUtc: DateTime.utc(2026, 8, 31, 4),
            onOpen: () {},
          ),
        ),
      ),
    );
    expect(find.text('Morning Sacred Hour'), findsOneWidget);
    expect(find.text('6:00–7:00am'), findsOneWidget);
    expect(find.text('Prepare'), findsOneWidget);
    expect(find.textContaining('missed'), findsNothing);
  });

  testWidgets('uses Begin during the hour and Continue after starting', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SacredHourTodayCard(
            hour: _hour(),
            nowUtc: DateTime.utc(2026, 8, 31, 5, 15),
            onOpen: () {},
          ),
        ),
      ),
    );
    expect(find.text('Begin'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SacredHourTodayCard(
            hour: _hour(),
            nowUtc: DateTime.utc(2026, 8, 31, 5, 15),
            continued: true,
            onOpen: () {},
          ),
        ),
      ),
    );
    expect(find.text('Continue'), findsOneWidget);
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
  prayerMinutes: 15,
  enabled: true,
  sound: SacredHourSound.gentleChime,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
