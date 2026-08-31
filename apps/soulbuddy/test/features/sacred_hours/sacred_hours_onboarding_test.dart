import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/sacred_hours/presentation/sacred_hours_onboarding_page.dart';

void main() {
  testWidgets('teaches Sacred Hours with two useful defaults', (tester) async {
    var selection = SacredHoursOnboardingSelection.defaults();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SacredHoursOnboardingPage(
            selection: selection,
            onChanged: (value) => selection = value,
          ),
        ),
      ),
    );

    expect(find.text('Set apart an hour'), findsOneWidget);
    expect(find.textContaining('Pray first.'), findsOneWidget);
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('6:00–7:00am'), findsOneWidget);
    expect(find.text('Evening'), findsOneWidget);
    expect(find.text('10:00–11:00pm'), findsOneWidget);
    expect(find.text('5 min'), findsNWidgets(2));
    expect(find.text('15 min'), findsNWidgets(2));
    expect(find.text('30 min'), findsNWidgets(2));
  });

  testWidgets('lets each prayer opening be changed directly', (tester) async {
    var selection = SacredHoursOnboardingSelection.defaults();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: SacredHoursOnboardingPage(
              selection: selection,
              onChanged: (value) => setState(() => selection = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('morning-prayer-5')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('evening-prayer-30')));
    await tester.pump();

    expect(selection.morningPrayerMinutes, 5);
    expect(selection.eveningPrayerMinutes, 30);
  });

  testWidgets('edits a start time with the familiar system picker', (
    tester,
  ) async {
    var selection = SacredHoursOnboardingSelection.defaults();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: SacredHoursOnboardingPage(
              selection: selection,
              onChanged: (value) => setState(() => selection = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('morning-time-change')));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(selection.morningStart, PrayerLocalTime(hour: 6, minute: 0));
  });

  testWidgets('fits a standard phone and scrolls safely at 200 percent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
            body: SacredHoursOnboardingPage(
              selection: SacredHoursOnboardingSelection.defaults(),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('10:00–11:00pm'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SacredHoursOnboardingPage(
              selection: SacredHoursOnboardingSelection.defaults(),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
