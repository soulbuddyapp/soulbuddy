import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';

class SacredHourPrayerControls extends StatelessWidget {
  const SacredHourPrayerControls({
    required this.prayerLabel,
    required this.soundLabel,
    required this.prayerPlaying,
    required this.soundPlaying,
    required this.completing,
    required this.onPrayer,
    required this.onSound,
    required this.onPrayed,
    this.onPrayerPlayback,
    this.onSoundPlayback,
    super.key,
  });

  final String prayerLabel;
  final String soundLabel;
  final bool prayerPlaying;
  final bool soundPlaying;
  final bool completing;
  final VoidCallback onPrayer;
  final VoidCallback onSound;
  final VoidCallback onPrayed;
  final VoidCallback? onPrayerPlayback;
  final VoidCallback? onSoundPlayback;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Expanded(
            child: _Choice(
              controlKey: const Key('sacred-hour-prayer-choice'),
              icon: Icons.volunteer_activism_outlined,
              label: 'Prayer',
              value: prayerLabel,
              playing: prayerPlaying,
              onTap: onPrayer,
              onPlayback: onPrayerPlayback,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _Choice(
              controlKey: const Key('sacred-hour-sound-choice'),
              icon: Icons.music_note_outlined,
              label: 'Sound',
              value: soundLabel,
              playing: soundPlaying,
              onTap: onSound,
              onPlayback: onSoundPlayback,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      FilledButton(
        key: const Key('sacred-hour-prayed'),
        onPressed: completing ? null : onPrayed,
        child: completing
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text("I've prayed"),
      ),
    ],
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.controlKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.playing,
    required this.onTap,
    required this.onPlayback,
  });

  final Key controlKey;
  final IconData icon;
  final String label;
  final String value;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback? onPlayback;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: controlKey,
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: const Size(0, 56),
    ),
    child: Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, maxLines: 1),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (onPlayback != null)
          IconButton(
            tooltip: playing ? 'Pause $label' : 'Play $label',
            onPressed: onPlayback,
            icon: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
          ),
      ],
    ),
  );
}
