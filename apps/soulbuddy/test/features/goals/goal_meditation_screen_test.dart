import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/goals/data/goal_meditation_repository.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/domain/goal_meditation_plan.dart';
import 'package:soulbuddy/features/goals/presentation/goal_meditation_screen.dart';
import 'package:soulbuddy/features/goals/providers/goal_meditation_providers.dart';
import 'package:soulbuddy/features/goals/providers/goal_providers.dart';
import 'package:soulbuddy/features/kingdom/providers/kingdom_course_providers.dart';
import 'package:soulbuddy/features/prayers/application/meditation_sound_preferences.dart';
import 'package:soulbuddy/features/record/providers/voice_note_providers.dart';

void main() {
  testWidgets('a saved meditation time begins without repeating setup', (
    tester,
  ) async {
    const goalId = 'meditation-goal';
    final goal = Goal(
      id: goalId,
      ownerId: 'owner',
      mode: GoalMode.mixed,
      status: GoalStatus.active,
      currentRevisionId: 'revision',
      position: 0,
      title: 'Practice patience',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    const plan = GoalMeditationPlan(
      goalId: goalId,
      frequency: GoalMeditationFrequency.daily,
      hour: 7,
      minute: 0,
      durationMinutes: 10,
    );
    final repository = GoalMeditationRepository(
      read: (_) async => null,
      write: (_, _) async {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceNotesProvider.overrideWith((ref, context) => Stream.value([])),
          kingdomMeditationReadyProvider.overrideWith((ref) async => true),
          goalProvider(goalId).overrideWith((ref) => Stream.value(goal)),
          goalMeditationPlanProvider(goalId).overrideWith((ref) async => plan),
          goalMeditationEntriesProvider(goalId).overrideWith((ref) async => []),
          goalMeditationRepositoryProvider.overrideWithValue(repository),
          meditationSoundPreferencesProvider.overrideWithValue(
            MeditationSoundPreferencesRepository(
              read: (_) async => null,
              write: (_, _) async {},
            ),
          ),
        ],
        child: const MaterialApp(home: GoalMeditationScreen(goalId: goalId)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily at 7:00 AM'), findsOneWidget);
    expect(find.byKey(const Key('start-goal-meditation')), findsOneWidget);
    expect(find.byKey(const Key('save-goal-meditation-plan')), findsNothing);

    await tester.tap(find.byKey(const Key('change-goal-meditation-plan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save-goal-meditation-plan')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('cancel-goal-meditation-plan')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-goal-meditation-plan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('start-goal-meditation')), findsOneWidget);
    expect(find.byKey(const Key('save-goal-meditation-plan')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('start-goal-meditation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-goal-meditation')));
    await tester.pump();
    expect(
      find.byKey(const Key('goal-scripture-response-picker')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('goal-scripture-response-picker')));
    await tester.pumpAndSettle();
    expect(find.text('Anger · James 1:19–20'), findsOneWidget);
    await tester.tap(find.text('Anger · James 1:19–20'));
    await tester.pump();
    expect(
      find.byKey(const Key('read-goal-scripture-response')),
      findsOneWidget,
    );
  });
}
