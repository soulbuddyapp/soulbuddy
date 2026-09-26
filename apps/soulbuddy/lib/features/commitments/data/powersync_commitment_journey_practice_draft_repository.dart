import 'package:powersync/powersync.dart';
import '../domain/commitment.dart';
import 'commitment_journey_practice_draft_repository.dart';

class PowerSyncCommitmentJourneyPracticeDraftRepository
    implements CommitmentJourneyPracticeDraftRepository {
  PowerSyncCommitmentJourneyPracticeDraftRepository({
    required this.database,
    required this.ownerId,
  });
  final PowerSyncDatabase database;
  final String ownerId;
  @override
  Future<List<CommitmentPracticeDraft>> load() async =>
      (await database.getAll(
            'SELECT * FROM commitment_journey_practice_drafts WHERE owner_id=? ORDER BY position,id',
            [ownerId],
          ))
          .map(
            (r) => CommitmentPracticeDraft.fromRow({
              ...r,
              'id': (r['id'] as String).substring(ownerId.length + 1),
            }),
          )
          .toList();
  @override
  Future<void> save(List<CommitmentPracticeDraft> practices) async {
    if (practices.length > 12 ||
        practices.map((p) => p.id).toSet().length != practices.length) {
      throw ArgumentError('Invalid practices');
    }
    for (final p in practices) {
      validateCommitmentText('practice', p.body);
      if (p.id.isEmpty ||
          (p.source == CommitmentPracticeSource.reviewedSuggestion &&
              (p.suggestionId == null || p.suggestionId!.isEmpty))) {
        throw ArgumentError('Invalid practice');
      }
    }
    await database.writeTransaction((tx) async {
      await tx.execute(
        'DELETE FROM commitment_journey_practice_drafts WHERE owner_id=?',
        [ownerId],
      );
      for (var i = 0; i < practices.length; i++) {
        final row = practices[i].copyWith(position: i).toRow()
          ..addAll({
            'id': '$ownerId:${practices[i].id}',
            'owner_id': ownerId,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        await tx.execute(
          'INSERT INTO commitment_journey_practice_drafts (${row.keys.join(',')}) VALUES (${List.filled(row.length, '?').join(',')})',
          row.values.toList(),
        );
      }
    });
  }

  @override
  Future<void> remove(String id) async {
    await database.execute(
      'DELETE FROM commitment_journey_practice_drafts WHERE id=? AND owner_id=?',
      ['$ownerId:$id', ownerId],
    );
  }

  @override
  Future<void> clear() async {
    await database.execute(
      'DELETE FROM commitment_journey_practice_drafts WHERE owner_id=?',
      [ownerId],
    );
  }
}
