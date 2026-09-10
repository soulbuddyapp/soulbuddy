import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../prayers/domain/library_prayer.dart';
import '../../prayers/domain/meditation_session.dart';
import '../../prayers/presentation/meditation_sound_picker.dart';
import '../application/sacred_hour_prayer_suggestions.dart';
import '../domain/sacred_hour.dart';

class SacredHourPrayerMusicSheet extends StatelessWidget {
  const SacredHourPrayerMusicSheet({
    required this.hour,
    required this.suggestions,
    required this.selectedSound,
    required this.onChoosePrayer,
    required this.onAddPrayer,
    required this.onSoundSelected,
    this.onPreviewSound,
    super.key,
  });

  final SacredHour hour;
  final List<PrayerDisplay> suggestions;
  final MeditationSoundBed? selectedSound;
  final Future<void> Function(PrayerDisplay prayer) onChoosePrayer;
  final ValueChanged<PrayerPurpose> onAddPrayer;
  final Future<void> Function(MeditationSoundBed? sound) onSoundSelected;
  final Future<void> Function(MeditationSoundBed sound)? onPreviewSound;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      shrinkWrap: true,
      children: [
        Text(
          'Prayer and music',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
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
        const SizedBox(height: AppSpacing.lg),
        MeditationSoundPicker(
          selected: selectedSound,
          onSelected: onSoundSelected,
          onPreview: onPreviewSound,
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
