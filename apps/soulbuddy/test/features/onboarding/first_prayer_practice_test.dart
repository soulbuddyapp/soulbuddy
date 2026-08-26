import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/onboarding/presentation/first_prayer_practice_page.dart';

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
}
