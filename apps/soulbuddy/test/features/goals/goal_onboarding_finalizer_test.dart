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
      ownerId: 'owner-1',
    );
    const progress = GoalOnboardingProgress(
      stage: GoalOnboardingStage.prayer,
      starterKey: GoalStarterKey.stopControl,
      stopBehaviorKey: GoalStopBehaviorKey.pornography,
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
    for (final field in ['situation', 'action', 'guard']) {
      await database.powersync.execute(
        'INSERT INTO voice_note_links '
        '(id, owner_id, context_type, context_id, field_key, encounter_id, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          'note-$field', 'owner-1', 'goal', 'onboarding', field,
          'recording-$field', '2026-11-03T00:00:00Z',
        ],
      );
    }
    await database.powersync.execute(
      'INSERT INTO voice_note_links '
      '(id, owner_id, context_type, context_id, field_key, encounter_id, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      ['other-note', 'owner-2', 'goal', 'onboarding', 'situation',
        'other-recording', '2026-11-03T00:00:00Z'],
    );
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
    final recordings = await database.powersync.getAll(
      'SELECT context_id FROM voice_note_links WHERE owner_id = ?',
      ['owner-1'],
    );
    expect(recordings, hasLength(3));
    expect(recordings.every((row) => row['context_id'] == result.goalId), isTrue);
    expect(
      (await database.powersync.get(
        'SELECT context_id FROM voice_note_links WHERE id = ?',
        ['other-note'],
      ))['context_id'],
      'onboarding',
    );
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

  test(
    'five behavior starters finalize through the shared Goal engine',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/behavior-starters.db',
      );
      addTearDown(database.close);
      final finalizer = PowerSyncGoalOnboardingFinalizer(
        database: database.powersync,
        ownerId: 'owner-1',
        deviceId: 'device-1',
        now: () => DateTime(2026, 8, 29, 9),
        uuid: const Uuid(),
      );
      const starters = <(GoalStopBehaviorKey, String)>[
        (GoalStopBehaviorKey.pornography, 'Stop watching pornography'),
        (GoalStopBehaviorKey.gambling, 'Stop gambling'),
        (GoalStopBehaviorKey.nicotineTobacco, 'Stop smoking cigarettes'),
        (GoalStopBehaviorKey.alcohol, 'Change my drinking'),
        (GoalStopBehaviorKey.digitalDistraction, 'Stop losing hours online'),
      ];

      for (final starter in starters) {
        final result = await finalizer.finalize(
          GoalOnboardingProgress(
            stage: GoalOnboardingStage.prayer,
            starterKey: GoalStarterKey.stopControl,
            stopBehaviorKey: starter.$1,
            alcoholSafetyChoice: starter.$1 == GoalStopBehaviorKey.alcohol
                ? GoalAlcoholSafetyChoice.noKnownWithdrawalRisk
                : null,
            title: starter.$2,
            agencyChoice: GoalAgencyChoice.stepsICanTake,
            accountabilityChoice: GoalAccountabilityChoice.notNow,
            prayerSource: GoalOnboardingPrayerSource.ownWords,
            ownPrayerText: 'God, help me take the next faithful step.',
          ),
        );
        expect(result.goalId, isNotEmpty);
      }

      final goals = await database.powersync.getAll(
        'SELECT * FROM goals ORDER BY position',
      );
      expect(goals, hasLength(starters.length));
      expect(
        goals.every((row) => row['starter_key'] == 'stop_control'),
        isTrue,
      );
      expect(
        goals.every((row) => !row.containsKey('stop_behavior_key')),
        isTrue,
      );
    },
  );

  test('failure leaves both synced records and progress untouched', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/rollback.db',
    );
    addTearDown(database.close);
    final progressRepository = PowerSyncGoalOnboardingProgressRepository(
      database: database.powersync,
      ownerId: 'owner-1',
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
    await database.powersync.execute(
      'INSERT INTO voice_note_links '
      '(id, owner_id, context_type, context_id, field_key, encounter_id, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      ['draft-note', 'owner-1', 'goal', 'onboarding', 'situation',
        'recording', '2026-11-03T00:00:00Z'],
    );
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
    expect(
      (await database.powersync.get(
        'SELECT context_id FROM voice_note_links WHERE id = ?',
        ['draft-note'],
      ))['context_id'],
      'onboarding',
    );
  });
}
