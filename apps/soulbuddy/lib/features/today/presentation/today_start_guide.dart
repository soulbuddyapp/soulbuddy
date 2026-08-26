import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';

/// A compact first-use guide. The covenant slabs above it carry the screen's
/// primary visual weight, so this stays readable without pushing actions below
/// the first viewport.
class TodayStartGuide extends StatelessWidget {
  const TodayStartGuide({
    required this.onChoosePrayer,
    required this.onRecordMemory,
    super.key,
  });

  final VoidCallback onChoosePrayer;
  final VoidCallback onRecordMemory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('today-start-guide'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Begin today\'s communion.',
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Pray with attention. Carry one faithful step. Keep what God gives '
          'you.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          key: const Key('choose-prayer'),
          onPressed: onChoosePrayer,
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Choose a prayer'),
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
