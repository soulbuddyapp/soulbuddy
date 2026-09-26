import 'package:powersync/powersync.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';
import '../domain/commitment.dart';
import 'commitment_finalizer.dart';

class PowerSyncCommitmentFinalizer implements CommitmentFinalizer {
  PowerSyncCommitmentFinalizer({
    required this.database,
    required this.ownerId,
    required this.deviceId,
    DateTime Function()? now,
    Uuid? uuid,
  }) : _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();
  final PowerSyncDatabase database;
  final String ownerId, deviceId;
  final DateTime Function() _now;
  final Uuid _uuid;
  @override
  Future<CommitmentFinalizationResult> finalize(
    CommitmentJourneyProgress progress,
  ) async {
    return database.writeTransaction((tx) async {
      final existing = await tx.getOptional(
        "SELECT c.id,c.goal_id,p.id AS plan_id FROM commitments c LEFT JOIN commitment_meditation_plans p ON p.commitment_id=c.id AND p.owner_id=c.owner_id WHERE c.owner_id=? AND c.journey_slot='primary'",
        [ownerId],
      );
      if (existing != null) {
        if (existing['plan_id'] == null) {
          throw StateError('Commitment plan unavailable');
        }
        return CommitmentFinalizationResult(
          commitmentId: existing['id'] as String,
          goalId: existing['goal_id'] as String,
          planId: existing['plan_id'] as String,
        );
      }
      String text(String field, String? value) =>
          validateCommitmentText(field, value ?? '');
      final name = text('name', progress.name);
      final needs = [
        text('need', progress.keyNeedOne),
        text('need', progress.keyNeedTwo),
        text('need', progress.keyNeedThree),
      ];
      final calling = text('calling', progress.calling);
      final declaration = text('declaration', progress.declarationDraft);
      if (!progress.declarationReviewed ||
          progress.guideId == null ||
          progress.frequency == null) {
        throw ArgumentError('Commitment incomplete');
      }
      validateCommitmentPlan(
        frequency: progress.frequency!,
        localTime: progress.localTime ?? '',
        timezone: progress.timezone ?? '',
        durationMinutes: progress.durationMinutes ?? 0,
        weekdaysMask: progress.weekdaysMask,
      );
      final rows = await tx.getAll(
        'SELECT * FROM commitment_journey_practice_drafts WHERE owner_id=? ORDER BY position,id',
        [ownerId],
      );
      validatePracticeCount(rows.length);
      final practices = rows.map(CommitmentPracticeDraft.fromRow).toList();
      for (final practice in practices) {
        text('practice', practice.body);
        if (practice.source == CommitmentPracticeSource.reviewedSuggestion &&
            (practice.suggestionId == null || practice.suggestionId!.isEmpty)) {
          throw ArgumentError('Invalid practice');
        }
      }
      if ((progress.personalPrayerId == null) !=
          (progress.personalPrayerRevisionId == null)) {
        throw ArgumentError('Invalid prayer reference');
      }
      if (progress.personalPrayerId != null) {
        final prayer = await tx.getOptional(
          '''SELECT p.id FROM personal_prayers p JOIN personal_prayer_revisions r ON r.id=? AND r.prayer_id=p.id AND r.owner_id=p.owner_id WHERE p.id=? AND p.owner_id=? AND p.archived_at IS NULL''',
          [
            progress.personalPrayerRevisionId,
            progress.personalPrayerId,
            ownerId,
          ],
        );
        if (prayer == null) throw StateError('Prayer unavailable');
      }
      final now = _now().toUtc(), stamp = _now().toUtc().toIso8601String();
      final local = tz.TZDateTime.from(
        now,
        commitmentTimezone(progress.timezone!),
      );
      final localDate = commitmentLocalDate(local);
      final commitmentId = _uuid.v7(),
          goalId = _uuid.v7(),
          revisionId = _uuid.v7(),
          planId = _uuid.v7();
      Future<void> insert(String table, Map<String, Object?> row) async {
        await tx.execute(
          'INSERT INTO $table (${row.keys.join(',')}) VALUES (${List.filled(row.length, '?').join(',')})',
          row.values.toList(),
        );
      }

      final max = await tx.getOptional(
        'SELECT MAX(position) AS maximum FROM goals WHERE owner_id=?',
        [ownerId],
      );
      await insert('goals', {
        'id': goalId,
        'owner_id': ownerId,
        'starter_key': 'closer_to_god',
        'mode': 'actionable',
        'status': 'active',
        'current_revision_id': revisionId,
        'position': ((max?['maximum'] as num?)?.toInt() ?? -1) + 1,
        'created_at': stamp,
        'updated_at': stamp,
        'archived_at': null,
      });
      await insert('goal_revisions', {
        'id': revisionId,
        'goal_id': goalId,
        'owner_id': ownerId,
        'title': name,
        'current_situation': null,
        'why_it_matters': null,
        'created_at': stamp,
        'device_id': deviceId,
      });
      final actions = [for (final _ in practices) _uuid.v7()];
      for (var i = 0; i < practices.length; i++) {
        await insert('goal_actions', {
          'id': actions[i],
          'goal_id': goalId,
          'owner_id': ownerId,
          'body': practices[i].body,
          'action_kind': 'commitment_practice',
          'schedule_type': 'daily',
          'local_time': null,
          'timezone': null,
          'once_at': null,
          'weekdays_mask': null,
          'enabled': 1,
          'created_at': stamp,
          'updated_at': stamp,
          'archived_at': null,
        });
      }
      if (progress.personalPrayerId != null) {
        await insert('goal_links', {
          'id': _uuid.v7(),
          'goal_id': goalId,
          'owner_id': ownerId,
          'link_type': 'personal_prayer',
          'personal_prayer_id': progress.personalPrayerId,
          'role': 'primary_prayer',
          'created_at': stamp,
          'archived_at': null,
        });
      }
      await insert(
        'commitments',
        Commitment(
          id: commitmentId,
          ownerId: ownerId,
          journeySlot: CommitmentJourneySlot.primary,
          goalId: goalId,
          name: name,
          keyNeedOne: needs[0],
          keyNeedTwo: needs[1],
          keyNeedThree: needs[2],
          calling: calling,
          guideId: progress.guideId!,
          createdAt: now,
          updatedAt: now,
        ).toRow(),
      );
      for (var i = 0; i < practices.length; i++) {
        final p = practices[i];
        await insert(
          'commitment_practices',
          CommitmentPractice(
            id: _uuid.v7(),
            ownerId: ownerId,
            commitmentId: commitmentId,
            goalActionId: actions[i],
            category: p.category,
            body: p.body,
            position: i,
            source: p.source,
            suggestionId: p.suggestionId,
            createdAt: now,
            updatedAt: now,
          ).toRow(),
        );
      }
      await insert(
        'commitment_declarations',
        CommitmentDeclaration(
          id: _uuid.v7(),
          ownerId: ownerId,
          commitmentId: commitmentId,
          body: declaration,
          reviewedAt: now,
          createdAt: now,
          updatedAt: now,
        ).toRow(),
      );
      await insert(
        'commitment_meditation_plans',
        CommitmentMeditationPlan(
          id: planId,
          ownerId: ownerId,
          commitmentId: commitmentId,
          frequency: progress.frequency!,
          weekdaysMask: progress.weekdaysMask,
          localTime: progress.localTime!,
          timezone: progress.timezone!,
          durationMinutes: progress.durationMinutes!,
          enabled: true,
          createdAt: now,
          updatedAt: now,
        ).toRow(),
      );
      await insert(
        'commitment_preparation_cycles',
        CommitmentPreparationCycle(
          id: _uuid.v7(),
          ownerId: ownerId,
          commitmentId: commitmentId,
          startedAtUtc: now,
          startedLocalDate: localDate,
          startTimezone: progress.timezone!,
          reviewLocalDate: commitmentReviewLocalDate(localDate),
          state: CommitmentPreparationCycleState.active,
          createdAt: now,
          updatedAt: now,
        ).toRow(),
      );
      await insert('commitment_reminder_devices', {
        'id': '$ownerId:$deviceId:$commitmentId',
        'owner_id': ownerId,
        'commitment_id': commitmentId,
        'device_id': deviceId,
        'mode': (progress.reminderMode ?? CommitmentReminderMode.off).wireValue,
        'updated_at': stamp,
      });
      await insert('commitment_finalization_recovery', {
        'id': 'current:$ownerId',
        'owner_id': ownerId,
        'commitment_id': commitmentId,
        'finalized_at': stamp,
      });
      // Only explicitly consented audio of the selected immutable prayer moves
      // with the finalized draft. Unselected draft audio is discarded locally.
      if (progress.personalPrayerId != null) {
        await tx.execute(
          "UPDATE commitment_personal_prayer_narration_cache SET commitment_id=? WHERE owner_id=? AND commitment_id='draft' AND prayer_id=? AND revision_id=? AND consented=1",
          [
            commitmentId,
            ownerId,
            progress.personalPrayerId,
            progress.personalPrayerRevisionId,
          ],
        );
      }
      await tx.execute(
        "DELETE FROM commitment_personal_prayer_narration_cache WHERE owner_id=? AND commitment_id='draft'",
        [ownerId],
      );
      await tx.execute(
        'DELETE FROM commitment_journey_progress WHERE owner_id=?',
        [ownerId],
      );
      await tx.execute(
        'DELETE FROM commitment_journey_practice_drafts WHERE owner_id=?',
        [ownerId],
      );
      return CommitmentFinalizationResult(
        commitmentId: commitmentId,
        goalId: goalId,
        planId: planId,
      );
    });
  }
}
