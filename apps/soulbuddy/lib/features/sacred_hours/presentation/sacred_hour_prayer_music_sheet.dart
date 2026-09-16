import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../prayers/domain/library_prayer.dart';
import '../application/sacred_hour_prayer_suggestions.dart';
import '../domain/sacred_hour.dart';

class SacredHourPrayerPickerSheet extends StatelessWidget {
  const SacredHourPrayerPickerSheet({
    required this.hour,
    required this.suggestions,
    required this.onChoosePrayer,
    required this.onAddPrayer,
    super.key,
  });

  final SacredHour hour;
  final List<PrayerDisplay> suggestions;
  final Future<void> Function(PrayerDisplay prayer) onChoosePrayer;
  final ValueChanged<PrayerPurpose> onAddPrayer;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      shrinkWrap: true,
      children: [
        Text('Choose prayer', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Suggested prayers',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (suggestions.isEmpty)
          const Text('A prayer for this hour is ready to begin.'),
        for (final prayer in suggestions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.volunteer_activism_outlined),
            title: Text(prayer.title),
            subtitle: Text(_purposeLabel(prayer.purpose)),
            trailing: TextButton(
              onPressed: () => onChoosePrayer(prayer),
              child: const Text('Choose'),
            ),
          ),
        TextButton.icon(
          onPressed: () =>
              onAddPrayer(SacredHourPrayerSuggestions.primaryPurpose(hour)),
          icon: const Icon(Icons.add),
          label: const Text('Add a prayer'),
        ),
      ],
    ),
  );
}

String _purposeLabel(PrayerPurpose purpose) => switch (purpose) {
  PrayerPurpose.daily => 'Daily',
  PrayerPurpose.gratitude => 'Gratitude',
  PrayerPurpose.guidance => 'Guidance',
  PrayerPurpose.family => 'Family',
  PrayerPurpose.healing => 'Healing',
  PrayerPurpose.work => 'Work',
  PrayerPurpose.forgiveness => 'Forgiveness',
  PrayerPurpose.difficultTime => 'Difficult time',
};
