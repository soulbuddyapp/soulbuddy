import '../domain/commitment.dart';

abstract interface class CommitmentJourneyPracticeDraftRepository {
  Future<List<CommitmentPracticeDraft>> load();
  Future<void> save(List<CommitmentPracticeDraft> practices);
  Future<void> remove(String id);
  Future<void> clear();
}
