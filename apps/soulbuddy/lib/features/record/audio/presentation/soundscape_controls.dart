import 'package:flutter/material.dart';

import '../../../../core/design/app_spacing.dart';
import '../domain/memory_soundscape.dart';

class SoundscapeControls extends StatelessWidget {
  const SoundscapeControls({
    required this.settings,
    required this.onSelected,
    required this.onVolumeChanged,
    this.enabled = true,
    super.key,
  });

  final MemorySoundscapeSettings settings;
  final ValueChanged<MemorySoundscape> onSelected;
  final ValueChanged<double> onVolumeChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final volume = settings.validated.volume;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Background sound',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final soundscape in MemorySoundscape.values)
                  ChoiceChip(
                    key: Key('memory-soundscape-${soundscape.name}'),
                    label: Text(soundscape.label),
                    selected: settings.soundscape == soundscape,
                    onSelected: enabled ? (_) => onSelected(soundscape) : null,
                  ),
              ],
            ),
            if (settings.soundscape != MemorySoundscape.quiet) ...[
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                label: 'Background volume ${(volume * 100).round()} percent',
                child: Slider(
                  key: const Key('memory-soundscape-volume'),
                  value: volume,
                  max: 0.35,
                  divisions: 7,
                  label: '${(volume * 100).round()}%',
                  onChanged: enabled ? onVolumeChanged : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
