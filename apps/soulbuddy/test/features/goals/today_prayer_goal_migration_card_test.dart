import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/goals/data/goal_prayer_migration.dart';
import 'package:soulbuddy/features/goals/presentation/today_prayer_goal_migration_card.dart';
import 'package:soulbuddy/features/goals/providers/goal_providers.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:soulbuddy/features/prayers/domain/today_prayer.dart';

void main() {
  testWidgets('unlinked Today prayer is never migrated without confirmation', (
    tester,
  ) async {
    final migration = _FakeGoalPrayerMigration(linked: false);
    addTearDown(migration.close);
    await _pump(tester, migration);

    expect(find.text('Keep this prayer under a Goal?'), findsOneWidget);
    expect(migration.keepCalls, 0);

    await tester.tap(find.byKey(const Key('dismiss-prayer-goal-migration')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today-prayer-goal-migration')), findsNothing);
    expect(migration.keepCalls, 0);
  });

  testWidgets('keep requires a user-authored Goal title before migration', (
    tester,
  ) async {
    final migration = _FakeGoalPrayerMigration(linked: false);
    addTearDown(migration.close);
    await _pump(tester, migration);

    await tester.tap(find.byKey(const Key('keep-prayer-under-goal')));
    await tester.pumpAndSettle();

    expect(find.text('Name this Goal'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('confirm-prayer-goal-migration')),
          )
          .onPressed,
      isNull,
    );
    expect(migration.keepCalls, 0);

    await tester.enterText(
      find.byKey(const Key('migration-goal-title')),
      'Choose the next faithful step',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('confirm-prayer-goal-migration')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('confirm-prayer-goal-migration')));
    await tester.pumpAndSettle();

    expect(migration.keepCalls, 1);
    expect(migration.lastTitle, 'Choose the next faithful step');
    expect(migration.lastPrayer, const PrayerReference.library('prayer-1'));
    expect(find.byKey(const Key('today-prayer-goal-migration')), findsNothing);
    expect(find.text('Prayer kept under your Goal.'), findsOneWidget);
  });

  testWidgets('already-linked prayer never shows a migration prompt', (
    tester,
  ) async {
    final migration = _FakeGoalPrayerMigration(linked: true);
    addTearDown(migration.close);
    await _pump(tester, migration);

    expect(find.byKey(const Key('today-prayer-goal-migration')), findsNothing);
    expect(migration.keepCalls, 0);
  });

  testWidgets('migration prompt remains usable at 200 percent text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final migration = _FakeGoalPrayerMigration(linked: false);
    addTearDown(migration.close);
    await _pump(
      tester,
      migration,
      mediaQuery: const MediaQueryData(
        size: Size(320, 640),
        textScaler: TextScaler.linear(2),
      ),
    );

    expect(
      find.byKey(const Key('today-prayer-goal-migration')),
      findsOneWidget,
    );
    expect(find.byType(Wrap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  GoalPrayerMigration migration, {
  MediaQueryData? mediaQuery,
}) async {
  Widget child = Scaffold(
    body: SingleChildScrollView(
      child: TodayPrayerGoalMigrationCard(today: _today),
    ),
  );
  if (mediaQuery != null) {
    child = MediaQuery(data: mediaQuery, child: child);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        goalPrayerMigrationProvider.overrideWith((ref) async => migration),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: child),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeGoalPrayerMigration implements GoalPrayerMigration {
  _FakeGoalPrayerMigration({required this.linked});

  final _changes = StreamController<bool>.broadcast();
  bool linked;
  int keepCalls = 0;
  String? lastTitle;
  PrayerReference? lastPrayer;

  @override
  Stream<bool> watchLinked(PrayerReference prayer) async* {
    yield linked;
    yield* _changes.stream;
  }

  @override
  Future<String> keepPrayerUnderGoal({
    required String title,
    required PrayerReference prayer,
  }) async {
    keepCalls += 1;
    lastTitle = title;
    lastPrayer = prayer;
    linked = true;
    _changes.add(true);
    return 'goal-1';
  }

  Future<void> close() => _changes.close();
}

final _today = TodayPrayer(
  prayer: const PrayerDisplayValue(
    reference: PrayerReference.library('prayer-1'),
    title: 'Prayer for guidance',
    body: 'Lord, guide me.',
    grounding: PrayerGrounding.generalChristian,
    purpose: PrayerPurpose.guidance,
  ),
  localDate: DateTime(2026, 8, 28),
  includeAction: false,
  actionCompleted: false,
);
