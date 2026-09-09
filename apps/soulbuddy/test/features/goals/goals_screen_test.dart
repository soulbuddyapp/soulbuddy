import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/goals/data/goal_orderer.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/presentation/goals_screen.dart';
import 'package:soulbuddy/features/goals/providers/goal_providers.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/personal_prayer.dart';
import 'package:soulbuddy/features/prayers/providers/personal_prayer_providers.dart';

void main() {
  testWidgets(
    'shows created Goals and saved Prayers in one personal workspace',
    (tester) async {
      await _pump(
        tester,
        [
          _goal(id: 'active', title: 'Take the next faithful step'),
          _goal(
            id: 'paused',
            title: 'Discern the move',
            status: GoalStatus.paused,
          ),
          _goal(
            id: 'completed',
            title: 'Finish the application',
            status: GoalStatus.completed,
          ),
        ],
        personalPrayers: [_prayer()],
      );

      expect(find.text('My practice'), findsOneWidget);
      expect(find.text("What you've created"), findsOneWidget);
      expect(find.text('Take the next faithful step'), findsOneWidget);
      expect(find.text('My prayer · daily'), findsOneWidget);
      expect(find.byKey(const Key('open-create-workspace')), findsOneWidget);
    },
  );

  testWidgets('filters created work by Goal or Prayer', (tester) async {
    await _pump(
      tester,
      [_goal(id: 'active', title: 'Take the next faithful step')],
      personalPrayers: [_prayer()],
    );

    await tester.tap(find.byKey(const Key('created-filter-goals')));
    await tester.pumpAndSettle();
    expect(find.text('Take the next faithful step'), findsOneWidget);
    expect(find.text('My prayer · daily'), findsNothing);

    await tester.tap(find.byKey(const Key('created-filter-prayers')));
    await tester.pumpAndSettle();
    expect(find.text('Take the next faithful step'), findsNothing);
    expect(find.text('My prayer · daily'), findsOneWidget);
  });

  testWidgets('active Goals can move earlier or later without drag gestures', (
    tester,
  ) async {
    final orderer = _RecordingGoalOrderer();
    await _pump(tester, [
      _goal(id: 'first', title: 'Grow closer to God', position: 0),
      _goal(id: 'second', title: 'Take the next faithful step', position: 2),
      _goal(
        id: 'paused',
        title: 'Discern the move',
        status: GoalStatus.paused,
        position: 1,
      ),
    ], orderer: orderer);

    await tester.tap(find.byKey(const Key('created-sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('created-sort-goalPriority')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goal-order-menu-first')), findsOneWidget);
    expect(find.byKey(const Key('goal-order-menu-second')), findsOneWidget);
    expect(find.byKey(const Key('goal-order-menu-paused')), findsNothing);

    await tester.tap(find.byKey(const Key('goal-order-menu-second')));
    await tester.pumpAndSettle();
    expect(find.text('Move earlier'), findsOneWidget);
    expect(find.text('Move later'), findsNothing);

    await tester.tap(find.text('Move earlier'));
    await tester.pumpAndSettle();

    expect(orderer.orders, [
      ['second', 'first'],
    ]);
  });

  testWidgets('a failed order change is recoverable and keeps Goals visible', (
    tester,
  ) async {
    final orderer = _RecordingGoalOrderer(fail: true);
    await _pump(tester, [
      _goal(id: 'first', title: 'First Goal', position: 0),
      _goal(id: 'second', title: 'Second Goal', position: 1),
    ], orderer: orderer);

    await tester.tap(find.byKey(const Key('created-sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('created-sort-goalPriority')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('goal-order-menu-first')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move later'));
    await tester.pumpAndSettle();

    expect(find.text('Goal order could not be updated.'), findsOneWidget);
    expect(find.text('First Goal'), findsOneWidget);
    expect(find.text('Second Goal'), findsOneWidget);
    expect(
      find.byKey(const Key('goal-order-menu-first')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('empty workspace keeps creation clear', (tester) async {
    await _pump(tester, const []);

    expect(
      find.text('Nothing created yet. Use Create when you are ready to begin.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('open-create-workspace')), findsOneWidget);
  });

  testWidgets('Create collects Goal, Prayer, Meditation and browsing choices', (
    tester,
  ) async {
    await _pump(tester, const []);

    await tester.tap(find.byKey(const Key('open-create-workspace')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-goal')), findsOneWidget);
    expect(find.byKey(const Key('create-prayer')), findsOneWidget);
    expect(find.byKey(const Key('create-meditation')), findsOneWidget);
    expect(find.byKey(const Key('browse-prayer-library')), findsOneWidget);
  });

  testWidgets('Goals remains usable at 200 percent text on a small phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(
      tester,
      [
        _goal(id: 'first', title: 'Take one small step today', position: 0),
        _goal(
          id: 'second',
          title: 'Keep the phone outside the bedroom tonight',
          position: 1,
        ),
      ],
      mediaQuery: const MediaQueryData(
        size: Size(320, 640),
        textScaler: TextScaler.linear(2),
      ),
    );

    expect(find.byType(Scrollable), findsWidgets);
    expect(find.text('My practice'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -360));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-create-workspace')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  List<Goal> goals, {
  MediaQueryData? mediaQuery,
  GoalOrderer? orderer,
  List<PersonalPrayer> personalPrayers = const [],
}) async {
  Widget child = const GoalsScreen();
  if (mediaQuery != null) {
    child = MediaQuery(data: mediaQuery, child: child);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        visibleGoalsProvider.overrideWith((ref) => Stream.value(goals)),
        goalOrdererProvider.overrideWith(
          (ref) async => orderer ?? _RecordingGoalOrderer(),
        ),
        personalPrayersProvider.overrideWith(
          (ref) => Stream.value(personalPrayers),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Goal _goal({
  required String id,
  required String title,
  GoalStatus status = GoalStatus.active,
  int position = 0,
}) => Goal(
  id: id,
  ownerId: 'owner-1',
  mode: GoalMode.mixed,
  status: status,
  currentRevisionId: 'revision-$id',
  position: position,
  title: title,
  createdAt: DateTime.utc(2026, 8, 28, 8),
  updatedAt: DateTime.utc(2026, 8, 28, 8),
);

PersonalPrayer _prayer() => PersonalPrayer(
  id: 'prayer-1',
  ownerId: 'owner-1',
  title: 'My prayer · daily',
  style: 'own_words',
  reach: 'private',
  grounding: PrayerGrounding.generalChristian,
  purpose: PrayerPurpose.daily,
  currentRevisionId: 'revision-prayer-1',
  body: 'Father, keep me close to You today.',
  createdAt: DateTime.utc(2026, 8, 28, 8),
  updatedAt: DateTime.utc(2026, 8, 29, 8),
);

class _RecordingGoalOrderer implements GoalOrderer {
  _RecordingGoalOrderer({this.fail = false});

  final bool fail;
  final List<List<String>> orders = [];

  @override
  Future<void> reorderActive(List<String> orderedGoalIds) async {
    if (fail) throw StateError('offline write failed');
    orders.add(List.unmodifiable(orderedGoalIds));
  }
}
