import 'dart:io';
import 'package:soulbuddy/features/goals/data/powersync_goal_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/commitments/domain/commitment.dart';
import 'package:soulbuddy/features/commitments/data/powersync_commitment_journey_progress_repository.dart';
import 'package:soulbuddy/features/commitments/data/powersync_commitment_journey_practice_draft_repository.dart';
import 'package:soulbuddy/features/commitments/data/powersync_commitment_finalizer.dart';
import 'package:soulbuddy/features/commitments/data/powersync_commitment_repository.dart';
import 'package:soulbuddy/features/commitments/data/powersync_commitment_finalization_recovery_repository.dart';
import '../../helpers/powersync_test_database.dart';

void main() {
  test(
    'untouched and deliberately cleared draft fields persist as null',
    () async {
      final dir = await Directory.systemTemp.createTemp('commitment-empty-');
      final db = await openTestDatabase('${dir.path}/test.db');
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      final repo = PowerSyncCommitmentJourneyProgressRepository(
        database: db.powersync,
        ownerId: 'alice',
      );
      await repo.save(
        const CommitmentJourneyProgress(
          keyNeedOne: '',
          keyNeedTwo: '',
          keyNeedThree: '',
          calling: '',
          name: '',
          declarationDraft: '',
        ),
      );
      expect(
        (await repo.load()).progress!.stage,
        CommitmentJourneyStage.invitation,
      );
      await repo.save(
        const CommitmentJourneyProgress(keyNeedOne: 'Grace', calling: 'Serve'),
      );
      await repo.save(
        const CommitmentJourneyProgress(keyNeedOne: '   ', calling: 'Serve'),
      );
      final saved = (await repo.load()).progress!;
      expect(saved.keyNeedOne, isNull);
      expect(saved.calling, 'Serve');
    },
  );
  test(
    'owner drafts survive a database reopen without a sync mutation',
    () async {
      final dir = await Directory.systemTemp.createTemp('commitment-reopen-');
      final path = '${dir.path}/test.db';
      var db = await openTestDatabase(path);
      await PowerSyncCommitmentJourneyProgressRepository(
        database: db.powersync,
        ownerId: 'alice',
      ).save(const CommitmentJourneyProgress(calling: 'Serve with hope'));
      await db.close();
      db = await openTestDatabase(path);
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      final saved = await PowerSyncCommitmentJourneyProgressRepository(
        database: db.powersync,
        ownerId: 'alice',
      ).load();
      expect(saved.progress!.calling, 'Serve with hope');
      expect(await db.powersync.getNextCrudTransaction(), isNull);
    },
  );
  test(
    'drafts isolate owners and never queue; finalization is atomic and replay-safe',
    () async {
      final dir = await Directory.systemTemp.createTemp('commitment-');
      final db = await openTestDatabase('${dir.path}/test.db');
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      final progressRepo = PowerSyncCommitmentJourneyProgressRepository(
        database: db.powersync,
        ownerId: 'alice',
      );
      final practiceRepo = PowerSyncCommitmentJourneyPracticeDraftRepository(
        database: db.powersync,
        ownerId: 'alice',
      );
      const progress = CommitmentJourneyProgress(
        stage: CommitmentJourneyStage.summary,
        keyNeedOne: 'Grace',
        keyNeedTwo: 'Patience',
        keyNeedThree: 'Hope',
        calling: 'Serve my neighbors',
        declarationDraft: 'I surrender honestly.',
        declarationReviewed: true,
        guideId: CommitmentGuideId.peace,
        frequency: CommitmentMeditationFrequency.daily,
        localTime: '07:30',
        timezone: 'Africa/Lagos',
        durationMinutes: 10,
        reminderMode: CommitmentReminderMode.off,
        name: 'Faithful service',
      );
      await progressRepo.save(progress);
      await practiceRepo.save([
        for (var i = 0; i < 5; i++)
          CommitmentPracticeDraft(
            id: 'draft-$i',
            category: CommitmentPracticeCategory.joyPleasure,
            body: 'Practice $i',
            position: i,
          ),
      ]);
      expect((await progressRepo.load()).progress?.calling, progress.calling);
      expect(
        (await PowerSyncCommitmentJourneyProgressRepository(
          database: db.powersync,
          ownerId: 'bob',
        ).load()).progress,
        isNull,
      );
      expect(await db.powersync.getNextCrudTransaction(), isNull);
      for (final owner in ['alice', 'bob']) {
        await db.powersync.execute(
          'INSERT INTO voice_note_links '
          '(id, owner_id, context_type, context_id, field_key, encounter_id, created_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            '$owner-note',
            owner,
            'commitment',
            'journey:primary',
            'practice:draft-0',
            '$owner-recording',
            '2026-09-25T00:00:00Z',
          ],
        );
      }
      final finalizer = PowerSyncCommitmentFinalizer(
        database: db.powersync,
        ownerId: 'alice',
        deviceId: 'device',
        now: () => DateTime.utc(2026, 9, 25, 23, 30),
      );
      await expectLater(
        finalizer.finalize(
          progress.copyWith(
            personalPrayerId: 'missing',
            personalPrayerRevisionId: 'missing',
          ),
        ),
        throwsStateError,
      );
      expect(await db.powersync.getAll('SELECT * FROM goals'), isEmpty);
      expect((await progressRepo.load()).progress, isNotNull);
      expect(
        (await db.powersync.get(
          'SELECT context_id FROM voice_note_links WHERE id = ?',
          ['alice-note'],
        ))['context_id'],
        'journey:primary',
      );
      final result = await finalizer.finalize(progress);
      final replay = await finalizer.finalize(progress);
      expect(replay.commitmentId, result.commitmentId);
      final links = await db.powersync.getAll('SELECT * FROM voice_note_links');
      expect(links, hasLength(2));
      expect(
        links.singleWhere((row) => row['owner_id'] == 'alice')['context_id'],
        result.commitmentId,
      );
      expect(
        links.singleWhere((row) => row['owner_id'] == 'alice')['field_key'],
        'practice:draft-0',
      );
      expect(
        links.singleWhere((row) => row['owner_id'] == 'bob')['context_id'],
        'journey:primary',
      );
      expect((await progressRepo.load()).progress, isNull);
      expect(await practiceRepo.load(), isEmpty);
      expect(await db.powersync.getAll('SELECT * FROM goals'), hasLength(1));
      expect(
        await db.powersync.getAll('SELECT * FROM goal_actions'),
        hasLength(5),
      );
      expect(
        await db.powersync.getAll('SELECT * FROM goal_action_events'),
        isEmpty,
      );
      expect(
        await db.powersync.getAll(
          'SELECT * FROM commitment_meditation_sessions',
        ),
        isEmpty,
      );
      final repository = PowerSyncCommitmentRepository(
        database: db.powersync,
        ownerId: 'alice',
      );
      final details = await repository.watchDetails(result.commitmentId).first;
      expect(details!.practices.map((p) => p.id), [
        for (var i = 0; i < 5; i++) 'draft-$i',
      ]);
      expect(
        links.singleWhere((row) => row['owner_id'] == 'alice')['field_key'],
        'practice:${details.practices.first.id}',
      );
      expect(details.practices.map((p) => p.body), [
        'Practice 0',
        'Practice 1',
        'Practice 2',
        'Practice 3',
        'Practice 4',
      ]);
      expect(details.preparationCycle!.reviewLocalDate, '2026-10-05');
      expect(
        await PowerSyncCommitmentRepository(
          database: db.powersync,
          ownerId: 'bob',
        ).watchDetails(result.commitmentId).first,
        isNull,
      );
      await repository.updatePractice(
        details.practices.first.id,
        body: 'Help someone',
      );
      expect(
        (await db.powersync.get('SELECT body FROM goal_actions WHERE id=?', [
          details.practices.first.goalActionId,
        ]))['body'],
        'Help someone',
      );
      final goals = PowerSyncGoalRepository(
        database: db.powersync,
        ownerId: 'alice',
        deviceId: 'device',
      );
      final scheduled = await goals
          .watchScheduledActions(DateTime(2026, 9, 26))
          .first;
      expect(
        scheduled.map((o) => o.action.commitmentPracticePosition).toSet(),
        {0, 1, 2, 3, 4},
      );
      await expectLater(
        goals.edit(result.goalId, title: 'Divergent title'),
        throwsStateError,
      );
      await goals.editActionBody(
        details.practices.first.goalActionId,
        body: 'Serve a neighbor',
      );
      expect(
        (await repository.watchDetails(result.commitmentId).first)!
            .practices
            .first
            .body,
        'Serve a neighbor',
      );
      final session = CommitmentMeditationSessionDraft(
        id: 'stable-session',
        commitmentId: result.commitmentId,
        sessionKind: CommitmentSessionKind.meditation,
        startedAt: DateTime.utc(2026, 9, 26, 6),
        endedAt: DateTime.utc(2026, 9, 26, 6, 10),
        localDate: '2026-09-26',
        plannedDurationSeconds: 600,
        actualDurationSeconds: 600,
        outcome: CommitmentMeditationSessionOutcome.completed,
        deviceId: 'device',
      );
      final first = await repository.recordSession(session);
      await db.powersync.execute(
        'UPDATE commitment_meditation_sessions SET started_at=?,ended_at=? WHERE id=?',
        ['2026-09-26 06:00:00', '2026-09-26 06:10:00', first.id],
      );
      final retry = await repository.recordSession(session);
      expect(first.id, retry.id);
      expect(
        await repository.watchSessions(result.commitmentId).first,
        hasLength(1),
      );
      while (true) {
        final queued = await db.powersync.getNextCrudTransaction();
        if (queued == null) break;
        await queued.complete();
      }
      await db.powersync.execute(
        'UPDATE commitment_preparation_cycles SET started_at_utc=? WHERE commitment_id=?',
        ['2026-09-25 23:30:00', result.commitmentId],
      );
      await (await db.powersync.getNextCrudTransaction())!.complete();
      final remoteCycle =
          (await repository.watchDetails(result.commitmentId).first)!
              .preparationCycle!;
      await repository.savePreparationCycle(
        CommitmentPreparationCycleDraft(
          commitmentId: result.commitmentId,
          startedAtUtc: remoteCycle.startedAtUtc,
          startedLocalDate: remoteCycle.startedLocalDate,
          startTimezone: remoteCycle.startTimezone,
          reviewLocalDate: remoteCycle.reviewLocalDate,
          state: CommitmentPreparationCycleState.deferred,
        ),
      );
      final cyclePatch = await db.powersync.getNextCrudTransaction();
      expect(cyclePatch!.crud.single.opData!.keys.toSet(), {
        'state',
        'updated_at',
      });
      await cyclePatch.complete();
      await repository.savePlan(
        CommitmentMeditationPlanDraft(
          commitmentId: result.commitmentId,
          frequency: CommitmentMeditationFrequency.daily,
          localTime: '08:30',
          timezone: 'Africa/Lagos',
          durationMinutes: 15,
          enabled: true,
        ),
      );
      final planPatch = await db.powersync.getNextCrudTransaction();
      expect(planPatch!.crud.single.opData!.keys.toSet(), {
        'local_time',
        'duration_minutes',
        'updated_at',
      });
      await planPatch.complete();
      final bobDrafts = PowerSyncCommitmentJourneyPracticeDraftRepository(
        database: db.powersync,
        ownerId: 'bob',
      );
      await bobDrafts.save([
        const CommitmentPracticeDraft(
          id: 'draft-0',
          category: CommitmentPracticeCategory.joyPleasure,
          body: 'Another person cannot reuse this identity',
        ),
      ]);
      await expectLater(
        PowerSyncCommitmentFinalizer(
          database: db.powersync,
          ownerId: 'bob',
          deviceId: 'bob-device',
        ).finalize(progress),
        throwsStateError,
      );
      expect(await db.powersync.getAll('SELECT * FROM goals'), hasLength(1));
      final recovery = PowerSyncCommitmentFinalizationRecoveryRepository(
        database: db.powersync,
        ownerId: 'alice',
      );
      expect(await recovery.resolve(), result.commitmentId);
      await recovery.acknowledge('wrong');
      expect(await recovery.resolve(), result.commitmentId);
      await recovery.acknowledge(result.commitmentId);
      expect(await recovery.resolve(), isNull);
      // Partial remote hydration must not authorize a second primary.
      await db.powersync.execute(
        'DELETE FROM commitment_meditation_plans WHERE commitment_id=?',
        [result.commitmentId],
      );
      await practiceRepo.save([
        const CommitmentPracticeDraft(
          id: 'retry',
          category: CommitmentPracticeCategory.joyPleasure,
          body: 'Continue faithfully',
        ),
      ]);
      await expectLater(finalizer.finalize(progress), throwsStateError);
      expect(
        await db.powersync.getAll('SELECT * FROM commitments'),
        hasLength(1),
      );
      expect(await db.powersync.getAll('SELECT * FROM goals'), hasLength(1));
    },
  );
  test(
    'malformed fields are recovered independently without private error content',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'commitment-malformed-',
      );
      final db = await openTestDatabase('${dir.path}/test.db');
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      final repo = PowerSyncCommitmentJourneyProgressRepository(
        database: db.powersync,
        ownerId: 'alice',
      );
      await repo.save(
        const CommitmentJourneyProgress(
          keyNeedOne: 'Grace',
          keyNeedTwo: 'Hope',
        ),
      );
      await db.powersync.execute(
        "UPDATE commitment_journey_progress SET key_need_two=?,guide_id='bad',frequency='selected_days',local_time='24:00',duration_minutes=4 WHERE owner_id='alice'",
        ['secret' * 101],
      );
      final recovered = await repo.load();
      expect(recovered.progress!.keyNeedOne, 'Grace');
      expect(recovered.progress!.keyNeedTwo, isNull);
      expect(recovered.progress!.guideId, isNull);
      expect(recovered.progress!.frequency, isNull);
      expect(
        recovered.discardedFields,
        containsAll(['key_need_two', 'guide_id', 'schedule']),
      );
      expect(recovered.discardedFields.join(), isNot(contains('secret')));
      expect((await repo.load()).discardedFields, isEmpty);
    },
  );
}
