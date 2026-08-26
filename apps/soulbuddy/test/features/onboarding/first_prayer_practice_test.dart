import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/onboarding/presentation/first_prayer_result_page.dart';
import 'package:soulbuddy/features/onboarding/providers/first_prayer_providers.dart';
import 'package:soulbuddy/features/onboarding/presentation/first_prayer_practice_page.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';

void main() {
  testWidgets('places the practice directly beneath its title', (tester) async {
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FirstPrayerPracticePage(
            action: 'Call your sister before evening.',
            onContinue: () => continued = true,
          ),
        ),
      ),
    );

    expect(find.text('Practice'), findsOneWidget);
    expect(find.text('Call your sister before evening.'), findsOneWidget);
    final titleBottom = tester.getBottomLeft(find.text('Practice')).dy;
    final practiceTop = tester
        .getTopLeft(find.text('Call your sister before evening.'))
        .dy;
    expect(practiceTop - titleBottom, lessThanOrEqualTo(16));

    await tester.tap(find.text('Continue'));
    expect(continued, isTrue);
  });

  testWidgets('a failed keep stays on the prayer with a retry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FirstPrayerResultPage(
            prayer: const FirstPrayerResult(
              title: 'For guidance',
              body: 'Father, guide me. Amen.',
              grounding: PrayerGrounding.generalChristian,
              purpose: PrayerPurpose.guidance,
              reference: PrayerReference.library('prayer-id'),
            ),
            onPray: () async => false,
            onKeep: () async => false,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Keep this prayer'));
    await tester.pump();

    expect(find.text('For guidance'), findsOneWidget);
    expect(find.text("Couldn't keep this prayer. Try again."), findsOneWidget);
    expect(find.text('Keep this prayer'), findsOneWidget);
  });
}
