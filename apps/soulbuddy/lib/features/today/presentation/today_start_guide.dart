import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';

/// A compact first-use guide. The covenant slabs above it carry the screen's
/// primary visual weight, so this stays readable without pushing actions below
/// the first viewport.
class TodayStartGuide extends StatelessWidget {
  const TodayStartGuide({
    required this.onStartGoal,
    required this.onRecordMemory,
    super.key,
  });

  final VoidCallback onStartGoal;
  final VoidCallback onRecordMemory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('today-start-guide'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'What would you like help with?',
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Begin with one thing you want to seek, change, or carry.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          key: const Key('start-first-goal'),
          onPressed: onStartGoal,
          icon: const Icon(Icons.add),
          label: const Text('Start a Goal'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const Key('today-record-memory'),
          onPressed: onRecordMemory,
          icon: const Icon(Icons.mic_none_outlined),
          label: const Text('Record something'),
        ),
        const SizedBox(
          key: Key('today-start-guide-end'),
          height: AppSpacing.xs,
        ),
      ],
    );
  }
}
