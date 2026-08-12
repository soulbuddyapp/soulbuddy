import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';

class PrayerLibraryIntro extends StatelessWidget {
  const PrayerLibraryIntro({required this.onPersonalized, super.key});

  final VoidCallback onPersonalized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: AppSpacing.minimumTouchTarget,
              height: AppSpacing.minimumTouchTarget,
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome_outlined, color: colors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prayer is communion',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Choose words that help you turn toward God, surrender '
                    'your desires, and carry faith into action.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextButton.icon(
                    key: const Key('personalized-choice'),
                    onPressed: onPersonalized,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Create personalized'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
