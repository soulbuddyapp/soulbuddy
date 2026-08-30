import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../data/fallback_goal_action_suggestion_repository.dart';
import '../data/laravel_goal_action_suggestion_repository.dart';
import '../data/reviewed_goal_action_suggestions.dart';
import '../domain/goal_action_suggestion.dart';

final goalActionSuggestionHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final goalActionSuggestionRepositoryProvider =
    Provider<GoalActionSuggestionRepository>((ref) {
      final base = Uri.tryParse(AppConfig.apiBaseUrl);
      if (base == null || !base.hasScheme) {
        return const ReviewedGoalActionSuggestionRepository();
      }
      return FallbackGoalActionSuggestionRepository(
        primary: LaravelGoalActionSuggestionRepository(
          apiBaseUri: base,
          tokenReader: ref.watch(appSessionTokenReaderProvider),
          client: ref.watch(goalActionSuggestionHttpClientProvider),
        ),
        fallback: const ReviewedGoalActionSuggestionRepository(),
      );
    });

final goalActionSuggestionsProvider = FutureProvider.autoDispose
    .family<List<GoalActionSuggestion>, GoalActionSuggestionRequest>((
      ref,
      request,
    ) {
      return ref.watch(goalActionSuggestionRepositoryProvider).suggest(request);
    });
