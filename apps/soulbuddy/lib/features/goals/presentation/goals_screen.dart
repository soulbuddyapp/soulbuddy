import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/goal.dart';
import '../providers/goal_providers.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  var _reordering = false;

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(visibleGoalsProvider);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.md),
              Semantics(
                header: true,
                child: Text(
                  'Goals',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Keep what you are seeking in one place.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.icon(
                    key: const Key('start-goal'),
                    onPressed: () => context.push('/welcome/goal'),
                    icon: const Icon(Icons.add),
                    label: const Text('Start a Goal'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('open-prayer-library'),
                    onPressed: () => context.go('/prayers'),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Prayer library'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              goals.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _GoalsUnavailable(
                  onRetry: () {
                    ref.invalidate(goalRepositoryProvider);
                    ref.invalidate(visibleGoalsProvider);
                  },
                ),
                data: (items) => items.isEmpty
                    ? const _EmptyGoals()
                    : _GoalSections(
                        goals: items,
                        reordering: _reordering,
                        onMoveActive: _moveActive,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _moveActive(
    List<Goal> activeGoals,
    String goalId,
    _GoalMove move,
  ) async {
    if (_reordering) return;
    final index = activeGoals.indexWhere((goal) => goal.id == goalId);
    if (index < 0) return;
    final targetIndex = switch (move) {
      _GoalMove.earlier => index - 1,
      _GoalMove.later => index + 1,
    };
    if (targetIndex < 0 || targetIndex >= activeGoals.length) return;

    final orderedIds = activeGoals.map((goal) => goal.id).toList();
    final current = orderedIds[index];
    orderedIds[index] = orderedIds[targetIndex];
    orderedIds[targetIndex] = current;

    setState(() => _reordering = true);
    try {
      final orderer = await ref.read(goalOrdererProvider.future);
      await orderer.reorderActive(orderedIds);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal order could not be updated.')),
        );
      }
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }
}

enum _GoalMove { earlier, later }

class _GoalSections extends StatelessWidget {
  const _GoalSections({
    required this.goals,
    required this.reordering,
    required this.onMoveActive,
  });

  final List<Goal> goals;
  final bool reordering;
  final Future<void> Function(
    List<Goal> activeGoals,
    String goalId,
    _GoalMove move,
  )
  onMoveActive;

  @override
  Widget build(BuildContext context) {
    final active = goals
        .where((goal) => goal.status == GoalStatus.active)
        .toList(growable: false);
    final paused = goals
        .where((goal) => goal.status == GoalStatus.paused)
        .toList(growable: false);
    final completed = goals
        .where((goal) => goal.status == GoalStatus.completed)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (active.isNotEmpty)
          _GoalSection(
            title: 'Active',
            goals: active,
            reordering: reordering,
            onMove: (goalId, move) => onMoveActive(active, goalId, move),
          ),
        if (active.isNotEmpty && paused.isNotEmpty)
          const SizedBox(height: AppSpacing.lg),
        if (paused.isNotEmpty) _GoalSection(title: 'Paused', goals: paused),
        if ((active.isNotEmpty || paused.isNotEmpty) && completed.isNotEmpty)
          const SizedBox(height: AppSpacing.lg),
        if (completed.isNotEmpty)
          _GoalSection(title: 'Completed', goals: completed),
      ],
    );
  }
}

class _GoalSection extends StatelessWidget {
  const _GoalSection({
    required this.title,
    required this.goals,
    this.reordering = false,
    this.onMove,
  });

  final String title;
  final List<Goal> goals;
  final bool reordering;
  final Future<void> Function(String goalId, _GoalMove move)? onMove;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      for (var index = 0; index < goals.length; index++) ...[
        _GoalTile(
          goal: goals[index],
          reordering: reordering,
          canMoveEarlier: onMove != null && index > 0,
          canMoveLater: onMove != null && index < goals.length - 1,
          onMove: onMove,
        ),
        if (index != goals.length - 1) const SizedBox(height: AppSpacing.sm),
      ],
    ],
  );
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.goal,
    required this.reordering,
    required this.canMoveEarlier,
    required this.canMoveLater,
    this.onMove,
  });

  final Goal goal;
  final bool reordering;
  final bool canMoveEarlier;
  final bool canMoveLater;
  final Future<void> Function(String goalId, _GoalMove move)? onMove;

  @override
  Widget build(BuildContext context) {
    final situation = goal.currentSituation?.trim();
    final canReorder = canMoveEarlier || canMoveLater;
    return Card(
      child: ListTile(
        minTileHeight: 76,
        leading: Icon(_statusIcon(goal.status)),
        title: Text(goal.title),
        subtitle: situation == null || situation.isEmpty
            ? Text(_statusLabel(goal.status))
            : Text(situation, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: canReorder
            ? PopupMenuButton<_GoalMove>(
                key: Key('goal-order-menu-${goal.id}'),
                enabled: !reordering,
                tooltip: 'Change order for ${goal.title}',
                onSelected: (move) => onMove?.call(goal.id, move),
                itemBuilder: (context) => [
                  if (canMoveEarlier)
                    const PopupMenuItem(
                      value: _GoalMove.earlier,
                      child: Text('Move earlier'),
                    ),
                  if (canMoveLater)
                    const PopupMenuItem(
                      value: _GoalMove.later,
                      child: Text('Move later'),
                    ),
                ],
              )
            : const Icon(Icons.chevron_right),
        onTap: () => context.go('/goals/${goal.id}'),
      ),
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What would you like help with?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Begin with one thing you want to seek, change, or carry.',
          ),
        ],
      ),
    ),
  );
}

class _GoalsUnavailable extends StatelessWidget {
  const _GoalsUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Your Goals could not be opened just now.'),
      const SizedBox(height: AppSpacing.sm),
      OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
    ],
  );
}

String _statusLabel(GoalStatus status) => switch (status) {
  GoalStatus.active => 'Active',
  GoalStatus.paused => 'Paused',
  GoalStatus.completed => 'Completed',
  GoalStatus.archived => 'Archived',
};

IconData _statusIcon(GoalStatus status) => switch (status) {
  GoalStatus.active => Icons.flag_outlined,
  GoalStatus.paused => Icons.pause_circle_outline,
  GoalStatus.completed => Icons.check_circle_outline,
  GoalStatus.archived => Icons.archive_outlined,
};
