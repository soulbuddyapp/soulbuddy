import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soulbuddy/features/goals/data/fallback_goal_action_suggestion_repository.dart';
import 'package:soulbuddy/features/goals/data/laravel_goal_action_suggestion_repository.dart';
import 'package:soulbuddy/features/goals/data/reviewed_goal_action_suggestions.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/domain/goal_action_suggestion.dart';
import 'package:soulbuddy/features/goals/domain/goal_onboarding_progress.dart';

void main() {
  const request = GoalActionSuggestionRequest(
    starterKey: GoalStarterKey.direction,
    title: 'Find direction',
    situation: 'I am choosing between two paths.',
    agencyChoice: GoalAgencyChoice.notSure,
    locale: 'en',
  );

  test('posts only the reviewed context with bearer auth', () async {
    late http.Request captured;
    final repository = LaravelGoalActionSuggestionRepository(
      apiBaseUri: Uri.parse('https://sbuddy.example'),
      tokenReader: () async => 'session-token',
      client: MockClient((incoming) async {
        captured = incoming;
        return http.Response(
          jsonEncode({
            'suggestions': [
              'Write both options on one page.',
              'Ask a trusted person for a short conversation.',
              'Name the responsibility already in front of you.',
            ],
          }),
          200,
        );
      }),
    );

    final result = await repository.suggest(request);

    expect(captured.url.path, '/api/goal-action-suggestions');
    expect(captured.headers['authorization'], 'Bearer session-token');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body.keys, unorderedEquals([
      'starter_key',
      'title',
      'situation',
      'agency_choice',
      'locale',
    ]));
    expect(result, hasLength(3));
  });

  test('falls back to reviewed choices after an invalid response', () async {
    final repository = FallbackGoalActionSuggestionRepository(
      primary: LaravelGoalActionSuggestionRepository(
        apiBaseUri: Uri.parse('https://sbuddy.example'),
        tokenReader: () async => 'token',
        client: MockClient(
          (_) async => http.Response(jsonEncode({'suggestions': ['']}), 200),
        ),
      ),
      fallback: const ReviewedGoalActionSuggestionRepository(),
    );

    final result = await repository.suggest(request);

    expect(result, hasLength(3));
    expect(result.first.text, 'Write the two clearest options on one page');
  });
}
