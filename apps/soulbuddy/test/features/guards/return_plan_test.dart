import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/domain/goal_action.dart';
import 'package:soulbuddy/features/goals/domain/goal_link.dart';
import 'package:soulbuddy/features/guards/application/return_plan.dart';
import 'package:soulbuddy/features/guards/domain/guard_definition.dart';

void main() {
  test(
    'stop-control Goal is Return-relevant before every step is configured',
    () {
      final plan = ReturnPlanBuilder.build(
        goal: _goal(starterKey: GoalStarterKey.stopControl),
        actions: const [],
        links: const [],
        guardSelections: const [],
      );

      expect(plan.relevant, isTrue);
      expect(plan.hasCloseTheDoorStep, isFalse);
      expect(plan.hasReturnToGodStep, isFalse);
      expect(plan.hasReplacementStep, isFalse);
      expect(plan.hasDoNotHideStep, isFalse);
    },
  );

  test('Return plan reuses Goal actions, links, and selected guards', () {
    final goal = _goal(starterKey: GoalStarterKey.stopControl);
    final plan = ReturnPlanBuilder.build(
      goal: goal,
      actions: [
        _action(
          'guard',
          goal.id,
          GoalActionKind.guard,
          'Leave the phone outside',
        ),
        _action(
          'replacement',
          goal.id,
          GoalActionKind.nextStep,
          'Walk outside',
        ),
        _action(
          'accountability',
          goal.id,
          GoalActionKind.accountability,
          'Message my accountability partner',
        ),
      ],
      links: [
        GoalLink(
          id: 'scripture',
          goalId: goal.id,
          ownerId: goal.ownerId,
          type: GoalLinkType.scripture,
          role: GoalLinkRole.reference,
          translation: 'RSVCE',
          book: 'James',
          chapter: 1,
          firstVerse: 5,
          lastVerse: 5,
          createdAt: DateTime.utc(2026, 8, 29),
        ),
      ],
      guardSelections: [
        GoalGuardSelection(
          id: 'selection',
          goalId: goal.id,
          ownerId: goal.ownerId,
          guardDefinitionId: 'dns-cleanbrowsing-family',
          guardContentVersion: 1,
          configuredAt: DateTime.utc(2026, 8, 29),
        ),
      ],
    );

    expect(plan.barrierAction?.id, 'guard');
    expect(plan.spiritualResource?.id, 'scripture');
    expect(plan.replacementAction?.id, 'replacement');
    expect(plan.accountabilityAction?.id, 'accountability');
    expect(plan.guardSelections, hasLength(1));
    expect(plan.hasCloseTheDoorStep, isTrue);
    expect(plan.hasReturnToGodStep, isTrue);
    expect(plan.hasReplacementStep, isTrue);
    expect(plan.hasDoNotHideStep, isTrue);
  });

  test('ordinary Goal does not gain Return from unrelated work', () {
    final goal = _goal(starterKey: GoalStarterKey.direction);
    final plan = ReturnPlanBuilder.build(
      goal: goal,
      actions: [
        _action('step', goal.id, GoalActionKind.nextStep, 'Review the options'),
      ],
      links: const [],
      guardSelections: const [],
    );

    expect(plan.relevant, isFalse);
  });
}

Goal _goal({GoalStarterKey? starterKey}) => Goal(
  id: 'goal-1',
  ownerId: 'owner-1',
  starterKey: starterKey,
  mode: GoalMode.mixed,
  status: GoalStatus.active,
  currentRevisionId: 'revision-1',
  position: 0,
  title: 'Goal',
  createdAt: DateTime.utc(2026, 8, 29),
  updatedAt: DateTime.utc(2026, 8, 29),
);

GoalAction _action(
  String id,
  String goalId,
  GoalActionKind kind,
  String body,
) => GoalAction(
  id: id,
  goalId: goalId,
  ownerId: 'owner-1',
  body: body,
  kind: kind,
  scheduleType: GoalScheduleType.none,
  enabled: true,
  createdAt: DateTime.utc(2026, 8, 29),
  updatedAt: DateTime.utc(2026, 8, 29),
);
