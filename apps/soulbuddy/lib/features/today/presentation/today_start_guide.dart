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
            LayoutBuilder(
              builder: (context, constraints) {
                final largeText =
                    MediaQuery.textScalerOf(context).scale(1) >= 1.5;
                if (largeText) {
                  return _GuideCopy(colors: colors);
                }
                final illustrationWidth = constraints.maxWidth < 280
                    ? 64.0
                    : 112.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: illustrationWidth,
                      child: const _SignatureIllustration(),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _GuideCopy(colors: colors)),
                  ],
                );
              },
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

class _GuideCopy extends StatelessWidget {
  const _GuideCopy({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Begin with prayer', style: Theme.of(context).textTheme.titleLarge),
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
  );
}

class _SignatureIllustration extends StatelessWidget {
  const _SignatureIllustration();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'An olive tree growing from remembered grace and bearing fruit for others.',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          key: const Key('today-signature-illustration'),
          height: 88,
          child: Image.asset(
            'assets/images/soulbuddy_olive_memorial.webp',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}
