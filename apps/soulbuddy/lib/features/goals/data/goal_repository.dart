import '../domain/goal.dart';
import '../domain/goal_action.dart';
import '../domain/goal_link.dart';

abstract interface class GoalDailyActionReader {
  Stream<List<GoalActionOccurrence>> watchScheduledActions(DateTime localDate);
}

abstract interface class GoalRepository {
  Stream<List<Goal>> watchActive();

  Stream<Goal?> watch(String id);

  Stream<List<GoalRevision>> watchRevisions(String goalId);

  Stream<List<GoalActionOccurrence>> watchDueActions(DateTime localDate);

  Future<Goal> create({
    required String title,
    required GoalMode mode,
    GoalStarterKey? starterKey,
    String? currentSituation,
    String? whyItMatters,
    int? position,
  });

  Future<Goal> edit(
    String goalId, {
    required String title,
    String? currentSituation,
    String? whyItMatters,
  });

  Future<void> setStatus(String goalId, GoalStatus status);

  Future<GoalLink> addLink(String goalId, GoalLinkDraft link);

  Future<void> archiveLink(String linkId);

  Future<GoalAction> addAction(String goalId, GoalActionDraft action);

  Future<void> archiveAction(String actionId);

  Future<GoalActionEvent?> completeAction(
    String actionId, {
    required DateTime localDate,
    DateTime? occurredAt,
  });

  Future<GoalActionEvent?> skipAction(
    String actionId, {
    required DateTime localDate,
    DateTime? occurredAt,
  });

  Future<GoalActionEvent?> retractAction(
    String actionId, {
    required DateTime localDate,
    DateTime? occurredAt,
  });
}
