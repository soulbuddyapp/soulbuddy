import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../application/sacred_hour_sound_player.dart';
import '../domain/sacred_hour.dart';

class SacredHourSoundPicker extends StatefulWidget {
  const SacredHourSoundPicker({
    required this.selected,
    required this.soundsEnabled,
    required this.player,
    required this.onChanged,
    super.key,
  });

  final SacredHourSound selected;
  final bool soundsEnabled;
  final SacredHourSoundPlayer player;
  final ValueChanged<SacredHourSound> onChanged;

  @override
  State<SacredHourSoundPicker> createState() => _SacredHourSoundPickerState();
}

class _SacredHourSoundPickerState extends State<SacredHourSoundPicker> {
  SacredHourSound? _playing;

  Future<void> _preview(SacredHourSound sound) async {
    if (_playing == sound) {
      await widget.player.stop();
      if (mounted) setState(() => _playing = null);
      return;
    }
    await widget.player.stop();
    await widget.player.play(sound);
    if (mounted) setState(() => _playing = sound);
  }

  @override
  void dispose() {
    widget.player.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reminder sound', style: theme.textTheme.titleMedium),
        if (!widget.soundsEnabled) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Turn on in-app sounds to preview. Your reminder choice is still saved.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        for (final sound in SacredHourSound.values)
          RadioGroup<SacredHourSound>(
            groupValue: widget.selected,
            onChanged: (value) {
              if (value != null) widget.onChanged(value);
            },
            child: RadioListTile<SacredHourSound>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: sound,
              title: Text(_label(sound)),
              subtitle: Text(_description(sound)),
              secondary: _isBundled(sound)
                  ? IconButton(
                      key: Key('sound-preview-${sound.wireValue}'),
                      tooltip: _playing == sound ? 'Stop' : 'Play',
                      onPressed: widget.soundsEnabled
                          ? () => _preview(sound)
                          : null,
                      icon: Icon(
                        _playing == sound
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_outline,
                      ),
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

bool _isBundled(SacredHourSound sound) => switch (sound) {
  SacredHourSound.device || SacredHourSound.silent => false,
  _ => true,
};

String sacredHourSoundLabel(SacredHourSound sound) => _label(sound);

String _label(SacredHourSound sound) => switch (sound) {
  SacredHourSound.gentleChime => 'Gentle Chime',
  SacredHourSound.dawnChime => 'Dawn',
  SacredHourSound.stillBell => 'Still Bell',
  SacredHourSound.eveningChime => 'Evening',
  SacredHourSound.device => 'Device sound',
  SacredHourSound.silent => 'Silent',
};

String _description(SacredHourSound sound) => switch (sound) {
  SacredHourSound.gentleChime => 'Warm and unhurried',
  SacredHourSound.dawnChime => 'Clear, light opening',
  SacredHourSound.stillBell => 'One calm bell',
  SacredHourSound.eveningChime => 'Soft, lower chime',
  SacredHourSound.device => 'Use this device’s notification sound',
  SacredHourSound.silent => 'Show the reminder without sound',
};
