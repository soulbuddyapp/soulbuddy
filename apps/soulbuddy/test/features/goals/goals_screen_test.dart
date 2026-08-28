import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/presentation/goals_screen.dart';
import 'package:soulbuddy/features/goals/providers/goal_providers.dart';

void main() {
  testWidgets('shows active, paused and completed Goals without hiding prayer', (
    tester,
  ) async {
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
    );

    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);
    expect(find.text('Paused'), findsWidgets);
    expect(find.text('Completed'), findsWidgets);
    expect(find.byKey(const Key('start-goal')), findsOneWidget);
    expect(find.byKey(const Key('open-prayer-library')), findsOneWidget);
  });

  testWidgets('empty Goals keeps the approved first question visible', (
    tester,
  ) async {
    await _pump(tester, const []);

    expect(find.text('What would you like help with?'), findsOneWidget);
    expect(find.text('Prayer library'), findsOneWidget);
  });

  testWidgets('Goals remains usable at 200 percent text on a small phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(
      tester,
      [_goal(id: 'active', title: 'Take one small step today')],
      mediaQuery: const MediaQueryData(
        size: Size(320, 640),
        textScaler: TextScaler.linear(2),
      ),
    );

    expect(find.byType(Scrollable), findsWidgets);
    expect(find.text('Goals'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  List<Goal> goals, {
  MediaQueryData? mediaQuery,
}) async {
  Widget child = const GoalsScreen();
  if (mediaQuery != null) {
    child = MediaQuery(data: mediaQuery, child: child);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        visibleGoalsProvider.overrideWith((ref) => Stream.value(goals)),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: child),
    ),
  );
  await tester.pumpAndSettle();
}

Goal _goal({
  required String id,
  required String title,
  GoalStatus status = GoalStatus.active,
}) => Goal(
  id: id,
  ownerId: 'owner-1',
  mode: GoalMode.mixed,
  status: status,
  currentRevisionId: 'revision-$id',
  position: 0,
  title: title,
  createdAt: DateTime.utc(2026, 8, 28, 8),
  updatedAt: DateTime.utc(2026, 8, 28, 8),
);
