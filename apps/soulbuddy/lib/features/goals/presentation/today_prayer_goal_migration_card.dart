import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/speech/sayable_field.dart';
import '../../prayers/domain/today_prayer.dart';
import '../providers/goal_providers.dart';

class TodayPrayerGoalMigrationCard extends ConsumerStatefulWidget {
  const TodayPrayerGoalMigrationCard({required this.today, super.key});

  final TodayPrayer today;

  @override
  ConsumerState<TodayPrayerGoalMigrationCard> createState() =>
      _TodayPrayerGoalMigrationCardState();
}

class _TodayPrayerGoalMigrationCardState
    extends ConsumerState<TodayPrayerGoalMigrationCard> {
  var _dismissed = false;
  var _working = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final reference = widget.today.prayer.reference;
    final linked = ref.watch(prayerLinkedToGoalProvider(reference));
    return linked.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (alreadyLinked) {
        if (alreadyLinked) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Card(
            key: const Key('today-prayer-goal-migration'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Keep this prayer under a Goal?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Your prayer stays as it is. A Goal gives it a place beside what you want to do next.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      FilledButton(
                        key: const Key('keep-prayer-under-goal'),
                        onPressed: _working ? null : _keep,
                        child: Text(
                          _working ? 'Keeping…' : 'Keep this under a Goal',
                        ),
                      ),
                      TextButton(
                        key: const Key('dismiss-prayer-goal-migration'),
                        onPressed: _working
                            ? null
                            : () => setState(() => _dismissed = true),
                        child: const Text('Not now'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _keep() async {
    final title = await showDialog<String>(
      context: context,
      builder: (context) => const _GoalNameDialog(),
    );
    if (title == null || !mounted) return;

    setState(() => _working = true);
    try {
      final reference = widget.today.prayer.reference;
      final migration = await ref.read(goalPrayerMigrationProvider.future);
      final goalId = await migration.keepPrayerUnderGoal(
        title: title,
        prayer: reference,
      );
      ref.invalidate(prayerLinkedToGoalProvider(reference));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Prayer kept under your Goal.'),
          action: SnackBarAction(
            label: 'Open Goal',
            onPressed: () => context.go('/goals/$goalId'),
          ),
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This prayer could not be kept under a Goal just now.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}

class _GoalNameDialog extends StatefulWidget {
  const _GoalNameDialog();

  @override
  State<_GoalNameDialog> createState() => _GoalNameDialogState();
}

class _GoalNameDialogState extends State<_GoalNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Reports a limit that cut a dictated answer short.
  ///
  /// The messenger rather than the card that opened this dialog: the dialog may
  /// be gone by the time the notice shows, and the card's state may have been
  /// dismissed out from under it.
  void _reportTruncation() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(_limitReachedNotice)));
  }

  @override
  Widget build(BuildContext context) {
    final title = _controller.text.trim();
    return AlertDialog(
      title: const Text('Name this Goal'),
      // Held in a min-size column so the field takes the dialog's height rather
      // than filling whatever the dialog is allowed.
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SayableField(
            key: const Key('migration-goal-title'),
            controller: _controller,
            autofocus: true,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            labelText: 'What are you seeking help with?',
            // Keep is gated on the title read here in build, and a field's own
            // callback fires for typing alone. Without this the button would
            // stay disabled while dictated words sat plainly in the field.
            onChanged: (_) => setState(() {}),
            // A cut is said rather than left to look like a whole answer. This
            // dialog has no message line of its own, so it goes to the SnackBar
            // the card already reports through.
            onTruncated: _reportTruncation,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm-prayer-goal-migration'),
          onPressed: title.isEmpty ? null : () => Navigator.pop(context, title),
          child: const Text('Keep'),
        ),
      ],
    );
  }
}

/// Shown when the field's limit cut a dictated answer short.
///
/// The app's own wording for the same event, reused rather than reworded:
/// `commitment_journey_screen` already tells someone their answer reached the
/// limit when it does. A second phrasing of the same fact would be the small
/// inconsistency the design asked to avoid.
const String _limitReachedNotice = 'Your answer reached the limit.';
