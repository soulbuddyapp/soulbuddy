import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';

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
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('today-start-guide'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TodayGuideMark(),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Begin with prayer',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Turn your attention toward God, surrender this day, '
                        'and carry faith into action.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              key: const Key('choose-prayer'),
              onPressed: onChoosePrayer,
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Choose a prayer for today'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('today-record-memory'),
              onPressed: onRecordMemory,
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('Record something to remember'),
            ),
            const SizedBox(
              key: Key('today-start-guide-end'),
              height: AppSpacing.xs,
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayGuideMark extends StatelessWidget {
  const _TodayGuideMark();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Prayer, action, and remembrance',
      child: ExcludeSemantics(
        child: Center(
          child: SizedBox.square(
            dimension: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primaryContainer,
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surface,
                    border: Border.all(color: colors.outline),
                  ),
                ),
                Icon(Icons.wb_sunny_outlined, size: 20, color: colors.primary),
                Positioned(
                  right: 0,
                  bottom: 4,
                  child: Icon(
                    Icons.eco_outlined,
                    size: 16,
                    color: colors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
