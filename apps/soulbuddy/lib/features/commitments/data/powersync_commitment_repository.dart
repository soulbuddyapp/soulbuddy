import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import '../domain/commitment.dart';
import 'commitment_repository.dart';

class PowerSyncCommitmentRepository implements CommitmentRepository {
  PowerSyncCommitmentRepository({
    required this.database,
    required this.ownerId,
    DateTime Function()? now,
    Uuid? uuid,
  }) : _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();
  final PowerSyncDatabase database;
  final String ownerId;
  final DateTime Function() _now;
  final Uuid _uuid;
  @override
  Stream<Commitment?> watchPrimary() => database
      .watch(
        "SELECT * FROM commitments WHERE owner_id=? AND journey_slot='primary' ORDER BY created_at,id LIMIT 1",
        parameters: [ownerId],
      )
      .map((rows) => rows.isEmpty ? null : Commitment.fromRow(rows.first));
  @override
  Stream<CommitmentDetails?> watchDetails(String commitmentId) => database
      .watch(
        '''
 SELECT id,updated_at FROM commitments WHERE id=? AND owner_id=?
 UNION ALL SELECT id,updated_at FROM commitment_practices WHERE commitment_id=? AND owner_id=?
 UNION ALL SELECT id,updated_at FROM commitment_declarations WHERE commitment_id=? AND owner_id=?
 UNION ALL SELECT id,updated_at FROM commitment_meditation_plans WHERE commitment_id=? AND owner_id=?
 UNION ALL SELECT id,updated_at FROM commitment_preparation_cycles WHERE commitment_id=? AND owner_id=?
 UNION ALL SELECT id,updated_at FROM goal_actions WHERE owner_id=? AND goal_id IN (SELECT goal_id FROM commitments WHERE id=? AND owner_id=?)
 ''',
        parameters: [
          for (var i = 0; i < 5; i++) ...[commitmentId, ownerId],
          ownerId,
          commitmentId,
          ownerId,
        ],
      )
      .asyncMap((_) async {
        return database.readTransaction((tx) async {
          final row = await tx.getOptional(
            'SELECT * FROM commitments WHERE id=? AND owner_id=?',
            [commitmentId, ownerId],
          );
          if (row == null) return null;
          final practices = await tx.getAll(
            '''SELECT p.* FROM commitment_practices p JOIN goal_actions a ON a.id=p.goal_action_id AND a.owner_id=p.owner_id WHERE p.commitment_id=? AND p.owner_id=? AND a.archived_at IS NULL ORDER BY p.position,p.created_at,p.id''',
            [commitmentId, ownerId],
          );
          final declaration = await tx.getOptional(
            'SELECT * FROM commitment_declarations WHERE commitment_id=? AND owner_id=?',
            [commitmentId, ownerId],
          );
          final plan = await tx.getOptional(
            'SELECT * FROM commitment_meditation_plans WHERE commitment_id=? AND owner_id=?',
            [commitmentId, ownerId],
          );
          final cycle = await tx.getOptional(
            'SELECT * FROM commitment_preparation_cycles WHERE commitment_id=? AND owner_id=?',
            [commitmentId, ownerId],
          );
          return CommitmentDetails(
            commitment: Commitment.fromRow(row),
            practices: List.unmodifiable(
              practices.map(CommitmentPractice.fromRow),
            ),
            declaration: declaration == null
                ? null
                : CommitmentDeclaration.fromRow(declaration),
            plan: plan == null ? null : CommitmentMeditationPlan.fromRow(plan),
            preparationCycle: cycle == null
                ? null
                : CommitmentPreparationCycle.fromRow(cycle),
          );
        });
      });
  Future<void> _require(String id) async {
    if (await database.getOptional(
          'SELECT id FROM commitments WHERE id=? AND owner_id=?',
          [id, ownerId],
        ) ==
        null) {
      throw StateError('Commitment unavailable');
    }
  }

  @override
  Future<void> updateGuide(
    String commitmentId,
    CommitmentGuideId guideId,
  ) async {
    await _require(commitmentId);
    await database.execute(
      'UPDATE commitments SET guide_id=?,updated_at=? WHERE id=? AND owner_id=?',
      [
        guideId.wireValue,
        _now().toUtc().toIso8601String(),
        commitmentId,
        ownerId,
      ],
    );
  }

  Future<Map<String, dynamic>> _upsert(
    String table,
    String commitmentId,
    Map<String, Object?> values,
  ) async {
    return database.writeTransaction((tx) async {
      if (await tx.getOptional(
            'SELECT id FROM commitments WHERE id=? AND owner_id=?',
            [commitmentId, ownerId],
          ) ==
          null) {
        throw StateError('Commitment unavailable');
      }
      final existing = await tx.getOptional(
        'SELECT id,created_at FROM $table WHERE commitment_id=? AND owner_id=?',
        [commitmentId, ownerId],
      );
      final timestamp = _now().toUtc().toIso8601String();
      final row = <String, Object?>{
        ...values,
        'id': existing?['id'] ?? _uuid.v7(),
        'owner_id': ownerId,
        'commitment_id': commitmentId,
        'created_at': existing?['created_at'] ?? timestamp,
        'updated_at': timestamp,
      };
      if (existing == null) {
        await tx.execute(
          'INSERT INTO $table (${row.keys.join(',')}) VALUES (${List.filled(row.length, '?').join(',')})',
          row.values.toList(),
        );
      } else {
        final patch = Map<String, Object?>.from(row)
          ..remove('id')
          ..remove('owner_id')
          ..remove('created_at');
        await tx.execute(
          'UPDATE $table SET ${patch.keys.map((k) => '$k=?').join(',')} WHERE id=? AND owner_id=?',
          [...patch.values, row['id'], ownerId],
        );
      }
      return row;
    });
  }

  @override
  Future<CommitmentMeditationPlan> savePlan(
    CommitmentMeditationPlanDraft draft,
  ) async {
    validateCommitmentPlan(
      frequency: draft.frequency,
      localTime: draft.localTime,
      timezone: draft.timezone,
      durationMinutes: draft.durationMinutes,
      weekdaysMask: draft.weekdaysMask,
    );
    return CommitmentMeditationPlan.fromRow(
      await _upsert(
        'commitment_meditation_plans',
        draft.commitmentId,
        draft.toRow(),
      ),
    );
  }

  @override
  Stream<List<CommitmentMeditationSession>> watchSessions(
    String commitmentId,
  ) => database
      .watch(
        'SELECT * FROM commitment_meditation_sessions WHERE commitment_id=? AND owner_id=? ORDER BY started_at DESC,id',
        parameters: [commitmentId, ownerId],
      )
      .map(
        (rows) =>
            List.unmodifiable(rows.map(CommitmentMeditationSession.fromRow)),
      );
  @override
  Future<CommitmentMeditationSession> recordSession(
    CommitmentMeditationSessionDraft draft,
  ) async {
    validateCommitmentSession(draft);
    final row = <String, Object?>{
      ...draft.toRow(),
      'id': draft.id ?? _uuid.v7(),
      'owner_id': ownerId,
    };
    await database.writeTransaction((tx) async {
      if (await tx.getOptional(
            'SELECT id FROM commitments WHERE id=? AND owner_id=?',
            [draft.commitmentId, ownerId],
          ) ==
          null) {
        throw StateError('Commitment unavailable');
      }
      final existing = await tx.getOptional(
        'SELECT * FROM commitment_meditation_sessions WHERE id=? AND owner_id=?',
        [row['id'], ownerId],
      );
      if (existing != null) {
        final normalized = CommitmentMeditationSession.fromRow(
          existing,
        ).toRow();
        bool differs(MapEntry<String, Object?> entry) {
          if (entry.key == 'started_at' || entry.key == 'ended_at') {
            // Laravel SQL timestamps retain seconds; compare their stored
            // precision so an acknowledged replay survives remote hydration.
            final before = parseCommitmentUtcTimestamp(
              normalized[entry.key] as String,
            );
            final after = parseCommitmentUtcTimestamp(entry.value as String);
            return before.millisecondsSinceEpoch ~/ 1000 !=
                after.millisecondsSinceEpoch ~/ 1000;
          }
          return normalized[entry.key] != entry.value;
        }

        if (row.entries.any(differs)) {
          throw StateError('Session conflict');
        }
        return;
      }
      await tx.execute(
        'INSERT INTO commitment_meditation_sessions (${row.keys.join(',')}) VALUES (${List.filled(row.length, '?').join(',')})',
        row.values.toList(),
      );
    });
    return CommitmentMeditationSession.fromRow(row);
  }

  @override
  Future<void> updatePractice(String practiceId, {required String body}) async {
    final normalized = validateCommitmentText('practice', body);
    await database.writeTransaction((tx) async {
      final practice = await tx.getOptional(
        'SELECT goal_action_id FROM commitment_practices WHERE id=? AND owner_id=?',
        [practiceId, ownerId],
      );
      if (practice == null) throw StateError('Practice unavailable');
      final timestamp = _now().toUtc().toIso8601String();
      await tx.execute(
        'UPDATE commitment_practices SET body=?,updated_at=? WHERE id=? AND owner_id=?',
        [normalized, timestamp, practiceId, ownerId],
      );
      await tx.execute(
        'UPDATE goal_actions SET body=?,updated_at=? WHERE id=? AND owner_id=?',
        [normalized, timestamp, practice['goal_action_id'], ownerId],
      );
    });
  }

  @override
  Future<void> archivePractice(String practiceId) async {
    await database.writeTransaction((tx) async {
      final practice = await tx.getOptional(
        'SELECT goal_action_id FROM commitment_practices WHERE id=? AND owner_id=?',
        [practiceId, ownerId],
      );
      if (practice == null) throw StateError('Practice unavailable');
      final timestamp = _now().toUtc().toIso8601String();
      await tx.execute(
        'UPDATE goal_actions SET archived_at=?,updated_at=?,enabled=0 WHERE id=? AND owner_id=?',
        [timestamp, timestamp, practice['goal_action_id'], ownerId],
      );
    });
  }

  @override
  Future<void> saveDeclaration(CommitmentDeclarationDraft draft) async {
    await _upsert('commitment_declarations', draft.commitmentId, {
      'body': validateCommitmentText('declaration', draft.body),
      'reviewed_at': _now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> savePreparationCycle(
    CommitmentPreparationCycleDraft draft,
  ) async {
    commitmentTimezone(draft.startTimezone);
    if (commitmentReviewLocalDate(draft.startedLocalDate) !=
        draft.reviewLocalDate) {
      throw ArgumentError('Invalid preparation cycle');
    }
    await database.writeTransaction((tx) async {
      final existing = await tx.getOptional(
        'SELECT id FROM commitment_preparation_cycles WHERE commitment_id=? AND owner_id=?',
        [draft.commitmentId, ownerId],
      );
      final timestamp = _now().toUtc().toIso8601String();
      if (existing != null) {
        // The cycle's origin is immutable. Reserializing server timestamps can
        // otherwise emit forbidden origin fields in PowerSync's patch.
        await tx.execute(
          'UPDATE commitment_preparation_cycles SET state=?,updated_at=? WHERE id=? AND owner_id=?',
          [draft.state.wireValue, timestamp, existing['id'], ownerId],
        );
        return;
      }
      if (await tx.getOptional(
            'SELECT id FROM commitments WHERE id=? AND owner_id=?',
            [draft.commitmentId, ownerId],
          ) ==
          null) {
        throw StateError('Commitment unavailable');
      }
      final row = <String, Object?>{
        ...draft.toRow(),
        'id': _uuid.v7(),
        'owner_id': ownerId,
        'created_at': timestamp,
        'updated_at': timestamp,
      };
      await tx.execute(
        'INSERT INTO commitment_preparation_cycles (${row.keys.join(',')}) VALUES (${List.filled(row.length, '?').join(',')})',
        row.values.toList(),
      );
    });
  }
}
