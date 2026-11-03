import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/goals/data/powersync_goal_onboarding_progress_repository.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/domain/goal_onboarding_progress.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-goal-onboarding-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('survives database reopen without entering the sync queue', () async {
    final path = '${temporaryDirectory.path}/soulbuddy.db';
    final firstDatabase = await openTestDatabase(path);
    final repository = PowerSyncGoalOnboardingProgressRepository(
      database: firstDatabase.powersync,
      ownerId: 'owner-1',
      now: () => DateTime.utc(2026, 8, 28, 3),
    );

    await repository.save(
      const GoalOnboardingProgress(
        stage: GoalOnboardingStage.prayer,
        starterKey: GoalStarterKey.direction,
        title: 'Find direction in my work',
        currentSituation: 'I have two paths in front of me.',
        situationByVoice: true,
        agencyChoice: GoalAgencyChoice.stepsICanTake,
        todayAction: 'Call Emmanuel about the course',
        guardNote: 'Do not keep postponing the application',
        accountabilityChoice: GoalAccountabilityChoice.trustedPerson,
        prayerSource: GoalOnboardingPrayerSource.scripture,
        scriptureTranslation: 'RSVCE',
        scriptureBook: 'James',
        scriptureChapter: 1,
        scriptureFirstVerse: 5,
        scriptureLastVerse: 5,
      ),
    );

    expect(await firstDatabase.powersync.getCrudBatch(), isNull);
    await firstDatabase.close();

    final reopenedDatabase = await openTestDatabase(path);
    addTearDown(reopenedDatabase.close);
    final reopened = PowerSyncGoalOnboardingProgressRepository(
      database: reopenedDatabase.powersync,
      ownerId: 'owner-1',
    );
    final saved = await reopened.load();

    expect(saved, isNotNull);
    expect(saved!.stage, GoalOnboardingStage.prayer);
    expect(saved.starterKey, GoalStarterKey.direction);
    expect(saved.title, 'Find direction in my work');
    expect(saved.situationByVoice, isTrue);
    expect(saved.agencyChoice, GoalAgencyChoice.stepsICanTake);
    expect(saved.todayAction, 'Call Emmanuel about the course');
    expect(saved.accountabilityChoice, GoalAccountabilityChoice.trustedPerson);
    expect(saved.prayerSource, GoalOnboardingPrayerSource.scripture);
    expect(saved.scriptureBook, 'James');
    expect(saved.scriptureChapter, 1);
    expect(saved.hasCompletePrayerSelection, isTrue);
  });

  test('alcohol safety state survives reopen and remains local-only', () async {
    final path = '${temporaryDirectory.path}/alcohol.db';
    final firstDatabase = await openTestDatabase(path);
    final repository = PowerSyncGoalOnboardingProgressRepository(
      database: firstDatabase.powersync,
      ownerId: 'owner-1',
    );
    await repository.save(
      const GoalOnboardingProgress(
        stage: GoalOnboardingStage.situation,
        starterKey: GoalStarterKey.stopControl,
        stopBehaviorKey: GoalStopBehaviorKey.alcohol,
        alcoholSafetyChoice: GoalAlcoholSafetyChoice.medicalGuidance,
        alcoholCareAcknowledged: true,
      ),
    );

    expect(await firstDatabase.powersync.getCrudBatch(), isNull);
    await firstDatabase.close();

    final reopenedDatabase = await openTestDatabase(path);
    addTearDown(reopenedDatabase.close);
    final reopened = PowerSyncGoalOnboardingProgressRepository(
      database: reopenedDatabase.powersync,
      ownerId: 'owner-1',
    );
    final saved = await reopened.load();

    expect(saved?.stage, GoalOnboardingStage.situation);
    expect(saved?.stopBehaviorKey, GoalStopBehaviorKey.alcohol);
    expect(saved?.alcoholSafetyChoice, GoalAlcoholSafetyChoice.medicalGuidance);
    expect(saved?.alcoholCareAcknowledged, isTrue);
    expect(saved?.alcoholSafetyCleared, isTrue);
  });

  test('treats corrupt persisted enum state as unusable', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);
    await database.powersync.execute(
      '''
      INSERT INTO goal_onboarding_progress(id, stage, agency_choice, updated_at)
      VALUES (?, ?, ?, ?)
      ''',
      ['current', 'agency', 'invented_choice', '2026-08-28T03:00:00.000Z'],
    );
    final repository = PowerSyncGoalOnboardingProgressRepository(
      database: database.powersync,
      ownerId: 'owner-1',
    );

    expect(await repository.load(), isNull);
  });

  test('clear removes only the resumable wizard record', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncGoalOnboardingProgressRepository(
      database: database.powersync,
      ownerId: 'owner-1',
    );
    await repository.save(
      const GoalOnboardingProgress(
        stage: GoalOnboardingStage.situation,
        starterKey: GoalStarterKey.stopControl,
        stopBehaviorKey: GoalStopBehaviorKey.pornography,
        title: 'Stop watching pornography',
      ),
    );

    await repository.clear();

    expect(await repository.load(), isNull);
  });

  test('restart clears only this owner’s draft recording links', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/recording-reset.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncGoalOnboardingProgressRepository(
      database: database.powersync,
      ownerId: 'owner-1',
    );
    await repository.save(
      const GoalOnboardingProgress(
        stage: GoalOnboardingStage.situation,
        starterKey: GoalStarterKey.direction,
        title: 'Find direction',
      ),
    );
    for (final (id, owner, context) in [
      ('draft-note', 'owner-1', 'onboarding'),
      ('saved-goal-note', 'owner-1', 'saved-goal'),
      ('other-owner-note', 'owner-2', 'onboarding'),
    ]) {
      await database.powersync.execute(
        'INSERT INTO voice_note_links '
        '(id, owner_id, context_type, context_id, field_key, encounter_id, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [id, owner, 'goal', context, 'situation', 'audio-$id', '2026-11-03T00:00:00Z'],
      );
    }

    await repository.save(const GoalOnboardingProgress());

    final links = await database.powersync.getAll(
      'SELECT id FROM voice_note_links ORDER BY id',
    );
    expect(links.map((row) => row['id']), [
      'other-owner-note',
      'saved-goal-note',
    ]);
    expect(await database.powersync.getCrudBatch(), isNull);
  });

  test('own words require non-empty user text before completion', () {
    expect(
      const GoalOnboardingProgress(
        prayerSource: GoalOnboardingPrayerSource.ownWords,
        ownPrayerText: '   ',
      ).hasCompletePrayerSelection,
      isFalse,
    );
    expect(
      const GoalOnboardingProgress(
        prayerSource: GoalOnboardingPrayerSource.ownWords,
        ownPrayerText: 'Father, give me wisdom for the next faithful step.',
      ).hasCompletePrayerSelection,
      isTrue,
    );
  });
}
