import '../domain/goal.dart';
import '../domain/goal_action_suggestion.dart';
import '../domain/goal_onboarding_progress.dart';

List<GoalActionSuggestion> reviewedGoalActionSuggestions(
  GoalActionSuggestionRequest request,
) {
  final choices = switch ((request.starterKey, request.stopBehaviorKey)) {
    (GoalStarterKey.stopControl, GoalStopBehaviorKey.digitalDistraction) =>
      const [
        'Turn off one distracting notification for the rest of today',
        'Move the most distracting app away from your home screen',
        'Choose one phone-free part of your day',
      ],
    (GoalStarterKey.stopControl, GoalStopBehaviorKey.pornography) => const [
      'Move your phone out of the place where you are most vulnerable',
      'Turn on a content restriction you cannot easily ignore',
      'Tell one trusted person where you need accountability',
    ],
    (GoalStarterKey.stopControl, GoalStopBehaviorKey.gambling) => const [
      'Remove one easy path to gambling today',
      'Use an available account limit or self-exclusion control',
      'Tell one trusted person what access still needs to close',
    ],
    (GoalStarterKey.stopControl, GoalStopBehaviorKey.nicotineTobacco) => const [
      'Write down when the strongest urge usually appears',
      'Remove one easy source of tobacco or nicotine today',
      'Ask a qualified health professional about a safe quit plan',
    ],
    (GoalStarterKey.stopControl, GoalStopBehaviorKey.alcohol) => const [
      'Ask a qualified health professional what a safe next step is',
      'Tell one trusted person what support you need today',
      'Write down the time and place that most often leads to drinking',
    ],
    (GoalStarterKey.stopControl, _) => const [
      'Remove one easy path back to this today',
      'Choose one replacement action you can do immediately',
      'Tell one trusted person what you are changing',
    ],
    (GoalStarterKey.closerToGod, _) => const [
      'Set aside ten quiet minutes before opening another app',
      'Choose one Gospel passage to read slowly today',
      'Put one prayer where you will see it before the day becomes busy',
    ],
    (GoalStarterKey.direction, _) => const [
      'Write the two clearest options on one page',
      'Name one responsibility that is already in front of you',
      'Ask one trusted person for a short, honest conversation',
    ],
    (GoalStarterKey.difficultTime, _) => const [
      'Choose the one task that most needs gentle attention today',
      'Ask one trusted person for practical help',
      'Write down what can wait until tomorrow',
    ],
    (GoalStarterKey.other, _) => const [
      'Choose one small action you can finish today',
      'Write down what would make tomorrow easier',
      'Ask one trusted person for help naming the next step',
    ],
  };
  return normalizeGoalActionSuggestions(choices);
}

class ReviewedGoalActionSuggestionRepository
    implements GoalActionSuggestionRepository {
  const ReviewedGoalActionSuggestionRepository();

  @override
  Future<List<GoalActionSuggestion>> suggest(
    GoalActionSuggestionRequest request,
  ) async => reviewedGoalActionSuggestions(request);
}
