import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/presentation/goal_detail_screen.dart';
import 'package:soulbuddy/features/goals/providers/goal_providers.dart';

void main() {
  testWidgets('Goal detail remains usable at 320px and 200 percent text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final goal = _goal();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goalProvider(goal.id).overrideWith((ref) => Stream.value(goal)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: GoalDetailScreen(goalId: goal.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Scrollable), findsWidgets);
    expect(find.text(goal.title), findsOneWidget);
    expect(find.text('What is happening now'), findsOneWidget);
    expect(find.text('Why this matters'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final key in const [
      Key('edit-goal'),
      Key('pause-goal'),
      Key('complete-goal'),
      Key('goal-prayer-library'),
    ]) {
      await tester.ensureVisible(find.byKey(key));
      await tester.pumpAndSettle();
      expect(find.byKey(key).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

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
}

Goal _goal() => Goal(
  id: 'goal-detail-large-text',
  ownerId: 'owner-1',
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
