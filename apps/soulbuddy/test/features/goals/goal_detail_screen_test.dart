import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/presentation/goal_detail_screen.dart';
import 'package:soulbuddy/features/goals/providers/goal_providers.dart';
import 'package:soulbuddy/features/guards/application/return_plan.dart';
import 'package:soulbuddy/features/guards/providers/return_providers.dart';

void main() {
  testWidgets('Goal detail remains usable at 320px and 200 percent text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final goal = _goal();
    final plan = ReturnPlanBuilder.build(
      goal: goal,
      actions: const [],
      links: const [],
      guardSelections: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goalProvider(goal.id).overrideWith((ref) => Stream.value(goal)),
          goalReturnPlanProvider(
            goal.id,
          ).overrideWith((ref) => AsyncData(plan)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(body: GoalDetailScreen(goalId: goal.id)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Scrollable), findsWidgets);
    expect(find.text(goal.title), findsOneWidget);
    expect(find.text('What is happening now'), findsOneWidget);
    expect(find.text('Why this matters'), findsOneWidget);
    expect(find.byKey(const Key('goal-return')), findsNothing);
    expect(tester.takeException(), isNull);

    expect(find.byKey(const Key('edit-goal')), findsOneWidget);
    expect(find.byKey(const Key('pause-goal')), findsNothing);
    expect(find.byKey(const Key('complete-goal')), findsNothing);
    expect(find.byKey(const Key('goal-prayer-library')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('goal-more-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal-more-actions')));
    await tester.pumpAndSettle();
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    await tester.tapAt(const Offset(12, 12));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('edit-goal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-goal')));
    await tester.pumpAndSettle();
    expect(find.text('Edit Goal'), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);

    await tester.enterText(find.byKey(const Key('edit-goal-title')), '   ');
    await tester.pump();
    final save = tester.widget<FilledButton>(
      find.byKey(const Key('edit-goal-save')),
    );
    expect(save.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stop-control Goal exposes the five-step Return flow', (
    tester,
  ) async {
    final goal = _goal(starterKey: GoalStarterKey.stopControl);
    final plan = ReturnPlanBuilder.build(
      goal: goal,
      actions: const [],
      links: const [],
      guardSelections: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goalProvider(goal.id).overrideWith((ref) => Stream.value(goal)),
          goalReturnPlanProvider(
            goal.id,
          ).overrideWith((ref) => AsyncData(plan)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: GoalDetailScreen(goalId: goal.id)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goal-return')), findsOneWidget);
    await tester.tap(find.byKey(const Key('goal-return')));
    await tester.pumpAndSettle();

    expect(find.text('Return'), findsWidgets);
    expect(find.text('Move'), findsOneWidget);
    expect(find.text('Close the door'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Goal _goal({GoalStarterKey? starterKey}) => Goal(
  id: starterKey == GoalStarterKey.stopControl
      ? 'goal-detail-return'
      : 'goal-detail-large-text',
  ownerId: 'owner-1',
  starterKey: starterKey,
  mode: GoalMode.mixed,
  status: GoalStatus.active,
  currentRevisionId: 'revision-goal-detail-large-text',
  position: 0,
  title: 'Choose the next faithful step without rushing the decision',
  currentSituation:
      'I am carrying several responsibilities at once and need to decide what '
      'deserves attention first without turning urgency into anxiety.',
  whyItMatters:
      'I want the next decision to be clear, faithful, practical, and small '
      'enough to act on rather than becoming another abstract plan.',
  createdAt: DateTime.utc(2026, 8, 29, 6),
  updatedAt: DateTime.utc(2026, 8, 29, 6),
);
