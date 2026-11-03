import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';

/// A compact first-use guide. The covenant slabs above it carry the screen's
/// primary visual weight, so this stays readable without pushing actions below
/// the first viewport.
class TodayStartGuide extends StatelessWidget {
  const TodayStartGuide({
    required this.onStartGoal,
    required this.recordControl,
    super.key,
  });

  final VoidCallback? onStartGoal;
  final Widget recordControl;

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
        FilledButton.icon(
          key: const Key('start-first-goal'),
          onPressed: onStartGoal,
          icon: const Icon(Icons.add),
          label: const Text('Start a Goal'),
        ),
        const SizedBox(height: AppSpacing.sm),
        recordControl,
        const SizedBox(
          key: Key('today-start-guide-end'),
          height: AppSpacing.xs,
        ),
      ],
    );
  }
}
