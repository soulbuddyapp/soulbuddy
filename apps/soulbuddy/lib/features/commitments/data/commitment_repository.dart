import '../domain/commitment.dart';

abstract interface class CommitmentRepository {
  Stream<Commitment?> watchPrimary();
  Stream<CommitmentDetails?> watchDetails(String commitmentId);
  Future<void> updateGuide(String commitmentId, CommitmentGuideId guideId);
  Future<CommitmentMeditationPlan> savePlan(
    CommitmentMeditationPlanDraft draft,
  );
  Stream<List<CommitmentMeditationSession>> watchSessions(String commitmentId);
  Future<CommitmentMeditationSession> recordSession(
    CommitmentMeditationSessionDraft draft,
  );
  Future<void> updatePractice(String practiceId, {required String body});
  Future<void> archivePractice(String practiceId);
  Future<void> saveDeclaration(CommitmentDeclarationDraft draft);
  Future<void> savePreparationCycle(CommitmentPreparationCycleDraft draft);
}
