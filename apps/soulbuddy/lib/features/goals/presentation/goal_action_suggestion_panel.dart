import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/goal_action_suggestion.dart';
import '../providers/goal_action_suggestion_providers.dart';

class GoalActionSuggestionPanel extends ConsumerStatefulWidget {
  const GoalActionSuggestionPanel({
    required this.request,
    required this.onChoose,
    required this.expandedInitially,
    super.key,
  });

  final GoalActionSuggestionRequest request;
  final ValueChanged<String> onChoose;
  final bool expandedInitially;

  @override
  ConsumerState<GoalActionSuggestionPanel> createState() =>
      _GoalActionSuggestionPanelState();
}

class _GoalActionSuggestionPanelState
    extends ConsumerState<GoalActionSuggestionPanel> {
  late var _expanded = widget.expandedInitially;

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('suggest-goal-actions'),
          onPressed: () => setState(() => _expanded = true),
          icon: const Icon(Icons.lightbulb_outline),
          label: const Text('Suggest ideas'),
        ),
      );
    }

    final suggestions = ref.watch(
      goalActionSuggestionsProvider(widget.request),
    );
    return Column(
      key: const Key('goal-action-suggestions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('A few ideas', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        suggestions.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton(
            onPressed: () =>
                ref.invalidate(goalActionSuggestionsProvider(widget.request)),
            child: const Text('Try suggestions again'),
          ),
          data: (items) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: OutlinedButton(
                    onPressed: () => widget.onChoose(item.text),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(item.text),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('refresh-goal-action-suggestions'),
                  onPressed: () => ref.invalidate(
                    goalActionSuggestionsProvider(widget.request),
                  ),
                  child: const Text('Show other ideas'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
