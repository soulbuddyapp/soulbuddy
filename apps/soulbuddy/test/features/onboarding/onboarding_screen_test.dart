import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  testWidgets('guides a new person into a simple Sacred Hours setup', (
    tester,
  ) async {
    var beganWithGoal = false;
    var skipped = false;
    final cues = <OnboardingSensoryCue>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: OnboardingScreen(
          onBeginWithGoal: () async => beganWithGoal = true,
          onSkip: () async => skipped = true,
          onSensoryCue: (cue) async => cues.add(cue),
        ),
      ),
    );

    expect(find.text('Come as you are'), findsOneWidget);
    expect(find.textContaining('daily communion with God'), findsOneWidget);
    expect(find.text('SoulBuddy'), findsOneWidget);
    expect(find.text('Begin'), findsOneWidget);
    expect(find.text('Go to Today'), findsOneWidget);

    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();
    expect(find.text('Remember His deeds'), findsOneWidget);
    expect(
      find.textContaining('encounters, promises, Scripture'),
      findsOneWidget,
    );
    expect(cues, [OnboardingSensoryCue.step]);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Build a faithful rhythm'), findsOneWidget);
    for (final step in ['Bring', 'Pray', 'Act', 'Remember']) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.text('Continue'), findsOneWidget);
    expect(cues, [OnboardingSensoryCue.step, OnboardingSensoryCue.step]);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Set apart an hour'), findsOneWidget);
    expect(find.text('Keep these hours'), findsOneWidget);
    expect(cues.last, OnboardingSensoryCue.sacredHours);

    await tester.tap(find.text('Keep these hours'));
    await tester.pumpAndSettle();
    expect(beganWithGoal, isTrue);
    expect(skipped, isFalse);
    expect(cues.last, OnboardingSensoryCue.completed);
  });

  testWidgets('top action is a quiet way into Today', (tester) async {
    var skipped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: OnboardingScreen(
          onBeginWithGoal: () async {},
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
            onBeginWithGoal: () async {},
            onSkip: () async {},
          ),
        ),
      ),
    );

    expect(find.byType(Scrollable), findsWidgets);
    expect(find.text('Begin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a completed static visual when motion is reduced', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: OnboardingScreen(
            onBeginWithGoal: () async {},
            onSkip: () async {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('onboarding-visual-static-0')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-visual-motion-0')), findsNothing);
  });
}
