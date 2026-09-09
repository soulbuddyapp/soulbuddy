import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/playback/spiritual_session.dart';
import '../../../core/playback/spiritual_session_providers.dart';
import '../application/sacred_hour_today_window.dart';
import '../domain/sacred_hour.dart';
import '../providers/sacred_hour_providers.dart';

class SacredHourActiveOverlay extends ConsumerStatefulWidget {
  const SacredHourActiveOverlay({super.key});

  @override
  ConsumerState<SacredHourActiveOverlay> createState() =>
      _SacredHourActiveOverlayState();
}

class _SacredHourActiveOverlayState
    extends ConsumerState<SacredHourActiveOverlay> {
  String? _dismissedOccurrence;

  @override
  Widget build(BuildContext context) {
    final hour = ref.watch(currentOrNextSacredHourProvider).value;
    final now = (ref.watch(sacredHourClockProvider).value ?? DateTime.now())
        .toUtc();
    if (hour == null) return const SizedBox.shrink();
    final window = SacredHourTodayWindow.classify(hour, now);
    if (window.phase != SacredHourTodayPhase.active) {
      return const SizedBox.shrink();
    }
    final occurrence = '${hour.id}@${window.startsAtUtc.toIso8601String()}';
    if (_dismissedOccurrence == occurrence) return const SizedBox.shrink();
    final end = window.startsAtUtc.add(Duration(minutes: hour.durationMinutes));
    final elapsed = now.difference(window.startsAtUtc).inSeconds;
    final total = Duration(minutes: hour.durationMinutes).inSeconds;
    final remainingMinutes = ((end.difference(now).inSeconds + 59) ~/ 60).clamp(
      1,
      hour.durationMinutes,
    );
    final progress = (elapsed / total).clamp(0.0, 1.0);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: const Key('sacred-hour-active-overlay'),
      elevation: 8,
      color: colorScheme.inverseSurface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.notifications_active,
              color: colorScheme.onInverseSurface,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          child: Text(
                            'LIVE',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          hour.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: colorScheme.onInverseSurface),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: colorScheme.onInverseSurface.withValues(
                        alpha: 0.18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$remainingMinutes min remaining · Begin with prayer',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onInverseSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              tooltip: 'Begin Sacred Hour',
              onPressed: () async {
                final route = Uri(
                  pathSegments: ['sacred-hours', hour.id],
                  queryParameters: {'occurrence': occurrence},
                ).toString();
                await ref
                    .read(spiritualSessionControllerProvider)
                    .begin(
                      SpiritualSession(
                        id: 'sacred-hour:$occurrence',
                        kind: SpiritualSessionKind.sacredHour,
                        title: hour.name,
                        route: route,
                        canPause: false,
                        completionLabel: 'Complete',
                        onPause: () async {},
                        onResume: () async {},
                        onComplete: () async {
                          final repository = await ref.read(
                            sacredHourRepositoryProvider.future,
                          );
                          await repository.markOccurrence(
                            hour.id,
                            window.startsAtUtc,
                            SacredHourOccurrenceStatus.completed,
                          );
                          if (mounted) {
                            setState(() => _dismissedOccurrence = occurrence);
                          }
                        },
                        onClose: () async {},
                      ),
                    );
                if (context.mounted) context.go(route);
              },
              icon: const Icon(Icons.play_arrow),
            ),
            IconButton(
              tooltip: 'Hide for this hour',
              color: colorScheme.onInverseSurface,
              onPressed: () =>
                  setState(() => _dismissedOccurrence = occurrence),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
