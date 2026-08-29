import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/guards/domain/guard_definition.dart';
import 'package:soulbuddy/features/guards/presentation/guard_configuration_sheet.dart';
import 'package:soulbuddy/features/guards/providers/guard_providers.dart';

void main() {
  testWidgets(
    'guard configuration states enforcement truthfully at large text scale',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final goal = _goal();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            goalGuardSelectionsProvider(
              goal.id,
            ).overrideWith((ref) => Stream.value(const <GoalGuardSelection>[])),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: Scaffold(body: GuardConfigurationSheet(goal: goal)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Close the door'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('does not verify that a device'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('AdGuard Family Protection'),
        120,
      );
      expect(find.text('AdGuard Family Protection'), findsOneWidget);
      expect(find.text('Review'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}

Goal _goal() => Goal(
  id: 'guard-ui-goal',
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
