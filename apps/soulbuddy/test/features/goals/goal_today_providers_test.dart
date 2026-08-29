import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/goals/application/goal_today_composer.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/domain/goal_action.dart';
import 'package:soulbuddy/features/goals/domain/goal_link.dart';
import 'package:soulbuddy/features/goals/providers/goal_providers.dart';
import 'package:soulbuddy/features/goals/providers/goal_today_providers.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:soulbuddy/features/prayers/domain/today_prayer.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_practice_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_providers.dart';

void main() {
  test(
    'optional reminder and legacy failures never hide local Goal actions',
    () async {
      final goal = _goal('goal-1');
      final container = ProviderContainer(
        overrides: [
          todayPrayerDateProvider.overrideWith(
            (ref) => Stream.value((year: 2026, month: 8, day: 28)),
          ),
          activeGoalsProvider.overrideWith((ref) => Stream.value([goal])),
          activeGoalTodayLinksProvider.overrideWith(
            (ref) => Stream.value(const <GoalLink>[]),
          ),
          activeGoalPrayerTitlesProvider.overrideWith(
            (ref) => Stream.value(const <PrayerReference, String>{}),
          ),
          activeReturnGoalIdsProvider.overrideWith(
            (ref) => Stream.value(const <String>{}),
          ),
          dueGoalActionsProvider.overrideWith(
            (ref, localDate) => Stream.value([
              _occurrence(_action('action-1', goal.id), localDate),
            ]),
          ),
          duePrayerOccurrencesProvider.overrideWith(
            (ref) => Stream.error(StateError('reminders unavailable')),
          ),
          todayPrayerProvider.overrideWith(
            (ref) => Stream.error(StateError('legacy Today unavailable')),
          ),
        ],
      );
      addTearDown(container.dispose);

      final snapshot = await _nextSnapshot(container);

      expect(snapshot.localDate, DateTime(2026, 8, 28));
      expect(snapshot.sections, hasLength(1));
      expect(snapshot.sections.single.goal.id, goal.id);
      expect(snapshot.sections.single.items, hasLength(1));
      expect(snapshot.sections.single.items.single, isA<GoalTodayActionItem>());
      expect(snapshot.resources.candidates, isEmpty);
    },
  );

  test(
    'legacy Today stays explicit when it is not linked to an active Goal',
    () async {
      final goal = _goal('goal-1');
      final today = _today(const PrayerReference.library('library-1'));
      final container = ProviderContainer(
        overrides: [
          todayPrayerDateProvider.overrideWith(
            (ref) => Stream.value((year: 2026, month: 8, day: 28)),
          ),
          activeGoalsProvider.overrideWith((ref) => Stream.value([goal])),
          activeGoalTodayLinksProvider.overrideWith(
            (ref) => Stream.value(const <GoalLink>[]),
          ),
          activeGoalPrayerTitlesProvider.overrideWith(
            (ref) => Stream.value(const <PrayerReference, String>{}),
          ),
          activeReturnGoalIdsProvider.overrideWith(
            (ref) => Stream.value(const <String>{}),
          ),
          dueGoalActionsProvider.overrideWith(
            (ref, localDate) => Stream.value(const <GoalActionOccurrence>[]),
          ),
          duePrayerOccurrencesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          todayPrayerProvider.overrideWith((ref) => Stream.value(today)),
        ],
      );
      addTearDown(container.dispose);

      final snapshot = await _nextSnapshot(
        container,
        where: (value) => value.resources.legacyTodayOutsideActiveGoals != null,
      );

      expect(snapshot.sections, isEmpty);
      expect(snapshot.resources.legacyTodayOutsideActiveGoals, same(today));
    },
  );

  test(
    'core active-link failure is surfaced instead of silently dropping data',
    () async {
      final container = ProviderContainer(
        overrides: [
          todayPrayerDateProvider.overrideWith(
            (ref) => Stream.value((year: 2026, month: 8, day: 28)),
          ),
          activeGoalsProvider.overrideWith(
            (ref) => Stream.value([_goal('goal-1')]),
          ),
          activeGoalTodayLinksProvider.overrideWith(
            (ref) => Stream.error(StateError('links unavailable')),
          ),
          activeGoalPrayerTitlesProvider.overrideWith(
            (ref) => Stream.value(const <PrayerReference, String>{}),
          ),
          activeReturnGoalIdsProvider.overrideWith(
            (ref) => Stream.value(const <String>{}),
          ),
          duePrayerOccurrencesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          todayPrayerProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(_nextSnapshot(container), throwsStateError);
    },
  );

  test(
    'stop-control Goal remains on Today for Return with no due items',
    () async {
      final goal = _goal('goal-return', starterKey: GoalStarterKey.stopControl);
      final container = _quietGoalContainer(
        goal,
        returnIds: Stream.value({goal.id}),
      );
      addTearDown(container.dispose);

      final snapshot = await _nextSnapshot(
        container,
        where: (value) => value.returnGoalIds.contains(goal.id),
      );

      expect(snapshot.sections, hasLength(1));
      expect(snapshot.sections.single.goal.id, goal.id);
      expect(snapshot.sections.single.items, isEmpty);
      expect(snapshot.returnGoalIds, contains(goal.id));
    },
  );

  test(
    'Return relevance failure still keeps explicit stop-control Goal usable',
    () async {
      final goal = _goal('goal-return', starterKey: GoalStarterKey.stopControl);
      final container = _quietGoalContainer(
        goal,
        returnIds: Stream.error(StateError('return projection unavailable')),
      );
      addTearDown(container.dispose);

      final snapshot = await _nextSnapshot(
        container,
        where: (value) => value.returnGoalIds.contains(goal.id),
      );

      expect(snapshot.sections, hasLength(1));
      expect(snapshot.sections.single.goal.id, goal.id);
      expect(snapshot.sections.single.items, isEmpty);
    },
  );
}

ProviderContainer _quietGoalContainer(
  Goal goal, {
  required Stream<Set<String>> returnIds,
}) {
  return ProviderContainer(
    overrides: [
      todayPrayerDateProvider.overrideWith(
        (ref) => Stream.value((year: 2026, month: 8, day: 28)),
      ),
      activeGoalsProvider.overrideWith((ref) => Stream.value([goal])),
      activeGoalTodayLinksProvider.overrideWith(
        (ref) => Stream.value(const <GoalLink>[]),
      ),
      activeGoalPrayerTitlesProvider.overrideWith(
        (ref) => Stream.value(const <PrayerReference, String>{}),
      ),
      activeReturnGoalIdsProvider.overrideWith((ref) => returnIds),
      dueGoalActionsProvider.overrideWith(
        (ref, localDate) => Stream.value(const <GoalActionOccurrence>[]),
      ),
      duePrayerOccurrencesProvider.overrideWith((ref) => Stream.value(const [])),
      todayPrayerProvider.overrideWith((ref) => Stream.value(null)),
    ],
  );
}

Future<GoalTodaySnapshot> _nextSnapshot(
  ProviderContainer container, {
  bool Function(GoalTodaySnapshot)? where,
}) async {
  final completer = Completer<GoalTodaySnapshot>();
  final subscription = container.listen(goalTodaySnapshotProvider, (
    previous,
    next,
  ) {
    if (next case AsyncData(:final value)) {
      if ((where == null || where(value)) && !completer.isCompleted) {
        completer.complete(value);
      }
    } else if (next case AsyncError(:final error, :final stackTrace)) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }
  }, fireImmediately: true);
  try {
    return await completer.future;
  } finally {
    subscription.close();
  }
}

Goal _goal(String id, {GoalStarterKey? starterKey}) => Goal(
  id: id,
  ownerId: 'owner-1',
  starterKey: starterKey,
  mode: GoalMode.mixed,
  status: GoalStatus.active,
  currentRevisionId: 'revision-$id',
  position: 0,
  title: 'Goal $id',
  createdAt: DateTime.utc(2026, 8, 28, 8),
  updatedAt: DateTime.utc(2026, 8, 28, 8),
);

GoalAction _action(String id, String goalId) => GoalAction(
  id: id,
  goalId: goalId,
  ownerId: 'owner-1',
  body: 'Take one faithful step',
  kind: GoalActionKind.nextStep,
  scheduleType: GoalScheduleType.daily,
  enabled: true,
  createdAt: DateTime.utc(2026, 8, 28, 8),
  updatedAt: DateTime.utc(2026, 8, 28, 8),
);

GoalActionOccurrence _occurrence(GoalAction action, DateTime localDate) =>
    GoalActionOccurrence(
      action: action,
      occurrenceKey: action.occurrenceKeyFor(localDate),
    );

TodayPrayer _today(PrayerReference reference) => TodayPrayer(
  prayer: PrayerDisplayValue(
    reference: reference,
    title: 'Prayer for today',
    body: 'Lord, guide me.',
    grounding: PrayerGrounding.generalChristian,
    purpose: PrayerPurpose.guidance,
  ),
  localDate: DateTime(2026, 8, 28),
  includeAction: false,
  actionCompleted: false,
);
