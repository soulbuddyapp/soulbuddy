import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/sacred_hour.dart';
import 'sacred_hour_sound_picker.dart';

class SacredHoursSettingsSection extends StatelessWidget {
  const SacredHoursSettingsSection({
    required this.hours,
    required this.onAdd,
    required this.onEdit,
    required this.onEnabledChanged,
    required this.onArchive,
    super.key,
  });

  final List<SacredHour> hours;
  final Future<void> Function() onAdd;
  final Future<void> Function(SacredHour hour) onEdit;
  final Future<void> Function(SacredHour hour, bool enabled) onEnabledChanged;
  final Future<void> Function(SacredHour hour) onArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Sacred Hours', style: theme.textTheme.headlineMedium),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Set apart time to pray, then bring the work before you into God’s presence.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (hours.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('Your Sacred Hours will appear here.'),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (var index = 0; index < hours.length; index++) ...[
                  _SacredHourRow(
                    hour: hours[index],
                    onEdit: () => onEdit(hours[index]),
                    onEnabledChanged: (enabled) =>
                        onEnabledChanged(hours[index], enabled),
                    onArchive: () => onArchive(hours[index]),
                  ),
                  if (index != hours.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add Sacred Hour'),
        ),
      ],
    );
  }
}

class _SacredHourRow extends StatelessWidget {
  const _SacredHourRow({
    required this.hour,
    required this.onEdit,
    required this.onEnabledChanged,
    required this.onArchive,
  });

  final SacredHour hour;
  final VoidCallback onEdit;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: Key('sacred-hour-edit-${hour.id}'),
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hour.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_formatRange(hour)} · ${hour.prayerMinutes} min prayer',
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sacredHourSoundLabel(hour.sound),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Switch(
            key: Key('sacred-hour-enabled-${hour.id}'),
            value: hour.enabled,
            onChanged: onEnabledChanged,
          ),
          IconButton(
            key: Key('sacred-hour-archive-${hour.id}'),
            tooltip: 'Remove ${hour.name}',
            onPressed: onArchive,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

String _formatRange(SacredHour hour) {
  final start = hour.localTime.hour * 60 + hour.localTime.minute;
  final end = (start + hour.durationMinutes) % (24 * 60);
  return '${_time(start)}–${_time(end, suffix: true)}';
}

String _time(int minutes, {bool suffix = false}) {
  final hour24 = (minutes ~/ 60) % 24;
  final minute = minutes % 60;
  final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
  final value = '$hour12:${minute.toString().padLeft(2, '0')}';
  return suffix ? '$value${hour24 < 12 ? 'am' : 'pm'}' : value;
}
