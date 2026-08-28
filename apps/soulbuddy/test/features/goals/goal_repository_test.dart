import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/goals/data/powersync_goal_repository.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/domain/goal_action.dart';
import 'package:soulbuddy/features/goals/domain/goal_link.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-goals-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('creates and edits a Goal without destroying revisions', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/revision.db',
    );
    addTearDown(database.close);
    var now = DateTime.utc(2026, 8, 28, 8);
    final repository = PowerSyncGoalRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      now: () => now,
      uuid: const Uuid(),
    );

    final goal = await repository.create(
      title: 'Find direction in my work',
      currentSituation: 'I am deciding what to pursue next.',
      whyItMatters: 'I want to act faithfully instead of staying stuck.',
      mode: GoalMode.mixed,
      starterKey: GoalStarterKey.direction,
    );
    now = now.add(const Duration(minutes: 5));
    final edited = await repository.edit(
      goal.id,
      title: 'Choose the next faithful work step',
      currentSituation: 'I have two concrete options to examine.',
      whyItMatters: 'I should act on what is already clear.',
    );

    expect(edited.id, goal.id);
    expect(edited.currentRevisionId, isNot(goal.currentRevisionId));
    expect(edited.title, 'Choose the next faithful work step');
    final revisions = await repository.watchRevisions(goal.id).first;
    expect(revisions, hasLength(2));
    expect(
      revisions.map((revision) => revision.title),
      containsAll([
        'Find direction in my work',
        'Choose the next faithful work step',
      ]),
    );
  });

  test('keeps reads and mutations owner-scoped', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/owner.db',
    );
    addTearDown(database.close);
    final first = PowerSyncGoalRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      uuid: const Uuid(),
    );
    final second = PowerSyncGoalRepository(
      database: database.powersync,
      ownerId: 'owner-2',
      deviceId: 'device-2',
      uuid: const Uuid(),
    );
    final goal = await first.create(
      title: 'Grow closer to God',
      mode: GoalMode.mixed,
    );

    expect(await second.watch(goal.id).first, isNull);
    await expectLater(
      second.edit(goal.id, title: 'Tampered'),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      second.setStatus(goal.id, GoalStatus.completed),
      throwsA(isA<StateError>()),
    );
    expect((await first.watch(goal.id).first)?.status, GoalStatus.active);
  });

  test('links only owned or canonical resources with explicit shapes', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/links.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncGoalRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      uuid: const Uuid(),
    );
    final goal = await repository.create(
      title: 'Stop something fighting to control me',
      mode: GoalMode.actionable,
      starterKey: GoalStarterKey.stopControl,
    );
    const personalPrayerId = '0198b100-0000-7000-8000-000000000001';
    await database.powersync.execute(
      '''
      INSERT INTO personal_prayers(
        id, owner_id, title, style, reach, grounding, purpose,
        current_revision_id, created_at, updated_at, archived_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
      ''',
      [
        personalPrayerId,
        'owner-1',
        'Prayer for a clear mind',
        'daily',
        'personal',
        'general_christian',
        'daily',
        '0198b100-0000-7000-8000-000000000002',
        '2026-08-28T08:00:00.000Z',
        '2026-08-28T08:00:00.000Z',
      ],
    );

    final prayerLink = await repository.addLink(
      goal.id,
      const GoalLinkDraft.personalPrayer(personalPrayerId),
    );
    final scriptureLink = await repository.addLink(
      goal.id,
      const GoalLinkDraft.scripture(
        translation: 'RSVCE',
        book: 'James',
        chapter: 1,
        firstVerse: 5,
        lastVerse: 5,
      ),
    );

    expect(prayerLink.personalPrayerId, personalPrayerId);
    expect(scriptureLink.book, 'James');
    await expectLater(
      repository.addLink(
        goal.id,
        const GoalLinkDraft.circle('legacy-local-circle'),
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('composes due recurring actions and reopens them after retraction', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/actions.db',
    );
    addTearDown(database.close);
    final now = DateTime(2026, 8, 31, 8); // Monday.
    final repository = PowerSyncGoalRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      now: () => now,
      uuid: const Uuid(),
    );
    final goal = await repository.create(
      title: 'Keep my phone out of the bedroom',
      mode: GoalMode.actionable,
    );
    final daily = await repository.addAction(
      goal.id,
      const GoalActionDraft(
        body: 'Phone outside bedroom by 10 PM',
        kind: GoalActionKind.guard,
        scheduleType: GoalScheduleType.daily,
        localTime: '22:00',
      ),
    );
    await repository.addAction(
      goal.id,
      const GoalActionDraft(
        body: 'Monday check-in',
        kind: GoalActionKind.accountability,
        scheduleType: GoalScheduleType.selectedDays,
        weekdaysMask: 1,
      ),
    );

    expect(await repository.watchDueActions(now).first, hasLength(2));
    final completion = await repository.completeAction(
      daily.id,
      localDate: now,
      occurredAt: now.add(const Duration(hours: 14)),
    );
    expect(completion?.type, GoalActionEventType.completed);
    expect(await repository.watchDueActions(now).first, hasLength(1));
    expect(
      await repository.completeAction(daily.id, localDate: now),
      isNull,
    );

    final retraction = await repository.retractAction(
      daily.id,
      localDate: now,
      occurredAt: now.add(const Duration(hours: 14, minutes: 1)),
    );
    expect(retraction?.type, GoalActionEventType.retracted);
    expect(await repository.watchDueActions(now).first, hasLength(2));
  });

  test('records a Goal create as one offline CRUD transaction', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/crud.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncGoalRepository(
      database: database.powersync,
      ownerId: 'installation-owner',
      deviceId: 'device-1',
      uuid: const Uuid(),
    );

    final goal = await repository.create(
      title: 'Pray for Mum',
      mode: GoalMode.petition,
    );
    final transaction = await database.powersync.getNextCrudTransaction();

    expect(transaction, isNotNull);
    expect(transaction!.crud.map((entry) => entry.table).toSet(), {
      'goals',
      'goal_revisions',
    });
    expect(
      transaction.crud.singleWhere((entry) => entry.table == 'goals').id,
      goal.id,
    );
    await transaction.complete();
  });
}
