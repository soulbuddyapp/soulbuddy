import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/today/data/powersync_today_guidance_repository.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  test(
    'projects feature use and counts only scheduled uncompleted history',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'today-guidance-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final database = await openTestDatabase('${directory.path}/guidance.db');
      addTearDown(database.close);
      const owner = 'owner-1';
      await database.powersync.execute(
        "INSERT INTO personal_prayers(id, owner_id) VALUES ('prayer-1', ?)",
        [owner],
      );
      await database.powersync.execute(
        "INSERT INTO encounters(id, owner_id) VALUES ('memory-1', ?)",
        [owner],
      );
      await database.powersync.execute(
        "INSERT INTO prayer_people(id, owner_id) VALUES ('person-1', ?)",
        [owner],
      );
      await database.powersync.execute(
        "INSERT INTO goals(id, owner_id) VALUES ('goal-1', ?)",
        [owner],
      );
      await database.powersync.execute(
        '''
      INSERT INTO goal_actions(
        id, goal_id, owner_id, schedule_type, enabled, created_at
      ) VALUES ('action-1', 'goal-1', ?, 'daily', 1, '2026-08-23T08:00:00.000Z')
      ''',
        [owner],
      );
      await database.powersync.execute(
        '''
      INSERT INTO goal_action_events(
        id, goal_action_id, goal_id, owner_id, event_type, occurrence_key,
        occurred_at, local_date
      ) VALUES (
        'event-1', 'action-1', 'goal-1', ?, 'completed',
        'action-1:2026-08-23', '2026-08-23T09:00:00.000Z', '2026-08-23'
      )
      ''',
        [owner],
      );

      final snapshot = await PowerSyncTodayGuidanceRepository(
        database: database.powersync,
        ownerId: owner,
      ).watch(DateTime(2026, 8, 30)).first;

      expect(snapshot.usedPrayer, isTrue);
      expect(snapshot.usedMemory, isTrue);
      expect(snapshot.usedPersons, isTrue);
      expect(snapshot.usedGoals, isTrue);
      expect(snapshot.usedAltar, isFalse);
      expect(snapshot.joinedCircle, isFalse);
      expect(snapshot.missedScheduledRoutineCount, 6);
    },
  );

  test('selected-day masks and Circle membership remain factual', () async {
    final directory = await Directory.systemTemp.createTemp('today-circle-');
    addTearDown(() => directory.delete(recursive: true));
    final database = await openTestDatabase('${directory.path}/circle.db');
    addTearDown(database.close);
    const owner = 'owner-1';
    await database.powersync.execute(
      "INSERT INTO circle_members(id, owner_id) VALUES ('member-1', ?)",
      [owner],
    );
    await database.powersync.execute(
      "INSERT INTO goals(id, owner_id) VALUES ('goal-1', ?)",
      [owner],
    );
    await database.powersync.execute(
      '''
      INSERT INTO goal_actions(
        id, goal_id, owner_id, schedule_type, weekdays_mask, enabled, created_at
      ) VALUES (
        'action-1', 'goal-1', ?, 'selected_days', 1, 1,
        '2026-08-23T08:00:00.000Z'
      )
      ''',
      [owner],
    );

    final snapshot = await PowerSyncTodayGuidanceRepository(
      database: database.powersync,
      ownerId: owner,
    ).watch(DateTime(2026, 8, 30)).first;

    expect(snapshot.joinedCircle, isTrue);
    expect(snapshot.missedScheduledRoutineCount, 1);
  });
}
