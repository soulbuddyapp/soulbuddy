import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/design/sacred_piece.dart';
import '../../../core/presentation/sacred_piece_medallion.dart';
import '../../prayers/domain/personal_prayer.dart';
import '../../prayers/providers/personal_prayer_providers.dart';
import '../domain/goal.dart';
import '../providers/goal_providers.dart';
import '../../kingdom/providers/kingdom_course_providers.dart';
import 'create_meditation_goal.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  var _reordering = false;
  var _filter = _CreatedFilter.all;
  var _sort = _CreatedSort.recent;

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(visibleGoalsProvider);
    final personalPrayers = ref.watch(personalPrayersProvider);
    final kingdomComplete =
        ref.watch(kingdomMeditationReadyProvider).value ?? false;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'My Collection',
                        maxLines: 2,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton.filledTonal(
                      key: const Key('open-create-workspace'),
                      tooltip: 'Create',
                      onPressed: () =>
                          _showCreateSheet(context, ref, kingdomComplete),
                      icon: const Icon(Icons.add),
                    ),
                    const SizedBox(width: 56),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    const Text(
                      'Grow closer to God through personal prayer & goals.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    goals.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => _GoalsUnavailable(
                        onRetry: () {
                          ref.invalidate(goalRepositoryProvider);
                          ref.invalidate(visibleGoalsProvider);
                        },
                      ),
                      data: (items) => personalPrayers.when(
                        loading: () => _CreatedWorkspace(
                          goals: items,
                          prayers: const [],
                          filter: _filter,
                          sort: _sort,
                          loadingPrayers: true,
                          reordering: _reordering,
                          onFilterChanged: (value) =>
                              setState(() => _filter = value),
                          onSortChanged: (value) =>
                              setState(() => _sort = value),
                          onMoveActive: _moveActive,
                        ),
                        error: (_, _) => _CreatedWorkspace(
                          goals: items,
                          prayers: const [],
                          filter: _filter,
                          sort: _sort,
                          prayersUnavailable: true,
                          reordering: _reordering,
                          onFilterChanged: (value) =>
                              setState(() => _filter = value),
                          onSortChanged: (value) =>
                              setState(() => _sort = value),
                          onMoveActive: _moveActive,
                        ),
                        data: (prayers) => _CreatedWorkspace(
                          goals: items,
                          prayers: prayers,
                          filter: _filter,
                          sort: _sort,
                          reordering: _reordering,
                          onFilterChanged: (value) =>
                              setState(() => _filter = value),
                          onSortChanged: (value) =>
                              setState(() => _sort = value),
                          onMoveActive: _moveActive,
                        ),
                      ),
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

enum _CreatedFilter { all, goals, prayers }

enum _CreatedSort { recent, alphabetical, goalPriority }

Future<void> _showCreateSheet(
  BuildContext context,
  WidgetRef ref,
  bool kingdomComplete,
) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (sheetContext) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'What would you like to begin?',
            style: Theme.of(sheetContext).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          _CreateChoice(
            key: const Key('create-goal'),
            icon: Icons.flag_outlined,
            title: 'Goal',
            subtitle: 'Name a change, hope, or next faithful step.',
            onTap: () {
              Navigator.pop(sheetContext);
              context.push('/welcome/goal');
            },
          ),
          _CreateChoice(
            key: const Key('create-meditation-goal'),
            icon: kingdomComplete ? Icons.self_improvement : Icons.lock_outline,
            title: 'Meditation Goal',
            subtitle: kingdomComplete
                ? 'Daily or weekly listening and discernment.'
                : 'Complete Orientation and six Kingdom Nuggets to unlock.',
            onTap: () {
              Navigator.pop(sheetContext);
              if (kingdomComplete) {
                createMeditationGoal(context, ref);
              } else {
                context.go('/kingdom');
              }
            },
          ),
          _CreateChoice(
            key: const Key('create-prayer'),
            icon: Icons.edit_note_outlined,
            title: 'Prayer',
            subtitle: 'Personal prayer and intercession.',
            onTap: () {
              Navigator.pop(sheetContext);
              context.go('/prayers/create');
            },
          ),
        ],
      ),
    ),
  ),
);

class _CreateChoice extends StatelessWidget {
  const _CreateChoice({
    required super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: AppSpacing.minimumTouchTarget,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class _CreatedWorkspace extends StatelessWidget {
  const _CreatedWorkspace({
    required this.goals,
    required this.prayers,
    required this.filter,
    required this.sort,
    required this.reordering,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.onMoveActive,
    this.loadingPrayers = false,
    this.prayersUnavailable = false,
  });

  final List<Goal> goals;
  final List<PersonalPrayer> prayers;
  final _CreatedFilter filter;
  final _CreatedSort sort;
  final bool reordering;
  final bool loadingPrayers;
  final bool prayersUnavailable;
  final ValueChanged<_CreatedFilter> onFilterChanged;
  final ValueChanged<_CreatedSort> onSortChanged;
  final Future<void> Function(List<Goal>, String, _GoalMove) onMoveActive;

  @override
  Widget build(BuildContext context) {
    final activeGoals = goals
        .where((goal) => goal.status == GoalStatus.active)
        .toList(growable: false);
    final items =
        [
            for (final goal in goals) _CreatedItem.goal(goal),
            for (final prayer in prayers) _CreatedItem.prayer(prayer),
          ]
          ..removeWhere(
            (item) => switch (filter) {
              _CreatedFilter.all => false,
              _CreatedFilter.goals => item.goal == null,
              _CreatedFilter.prayers => item.prayer == null,
            },
          )
          ..sort((left, right) => _compareCreatedItems(left, right, sort));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final value in _CreatedFilter.values)
              ChoiceChip(
                key: Key('created-filter-${value.name}'),
                label: Text(_filterLabel(value)),
                selected: filter == value,
                onSelected: (_) => onFilterChanged(value),
              ),
            PopupMenuButton<_CreatedSort>(
              key: const Key('created-sort-menu'),
              tooltip: 'Sort collection',
              onSelected: onSortChanged,
              itemBuilder: (context) => [
                for (final value in _CreatedSort.values)
                  CheckedPopupMenuItem(
                    key: Key('created-sort-${value.name}'),
                    value: value,
                    checked: sort == value,
                    child: Text(_sortLabel(value)),
                  ),
              ],
              child: Chip(
                avatar: const Icon(Icons.sort, size: 18),
                label: Text(_sortLabel(sort)),
              ),
            ),
          ],
        ),
        if (loadingPrayers) ...[
          const SizedBox(height: AppSpacing.md),
          const LinearProgressIndicator(),
        ],
        if (prayersUnavailable) ...[
          const SizedBox(height: AppSpacing.md),
          const Text('Your saved prayers are unavailable just now.'),
        ],
        const SizedBox(height: AppSpacing.md),
        if (items.isEmpty && !loadingPrayers)
          const _EmptyCreatedWork()
        else
          for (var index = 0; index < items.length; index++) ...[
            _CreatedItemTile(
              item: items[index],
              reordering: reordering,
              showPriorityControls:
                  sort == _CreatedSort.goalPriority &&
                  filter != _CreatedFilter.prayers,
              activeGoals: activeGoals,
              onMoveActive: onMoveActive,
            ),
            if (index != items.length - 1)
              const SizedBox(height: AppSpacing.xs),
          ],
      ],
    );
  }
}

class _CreatedItem {
  const _CreatedItem.goal(this.goal) : prayer = null;
  const _CreatedItem.prayer(this.prayer) : goal = null;

  final Goal? goal;
  final PersonalPrayer? prayer;

  String get title => goal?.displayTitle ?? _prayerDisplayTitle(prayer!);
  DateTime get updatedAt => goal?.updatedAt ?? prayer!.updatedAt;
}

String _prayerDisplayTitle(PersonalPrayer prayer) {
  if (prayer.title != 'Grow closer to God') return prayer.title;
  final firstThought = prayer.body
      .trim()
      .split(RegExp(r'[.!?\n]'))
      .first
      .trim();
  return firstThought.isEmpty ? prayer.title : firstThought;
}

class _CreatedItemTile extends StatelessWidget {
  const _CreatedItemTile({
    required this.item,
    required this.reordering,
    required this.showPriorityControls,
    required this.activeGoals,
    required this.onMoveActive,
  });

  final _CreatedItem item;
  final bool reordering;
  final bool showPriorityControls;
  final List<Goal> activeGoals;
  final Future<void> Function(List<Goal>, String, _GoalMove) onMoveActive;

  @override
  Widget build(BuildContext context) {
    final goal = item.goal;
    final piece = goal == null ? SacredPiece.prayer : SacredPiece.goal;
    final canReorder =
        goal != null &&
        goal.status == GoalStatus.active &&
        showPriorityControls &&
        activeGoals.length > 1;
    final activeIndex = goal == null
        ? -1
        : activeGoals.indexWhere((item) => item.id == goal.id);
    return Card(
      child: ListTile(
        minTileHeight: 56,
        dense: true,
        leading: SacredPieceMedallion(
          key: Key(
            'collection-piece-${piece.name}-${goal?.id ?? item.prayer!.id}',
          ),
          piece: piece,
          decorative: true,
          size: 38,
        ),
        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          goal == null
              ? item.title == item.prayer!.title
                    ? 'Personal prayer'
                    : '${item.prayer!.title} · Prayer'
              : item.title == goal.title
              ? 'Goal · ${_statusLabel(goal.status)}'
              : '${goal.title} · ${_statusLabel(goal.status)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: canReorder
            ? PopupMenuButton<_GoalMove>(
                key: Key('goal-order-menu-${goal.id}'),
                enabled: !reordering,
                tooltip: 'Change priority for ${goal.title}',
                onSelected: (move) => onMoveActive(activeGoals, goal.id, move),
                itemBuilder: (context) => [
                  if (activeIndex > 0)
                    const PopupMenuItem(
                      value: _GoalMove.earlier,
                      child: Text('Move earlier'),
                    ),
                  if (activeIndex < activeGoals.length - 1)
                    const PopupMenuItem(
                      value: _GoalMove.later,
                      child: Text('Move later'),
                    ),
                ],
              )
            : const Icon(Icons.chevron_right),
        onTap: () => context.go(
          goal == null
              ? '/prayers/saved/${item.prayer!.id}'
              : '/goals/${goal.id}',
        ),
      ),
    );
  }
}

class _EmptyCreatedWork extends StatelessWidget {
  const _EmptyCreatedWork();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Text(
        'Begin with a Goal or personal prayer.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ),
  );
}

int _compareCreatedItems(
  _CreatedItem left,
  _CreatedItem right,
  _CreatedSort sort,
) => switch (sort) {
  _CreatedSort.recent => right.updatedAt.compareTo(left.updatedAt),
  _CreatedSort.alphabetical => left.title.toLowerCase().compareTo(
    right.title.toLowerCase(),
  ),
  _CreatedSort.goalPriority => () {
    final leftGoal = left.goal;
    final rightGoal = right.goal;
    if (leftGoal != null && rightGoal != null) {
      return leftGoal.position.compareTo(rightGoal.position);
    }
    if (leftGoal != null) return -1;
    if (rightGoal != null) return 1;
    return right.updatedAt.compareTo(left.updatedAt);
  }(),
};

String _filterLabel(_CreatedFilter value) => switch (value) {
  _CreatedFilter.all => 'All',
  _CreatedFilter.goals => 'Goals',
  _CreatedFilter.prayers => 'Prayers',
};

String _sortLabel(_CreatedSort value) => switch (value) {
  _CreatedSort.recent => 'Recent',
  _CreatedSort.alphabetical => 'A–Z',
  _CreatedSort.goalPriority => 'Goal priority',
};

enum _GoalMove { earlier, later }

// Legacy section renderer retained for safe migration of existing screen tests.
// ignore: unused_element
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

// ignore: unused_element
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
