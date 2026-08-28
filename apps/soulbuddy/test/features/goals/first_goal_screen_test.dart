import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/goals/data/goal_onboarding_progress_repository.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/domain/goal_onboarding_progress.dart';
import 'package:soulbuddy/features/goals/presentation/first_goal_screen.dart';
import 'package:soulbuddy/features/goals/providers/goal_providers.dart';

void main() {
  testWidgets('starts with the exact reviewed Goal shortcuts', (tester) async {
    final repository = _MemoryGoalProgressRepository();
    await _pump(tester, repository);

    expect(find.text('What would you like help with?'), findsOneWidget);
    for (final label in [
      'Grow closer to God',
      'Stop something fighting to control me',
      'Find direction',
      'Get through a difficult time',
      'Something else',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Stop something fighting to control me'));
    await tester.pumpAndSettle();
    expect(find.text('What do you want to stop?'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('first-goal-text-field')),
      'Stop watching pornography',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('What is happening now?'), findsOneWidget);
    expect(find.text('Speak'), findsOneWidget);
    expect(find.text('Write'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('What can you do about this?'), findsOneWidget);
    expect(find.text('There are steps I can take'), findsOneWidget);
    expect(find.text('Mostly pray and wait'), findsOneWidget);
    expect(find.text("I'm not sure"), findsOneWidget);
  });

  testWidgets('reopens the last committed Goal decision', (tester) async {
    final repository = _MemoryGoalProgressRepository(
      const GoalOnboardingProgress(
        stage: GoalOnboardingStage.agency,
        starterKey: GoalStarterKey.direction,
        title: 'Find direction',
        currentSituation: 'I am choosing between two paths.',
      ),
    );
    await _pump(tester, repository);

    expect(find.text('What can you do about this?'), findsOneWidget);
    expect(find.text('Find direction'), findsNothing);
  });

  testWidgets('starter remains usable at 200 percent text on a small phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _MemoryGoalProgressRepository();
    await _pump(
      tester,
      repository,
      mediaQuery: const MediaQueryData(
        size: Size(320, 640),
        textScaler: TextScaler.linear(2),
      ),
    );

    expect(find.byType(Scrollable), findsWidgets);
    expect(find.text('What would you like help with?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  GoalOnboardingProgressRepository repository, {
  MediaQueryData? mediaQuery,
}) async {
  Widget child = const FirstGoalScreen();
  if (mediaQuery != null) {
    child = MediaQuery(data: mediaQuery, child: child);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        goalOnboardingProgressRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: child),
    ),
  );
  await tester.pumpAndSettle();
}

class _MemoryGoalProgressRepository
    implements GoalOnboardingProgressRepository {
  _MemoryGoalProgressRepository([this.progress]);

  GoalOnboardingProgress? progress;

  @override
  Future<void> clear() async => progress = null;

  @override
  Future<GoalOnboardingProgress?> load() async => progress;

  @override
  Future<void> save(GoalOnboardingProgress value) async => progress = value;
}
