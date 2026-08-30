import 'goal.dart';
import 'goal_onboarding_progress.dart';

class GoalActionSuggestionRequest {
  const GoalActionSuggestionRequest({
    required this.starterKey,
    required this.title,
    required this.situation,
    required this.agencyChoice,
    required this.locale,
    this.stopBehaviorKey,
  });

  final GoalStarterKey starterKey;
  final GoalStopBehaviorKey? stopBehaviorKey;
  final String title;
  final String? situation;
  final GoalAgencyChoice agencyChoice;
  final String locale;

  Map<String, Object?> toJson() => {
    'starter_key': starterKey.wireValue,
    if (stopBehaviorKey case final value?)
      'stop_behavior_key': value.wireValue,
    'title': title.trim(),
    'situation': situation?.trim(),
    'agency_choice': agencyChoice.wireValue,
    'locale': locale,
  };
}

class GoalActionSuggestion {
  const GoalActionSuggestion(this.text);

  final String text;
}

List<GoalActionSuggestion> normalizeGoalActionSuggestions(
  Iterable<String> values,
) {
  final seen = <String>{};
  final result = <GoalActionSuggestion>[];
  for (final value in values) {
    var text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) continue;
    if (text.length > 160) text = text.substring(0, 160).trimRight();
    final identity = text.toLowerCase();
    if (!seen.add(identity)) continue;
    result.add(GoalActionSuggestion(text));
    if (result.length == 3) break;
  }
  return List.unmodifiable(result);
}

abstract interface class GoalActionSuggestionRepository {
  Future<List<GoalActionSuggestion>> suggest(
    GoalActionSuggestionRequest request,
  );
}
