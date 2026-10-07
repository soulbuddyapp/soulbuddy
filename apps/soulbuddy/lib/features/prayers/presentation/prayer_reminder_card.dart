import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/playback/spiritual_session.dart';
import '../../../core/playback/spiritual_session_providers.dart';
import '../../../core/feedback/app_feedback.dart';
import '../../../core/feedback/app_feedback_preferences.dart';
import '../../../core/feedback/app_feedback_providers.dart';
import '../../../core/feedback/app_feedback_service.dart';
import '../application/prayer_narration_eligibility.dart';
import '../application/prayer_reminder_scheduler.dart';
import '../domain/prayer_reminder.dart';
import '../providers/prayer_practice_providers.dart';
import 'prayer_narration_disclosure.dart';

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
  bool _reading = false;
  bool _preparingNarration = false;

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
                                key: const Key('prayer-reminder-title'),
                                maxLines: _reading ? null : 2,
                                overflow: _reading
                                    ? TextOverflow.clip
                                    : TextOverflow.ellipsis,
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
                    if (_hasPrayerText) ...[
                      _readControl(context),
                      _PrayerTextBody(
                        body: widget.occurrence.prayerBody,
                        expanded: _reading,
                        // The card already threads reduceMotion through its
                        // entrance; the body opens the same way.
                        duration: widget.reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
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
                        if (_narrationObtainable)
                          _compactAction(
                            label: _preparingNarration
                                ? 'Preparing prayer'
                                : 'Play prayer',
                            icon: Icons.play_arrow,
                            leading: _preparingNarration
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : null,
                            disabled: _preparingNarration,
                            onPressed: _playNarration,
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

  bool get _narrationReady {
    final device = widget.occurrence.device;
    return device.narrationRevisionId == widget.occurrence.prayerRevisionId &&
        device.narrationContentType == 'audio/mpeg' &&
        (device.narrationBytes?.isNotEmpty ?? false);
  }

  /// Narration can be requested for this occurrence's exact revision whether or
  /// not a recording happens to be cached, so the control stays available.
  bool get _narrationObtainable => canObtainPrayerNarration(
    personalPrayerId: widget.occurrence.reminder.personalPrayerId,
    prayerRevisionId: widget.occurrence.prayerRevisionId,
    prayerBody: widget.occurrence.prayerBody,
  );

  bool get _hasPrayerText => widget.occurrence.prayerBody.trim().isNotEmpty;

  Widget _readControl(BuildContext context) => Semantics(
    button: true,
    expanded: _reading,
    child: Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const Key('prayer-reminder-read'),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.minimumTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onPressed: _toggleReading,
        icon: Icon(_reading ? Icons.expand_less : Icons.expand_more, size: 18),
        label: Text(_reading ? 'Show less' : 'Read in full'),
      ),
    ),
  );

  void _toggleReading() => setState(() => _reading = !_reading);

  Widget _compactAction({
    required String label,
    required IconData icon,
    PrayerReminderAction? action,
    VoidCallback? onPressed,
    Widget? leading,
    bool disabled = false,
  }) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
    onPressed: _busy || disabled ? null : onPressed ?? () => _perform(action!),
    icon: leading ?? Icon(icon, size: 18),
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
      if (action == PrayerReminderAction.open && _narrationReady) {
        unawaited(_tryAutoplayNarration(displayedOccurrence));
      }
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

  Future<void> _tryAutoplayNarration(DuePrayerOccurrence occurrence) async {
    try {
      await ref.read(playReminderNarrationProvider)(
        occurrence,
        explicit: false,
      );
    } catch (_) {
      // The visible Play prayer control remains the recoverable path.
    }
  }

  Future<void> _playNarration() async {
    if (_busy || _preparingNarration || !_narrationObtainable) return;
    if (!_narrationReady &&
        !widget.occurrence.device.narrationConsentAccepted) {
      // Prayer text leaves this device only after the same disclosure and
      // consent the reminder sheet already asks for.
      final accepted = await showPrayerNarrationDisclosure(context);
      if (accepted != true || !mounted) return;
    }
    setState(() => _preparingNarration = true);
    try {
      await ref.read(prepareAndPlayReminderNarrationProvider)(
        widget.occurrence,
        consentAccepted: true,
      );
      final occurrence = widget.occurrence;
      final player = ref.read(prayerNarrationPlayerProvider);
      final perform = ref.read(prayerReminderActionProvider);
      await ref
          .read(spiritualSessionControllerProvider)
          .begin(
            SpiritualSession(
              id: 'prayer-reminder:${occurrence.occurrenceKey}',
              kind: SpiritualSessionKind.prayer,
              title: occurrence.prayerTitle,
              route: '/prayers/saved/${occurrence.reminder.personalPrayerId}',
              canPause: true,
              completionLabel: 'I prayed',
              onPause: player.pause,
              onResume: player.resume,
              onComplete: () async {
                await player.stop();
                await perform(occurrence, PrayerReminderAction.prayed);
              },
              onClose: player.stop,
            ),
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prayer narration is unavailable just now.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _preparingNarration = false);
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

/// The prayer body, revealed in place.
///
/// The text is bounded and laid out in a shrink-wrapped scroll view rather
/// than an unbounded column, so a long prayer at a large text scale scrolls
/// inside the card instead of overflowing it.
class _PrayerTextBody extends StatelessWidget {
  const _PrayerTextBody({
    required this.body,
    required this.expanded,
    required this.duration,
  });

  final String body;
  final bool expanded;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final revealed = expanded
        ? ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: _bodyViewportHeight(context),
            ),
            child: ListView(
              key: const Key('prayer-reminder-body'),
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                Text(
                  body,
                  key: const Key('prayer-reminder-body-text'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          )
        : const SizedBox(width: double.infinity, height: 0);
    // With reduced motion the body simply changes; no animation widget runs.
    if (duration == Duration.zero) return revealed;
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: revealed,
    );
  }
}

double _bodyViewportHeight(BuildContext context) {
  final height = MediaQuery.maybeOf(context)?.size.height ?? 640;
  return (height * 0.34).clamp(120.0, 420.0);
}
