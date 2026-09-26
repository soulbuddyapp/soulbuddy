import '../domain/commitment.dart';

class CommitmentProgressLoadResult {
  const CommitmentProgressLoadResult({
    this.progress,
    this.discardedFields = const {},
  });
  final CommitmentJourneyProgress? progress;
  final Set<String> discardedFields;
}

abstract interface class CommitmentJourneyProgressRepository {
  Future<CommitmentProgressLoadResult> load();
  Future<void> save(CommitmentJourneyProgress progress);
  Future<void> clear();
}
