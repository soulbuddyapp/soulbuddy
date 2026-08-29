import '../../goals/domain/goal.dart';
import '../../goals/domain/goal_action.dart';
import '../../goals/domain/goal_link.dart';
import '../domain/guard_definition.dart';

enum ReturnPlanPart { actions, spiritualResources, guards }

class ReturnPlan {
  const ReturnPlan({
    required this.goal,
    required this.relevant,
    required this.guardSelections,
    this.barrierAction,
    this.spiritualResource,
    this.replacementAction,
    this.accountabilityAction,
    this.unavailableParts = const {},
  });

  final Goal goal;
  final bool relevant;
  final GoalAction? barrierAction;
  final GoalLink? spiritualResource;
  final GoalAction? replacementAction;
  final GoalAction? accountabilityAction;
  final List<GoalGuardSelection> guardSelections;
  final Set<ReturnPlanPart> unavailableParts;

  bool get hasCloseTheDoorStep =>
      barrierAction != null || guardSelections.isNotEmpty;
  bool get hasReturnToGodStep => spiritualResource != null;
  bool get hasReplacementStep => replacementAction != null;
  bool get hasDoNotHideStep => accountabilityAction != null;
  bool get isDegraded => unavailableParts.isNotEmpty;
}

abstract final class ReturnPlanBuilder {
  static ReturnPlan build({
    required Goal goal,
    required List<GoalAction> actions,
    required List<GoalLink> links,
    required List<GoalGuardSelection> guardSelections,
    Set<ReturnPlanPart> unavailableParts = const {},
  }) {
    final availableActions = actions
        .where(
          (action) =>
              action.goalId == goal.id &&
              action.enabled &&
              action.archivedAt == null,
        )
        .toList(growable: false);
    final availableLinks = links
        .where((link) => link.goalId == goal.id && link.archivedAt == null)
        .toList(growable: false);
    final activeGuards = guardSelections
        .where(
          (selection) =>
              selection.goalId == goal.id && selection.archivedAt == null,
        )
        .toList(growable: false);

    final barrier = _firstAction(availableActions, GoalActionKind.guard);
    final replacement = _firstAction(availableActions, GoalActionKind.nextStep);
    final accountability = _firstAction(
      availableActions,
      GoalActionKind.accountability,
    );
    final spiritual = _firstSpiritualResource(availableLinks);
    final relevant =
        goal.status != GoalStatus.archived &&
        (goal.starterKey == GoalStarterKey.stopControl ||
            barrier != null ||
            activeGuards.isNotEmpty);

    return ReturnPlan(
      goal: goal,
      relevant: relevant,
      barrierAction: barrier,
      spiritualResource: spiritual,
      replacementAction: replacement,
      accountabilityAction: accountability,
      guardSelections: List.unmodifiable(activeGuards),
      unavailableParts: Set.unmodifiable(unavailableParts),
    );
  }
}

GoalAction? _firstAction(List<GoalAction> actions, GoalActionKind kind) {
  for (final action in actions) {
    if (action.kind == kind) return action;
  }
  return null;
}

GoalLink? _firstSpiritualResource(List<GoalLink> links) {
  for (final preferredType in const [
    GoalLinkType.personalPrayer,
    GoalLinkType.libraryPrayer,
    GoalLinkType.scripture,
    GoalLinkType.voiceTablet,
  ]) {
    for (final link in links) {
      if (link.type == preferredType) return link;
    }
  }
  return null;
}
