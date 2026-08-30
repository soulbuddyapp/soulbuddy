import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/domain/goal_action_suggestion.dart';
import 'package:soulbuddy/features/goals/domain/goal_onboarding_progress.dart';
import 'package:soulbuddy/features/goals/presentation/goal_action_suggestion_panel.dart';
import 'package:soulbuddy/features/goals/providers/goal_action_suggestion_providers.dart';

void main() {
  testWidgets('reviewed choices remain immediate while remote ranking waits', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goalActionSuggestionRepositoryProvider.overrideWith(
            (ref) => _NeverSuggestionRepository(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: GoalActionSuggestionPanel(
              request: const GoalActionSuggestionRequest(
                starterKey: GoalStarterKey.direction,
                title: 'Find direction',
                situation: 'I am choosing between two paths.',
                agencyChoice: GoalAgencyChoice.notSure,
                locale: 'en',
              ),
              expandedInitially: true,
              onChoose: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      find.text('Write the two clearest options on one page'),
      findsOneWidget,
    );
  });
}

class _NeverSuggestionRepository implements GoalActionSuggestionRepository {
  @override
  Future<List<GoalActionSuggestion>> suggest(
    GoalActionSuggestionRequest request,
  ) => Completer<List<GoalActionSuggestion>>().future;
}
