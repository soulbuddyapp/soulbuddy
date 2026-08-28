import '../domain/goal_onboarding_progress.dart';

class GoalOnboardingFinalizationResult {
  const GoalOnboardingFinalizationResult({
    required this.goalId,
    this.createdPersonalPrayerId,
  });

  final String goalId;
  final String? createdPersonalPrayerId;
}

abstract interface class GoalOnboardingFinalizer {
  Future<GoalOnboardingFinalizationResult> finalize(
    GoalOnboardingProgress progress,
  );
}
