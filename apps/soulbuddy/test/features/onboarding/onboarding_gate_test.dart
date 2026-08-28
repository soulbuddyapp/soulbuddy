import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/domain/goal_onboarding_progress.dart';
import 'package:soulbuddy/features/goals/providers/goal_providers.dart';
import 'package:soulbuddy/features/onboarding/data/onboarding_repository.dart';
import 'package:soulbuddy/features/onboarding/data/first_prayer_progress_repository.dart';
import 'package:soulbuddy/features/onboarding/domain/first_prayer_progress.dart';
import 'package:soulbuddy/features/onboarding/presentation/onboarding_gate.dart';
import 'package:soulbuddy/features/onboarding/providers/first_prayer_providers.dart';
import 'package:soulbuddy/features/onboarding/providers/onboarding_providers.dart';

void main() {
  testWidgets('first use shows welcome instead of the routed app', (
    tester,
  ) async {
    final repository = _MemoryOnboardingRepository();
    await _pumpGate(tester, repository);

    expect(find.text('Bring what matters'), findsOneWidget);
    expect(find.text('Routed app'), findsNothing);
  });

  testWidgets('completed welcome shows the routed app', (tester) async {
    final repository = _MemoryOnboardingRepository(completed: true);
    await _pumpGate(tester, repository);

    expect(find.text('Routed app'), findsOneWidget);
    expect(find.text('Bring what matters'), findsNothing);
  });

  testWidgets('completed welcome resumes a saved legacy first prayer', (
    tester,
  ) async {
    final repository = _MemoryOnboardingRepository(completed: true);
    var resumedPrayer = false;
    var resumedGoal = false;
    await _pumpGate(
      tester,
      repository,
      progressRepository: _MemoryProgressRepository(
        const FirstPrayerProgress(stage: FirstPrayerStage.frequency),
      ),
      goalProgress: const GoalOnboardingProgress(
        stage: GoalOnboardingStage.agency,
        starterKey: GoalStarterKey.direction,
      ),
      onResumeFirstPrayer: () => resumedPrayer = true,
      onBeginWithGoal: () => resumedGoal = true,
    );

    expect(resumedPrayer, isTrue);
    expect(resumedGoal, isFalse);
    expect(find.text('Routed app'), findsOneWidget);
  });

  testWidgets('completed welcome resumes a saved first Goal', (tester) async {
    final repository = _MemoryOnboardingRepository(completed: true);
    var resumedGoal = false;
    await _pumpGate(
      tester,
      repository,
      goalProgress: const GoalOnboardingProgress(
        stage: GoalOnboardingStage.agency,
        starterKey: GoalStarterKey.direction,
        title: 'Find direction',
      ),
      onBeginWithGoal: () => resumedGoal = true,
    );

    expect(resumedGoal, isTrue);
    expect(find.text('Routed app'), findsOneWidget);
  });

  testWidgets('final welcome action persists and opens Goal choices', (
    tester,
  ) async {
    final repository = _MemoryOnboardingRepository();
    var openedGoalChoices = false;
    await _pumpGate(
      tester,
      repository,
      onBeginWithGoal: () => openedGoalChoices = true,
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();

    expect(repository.completed, isTrue);
    expect(openedGoalChoices, isTrue);
    expect(find.text('Routed app'), findsOneWidget);
  });

  testWidgets('a storage failure never traps the person in welcome', (
    tester,
  ) async {
    final repository = _MemoryOnboardingRepository(failWrite: true);
    await _pumpGate(tester, repository);

    await tester.tap(find.text('Go to Today'));
    await tester.pumpAndSettle();

    expect(find.text('Routed app'), findsOneWidget);
  });
}

Future<void> _pumpGate(
  WidgetTester tester,
  OnboardingRepository repository, {
  VoidCallback? onBeginWithGoal,
  VoidCallback? onResumeFirstPrayer,
  FirstPrayerProgressRepository? progressRepository,
  GoalOnboardingProgress? goalProgress,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        onboardingRepositoryProvider.overrideWithValue(repository),
        firstPrayerProgressRepositoryProvider.overrideWith(
          (ref) async => progressRepository ?? _MemoryProgressRepository(null),
        ),
        goalOnboardingProgressProvider.overrideWith(
          (ref) async => goalProgress,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: OnboardingGate(
          onBeginWithGoal: onBeginWithGoal ?? () {},
          onResumeFirstPrayer: onResumeFirstPrayer ?? () {},
          onSkip: () {},
          child: const Scaffold(body: Center(child: Text('Routed app'))),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _MemoryProgressRepository implements FirstPrayerProgressRepository {
  _MemoryProgressRepository(this.progress);

  FirstPrayerProgress? progress;

  @override
  Future<void> clear() async => progress = null;

  @override
  Future<FirstPrayerProgress?> load() async => progress;

  @override
  Future<void> save(FirstPrayerProgress value) async => progress = value;
}

class _MemoryOnboardingRepository extends OnboardingRepository {
  _MemoryOnboardingRepository({this.completed = false, this.failWrite = false})
    : super(read: _unusedRead, write: _unusedWrite);

  bool completed;
  final bool failWrite;

  @override
  Future<bool> isComplete() async => completed;

  @override
  Future<void> complete() async {
    if (failWrite) throw StateError('storage unavailable');
    completed = true;
  }

  static Future<String?> _unusedRead(String key) async => null;
  static Future<void> _unusedWrite(String key, String value) async {}
}
