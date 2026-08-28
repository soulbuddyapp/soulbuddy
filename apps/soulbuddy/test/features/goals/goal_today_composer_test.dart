import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/goals/application/goal_today_composer.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/domain/goal_action.dart';

void main() {
  const composer = GoalTodayComposer();

  test('groups only active Goals in explicit position order', () {
    final sections = composer.compose(
      goals: [
        _goal('second', position: 2),
        _goal('paused', position: 0, status: GoalStatus.paused),
        _goal('first', position: 1),
      ],
      dueActions: [
        _occurrence(_action('a-second', 'second')),
        _occurrence(_action('a-paused', 'paused')),
        _occurrence(_action('a-first', 'first')),
      ],
    );

    expect(sections.map((section) => section.goal.id), ['first', 'second']);
    expect(
      sections.expand((section) => section.items).map((item) => item.goalId),
      ['first', 'second'],
    );
  });

  test('keeps the smallest useful set and uses transparent priority', () {
    final goal = _goal('goal');
    final ordinary = _occurrence(
      _action('ordinary', goal.id, kind: GoalActionKind.nextStep),
    );
    final timedGuard = _occurrence(
      _action(
        'timed-guard',
        goal.id,
        kind: GoalActionKind.guard,
        scheduleType: GoalScheduleType.daily,
        localTime: '22:00',
      ),
    );
    final care = _occurrence(
      _action('care', goal.id, kind: GoalActionKind.care),
    );
    final sections = composer.compose(
      goals: [goal],
      dueActions: [ordinary, care, timedGuard],
      resources: [
        GoalTodayResourceCandidate(
          goalId: goal.id,
          stableKey: 'prayer-1',
          dedupeKey: 'prayer:1',
          kind: GoalTodayResourceKind.prayer,
          label: 'Prayer',
        ),
      ],
    );

    expect(sections, hasLength(1));
    final items = sections.single.items;
    expect(items, hasLength(3));
    expect(
      (items[0] as GoalTodayActionItem).occurrence.action.id,
      'timed-guard',
    );
    expect(
      (items[1] as GoalTodayResourceItem).resource.kind,
      GoalTodayResourceKind.prayer,
    );
    expect((items[2] as GoalTodayActionItem).occurrence.action.id, 'ordinary');
  });

  test('today onceAt alone does not make a guard time-sensitive', () {
    final goal = _goal('goal');
    final sameDayGuard = _occurrence(
      _action(
        'today-guard',
        goal.id,
        kind: GoalActionKind.guard,
        scheduleType: GoalScheduleType.today,
        onceAt: DateTime(2026, 8, 28, 9),
      ),
    );
    final timedGuard = _occurrence(
      _action(
        'timed-guard',
        goal.id,
        kind: GoalActionKind.guard,
        scheduleType: GoalScheduleType.daily,
        localTime: '21:30',
      ),
    );

    final items = composer
        .compose(
          goals: [goal],
          dueActions: [sameDayGuard, timedGuard],
          resources: [
            GoalTodayResourceCandidate(
              goalId: goal.id,
              stableKey: 'prayer',
              dedupeKey: 'prayer:1',
              kind: GoalTodayResourceKind.prayer,
              label: 'Prayer',
            ),
          ],
        )
        .single
        .items;

    expect(
      (items[0] as GoalTodayActionItem).occurrence.action.id,
      'timed-guard',
    );
    expect(items[1], isA<GoalTodayResourceItem>());
    expect(
      (items[2] as GoalTodayActionItem).occurrence.action.id,
      'today-guard',
    );
  });

  test('due reminder replaces the generic copy of the same prayer', () {
    final goal = _goal('goal');
    final items = composer
        .compose(
          goals: [goal],
          dueActions: const [],
          resources: [
            GoalTodayResourceCandidate(
              goalId: goal.id,
              stableKey: 'generic-prayer',
              dedupeKey: 'prayer:library:1',
              kind: GoalTodayResourceKind.prayer,
              label: 'Prayer',
            ),
            GoalTodayResourceCandidate(
              goalId: goal.id,
              stableKey: 'reminder-occurrence',
              dedupeKey: 'prayer:library:1',
              kind: GoalTodayResourceKind.reminder,
              label: 'Prayer reminder',
              dueAt: DateTime(2026, 8, 28, 8),
            ),
          ],
        )
        .single
        .items;

    expect(items, hasLength(1));
    expect(
      (items.single as GoalTodayResourceItem).resource.kind,
      GoalTodayResourceKind.reminder,
    );
  });

  test(
    'completed and skipped occurrences stay out while retracted reopens',
    () {
      final goal = _goal('goal');
      final items = composer
          .compose(
            goals: [goal],
            dueActions: [
              _occurrence(
                _action('complete', goal.id),
                latest: GoalActionEventType.completed,
              ),
              _occurrence(
                _action('skip', goal.id),
                latest: GoalActionEventType.skipped,
              ),
              _occurrence(
                _action('retracted', goal.id),
                latest: GoalActionEventType.retracted,
              ),
              _occurrence(_action('open', goal.id)),
            ],
          )
          .single
          .items;

      expect(
        items.cast<GoalTodayActionItem>().map(
          (item) => item.occurrence.action.id,
        ),
        ['retracted', 'open'],
      );
    },
  );

  test('duplicate action occurrence keys render once and keep first source', () {
    final goal = _goal('goal');
    const occurrenceKey = 'same-occurrence:2026-08-28';
    final items = composer
        .compose(
          goals: [goal],
          dueActions: [
            GoalActionOccurrence(
              action: _action('first-source', goal.id),
              occurrenceKey: occurrenceKey,
            ),
            GoalActionOccurrence(
              action: _action('duplicate-source', goal.id),
              occurrenceKey: occurrenceKey,
            ),
          ],
        )
        .single
        .items;

    expect(items, hasLength(1));
    expect(
      (items.single as GoalTodayActionItem).occurrence.action.id,
      'first-source',
    );
  });

  test(
    'same-priority items preserve repository order without hidden scoring',
    () {
      final goal = _goal('goal');
      final items = composer
          .compose(
            goals: [goal],
            dueActions: [
              _occurrence(_action('first', goal.id)),
              _occurrence(_action('second', goal.id)),
              _occurrence(_action('third', goal.id)),
              _occurrence(_action('fourth', goal.id)),
            ],
          )
          .single
          .items;

      expect(
        items.cast<GoalTodayActionItem>().map(
          (item) => item.occurrence.action.id,
        ),
        ['first', 'second', 'third'],
      );
    },
  );
}

Goal _goal(
  String id, {
  int position = 0,
  GoalStatus status = GoalStatus.active,
}) => Goal(
  id: id,
  ownerId: 'owner-1',
  mode: GoalMode.mixed,
  status: status,
  currentRevisionId: 'revision-$id',
  position: position,
  title: 'Goal $id',
  createdAt: DateTime.utc(2026, 8, 28, 7),
  updatedAt: DateTime.utc(2026, 8, 28, 7),
);

GoalAction _action(
  String id,
  String goalId, {
  GoalActionKind kind = GoalActionKind.nextStep,
  GoalScheduleType scheduleType = GoalScheduleType.daily,
  String? localTime,
  DateTime? onceAt,
}) => GoalAction(
  id: id,
  goalId: goalId,
  ownerId: 'owner-1',
  body: 'Action $id',
  kind: kind,
  scheduleType: scheduleType,
  localTime: localTime,
  onceAt: onceAt,
  enabled: true,
  createdAt: DateTime.utc(2026, 8, 28, 7),
  updatedAt: DateTime.utc(2026, 8, 28, 7),
);

GoalActionOccurrence _occurrence(
  GoalAction action, {
  GoalActionEventType? latest,
}) => GoalActionOccurrence(
  action: action,
  occurrenceKey: '${action.id}:2026-08-28',
  latestEventType: latest,
);
