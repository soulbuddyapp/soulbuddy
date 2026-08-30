import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/identity/local_identity_providers.dart';
import '../domain/goal_action_suggestion.dart';

class LaravelGoalActionSuggestionRepository
    implements GoalActionSuggestionRepository {
  LaravelGoalActionSuggestionRepository({
    required this.apiBaseUri,
    required this.tokenReader,
    required this.client,
    this.requestTimeout = const Duration(seconds: 12),
  });

  final Uri apiBaseUri;
  final AppSessionTokenReader tokenReader;
  final http.Client client;
  final Duration requestTimeout;

  @override
  Future<List<GoalActionSuggestion>> suggest(
    GoalActionSuggestionRequest request,
  ) async {
    final token = await tokenReader();
    if (token == null || token.isEmpty) {
      throw const GoalActionSuggestionUnavailable();
    }
    try {
      final response = await client
          .post(
            _resolve('/api/goal-action-suggestions'),
            headers: {
              'authorization': 'Bearer $token',
              'accept': 'application/json',
              'content-type': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(requestTimeout);
      if (response.statusCode != 200) {
        throw const GoalActionSuggestionUnavailable();
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['suggestions'] is! List<dynamic>) {
        throw const GoalActionSuggestionUnavailable();
      }
      final raw = decoded['suggestions'] as List<dynamic>;
      if (raw.any((item) => item is! String)) {
        throw const GoalActionSuggestionUnavailable();
      }
      final result = normalizeGoalActionSuggestions(raw.cast<String>());
      if (result.isEmpty) throw const GoalActionSuggestionUnavailable();
      return result;
    } on GoalActionSuggestionUnavailable {
      rethrow;
    } on Object {
      throw const GoalActionSuggestionUnavailable();
    }
  }

  Uri _resolve(String path) {
    final base = apiBaseUri.toString().replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$base$path');
  }
}
