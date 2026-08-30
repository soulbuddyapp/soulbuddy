import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/goals/data/reviewed_goal_action_suggestions.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/domain/goal_action_suggestion.dart';
import 'package:soulbuddy/features/goals/domain/goal_onboarding_progress.dart';

void main() {
  test('returns reviewed closer-to-God choices without spiritual claims', () {
    final result = reviewedGoalActionSuggestions(
      const GoalActionSuggestionRequest(
        starterKey: GoalStarterKey.closerToGod,
        title: 'Grow closer to God',
        situation: 'I rush through every morning',
        agencyChoice: GoalAgencyChoice.notSure,
        locale: 'en',
      ),
    );

    expect(result, hasLength(3));
    expect(
      result.map((item) => item.text),
      contains('Set aside ten quiet minutes before opening another app'),
    );
    expect(
      result.map((item) => item.text.toLowerCase()).join(' '),
      isNot(contains('god told')),
    );
  });

  test('normalizes duplicate, blank, and overlong provider choices', () {
    final suggestions = normalizeGoalActionSuggestions([
      '  Call a trusted person today. ',
      'Call a trusted person today.',
      '',
      List.filled(200, 'x').join(),
      'Write down the next decision.',
      'Take a short walk without your phone.',
      'A fourth valid choice is ignored.',
    ]);

    expect(suggestions, hasLength(3));
    expect(suggestions.first.text, 'Call a trusted person today.');
    expect(suggestions.every((item) => item.text.length <= 160), isTrue);
  });

  test('uses behavior-specific choices when stopping something', () {
    final result = reviewedGoalActionSuggestions(
      const GoalActionSuggestionRequest(
        starterKey: GoalStarterKey.stopControl,
        stopBehaviorKey: GoalStopBehaviorKey.digitalDistraction,
        title: 'Stop losing time on my phone',
        situation: null,
        agencyChoice: GoalAgencyChoice.stepsICanTake,
        locale: 'en',
      ),
    );

    expect(result.map((item) => item.text).join(' '), contains('notification'));
  });
}
