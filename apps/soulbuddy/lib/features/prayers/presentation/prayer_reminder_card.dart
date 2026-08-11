import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../application/prayer_reminder_scheduler.dart';
import '../domain/prayer_reminder.dart';
import '../providers/prayer_practice_providers.dart';

class PrayerReminderCardHost extends ConsumerWidget {
  const PrayerReminderCardHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(duePrayerOccurrencesProvider);
    return due.when(
      data: (occurrences) => occurrences.isEmpty
          ? const SizedBox.shrink()
          : PrayerReminderCard(occurrence: occurrences.first),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class PrayerReminderCard extends ConsumerStatefulWidget {
  const PrayerReminderCard({required this.occurrence, super.key});

  final DuePrayerOccurrence occurrence;

  @override
  ConsumerState<PrayerReminderCard> createState() => _PrayerReminderCardState();
}

class _PrayerReminderCardState extends ConsumerState<PrayerReminderCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          elevation: 8,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.occurrence.prayerTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _action(
                      label: 'Open prayer',
                      icon: Icons.open_in_new,
                      action: PrayerReminderAction.open,
                    ),
                    _action(
                      label: 'I prayed this',
                      icon: Icons.check,
                      action: PrayerReminderAction.prayed,
                    ),
                    _action(
                      label: 'Snooze 10 minutes',
                      icon: Icons.snooze,
                      action: PrayerReminderAction.snoozeTenMinutes,
                    ),
                    _action(
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
    );
  }

  Widget _action({
    required String label,
    required IconData icon,
    required PrayerReminderAction action,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
      onPressed: _busy ? null : () => _perform(action),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Future<void> _perform(PrayerReminderAction action) async {
    if (_busy) return;
    final displayedOccurrence = widget.occurrence;
    setState(() => _busy = true);
    try {
      final session = await ref.read(prayerReminderActionProvider)(
        displayedOccurrence,
        action,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      if (session != null) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: const Text('Prayer time recorded'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => unawaited(_undo(session.id)),
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

  Future<void> _undo(String sessionId) async {
    try {
      await ref.read(prayerSessionRetractorProvider)(sessionId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not undo this prayer record just now.'),
        ),
      );
    }
  }
}
