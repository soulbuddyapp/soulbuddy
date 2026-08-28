import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/goal.dart';
import '../providers/goal_providers.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    : _GoalSections(goals: items),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalSections extends StatelessWidget {
  const _GoalSections({required this.goals});

  final List<Goal> goals;

  @override
  Widget build(BuildContext context) {
    final active = goals.where((goal) => goal.status == GoalStatus.active);
    final paused = goals.where((goal) => goal.status == GoalStatus.paused);
    final completed = goals.where(
      (goal) => goal.status == GoalStatus.completed,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (active.isNotEmpty)
          _GoalSection(title: 'Active', goals: active.toList()),
        if (active.isNotEmpty && paused.isNotEmpty)
          const SizedBox(height: AppSpacing.lg),
        if (paused.isNotEmpty)
          _GoalSection(title: 'Paused', goals: paused.toList()),
        if ((active.isNotEmpty || paused.isNotEmpty) && completed.isNotEmpty)
          const SizedBox(height: AppSpacing.lg),
        if (completed.isNotEmpty)
          _GoalSection(title: 'Completed', goals: completed.toList()),
      ],
    );
  }
}

class _GoalSection extends StatelessWidget {
  const _GoalSection({required this.title, required this.goals});

  final String title;
  final List<Goal> goals;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      for (var index = 0; index < goals.length; index++) ...[
        _GoalTile(goal: goals[index]),
        if (index != goals.length - 1) const SizedBox(height: AppSpacing.sm),
      ],
    ],
  );
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final situation = goal.currentSituation?.trim();
    return Card(
      child: ListTile(
        minTileHeight: 76,
        leading: Icon(_statusIcon(goal.status)),
        title: Text(goal.title),
        subtitle: situation == null || situation.isEmpty
            ? Text(_statusLabel(goal.status))
            : Text(situation, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
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
