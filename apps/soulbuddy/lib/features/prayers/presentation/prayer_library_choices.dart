import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';

class PrayerLibraryChoices extends StatelessWidget {
  const PrayerLibraryChoices({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const library = _PrayerChoice(
          key: Key('library-choice'),
          title: 'Choose from library',
          subtitle: 'Current',
          selected: true,
        );
        const personalized = _PrayerChoice(
          key: Key('personalized-choice'),
          title: 'Create personalized',
          subtitle: 'Next',
          enabled: false,
        );

        if (constraints.maxWidth >= 560) {
          return const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: library),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: personalized),
            ],
          );
        }

        return const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            library,
            SizedBox(height: AppSpacing.sm),
            personalized,
          ],
        );
      },
    );
  }
}

class _PrayerChoice extends StatelessWidget {
  const _PrayerChoice({
    required this.title,
    required this.subtitle,
    this.selected = false,
    this.enabled = true,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      excludeSemantics: true,
      enabled: enabled,
      selected: selected,
      label: '$title, $subtitle',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primaryContainer
                : colorScheme.surface,
            border: Border.all(color: colorScheme.outline),
            borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.lock_clock_outlined,
                  color: enabled
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
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
