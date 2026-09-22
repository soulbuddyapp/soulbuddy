import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/goals/data/goal_meditation_repository.dart';
import 'package:soulbuddy/features/goals/domain/goal_meditation_plan.dart';
import 'package:soulbuddy/features/goals/domain/goal_scripture_response.dart';

void main() {
  test('daily and weekly plans calculate the next local practice', () {
    final monday = DateTime(2026, 9, 21, 9);
    const daily = GoalMeditationPlan(
      goalId: 'goal-a',
      frequency: GoalMeditationFrequency.daily,
      hour: 7,
      minute: 30,
      durationMinutes: 10,
    );
    const weekly = GoalMeditationPlan(
      goalId: 'goal-b',
      frequency: GoalMeditationFrequency.weekly,
      weekday: DateTime.friday,
      hour: 8,
      minute: 0,
      durationMinutes: 20,
    );
    expect(daily.nextAfter(monday), DateTime(2026, 9, 22, 7, 30));
    expect(weekly.nextAfter(monday), DateTime(2026, 9, 25, 8));
    expect(
      weekly.nextAfter(DateTime(2026, 9, 25, 9)),
      DateTime(2026, 10, 2, 8),
    );
  });

  test('plan and private notes survive repository reload', () async {
    final values = <String, String>{};
    GoalMeditationRepository repo() => GoalMeditationRepository(
      read: (key) async => values[key],
      write: (key, value) async => values[key] = value,
    );
    const plan = GoalMeditationPlan(
      goalId: 'goal-a',
      frequency: GoalMeditationFrequency.daily,
      hour: 7,
      minute: 30,
      durationMinutes: 10,
    );
    await repo().savePlan(plan);
    await repo().addEntry(
      GoalMeditationEntry(
        id: 'note-a',
        goalId: 'goal-a',
        createdAt: DateTime.utc(2026, 9, 21, 7, 40),
        text: 'Serve my neighbor this week.',
      ),
    );
    expect((await repo().loadPlans()).single, plan);
    expect(
      (await repo().loadEntries('goal-a')).single.text,
      'Serve my neighbor this week.',
    );
    await repo().deletePlan('goal-a');
    expect(await repo().loadPlan('goal-a'), isNull);
    expect(
      (await repo().loadEntries('goal-a')).single.text,
      'Serve my neighbor this week.',
    );
  });

  test(
    'unfinished notebook draft survives restart and clears on finish',
    () async {
      final values = <String, String>{};
      GoalMeditationRepository repo() => GoalMeditationRepository(
        read: (key) async => values[key],
        write: (key, value) async => values[key] = value,
      );
      await repo().saveDraft('goal-a', 'A thought worth discerning');
      expect(await repo().loadDraft('goal-a'), 'A thought worth discerning');
      await repo().clearDraft('goal-a');
      expect(await repo().loadDraft('goal-a'), isNull);
    },
  );

  test('a Scripture response stays with its Goal across sessions', () async {
    final values = <String, String>{};
    GoalMeditationRepository repo() => GoalMeditationRepository(
      read: (key) async => values[key],
      write: (key, value) async => values[key] = value,
    );
    await repo().saveScriptureResponseKey('goal-a', 'anger');
    expect(await repo().loadScriptureResponseKey('goal-a'), 'anger');
    expect(await repo().loadScriptureResponseKey('goal-b'), isNull);
    expect(goalScriptureResponseForKey('anger')?.reference, 'James 1:19–20');
    expect(goalScriptureResponseForKey('unknown'), isNull);
  });
}
