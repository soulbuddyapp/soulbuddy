import '../domain/goal_onboarding_progress.dart';

abstract interface class GoalOnboardingProgressRepository {
  Future<GoalOnboardingProgress?> load();

  Future<void> save(GoalOnboardingProgress progress);

  Future<void> clear();
}
