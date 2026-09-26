import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../guards/presentation/return_sheet.dart';
import '../../today/presentation/completed_today_item.dart';
import '../application/goal_today_composer.dart';
import '../application/goal_today_resource_adapter.dart';
import '../domain/goal.dart';
import '../domain/goal_action.dart';
import '../providers/goal_today_providers.dart';

class GoalTodaySections extends StatefulWidget {
  const GoalTodaySections({
    required this.snapshot,
    required this.onCompleteAction,
    required this.onOpenResource,
    required this.onCompleteResource,
    this.excludedGoalIds = const <String>{},
    this.onReturn,
    super.key,
  });

  final GoalTodaySnapshot snapshot;
  final Set<String> excludedGoalIds;
  final Future<void> Function(Goal goal)? onReturn;
  final Future<void> Function(GoalTodayActionItem item) onCompleteAction;
  final Future<void> Function(
    GoalTodayResourceItem item,
    GoalTodayResourceHandle? handle,
  )
  onOpenResource;
  final Future<void> Function(
    GoalTodayResourceItem item,
    GoalTodayResourceHandle handle,
  )
  onCompleteResource;

  @override
  State<GoalTodaySections> createState() => _GoalTodaySectionsState();
}

class _GoalTodaySectionsState extends State<GoalTodaySections> {
  final Set<String> _busyKeys = <String>{};
  final Map<String, _CompletedItem> _completedItems =
      <String, _CompletedItem>{};

  @override
  void didUpdateWidget(covariant GoalTodaySections oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(
      oldWidget.snapshot.localDate,
      widget.snapshot.localDate,
    )) {
      _completedItems.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = widget.snapshot.sections
        .where((section) => !widget.excludedGoalIds.contains(section.goal.id))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          _GoalTodaySectionCard(
            section: sections[index],
            resources: widget.snapshot.resources,
            busyKeys: _busyKeys,
            completedItems: _completedItems.values
                .where((item) => item.goalId == sections[index].goal.id)
                .toList(growable: false),
            returnAvailable: widget.snapshot.returnGoalIds.contains(
              sections[index].goal.id,
            ),
            onReturn: (goal) => _run('return:${goal.id}', () async {
              final callback = widget.onReturn;
              if (callback != null) {
                await callback(goal);
                return;
              }
              if (!mounted) return;
              await showReturnSheet(context, goalId: goal.id);
            }),
            onCompleteAction: (item) => _complete(
              key: item.occurrence.occurrenceKey,
              busyKey: item.stableKey,
              goalId: item.occurrence.action.goalId,
              label: item.occurrence.action.body,
              operation: () => widget.onCompleteAction(item),
            ),
            onOpenResource: (item, handle) =>
                _run(item.stableKey, () => widget.onOpenResource(item, handle)),
            onCompleteResource: (item, handle) => _complete(
              key: item.resource.stableKey,
              busyKey: item.stableKey,
              goalId: item.resource.goalId,
              label: item.resource.label,
              operation: () => widget.onCompleteResource(item, handle),
            ),
            onDismissCompleted: (key) =>
                setState(() => _completedItems.remove(key)),
          ),
          if (index != sections.length - 1)
            const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  Future<void> _run(String key, Future<void> Function() action) async {
    if (_busyKeys.contains(key)) return;
    setState(() => _busyKeys.add(key));
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
  }

  Future<void> _complete({
    required String key,
    required String busyKey,
    required String goalId,
    required String label,
    required Future<void> Function() operation,
  }) async {
    if (_busyKeys.contains(busyKey)) return;
    setState(() => _busyKeys.add(busyKey));
    try {
      await operation();
      if (!mounted) return;
      setState(() {
        _completedItems[key] = _CompletedItem(
          key: key,
          goalId: goalId,
          label: label,
          completedAt: DateTime.now(),
        );
      });
    } catch (_) {
      // The screen-level callback owns user-facing persistence errors.
    } finally {
      if (mounted) setState(() => _busyKeys.remove(busyKey));
    }
  }
}

class _CompletedItem {
  const _CompletedItem({
    required this.key,
    required this.goalId,
    required this.label,
    required this.completedAt,
  });

  final String key;
  final String goalId;
  final String label;
  final DateTime completedAt;
}

class _GoalTodaySectionCard extends StatelessWidget {
  const _GoalTodaySectionCard({
    required this.section,
    required this.resources,
    required this.busyKeys,
    required this.completedItems,
    required this.returnAvailable,
    required this.onReturn,
    required this.onCompleteAction,
    required this.onOpenResource,
    required this.onCompleteResource,
    required this.onDismissCompleted,
  });

  final GoalTodaySection section;
  final GoalTodayResourceProjection resources;
  final Set<String> busyKeys;
  final List<_CompletedItem> completedItems;
  final bool returnAvailable;
  final Future<void> Function(Goal goal) onReturn;
  final Future<void> Function(GoalTodayActionItem item) onCompleteAction;
  final Future<void> Function(
    GoalTodayResourceItem item,
    GoalTodayResourceHandle? handle,
  )
  onOpenResource;
  final Future<void> Function(
    GoalTodayResourceItem item,
    GoalTodayResourceHandle handle,
  )
  onCompleteResource;
  final ValueChanged<String> onDismissCompleted;

  @override
  Widget build(BuildContext context) {
    final returnBusy = busyKeys.contains('return:${section.goal.id}');
    return Card(
      key: ValueKey('goal-today-section-${section.goal.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                section.goal.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (returnAvailable) ...[
              const SizedBox(height: AppSpacing.sm),
              FilledButton.tonalIcon(
                key: ValueKey('goal-today-return-${section.goal.id}'),
                onPressed: returnBusy ? null : () => onReturn(section.goal),
                icon: returnBusy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.reply_outlined, size: 18),
                label: const Text('Return'),
              ),
            ],
            if (section.items.isNotEmpty || completedItems.isNotEmpty)
              const SizedBox(height: AppSpacing.xs),
            for (final completed in completedItems)
              CompletedTodayItem(
                id: completed.key,
                label: completed.label,
                completedAt: completed.completedAt,
                onDismiss: () => onDismissCompleted(completed.key),
              ),
            for (var index = 0; index < section.items.length; index++) ...[
              if (!completedItems.any(
                (completed) =>
                    completed.key == _completionKey(section.items[index]),
              )) ...[
                _GoalTodayItemRow(
                  item: section.items[index],
                  handle: section.items[index] is GoalTodayResourceItem
                      ? resources.handleFor(
                          section.items[index] as GoalTodayResourceItem,
                        )
                      : null,
                  busy: busyKeys.contains(section.items[index].stableKey),
                  onCompleteAction: onCompleteAction,
                  onOpenResource: onOpenResource,
                  onCompleteResource: onCompleteResource,
                ),
                if (index != section.items.length - 1)
                  const Divider(height: AppSpacing.xs),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalTodayItemRow extends StatelessWidget {
  const _GoalTodayItemRow({
    required this.item,
    required this.handle,
    required this.busy,
    required this.onCompleteAction,
    required this.onOpenResource,
    required this.onCompleteResource,
  });

  final GoalTodayItem item;
  final GoalTodayResourceHandle? handle;
  final bool busy;
  final Future<void> Function(GoalTodayActionItem item) onCompleteAction;
  final Future<void> Function(
    GoalTodayResourceItem item,
    GoalTodayResourceHandle? handle,
  )
  onOpenResource;
  final Future<void> Function(
    GoalTodayResourceItem item,
    GoalTodayResourceHandle handle,
  )
  onCompleteResource;

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      GoalTodayActionItem action => _ActionRow(
        item: action,
        busy: busy,
        onDone: () => onCompleteAction(action),
      ),
      GoalTodayResourceItem resource => _ResourceRow(
        item: resource,
        handle: handle,
        busy: busy,
        onOpen: () => onOpenResource(resource, handle),
        onComplete: _isCompletable(handle)
            ? () => onCompleteResource(resource, handle!)
            : null,
      ),
    };
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.item,
    required this.busy,
    required this.onDone,
  });

  final GoalTodayActionItem item;
  final bool busy;
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    final action = item.occurrence.action;
    final time = _actionTimeLabel(context, action);
    return ConstrainedBox(
      key: ValueKey('goal-today-row-${item.stableKey}'),
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          Icon(_actionIcon(action.kind), size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (time != null)
                  Text(time, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          TextButton.icon(
            key: ValueKey('goal-today-done-${item.occurrence.occurrenceKey}'),
            onPressed: busy ? null : onDone,
            icon: busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check, size: 18),
            label: const Text('Done'),
          ),
          PopupMenuButton<void>(
            key: ValueKey('goal-today-more-${item.stableKey}'),
            tooltip: 'More actions',
            itemBuilder: (_) => const [
              PopupMenuItem(enabled: false, child: Text('Action for today')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.item,
    required this.handle,
    required this.busy,
    required this.onOpen,
    required this.onComplete,
  });

  final GoalTodayResourceItem item;
  final GoalTodayResourceHandle? handle;
  final bool busy;
  final Future<void> Function() onOpen;
  final Future<void> Function()? onComplete;

  @override
  Widget build(BuildContext context) {
    final resource = item.resource;
    final due = resource.dueAt == null
        ? null
        : MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(resource.dueAt!.toLocal()));
    return ConstrainedBox(
      key: ValueKey('goal-today-row-${resource.stableKey}'),
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          Icon(_resourceIcon(resource.kind), size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: InkWell(
              onTap: busy ? null : onOpen,
              borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (due != null)
                      Text(due, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
            ),
          ),
          TextButton(
            key: ValueKey(
              onComplete == null
                  ? 'goal-today-open-${resource.stableKey}'
                  : 'goal-today-prayed-${resource.stableKey}',
            ),
            onPressed: busy ? null : (onComplete ?? onOpen),
            child: Text(
              resource.kind == GoalTodayResourceKind.prayer ? 'Pray' : 'Open',
            ),
          ),
          PopupMenuButton<_ResourceMenuAction>(
            key: ValueKey('goal-today-more-${resource.stableKey}'),
            tooltip: 'More actions',
            onSelected: (_) => onOpen(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ResourceMenuAction.details,
                child: Text('Details'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _ResourceMenuAction { details }

String _completionKey(GoalTodayItem item) => switch (item) {
  GoalTodayActionItem(:final occurrence) => occurrence.occurrenceKey,
  GoalTodayResourceItem(:final resource) => resource.stableKey,
};

bool _isCompletable(GoalTodayResourceHandle? handle) =>
    handle is GoalTodayReminderHandle || handle is GoalTodayLegacyPrayerHandle;

IconData _actionIcon(GoalActionKind kind) => switch (kind) {
  GoalActionKind.guard => Icons.shield_outlined,
  GoalActionKind.accountability => Icons.people_outline,
  GoalActionKind.nextStep => Icons.arrow_forward_outlined,
  GoalActionKind.commitmentPractice => Icons.checklist_outlined,
  GoalActionKind.care => Icons.favorite_border,
  GoalActionKind.other => Icons.circle_outlined,
};

IconData _resourceIcon(GoalTodayResourceKind kind) => switch (kind) {
  GoalTodayResourceKind.prayer => Icons.front_hand_outlined,
  GoalTodayResourceKind.scripture => Icons.menu_book_outlined,
  GoalTodayResourceKind.reminder => Icons.notifications_active_outlined,
  GoalTodayResourceKind.accountability => Icons.people_outline,
};

String? _actionTimeLabel(BuildContext context, GoalAction action) {
  final localTime = action.localTime;
  if (localTime != null) return localTime;
  if (action.scheduleType != GoalScheduleType.once || action.onceAt == null) {
    return null;
  }
  return MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay.fromDateTime(action.onceAt!.toLocal()));
}
