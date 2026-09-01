import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../application/sacred_hour_today_window.dart';
import '../domain/sacred_hour.dart';

class SacredHourTodayCard extends StatelessWidget {
  const SacredHourTodayCard({
    required this.hour,
    required this.nowUtc,
    required this.onOpen,
    this.continued = false,
    super.key,
  });

  final SacredHour hour;
  final DateTime nowUtc;
  final VoidCallback onOpen;
  final bool continued;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final window = SacredHourTodayWindow.classify(hour, nowUtc);
    final active = window.phase == SacredHourTodayPhase.active;
    final action = active ? (continued ? 'Continue' : 'Begin') : 'Prepare';
    return Card(
      key: const Key('sacred-hour-today-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(width: 4, height: 64, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hour.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    '${active ? 'Now' : 'In ${window.minutesUntil} min'} · '
                    '${_formatRange(hour)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: active
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: active ? FontWeight.w600 : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Begin with ${hour.prayerMinutes} minutes of prayer',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.tonal(onPressed: onOpen, child: Text(action)),
          ],
        ),
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
