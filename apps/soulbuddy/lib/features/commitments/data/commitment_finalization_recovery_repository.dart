abstract interface class CommitmentFinalizationRecoveryRepository {
  Future<String?> resolve();
  Future<void> acknowledge(String commitmentId);
}
