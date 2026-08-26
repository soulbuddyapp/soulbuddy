import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  testWidgets('guides a new person through the three SoulBuddy scenes', (
    tester,
  ) async {
    var beganWithPrayer = false;
    var skipped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: OnboardingScreen(
          onBeginWithPrayer: () async => beganWithPrayer = true,
          onSkip: () async => skipped = true,
        ),
      ),
    );

    expect(find.text('A place to return to God'), findsOneWidget);
    expect(find.text('SoulBuddy'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Go to Today'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Remember what God has done'), findsOneWidget);
    expect(find.textContaining('Abraham built altars'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Carry prayer into life'), findsOneWidget);
    expect(find.text('Prepare my first prayer'), findsOneWidget);

    await tester.tap(find.text('Prepare my first prayer'));
    await tester.pumpAndSettle();
    expect(beganWithPrayer, isTrue);
    expect(skipped, isFalse);
  });

  testWidgets('top action is a quiet way into Today', (tester) async {
    var skipped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: OnboardingScreen(
          onBeginWithPrayer: () async {},
          onSkip: () async => skipped = true,
        ),
      ),
    );

    await tester.tap(find.text('Go to Today'));
    await tester.pumpAndSettle();

    expect(skipped, isTrue);
  });

  testWidgets('welcome remains usable on a small screen at large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: OnboardingScreen(
            onBeginWithPrayer: () async {},
            onSkip: () async {},
          ),
        ),
      ),
    );

    expect(find.byType(Scrollable), findsWidgets);
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
