import 'package:powersync/powersync.dart';
import 'commitment_finalization_recovery_repository.dart';

class PowerSyncCommitmentFinalizationRecoveryRepository
    implements CommitmentFinalizationRecoveryRepository {
  PowerSyncCommitmentFinalizationRecoveryRepository({
    required this.database,
    required this.ownerId,
  });
  final PowerSyncDatabase database;
  final String ownerId;
  @override
  Future<String?> resolve() async => database.writeTransaction((tx) async {
    final marker = await tx.getOptional(
      'SELECT commitment_id FROM commitment_finalization_recovery WHERE owner_id=?',
      [ownerId],
    );
    if (marker == null) return null;
    final id = marker['commitment_id'] as String;
    if (await tx.getOptional(
          'SELECT id FROM commitments WHERE id=? AND owner_id=?',
          [id, ownerId],
        ) !=
        null) {
      return id;
    }
    await tx.execute(
      'DELETE FROM commitment_finalization_recovery WHERE owner_id=? AND commitment_id=?',
      [ownerId, id],
    );
    return null;
  });
  @override
  Future<void> acknowledge(String commitmentId) async {
    await database.execute(
      'DELETE FROM commitment_finalization_recovery WHERE owner_id=? AND commitment_id=?',
      [ownerId, commitmentId],
    );
  }
}
