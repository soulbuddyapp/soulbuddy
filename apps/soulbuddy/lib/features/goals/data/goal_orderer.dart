abstract interface class GoalOrderer {
  Future<void> reorderActive(List<String> orderedGoalIds);
}
