import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/goals/application/daily_faithfulness.dart';
import 'package:soulbuddy/features/goals/data/powersync_goal_repository.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/domain/goal_action.dart';
import '../../helpers/powersync_test_database.dart';

void main() {
  test(
    'a practice persists as a normal goal action and survives reopening',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'soulbuddy-faithfulness-',
      );
      final database = await openTestDatabase('${dir.path}/practice.db');
      addTearDown(() async {
        await database.close();
        await dir.delete(recursive: true);
      });
      final day = DateTime(2026, 9, 11, 8);
      final goals = PowerSyncGoalRepository(
        database: database.powersync,
        ownerId: 'owner',
        deviceId: 'device',
        now: () => day,
      );
      final service = DailyFaithfulness(goals);
      final action = await service.save(
        precept: SpiritualPrecept.guardTheGate,
        body: 'Silence one distraction',
        localDate: day,
      );
      expect(action.kind, GoalActionKind.guard);
      expect(action.scheduleType, GoalScheduleType.today);
      expect((await goals.watchActive().first).single.title, 'Guard the gate');
      final reopened = DailyFaithfulness(goals);
      final repeated = await reopened.save(
        precept: SpiritualPrecept.guardTheGate,
        body: 'Silence one distraction',
        localDate: day,
      );
      expect(repeated.id, action.id);
      expect(await goals.watchDueActions(day).first, hasLength(1));
      await goals.completeAction(action.id, localDate: day);
      expect(
        (await goals.watchScheduledActions(day).first).single.latestEventType,
        GoalActionEventType.completed,
      );
      expect(await goals.watchDueActions(day).first, isEmpty);
      expect(
        (await reopened.save(
          precept: SpiritualPrecept.guardTheGate,
          body: 'Silence one distraction',
          localDate: day,
        )).id,
        action.id,
      );
      expect(await goals.watchDueActions(DateTime(2026, 9, 12)).first, isEmpty);
    },
  );

  test(
    'daily practice attaches to the chosen goal without creating another goal',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'soulbuddy-faithfulness-',
      );
      final database = await openTestDatabase('${dir.path}/daily.db');
      addTearDown(() async {
        await database.close();
        await dir.delete(recursive: true);
      });
      final day = DateTime(2026, 9, 11, 8);
      final goals = PowerSyncGoalRepository(
        database: database.powersync,
        ownerId: 'owner',
        deviceId: 'device',
        now: () => day,
      );
      final goal = await goals.create(
        title: 'Serve my family',
        mode: GoalMode.actionable,
      );
      final service = DailyFaithfulness(goals);
      final action = await service.save(
        precept: SpiritualPrecept.strengthForToday,
        body: 'Help with one household task',
        goalId: goal.id,
        repeatDaily: true,
        localDate: day,
      );
      expect(action.goalId, goal.id);
      expect(action.scheduleType, GoalScheduleType.daily);
      expect(
        (await goals.watchDueActions(DateTime(2026, 9, 12)).first)
            .single
            .action
            .id,
        action.id,
      );
      expect(await goals.watchActive().first, hasLength(1));
      await expectLater(
        service.save(
          precept: SpiritualPrecept.strengthForToday,
          body: '  ',
          localDate: day,
        ),
        throwsArgumentError,
      );
      expect(await goals.watchActive().first, hasLength(1));
    },
  );
}
