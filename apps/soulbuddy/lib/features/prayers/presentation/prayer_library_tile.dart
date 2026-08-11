import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/library_prayer.dart';

class PrayerLibraryTile extends StatelessWidget {
  const PrayerLibraryTile({
    required this.prayer,
    required this.onTap,
    super.key,
  });

  final LibraryPrayer prayer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final purpose = prayerPurposeLabel(prayer.purpose);
    final grounding = prayerGroundingLabel(prayer.grounding);
    final helpful = 'Helpful · ${prayer.helpfulCount}';

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${prayer.title}. $purpose. $grounding. $helpful.',
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minimumTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prayer.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '$purpose · $grounding',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Icon(
                              prayer.viewerMarkedHelpful
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                helpful,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String prayerGroundingLabel(PrayerGrounding grounding) {
  return switch (grounding) {
    PrayerGrounding.generalChristian => 'General Christian',
    PrayerGrounding.catholic => 'Catholic',
  };
}

String prayerPurposeLabel(PrayerPurpose purpose) {
  return switch (purpose) {
    PrayerPurpose.daily => 'Daily',
    PrayerPurpose.gratitude => 'Gratitude',
    PrayerPurpose.guidance => 'Guidance',
    PrayerPurpose.family => 'Family',
    PrayerPurpose.healing => 'Healing',
    PrayerPurpose.work => 'Work',
    PrayerPurpose.forgiveness => 'Forgiveness',
    PrayerPurpose.difficultTime => 'Difficult time',
  };
}
