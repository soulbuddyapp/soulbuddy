import '../domain/goal_action_suggestion.dart';

class FallbackGoalActionSuggestionRepository
    implements GoalActionSuggestionRepository {
  const FallbackGoalActionSuggestionRepository({
    required this.primary,
    required this.fallback,
  });

  final GoalActionSuggestionRepository primary;
  final GoalActionSuggestionRepository fallback;

  @override
  Future<List<GoalActionSuggestion>> suggest(
    GoalActionSuggestionRequest request,
  ) async {
    try {
      final result = await primary.suggest(request);
      if (result.isNotEmpty) return result;
    } on GoalActionSuggestionUnavailable {
      // The reviewed local path below keeps onboarding available offline.
    }
    return fallback.suggest(request);
  }
}
