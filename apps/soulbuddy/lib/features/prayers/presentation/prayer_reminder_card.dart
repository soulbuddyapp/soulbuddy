import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/feedback/app_feedback.dart';
import '../../../core/feedback/app_feedback_preferences.dart';
import '../../../core/feedback/app_feedback_providers.dart';
import '../../../core/feedback/app_feedback_service.dart';
import '../application/prayer_reminder_scheduler.dart';
import '../domain/prayer_reminder.dart';
import '../providers/prayer_practice_providers.dart';

class PrayerReminderCardHost extends ConsumerStatefulWidget {
  const PrayerReminderCardHost({super.key});

  @override
  ConsumerState<PrayerReminderCardHost> createState() =>
      _PrayerReminderCardHostState();
}

class _PrayerReminderCardHostState
    extends ConsumerState<PrayerReminderCardHost> {
  final _announcedOccurrences = <String>{};

  @override
  Widget build(BuildContext context) {
    final due = ref.watch(duePrayerOccurrencesProvider);
    final preferences =
        ref.watch(appFeedbackPreferencesProvider).value ??
        AppFeedbackPreferences.defaults;
    return due.when(
      data: (occurrences) {
        if (occurrences.isEmpty) return const SizedBox.shrink();
        final occurrence = occurrences.first;
        _announceOnce(occurrence.occurrenceKey);
        return PrayerReminderCard(
          key: ValueKey(occurrence.occurrenceKey),
          occurrence: occurrence,
          dueCount: occurrences.length,
          reduceMotion:
              preferences.reducedMotion ||
              (MediaQuery.maybeOf(context)?.disableAnimations ?? false),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  void _announceOnce(String occurrenceKey) {
    if (!_announcedOccurrences.add(occurrenceKey)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final preferences =
          ref.read(appFeedbackPreferencesProvider).value ??
          AppFeedbackPreferences.defaults;
      await ref
          .read(appFeedbackServiceProvider)
          .emit(
            AppFeedbackIntent.selection,
            preferences: preferences,
            systemReduceMotion:
                MediaQuery.maybeOf(context)?.disableAnimations ?? false,
          );
    });
  }
}

class PrayerReminderCard extends ConsumerStatefulWidget {
  const PrayerReminderCard({
    required this.occurrence,
    this.dueCount = 1,
    this.reduceMotion = false,
    super.key,
  });

  final DuePrayerOccurrence occurrence;
  final int dueCount;
  final bool reduceMotion;

  @override
  ConsumerState<PrayerReminderCard> createState() => _PrayerReminderCardState();
}

class _PrayerReminderCardState extends ConsumerState<PrayerReminderCard> {
  bool _busy = false;
  bool _showMore = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final localTime = widget.occurrence.reminder.schedule.localTime;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: localTime.hour, minute: localTime.minute),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: widget.reduceMotion ? 1 : 0, end: 1),
      duration: widget.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, (1 - progress) * 12),
          child: child,
        ),
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            elevation: 8,
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: DecoratedBox(
              key: const Key('prayer-reminder-focus-edge'),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: scheme.secondary, width: 4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.notifications_active_outlined,
                          key: const Key('prayer-reminder-icon'),
                          color: scheme.secondary,
                          semanticLabel: 'Prayer reminder',
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.occurrence.prayerTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                time,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                              if (widget.dueCount > 1)
                                Text(
                                  '${widget.dueCount} prayer reminders due',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        Semantics(
                          label: 'More reminder actions',
                          button: true,
                          child: IconButton(
                            key: const Key('prayer-reminder-more-actions'),
                            onPressed: _busy
                                ? null
                                : () => setState(() => _showMore = !_showMore),
                            icon: const Icon(Icons.more_vert),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _perform(PrayerReminderAction.open),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open prayer'),
                        ),
                        _compactAction(
                          label: 'I prayed this',
                          icon: Icons.check,
                          action: PrayerReminderAction.prayed,
                        ),
                        _compactAction(
                          label: 'Snooze 10 minutes',
                          icon: Icons.snooze,
                          action: PrayerReminderAction.snoozeTenMinutes,
                        ),
                        if (_showMore)
                          _compactAction(
                            label: 'Dismiss',
                            icon: Icons.close,
                            action: PrayerReminderAction.dismiss,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactAction({
    required String label,
    required IconData icon,
    required PrayerReminderAction action,
  }) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
    onPressed: _busy ? null : () => _perform(action),
    icon: Icon(icon, size: 18),
    label: Text(label),
  );

  Future<void> _perform(PrayerReminderAction action) async {
    if (_busy) return;
    final displayedOccurrence = widget.occurrence;
    final messenger = ScaffoldMessenger.of(context);
    final retract = ref.read(prayerSessionRetractorProvider);
    final feedbackService = ref.read(appFeedbackServiceProvider);
    final feedbackPreferences =
        ref.read(appFeedbackPreferencesProvider).value ??
        AppFeedbackPreferences.defaults;
    final systemReduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    setState(() => _busy = true);
    try {
      final session = await ref.read(prayerReminderActionProvider)(
        displayedOccurrence,
        action,
      );
      if (mounted) setState(() => _busy = false);
      unawaited(
        _emitActionFeedback(
          action,
          service: feedbackService,
          preferences: feedbackPreferences,
          systemReduceMotion: systemReduceMotion,
        ),
      );
      if (session != null) {
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: const Text('Prayer time recorded'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => unawaited(
                _undo(
                  messenger: messenger,
                  retract: retract,
                  sessionId: session.id,
                ),
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update this reminder just now.'),
        ),
      );
    }
  }

  Future<void> _emitActionFeedback(
    PrayerReminderAction action, {
    required AppFeedbackService service,
    required AppFeedbackPreferences preferences,
    required bool systemReduceMotion,
  }) async {
    final intent = switch (action) {
      PrayerReminderAction.prayed => AppFeedbackIntent.prayerCompleted,
      PrayerReminderAction.dismiss => AppFeedbackIntent.dismissed,
      _ => AppFeedbackIntent.selection,
    };
    await service.emit(
      intent,
      preferences: preferences,
      systemReduceMotion: systemReduceMotion,
    );
  }

  Future<void> _undo({
    required ScaffoldMessengerState messenger,
    required Future<void> Function(String) retract,
    required String sessionId,
  }) async {
    try {
      await retract(sessionId);
    } catch (_) {
      if (!messenger.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not undo this prayer record just now.'),
        ),
      );
    }
  }
}
