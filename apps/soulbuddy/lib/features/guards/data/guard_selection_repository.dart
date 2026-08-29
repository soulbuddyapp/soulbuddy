import '../domain/guard_definition.dart';

abstract interface class GuardSelectionRepository {
  Stream<List<GoalGuardSelection>> watchForGoal(String goalId);

  Future<GoalGuardSelection> select({
    required String goalId,
    required GuardDefinition definition,
    String? privateNote,
  });

  Future<void> archive(String selectionId);
}
