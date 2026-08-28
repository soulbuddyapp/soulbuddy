import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
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

  @override
  Widget build(BuildContext context) {
    final title = _controller.text.trim();
    return AlertDialog(
      title: const Text('Name this Goal'),
      content: TextField(
        key: const Key('migration-goal-title'),
        controller: _controller,
        autofocus: true,
        maxLength: 120,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'What are you seeking help with?',
        ),
        onChanged: (_) => setState(() {}),
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
