import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/domain/goal_action.dart';
import 'package:soulbuddy/features/goals/domain/goal_link.dart';
import 'package:soulbuddy/features/goals/providers/goal_providers.dart';
import 'package:soulbuddy/features/guards/application/return_plan.dart';
import 'package:soulbuddy/features/guards/domain/guard_definition.dart';
import 'package:soulbuddy/features/guards/providers/guard_providers.dart';
import 'package:soulbuddy/features/guards/providers/return_providers.dart';

void main() {
  test('optional Return provider failures keep a stop-control Goal usable', () async {
    final goal = _goal();
    final container = ProviderContainer(
      overrides: [
        goalProvider(goal.id).overrideWith((ref) => Stream.value(goal)),
        goalReturnActionsProvider(goal.id).overrideWith(
          (ref) => Stream.error(StateError('actions unavailable')),
        ),
        goalReturnLinksProvider(goal.id).overrideWith(
          (ref) => Stream.error(StateError('links unavailable')),
        ),
        goalGuardSelectionsProvider(goal.id).overrideWith(
          (ref) => Stream.error(StateError('guards unavailable')),
        ),
      ],
    );
    addTearDown(container.dispose);

    final plan = await _nextPlan(
      container,
      goal.id,
      where: (value) => value.unavailableParts.length == 3,
    );

    expect(plan.relevant, isTrue);
    expect(plan.barrierAction, isNull);
    expect(plan.spiritualResource, isNull);
    expect(plan.replacementAction, isNull);
    expect(plan.accountabilityAction, isNull);
    expect(plan.guardSelections, isEmpty);
    expect(
      plan.unavailableParts,
      {
        ReturnPlanPart.actions,
        ReturnPlanPart.spiritualResources,
        ReturnPlanPart.guards,
      },
    );
  });

  test('available Return data replaces loading fallbacks deterministically', () async {
    final goal = _goal();
    final actionController = StreamController<List<GoalAction>>();
    final linkController = StreamController<List<GoalLink>>();
    final guardController = StreamController<List<GoalGuardSelection>>();
    addTearDown(actionController.close);
    addTearDown(linkController.close);
    addTearDown(guardController.close);

    final container = ProviderContainer(
      overrides: [
        goalProvider(goal.id).overrideWith((ref) => Stream.value(goal)),
        goalReturnActionsProvider(goal.id).overrideWith(
          (ref) => actionController.stream,
        ),
        goalReturnLinksProvider(goal.id).overrideWith(
          (ref) => linkController.stream,
        ),
        goalGuardSelectionsProvider(goal.id).overrideWith(
          (ref) => guardController.stream,
        ),
      ],
    );
    addTearDown(container.dispose);

    final first = await _nextPlan(container, goal.id);
    expect(first.relevant, isTrue);
    expect(first.unavailableParts, isEmpty);

    actionController.add([_action(goal.id)]);
    linkController.add(const []);
    guardController.add(const []);

    final resolved = await _nextPlan(
      container,
      goal.id,
      where: (value) => value.barrierAction != null,
    );
    expect(resolved.barrierAction?.body, 'Leave the room');
    expect(resolved.unavailableParts, isEmpty);
  });
}

Future<ReturnPlan> _nextPlan(
  ProviderContainer container,
  String goalId, {
  bool Function(ReturnPlan)? where,
}) async {
  final completer = Completer<ReturnPlan>();
  final subscription = container.listen(goalReturnPlanProvider(goalId), (
    previous,
    next,
  ) {
    if (next case AsyncData(:final value)) {
      if ((where == null || where(value)) && !completer.isCompleted) {
        completer.complete(value);
      }
    } else if (next case AsyncError(:final error, :final stackTrace)) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }
  }, fireImmediately: true);
  try {
    return await completer.future.timeout(const Duration(seconds: 2));
  } finally {
    subscription.close();
  }
}

Goal _goal() => Goal(
  id: 'return-provider-goal',
  ownerId: 'owner-1',
  starterKey: GoalStarterKey.stopControl,
  mode: GoalMode.mixed,
  status: GoalStatus.active,
  currentRevisionId: 'revision-1',
  position: 0,
  title: 'Stop something fighting to control me',
  createdAt: DateTime.utc(2026, 8, 29),
  updatedAt: DateTime.utc(2026, 8, 29),
);

GoalAction _action(String goalId) => GoalAction(
  id: 'guard-action',
  goalId: goalId,
  ownerId: 'owner-1',
  body: 'Leave the room',
  kind: GoalActionKind.guard,
  scheduleType: GoalScheduleType.none,
  enabled: true,
  createdAt: DateTime.utc(2026, 8, 29),
  updatedAt: DateTime.utc(2026, 8, 29),
);
