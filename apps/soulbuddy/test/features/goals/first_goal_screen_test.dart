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
  testWidgets('stop-control starts with the reviewed behavior choices', (
    tester,
  ) async {
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
    expect(find.text('What are you trying to stop?'), findsOneWidget);
    for (final label in [
      'Pornography',
      'Gambling',
      'Nicotine or tobacco',
      'Alcohol',
      'Digital distraction',
      'Something else',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Pornography'));
    await tester.pumpAndSettle();
    expect(find.text('What do you want to stop?'), findsOneWidget);
    expect(find.text('Pornography'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('first-goal-text-field')),
      'Stop watching pornography',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('first-goal-text-continue')));
    await tester.pumpAndSettle();
    expect(find.text('What is happening now?'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('There are steps I can take'));
    await tester.pumpAndSettle();
    expect(find.text('What would help today?'), findsOneWidget);
    expect(
      find.widgetWithText(
        TextField,
        'One concrete step that removes easy access today',
      ),
      findsNothing,
    );

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(
      find.text('What do you need to guard against or remove?'),
      findsOneWidget,
    );
    expect(find.text('Walls to consider'), findsOneWidget);
    expect(find.text('AdGuard Family Protection'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Who can walk with you?'), findsOneWidget);
  });

  testWidgets('required stop Goal title cannot continue blank', (tester) async {
    final repository = _MemoryGoalProgressRepository();
    await _pump(tester, repository);

    await tester.tap(find.text('Stop something fighting to control me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pornography'));
    await tester.pumpAndSettle();

    FilledButton continueButton() => tester.widget<FilledButton>(
      find.byKey(const Key('first-goal-text-continue')),
    );

    expect(continueButton().onPressed, isNull);
    await tester.enterText(
      find.byKey(const Key('first-goal-text-field')),
      '   ',
    );
    await tester.pump();
    expect(continueButton().onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('first-goal-text-field')),
      'Stop watching pornography',
    );
    await tester.pump();
    expect(continueButton().onPressed, isNotNull);
  });

  testWidgets('alcohol medical-guidance path precedes Goal planning', (
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
        disableAnimations: true,
      ),
    );

    await tester.tap(find.text('Stop something fighting to control me'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Alcohol'), 120);
    await tester.tap(find.text('Alcohol'));
    await tester.pumpAndSettle();

    expect(find.text('Before you make an alcohol plan'), findsOneWidget);
    expect(find.byKey(const Key('first-goal-text-field')), findsNothing);
    expect(
      find.byKey(const Key('first-goal-alcohol-medical-guidance')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(
      find.byKey(const Key('first-goal-alcohol-medical-guidance')),
    );
    await tester.tap(
      find.byKey(const Key('first-goal-alcohol-medical-guidance')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Make medical guidance the first step'), findsOneWidget);
    expect(find.byKey(const Key('first-goal-text-field')), findsNothing);
    await tester.ensureVisible(
      find.byKey(const Key('first-goal-alcohol-care-reviewed')),
    );
    await tester.tap(find.byKey(const Key('first-goal-alcohol-care-reviewed')));
    await tester.pumpAndSettle();

    expect(
      find.text('What change do you want help making with alcohol?'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('first-goal-text-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gambling guard step prioritizes structural walls', (
    tester,
  ) async {
    final repository = _MemoryGoalProgressRepository(
      const GoalOnboardingProgress(
        stage: GoalOnboardingStage.guard,
        starterKey: GoalStarterKey.stopControl,
        stopBehaviorKey: GoalStopBehaviorKey.gambling,
        title: 'Stop gambling',
        agencyChoice: GoalAgencyChoice.stepsICanTake,
      ),
    );
    await _pump(tester, repository);

    expect(find.text('Walls to consider'), findsOneWidget);
    expect(find.text('Use official self-exclusion'), findsOneWidget);
    expect(find.text('Set binding money and time limits'), findsOneWidget);
    expect(find.text('AdGuard Family Protection'), findsNothing);
    expect(
      find.textContaining('Nothing is configured until you set it up'),
      findsOneWidget,
    );
  });

  testWidgets('legacy stop-control progress resumes before behavior planning', (
    tester,
  ) async {
    final repository = _MemoryGoalProgressRepository(
      const GoalOnboardingProgress(
        stage: GoalOnboardingStage.agency,
        starterKey: GoalStarterKey.stopControl,
        title: 'Stop watching pornography',
        currentSituation: 'Late-night phone use makes this easier.',
      ),
    );
    await _pump(tester, repository);

    expect(find.text('What are you trying to stop?'), findsOneWidget);
    expect(repository.progress?.stage, GoalOnboardingStage.stopBehavior);
    expect(repository.progress?.title, 'Stop watching pornography');
  });

  testWidgets('reopens the last committed ordinary Goal decision', (
    tester,
  ) async {
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
