import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/goal.dart';
import '../providers/goal_providers.dart';

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
                    Text(
                      goal.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _StatusLabel(status: goal.status),
                    if (_hasText(goal.currentSituation)) ...[
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
                    const SizedBox(height: AppSpacing.xl),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        FilledButton.tonalIcon(
                          key: const Key('edit-goal'),
                          onPressed: _working ? null : () => _edit(goal),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                        ),
                        ..._statusActions(goal),
                        OutlinedButton.icon(
                          key: const Key('goal-prayer-library'),
                          onPressed: _working
                              ? null
                              : () => context.go('/prayers'),
                          icon: const Icon(Icons.menu_book_outlined),
                          label: const Text('Prayer library'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _statusActions(Goal goal) {
    final actions = <Widget>[];
    switch (goal.status) {
      case GoalStatus.active:
        actions.add(
          OutlinedButton.icon(
            key: const Key('pause-goal'),
            onPressed: _working
                ? null
                : () => _setStatus(goal, GoalStatus.paused),
            icon: const Icon(Icons.pause_outlined),
            label: const Text('Pause'),
          ),
        );
        actions.add(
          FilledButton.icon(
            key: const Key('complete-goal'),
            onPressed: _working
                ? null
                : () => _setStatus(goal, GoalStatus.completed),
            icon: const Icon(Icons.check_outlined),
            label: const Text('Complete'),
          ),
        );
      case GoalStatus.paused:
        actions.add(
          OutlinedButton.icon(
            key: const Key('resume-goal'),
            onPressed: _working
                ? null
                : () => _setStatus(goal, GoalStatus.active),
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('Resume'),
          ),
        );
        actions.add(
          FilledButton.icon(
            key: const Key('complete-goal'),
            onPressed: _working
                ? null
                : () => _setStatus(goal, GoalStatus.completed),
            icon: const Icon(Icons.check_outlined),
            label: const Text('Complete'),
          ),
        );
      case GoalStatus.completed:
        actions.add(
          OutlinedButton.icon(
            key: const Key('reopen-goal'),
            onPressed: _working
                ? null
                : () => _setStatus(goal, GoalStatus.active),
            icon: const Icon(Icons.replay_outlined),
            label: const Text('Reopen'),
          ),
        );
      case GoalStatus.archived:
        return actions;
    }
    actions.add(
      TextButton.icon(
        key: const Key('archive-goal'),
        onPressed: _working ? null : () => _archive(goal),
        icon: const Icon(Icons.archive_outlined),
        label: const Text('Archive'),
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
          'It will leave your Goals list. Its saved resources are not deleted.',
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
        TextField(
          controller: _situationController,
          maxLength: 4000,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'What is happening now'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _whyController,
          maxLength: 4000,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Why this matters'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );

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
