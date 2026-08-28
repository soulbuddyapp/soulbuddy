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
      await tester.pump();

      expect(completed, 1);
    },
  );

  testWidgets(
    'legacy Goal prayer exposes Open and Prayed through typed handle',
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
      expect(find.text('Prayed'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('goal-today-prayed-legacy-prayer')),
      );
      await tester.pump();
      expect(prayed, 1);

      await tester.tap(find.text('Prayer for today'));
      await tester.pump();
      expect(opened, 1);
    },
  );

  testWidgets(
    'Goal Today remains usable at 200 percent text on a small phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final snapshot = _snapshot([
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
      ]);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _host(snapshot),
        ),
      );
      await tester.pump();

      expect(find.byType(Scrollable), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _host(
  GoalTodaySnapshot snapshot, {
  Future<void> Function(GoalTodayActionItem)? onCompleteAction,
  Future<void> Function(GoalTodayResourceItem, GoalTodayResourceHandle?)?
  onOpenResource,
  Future<void> Function(GoalTodayResourceItem, GoalTodayResourceHandle)?
  onCompleteResource,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: GoalTodaySections(
          snapshot: snapshot,
          onCompleteAction: onCompleteAction ?? (_) async {},
          onOpenResource: onOpenResource ?? (_, _) async {},
          onCompleteResource: onCompleteResource ?? (_, _) async {},
        ),
      ),
    ),
  );
}

GoalTodaySnapshot _snapshot(List<GoalTodayItem> items) => GoalTodaySnapshot(
  localDate: DateTime(2026, 8, 28),
  activeGoalCount: 1,
  sections: [GoalTodaySection(goal: _goal(), items: items)],
  resources: const GoalTodayResourceProjection(
    candidates: [],
    handlesByStableKey: {},
  ),
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
