import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/goals/application/goal_today_composer.dart';
import 'package:soulbuddy/features/goals/application/goal_today_resource_adapter.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/domain/goal_action.dart';
import 'package:soulbuddy/features/goals/domain/goal_link.dart';
import 'package:soulbuddy/features/goals/presentation/goal_today_sections.dart';
import 'package:soulbuddy/features/goals/providers/goal_today_providers.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:soulbuddy/features/prayers/domain/today_prayer.dart';

void main() {
  testWidgets(
    'renders Goal work without progress mechanics and completes action',
    (tester) async {
      var completed = 0;
      final action = _action('action-1', 'goal-1');
      final snapshot = _snapshot([
        GoalTodayActionItem(
          GoalActionOccurrence(
            action: action,
            occurrenceKey: 'action-1:2026-08-28',
          ),
        ),
      ]);

      await tester.pumpWidget(
        _host(snapshot, onCompleteAction: (_) async => completed++),
      );

      expect(find.text('Stay close to God'), findsOneWidget);
      expect(find.text('Take one faithful step'), findsOneWidget);
      expect(find.textContaining('progress'), findsNothing);
      expect(find.textContaining('streak'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('goal-today-done-action-1:2026-08-28')),
      );
      await tester.pumpAndSettle();

      expect(completed, 1);
      expect(
        find.byKey(const ValueKey('completed-today-action-1:2026-08-28')),
        findsOneWidget,
      );
    },
  );

  testWidgets('quiet Return Goal exposes direct Return action', (tester) async {
    var returned = 0;
    final snapshot = _snapshot(const [], returnGoalIds: const {'goal-1'});

    await tester.pumpWidget(_host(snapshot, onReturn: (_) async => returned++));

    expect(find.text('Stay close to God'), findsOneWidget);
    expect(find.text('Return'), findsOneWidget);
    final button = find.byKey(const ValueKey('goal-today-return-goal-1'));
    expect(button.hitTestable(), findsOneWidget);

    await tester.tap(button);
    await tester.pump();

    expect(returned, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'legacy Goal prayer exposes Open and I prayed this through typed handle',
    (tester) async {
      var opened = 0;
      var prayed = 0;
      final link = GoalLink(
        id: 'link-1',
        goalId: 'goal-1',
        ownerId: 'owner-1',
        type: GoalLinkType.libraryPrayer,
        role: GoalLinkRole.primaryPrayer,
        libraryPrayerId: 'library-1',
        createdAt: DateTime.utc(2026, 8, 28, 8),
      );
      final today = TodayPrayer(
        prayer: const PrayerDisplayValue(
          reference: PrayerReference.library('library-1'),
          title: 'Prayer for today',
          body: 'Lord, guide me.',
          grounding: PrayerGrounding.generalChristian,
          purpose: PrayerPurpose.guidance,
        ),
        localDate: DateTime(2026, 8, 28),
        includeAction: false,
        actionCompleted: false,
      );
      const candidate = GoalTodayResourceCandidate(
        goalId: 'goal-1',
        stableKey: 'legacy-prayer',
        dedupeKey: 'prayer:library:library-1',
        kind: GoalTodayResourceKind.prayer,
        label: 'Prayer for today',
      );
      final item = GoalTodayResourceItem(candidate);
      final snapshot = GoalTodaySnapshot(
        localDate: DateTime(2026, 8, 28),
        activeGoalCount: 1,
        sections: [
          GoalTodaySection(goal: _goal(), items: [item]),
        ],
        resources: GoalTodayResourceProjection(
          candidates: const [candidate],
          handlesByStableKey: {
            candidate.stableKey: GoalTodayLegacyPrayerHandle(link, today),
          },
        ),
      );

      await tester.pumpWidget(
        _host(
          snapshot,
          onOpenResource: (_, _) async => opened++,
          onCompleteResource: (_, _) async => prayed++,
        ),
      );

      expect(find.text('Prayer for today'), findsOneWidget);
      final row = find.byKey(const ValueKey('goal-today-row-legacy-prayer'));
      expect(row, findsOneWidget);
      expect(tester.getSize(row).height, lessThanOrEqualTo(72));
      expect(find.text('Pray'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('goal-today-more-legacy-prayer')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Details'), findsOneWidget);
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(opened, 1);

      await tester.tap(
        find.byKey(const ValueKey('goal-today-prayed-legacy-prayer')),
      );
      await tester.pumpAndSettle();
      expect(prayed, 1);
      final completedRow = find.byKey(
        const ValueKey('completed-today-legacy-prayer'),
      );
      expect(completedRow, findsOneWidget);
      expect(tester.getSize(completedRow).height, 48);
      await tester.tap(
        find.byKey(const ValueKey('dismiss-completed-legacy-prayer')),
      );
      await tester.pumpAndSettle();
      expect(completedRow, findsNothing);
    },
  );

  testWidgets('failed completion keeps the original action expanded', (
    tester,
  ) async {
    final snapshot = _snapshot([
      GoalTodayActionItem(
        GoalActionOccurrence(
          action: _action('action-1', 'goal-1'),
          occurrenceKey: 'action-1:2026-08-28',
        ),
      ),
    ]);
    await tester.pumpWidget(
      _host(
        snapshot,
        onCompleteAction: (_) async => throw StateError('save failed'),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('goal-today-done-action-1:2026-08-28')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Take one faithful step'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('completed-today-action-1:2026-08-28')),
      findsNothing,
    );
  });

  testWidgets(
    'Goal Today remains usable at 200 percent text on a small phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final snapshot = _snapshot(
        [
          GoalTodayActionItem(
            GoalActionOccurrence(
              action: _action('guard-1', 'goal-1'),
              occurrenceKey: 'guard-1:2026-08-28',
            ),
          ),
          const GoalTodayResourceItem(
            GoalTodayResourceCandidate(
              goalId: 'goal-1',
              stableKey: 'scripture-1',
              dedupeKey: 'scripture:RSVCE:James:1:5:6',
              kind: GoalTodayResourceKind.scripture,
              label: 'James 1:5-6',
            ),
          ),
        ],
        returnGoalIds: const {'goal-1'},
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _host(snapshot, onReturn: (_) async {}),
        ),
      );
      await tester.pump();

      expect(find.byType(Scrollable), findsWidgets);
      expect(find.text('Return'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('can omit a Goal represented by a dedicated Today feature', (
    tester,
  ) async {
    final snapshot = _snapshot(const []);
    await tester.pumpWidget(_host(snapshot, excludedGoalIds: const {'goal-1'}));

    expect(find.text('Stay close to God'), findsNothing);
  });
}

Widget _host(
  GoalTodaySnapshot snapshot, {
  Future<void> Function(Goal)? onReturn,
  Future<void> Function(GoalTodayActionItem)? onCompleteAction,
  Future<void> Function(GoalTodayResourceItem, GoalTodayResourceHandle?)?
  onOpenResource,
  Future<void> Function(GoalTodayResourceItem, GoalTodayResourceHandle)?
  onCompleteResource,
  Set<String> excludedGoalIds = const <String>{},
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: GoalTodaySections(
          snapshot: snapshot,
          excludedGoalIds: excludedGoalIds,
          onReturn: onReturn,
          onCompleteAction: onCompleteAction ?? (_) async {},
          onOpenResource: onOpenResource ?? (_, _) async {},
          onCompleteResource: onCompleteResource ?? (_, _) async {},
        ),
      ),
    ),
  );
}

GoalTodaySnapshot _snapshot(
  List<GoalTodayItem> items, {
  Set<String> returnGoalIds = const <String>{},
}) => GoalTodaySnapshot(
  localDate: DateTime(2026, 8, 28),
  activeGoalCount: 1,
  sections: [GoalTodaySection(goal: _goal(), items: items)],
  resources: const GoalTodayResourceProjection(
    candidates: [],
    handlesByStableKey: {},
  ),
  returnGoalIds: returnGoalIds,
);

Goal _goal() => Goal(
  id: 'goal-1',
  ownerId: 'owner-1',
  mode: GoalMode.mixed,
  status: GoalStatus.active,
  currentRevisionId: 'revision-1',
  position: 0,
  title: 'Stay close to God',
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
