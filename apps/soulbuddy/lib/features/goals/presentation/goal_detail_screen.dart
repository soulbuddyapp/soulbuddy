import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/speech/sayable_field.dart';
import '../../guards/presentation/return_sheet.dart';
import '../../guards/providers/return_providers.dart';
import '../domain/goal.dart';
import '../providers/goal_providers.dart';
import '../../kingdom/providers/kingdom_course_providers.dart';
import '../providers/goal_meditation_providers.dart';

enum _GoalAction { edit, pause, resume, reopen, complete, archive }

class GoalDetailScreen extends ConsumerStatefulWidget {
  const GoalDetailScreen({required this.goalId, super.key});

  final String goalId;

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  var _working = false;

  @override
  Widget build(BuildContext context) {
    final goal = ref.watch(goalProvider(widget.goalId));
    return goal.when(
      loading: () =>
          const SafeArea(child: Center(child: CircularProgressIndicator())),
      error: (_, _) => _GoalUnavailable(
        onRetry: () => ref.invalidate(goalProvider(widget.goalId)),
      ),
      data: (value) =>
          value == null ? const _GoalUnavailable() : _buildGoal(context, value),
    );
  }

  Widget _buildGoal(BuildContext context, Goal goal) {
    final kingdomComplete =
        ref.watch(kingdomMeditationReadyProvider).value ?? false;
    final returnPlan = ref.watch(goalReturnPlanProvider(goal.id));
    final returnRelevant =
        goal.starterKey == GoalStarterKey.stopControl ||
        switch (returnPlan) {
          AsyncData(:final value) => value.relevant,
          _ => false,
        };

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back to Goals',
                    onPressed: _working ? null : () => context.go('/goals'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Goal',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (goal.displayTitle != goal.title)
                      Text(
                        goal.title,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    Text(
                      goal.displayTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _StatusLabel(status: goal.status),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        if (kingdomComplete)
                          FilledButton.icon(
                            key: const Key('meditate-on-goal'),
                            onPressed: () =>
                                context.go('/goals/${goal.id}/meditate'),
                            icon: const Icon(Icons.self_improvement),
                            label: const Text('Meditate on this Goal'),
                          ),
                        if (returnRelevant)
                          FilledButton.tonalIcon(
                            key: const Key('goal-return'),
                            onPressed: _working
                                ? null
                                : () =>
                                      showReturnSheet(context, goalId: goal.id),
                            icon: const Icon(Icons.reply_outlined),
                            label: const Text('Return'),
                          ),
                        if (!kingdomComplete && !returnRelevant)
                          FilledButton.tonalIcon(
                            key: const Key('edit-goal'),
                            onPressed: _working ? null : () => _edit(goal),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                        PopupMenuButton<_GoalAction>(
                          key: const Key('goal-more-actions'),
                          tooltip: 'More Goal actions',
                          enabled: !_working,
                          onSelected: (action) => switch (action) {
                            _GoalAction.edit => _edit(goal),
                            _GoalAction.pause => _setStatus(
                              goal,
                              GoalStatus.paused,
                            ),
                            _GoalAction.resume || _GoalAction.reopen =>
                              _setStatus(goal, GoalStatus.active),
                            _GoalAction.complete => _setStatus(
                              goal,
                              GoalStatus.completed,
                            ),
                            _GoalAction.archive => _archive(goal),
                          },
                          itemBuilder: (_) => [
                            if (kingdomComplete || returnRelevant)
                              const PopupMenuItem(
                                value: _GoalAction.edit,
                                child: Text('Edit'),
                              ),
                            ..._statusActions(goal),
                          ],
                          child: const Chip(
                            avatar: Icon(Icons.more_horiz, size: 18),
                            label: Text('More'),
                          ),
                        ),
                      ],
                    ),
                    if (_hasText(goal.currentSituation) &&
                        goal.currentSituation!.trim() != goal.displayTitle) ...[
                      const SizedBox(height: AppSpacing.xl),
                      const _SectionLabel('What is happening now'),
                      const SizedBox(height: AppSpacing.xs),
                      Text(goal.currentSituation!.trim()),
                    ],
                    if (_hasText(goal.whyItMatters)) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const _SectionLabel('Why this matters'),
                      const SizedBox(height: AppSpacing.xs),
                      Text(goal.whyItMatters!.trim()),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<_GoalAction>> _statusActions(Goal goal) {
    final actions = <PopupMenuEntry<_GoalAction>>[];
    switch (goal.status) {
      case GoalStatus.active:
        actions.add(
          const PopupMenuItem(
            key: Key('pause-goal'),
            value: _GoalAction.pause,
            child: Text('Pause'),
          ),
        );
        actions.add(
          const PopupMenuItem(
            key: Key('complete-goal'),
            value: _GoalAction.complete,
            child: Text('Complete'),
          ),
        );
      case GoalStatus.paused:
        actions.add(
          const PopupMenuItem(
            key: Key('resume-goal'),
            value: _GoalAction.resume,
            child: Text('Resume'),
          ),
        );
        actions.add(
          const PopupMenuItem(
            key: Key('complete-goal'),
            value: _GoalAction.complete,
            child: Text('Complete'),
          ),
        );
      case GoalStatus.completed:
        actions.add(
          const PopupMenuItem(
            key: Key('reopen-goal'),
            value: _GoalAction.reopen,
            child: Text('Reopen'),
          ),
        );
      case GoalStatus.archived:
        return actions;
    }
    actions.add(
      const PopupMenuItem(
        key: Key('archive-goal'),
        value: _GoalAction.archive,
        child: Text('Archive'),
      ),
    );
    return actions;
  }

  Future<void> _edit(Goal goal) async {
    final edit = await showDialog<_GoalEdit>(
      context: context,
      builder: (context) => _EditGoalDialog(goal: goal),
    );
    if (edit == null || !mounted) return;
    await _run(() async {
      final repository = await ref.read(goalRepositoryProvider.future);
      await repository.edit(
        goal.id,
        title: edit.title,
        currentSituation: edit.currentSituation,
        whyItMatters: edit.whyItMatters,
      );
    });
  }

  Future<void> _setStatus(Goal goal, GoalStatus status) => _run(() async {
    final repository = await ref.read(goalRepositoryProvider.future);
    await repository.setStatus(goal.id, status);
  });

  Future<void> _archive(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive this Goal?'),
        content: const Text(
          'Meditation reminders will stop. Saved reflections remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      final repository = await ref.read(goalRepositoryProvider.future);
      await repository.setStatus(goal.id, GoalStatus.archived);
      await ref.read(goalMeditationRepositoryProvider).deletePlan(goal.id);
      final reminders = await ref.read(
        goalMeditationReminderCoordinatorProvider.future,
      );
      await reminders.cancel(goal.id);
      ref.invalidate(goalMeditationPlanProvider(goal.id));
      if (mounted) context.go('/goals');
    });
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await operation();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This Goal could not be updated.')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final GoalStatus status;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Text(_statusLabel(status)),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.labelLarge);
}

class _GoalUnavailable extends StatelessWidget {
  const _GoalUnavailable({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This Goal could not be opened just now.'),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _EditGoalDialog extends StatefulWidget {
  const _EditGoalDialog({required this.goal});

  final Goal goal;

  @override
  State<_EditGoalDialog> createState() => _EditGoalDialogState();
}

class _EditGoalDialogState extends State<_EditGoalDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _situationController;
  late final TextEditingController _whyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.goal.title);
    _situationController = TextEditingController(
      text: widget.goal.currentSituation,
    );
    _whyController = TextEditingController(text: widget.goal.whyItMatters);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _situationController.dispose();
    _whyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Edit Goal'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('edit-goal-title'),
          controller: _titleController,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Goal'),
        ),
        const SizedBox(height: AppSpacing.sm),
        // These two are a person's own account of the Goal, in sentences, so
        // they can be spoken. The Goal field stays a bare field: there it names
        // the row in the list rather than answering a question.
        SayableField(
          controller: _situationController,
          maxLength: 4000,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          labelText: 'What is happening now',
          // A cut is said rather than left to look like a whole account. The
          // dialog has no message line of its own, so it goes to the SnackBar
          // this screen already reports through: the messenger is an ancestor
          // of the dialog's route, so the notice lands on this screen while
          // the dialog is still up.
          onTruncated: _reportTruncation,
        ),
        const SizedBox(height: AppSpacing.sm),
        SayableField(
          controller: _whyController,
          maxLength: 4000,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          labelText: 'Why this matters',
          // Said for the same reason, and to the same place.
          onTruncated: _reportTruncation,
          // The field above already said it. Both are one dialog, so the notice
          // is said once rather than once per field.
          showUnavailableNotice: false,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: _titleController,
        builder: (context, value, child) => FilledButton(
          key: const Key('edit-goal-save'),
          onPressed: value.text.trim().isEmpty ? null : _save,
          child: const Text('Save'),
        ),
      ),
    ],
  );

  /// Reports a limit that cut a dictated account short.
  ///
  /// The messenger this reaches is the app's own, above the route holding this
  /// dialog, so the notice does not depend on the dialog outliving it. A dialog
  /// dismissed between the cut and the notice is a real possibility, and the
  /// notice still has to reach someone.
  void _reportTruncation() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(_limitReachedNotice)));
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(
      context,
      _GoalEdit(
        title: title,
        currentSituation: _optional(_situationController.text),
        whyItMatters: _optional(_whyController.text),
      ),
    );
  }
}

class _GoalEdit {
  const _GoalEdit({
    required this.title,
    this.currentSituation,
    this.whyItMatters,
  });

  final String title;
  final String? currentSituation;
  final String? whyItMatters;
}

/// Shown when a field's limit cut a dictated account short.
///
/// The app's own wording for the same event, reused rather than reworded:
/// `commitment_journey_screen` already tells someone their answer reached the
/// limit when it does. A second phrasing of the same fact would be the small
/// inconsistency the design asked to avoid.
const String _limitReachedNotice = 'Your answer reached the limit.';

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

String? _optional(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

String _statusLabel(GoalStatus status) => switch (status) {
  GoalStatus.active => 'Active',
  GoalStatus.paused => 'Paused',
  GoalStatus.completed => 'Completed',
  GoalStatus.archived => 'Archived',
};
