import '../domain/commitment.dart';

class CommitmentFinalizationResult {
  const CommitmentFinalizationResult({
    required this.commitmentId,
    required this.goalId,
    required this.planId,
  });
  final String commitmentId;
  final String goalId;
  final String planId;
}

abstract interface class CommitmentFinalizer {
  Future<CommitmentFinalizationResult> finalize(
    CommitmentJourneyProgress progress,
  );
}
