import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/guards/application/return_plan.dart';
import 'package:soulbuddy/features/guards/presentation/return_sheet.dart';
import 'package:soulbuddy/features/guards/providers/return_providers.dart';

void main() {
  testWidgets(
    'Return keeps all five steps usable at 320px and 200 percent text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final goal = _goal();
      final plan = ReturnPlanBuilder.build(
        goal: goal,
        actions: const [],
        links: const [],
        guardSelections: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            goalReturnPlanProvider(
              goal.id,
            ).overrideWith((ref) => AsyncData(plan)),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: Scaffold(body: ReturnSheet(goalId: goal.id)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final title in const [
        'Move',
        'Close the door',
        'Return to God',
        'Do the replacement',
        'Do not hide',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 160);
        expect(find.text(title), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      final reflection = find.byKey(const Key('return-record-open-door'));
      await tester.scrollUntilVisible(reflection, 240);
      await tester.ensureVisible(reflection);
      await tester.pumpAndSettle();
      expect(reflection.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Return remains usable when optional data is degraded', (
    tester,
  ) async {
    final goal = _goal();
    final plan = ReturnPlanBuilder.build(
      goal: goal,
      actions: const [],
      links: const [],
      guardSelections: const [],
      unavailableParts: const {
        ReturnPlanPart.actions,
        ReturnPlanPart.spiritualResources,
        ReturnPlanPart.guards,
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goalReturnPlanProvider(
            goal.id,
          ).overrideWith((ref) => AsyncData(plan)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: ReturnSheet(goalId: goal.id)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Some saved Return details are unavailable just now. The core steps are still available.',
      ),
      findsOneWidget,
    );
    expect(find.text('Move'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Goal _goal() => Goal(
  id: 'return-screen-goal',
  ownerId: 'owner-1',
  starterKey: GoalStarterKey.stopControl,
  mode: GoalMode.mixed,
  status: GoalStatus.active,
  currentRevisionId: 'revision-1',
  position: 0,
  title: 'Stop something fighting to control me',
  createdAt: DateTime.utc(2026, 8, 29),
  updatedAt: DateTime.utc(2026, 8, 29),
);
