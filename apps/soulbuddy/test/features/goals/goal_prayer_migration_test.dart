import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/goals/data/goal_prayer_migration.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-goal-prayer-migration-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('explicit keep atomically creates one Goal, revision and prayer link', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/library.db',
    );
    addTearDown(database.close);
    const prayerId = '0198b200-0000-7000-8000-000000000001';
    await database.powersync.execute(
      '''
      INSERT INTO bundled_prayers(
        id, title, body, grounding, language_style, purpose, action,
        helpful_count, content_version, archived_at
      ) VALUES (?, ?, ?, ?, ?, ?, NULL, 0, 1, NULL)
      ''',
      [
        prayerId,
        'Prayer for guidance',
        'Lord, guide me.',
        'general_christian',
        'christian',
        'guidance',
      ],
    );

    final migration = PowerSyncGoalPrayerMigration(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      now: () => DateTime.utc(2026, 8, 28, 7, 30),
      uuid: const Uuid(),
    );
    const reference = PrayerReference.library(prayerId);

    expect(await migration.watchLinked(reference).first, isFalse);
    final goalId = await migration.keepPrayerUnderGoal(
      title: 'Choose the next faithful work step',
      prayer: reference,
    );

    final goals = await database.powersync.getAll(
      '''
      SELECT goal.id, goal.mode, goal.status, revision.title
      FROM goals AS goal
      JOIN goal_revisions AS revision
        ON revision.id = goal.current_revision_id
       AND revision.goal_id = goal.id
       AND revision.owner_id = goal.owner_id
      WHERE goal.owner_id = ?
      ''',
      ['owner-1'],
    );
    final links = await database.powersync.getAll(
      'SELECT * FROM goal_links WHERE owner_id = ?',
      ['owner-1'],
    );
    final actions = await database.powersync.getAll(
      'SELECT * FROM goal_actions WHERE owner_id = ?',
      ['owner-1'],
    );

    expect(goals, hasLength(1));
    expect(goals.single['id'], goalId);
    expect(goals.single['title'], 'Choose the next faithful work step');
    expect(goals.single['mode'], 'mixed');
    expect(goals.single['status'], 'active');
    expect(links, hasLength(1));
    expect(links.single['goal_id'], goalId);
    expect(links.single['link_type'], 'library_prayer');
    expect(links.single['library_prayer_id'], prayerId);
    expect(links.single['role'], 'primary_prayer');
    expect(actions, isEmpty, reason: 'Migration must not invent a Goal action.');
    expect(await migration.watchLinked(reference).first, isTrue);
    expect(await database.powersync.getCrudBatch(), isNotNull);

    final replayedGoalId = await migration.keepPrayerUnderGoal(
      title: 'A different title must not duplicate the migration',
      prayer: reference,
    );
    expect(replayedGoalId, goalId);
    expect(
      await database.powersync.getAll(
        'SELECT id FROM goals WHERE owner_id = ?',
        ['owner-1'],
      ),
      hasLength(1),
    );
    expect(
      await database.powersync.getAll(
        'SELECT id FROM goal_links WHERE owner_id = ?',
        ['owner-1'],
      ),
      hasLength(1),
    );
  });

  test('wrong-owner personal prayer cannot create a Goal', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/owner.db',
    );
    addTearDown(database.close);
    const prayerId = '0198b200-0000-7000-8000-000000000002';
    await database.powersync.execute(
      '''
      INSERT INTO personal_prayers(
        id, owner_id, title, style, reach, grounding, purpose,
        current_revision_id, created_at, updated_at, archived_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
      ''',
      [
        prayerId,
        'owner-2',
        'Private prayer',
        'situational',
        'personal',
        'general_christian',
        'daily',
        'revision-2',
        '2026-08-28T07:30:00.000Z',
        '2026-08-28T07:30:00.000Z',
      ],
    );
    final migration = PowerSyncGoalPrayerMigration(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      uuid: const Uuid(),
    );

    await expectLater(
      migration.keepPrayerUnderGoal(
        title: 'Should not exist',
        prayer: const PrayerReference.personal(prayerId),
      ),
      throwsStateError,
    );
    expect(
      await database.powersync.getAll(
        'SELECT id FROM goals WHERE owner_id = ?',
        ['owner-1'],
      ),
      isEmpty,
    );
  });
}
