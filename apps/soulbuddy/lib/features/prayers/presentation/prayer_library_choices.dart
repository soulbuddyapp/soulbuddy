import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';

class PrayerLibraryChoices extends StatelessWidget {
  const PrayerLibraryChoices({
    required this.onLibrary,
    required this.onPersonalized,
    super.key,
  });

  final VoidCallback onLibrary;
  final VoidCallback onPersonalized;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final library = _PrayerChoice(
          key: const Key('library-choice'),
          title: 'Choose from library',
          subtitle: 'Current',
          selected: true,
          onTap: onLibrary,
        );
        final personalized = _PrayerChoice(
          key: const Key('personalized-choice'),
          title: 'Create personalized',
          subtitle: 'Guided',
          onTap: onPersonalized,
        );

        if (constraints.maxWidth >= 560) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: library),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: personalized),
            ],
          );
        }

        return Column(
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
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      excludeSemantics: true,
      button: true,
      enabled: true,
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
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.check_circle : Icons.auto_awesome_outlined,
                    color: colorScheme.primary,
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
      ),
    );
  }
}
