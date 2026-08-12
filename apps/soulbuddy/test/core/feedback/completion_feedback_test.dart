import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/feedback/app_feedback.dart';
import 'package:soulbuddy/core/feedback/completion_feedback.dart';

void main() {
  testWidgets('completion feedback settles after one restrained animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CompletionFeedback(
            cue: AppFeedbackVisualCue.completion,
            animate: true,
            semanticLabel: 'Prayer time recorded',
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('completion-feedback-check')), findsOneWidget);
    expect(find.byKey(const Key('completion-feedback-ripple')), findsOneWidget);
    expect(find.bySemanticsLabel('Prayer time recorded'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('reduced motion renders an immediate check without ripple', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CompletionFeedback(
            cue: AppFeedbackVisualCue.check,
            animate: false,
            semanticLabel: 'Saved',
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('completion-feedback-check')), findsOneWidget);
    expect(find.byKey(const Key('completion-feedback-ripple')), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('rare eligibility uses no more than twelve brief light motes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CompletionFeedback(
            cue: AppFeedbackVisualCue.lightMotes,
            animate: true,
            semanticLabel: 'Prayer is ready to prepare for sharing',
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('completion-feedback-motes')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'completion-feedback-mote-',
            ),
      ),
      findsNWidgets(10),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(tester.binding.transientCallbackCount, 0);
  });
}
