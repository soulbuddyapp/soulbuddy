import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/goals/data/powersync_goal_onboarding_finalizer.dart';
import 'package:soulbuddy/features/goals/data/powersync_goal_onboarding_progress_repository.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/domain/goal_onboarding_progress.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-goal-finalizer-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('commits Goal, own prayer, link and Today items atomically', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/finalize.db',
    );
    addTearDown(database.close);
    final progressRepository = PowerSyncGoalOnboardingProgressRepository(
      database: database.powersync,
    );
    const progress = GoalOnboardingProgress(
      stage: GoalOnboardingStage.prayer,
      starterKey: GoalStarterKey.stopControl,
      title: 'Stop watching pornography',
      currentSituation: 'Late-night phone use makes this easier.',
      situationByVoice: false,
      agencyChoice: GoalAgencyChoice.stepsICanTake,
      todayAction: 'Charge my phone outside the bedroom',
      guardNote: 'Keep content filtering enabled',
      accountabilityChoice: GoalAccountabilityChoice.trustedPerson,
      prayerSource: GoalOnboardingPrayerSource.ownWords,
      ownPrayerText: 'Jesus, keep me close to you and help me act faithfully.',
    );
    await progressRepository.save(progress);
    final finalizer = PowerSyncGoalOnboardingFinalizer(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      now: () => DateTime(2026, 8, 28, 4, 30),
      uuid: const Uuid(),
    );

    final result = await finalizer.finalize(progress);

    expect(result.goalId, isNotEmpty);
    expect(result.createdPersonalPrayerId, isNotNull);
    expect(await progressRepository.load(), isNull);
    final goals = await database.powersync.getAll('SELECT * FROM goals');
    final revisions = await database.powersync.getAll(
      'SELECT * FROM goal_revisions',
    );
    final prayers = await database.powersync.getAll(
      'SELECT * FROM personal_prayers',
    );
    final prayerRevisions = await database.powersync.getAll(
      'SELECT * FROM personal_prayer_revisions',
    );
    final links = await database.powersync.getAll('SELECT * FROM goal_links');
    final actions = await database.powersync.getAll(
      'SELECT * FROM goal_actions ORDER BY action_kind',
    );
    expect(goals, hasLength(1));
    expect(revisions, hasLength(1));
    expect(prayers, hasLength(1));
    expect(prayerRevisions, hasLength(1));
    expect(links, hasLength(1));
    expect(actions, hasLength(3));
    expect(goals.single['current_revision_id'], revisions.single['id']);
    expect(prayers.single['current_revision_id'], prayerRevisions.single['id']);
    expect(links.single['goal_id'], result.goalId);
    expect(links.single['personal_prayer_id'], result.createdPersonalPrayerId);
    expect(actions.map((row) => row['action_kind']).toSet(), {
      'accountability',
      'guard',
      'next_step',
    });
    expect(
      actions.singleWhere(
        (row) => row['action_kind'] == 'accountability',
      )['body'],
      'Contact a trusted person',
    );
    expect(actions.every((row) => row['schedule_type'] == 'today'), isTrue);
    expect(await database.powersync.getCrudBatch(), isNotNull);
  });

  test('failure leaves both synced records and progress untouched', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/rollback.db',
    );
    addTearDown(database.close);
    final progressRepository = PowerSyncGoalOnboardingProgressRepository(
      database: database.powersync,
    );
    const progress = GoalOnboardingProgress(
      stage: GoalOnboardingStage.prayer,
      starterKey: GoalStarterKey.direction,
      title: 'Find direction',
      agencyChoice: GoalAgencyChoice.notSure,
      accountabilityChoice: GoalAccountabilityChoice.notNow,
      prayerSource: GoalOnboardingPrayerSource.personalPrayer,
      prayerResourceId: '0198a800-0000-7000-8000-000000009999',
    );
    await progressRepository.save(progress);
    final finalizer = PowerSyncGoalOnboardingFinalizer(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      uuid: const Uuid(),
    );

    await expectLater(finalizer.finalize(progress), throwsStateError);

    expect(await database.powersync.getAll('SELECT id FROM goals'), isEmpty);
    expect(
      await database.powersync.getAll('SELECT id FROM personal_prayers'),
      isEmpty,
    );
    expect(await progressRepository.load(), isNotNull);
  });
}
