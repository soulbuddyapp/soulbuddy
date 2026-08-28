import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../application/goal_today_composer.dart';
import '../application/goal_today_resource_adapter.dart';
import '../domain/goal_action.dart';
import '../providers/goal_today_providers.dart';

class GoalTodaySections extends StatefulWidget {
  const GoalTodaySections({
    required this.snapshot,
    required this.onCompleteAction,
    required this.onOpenResource,
    required this.onCompleteResource,
    super.key,
  });

  final GoalTodaySnapshot snapshot;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (
          var index = 0;
          index < widget.snapshot.sections.length;
          index++
        ) ...[
          _GoalTodaySectionCard(
            section: widget.snapshot.sections[index],
            resources: widget.snapshot.resources,
            busyKeys: _busyKeys,
            onCompleteAction: (item) =>
                _run(item.stableKey, () => widget.onCompleteAction(item)),
            onOpenResource: (item, handle) =>
                _run(item.stableKey, () => widget.onOpenResource(item, handle)),
            onCompleteResource: (item, handle) => _run(
              item.stableKey,
              () => widget.onCompleteResource(item, handle),
            ),
          ),
          if (index != widget.snapshot.sections.length - 1)
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
}

class _GoalTodaySectionCard extends StatelessWidget {
  const _GoalTodaySectionCard({
    required this.section,
    required this.resources,
    required this.busyKeys,
    required this.onCompleteAction,
    required this.onOpenResource,
    required this.onCompleteResource,
  });

  final GoalTodaySection section;
  final GoalTodayResourceProjection resources;
  final Set<String> busyKeys;
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
    return Card(
      key: ValueKey('goal-today-section-${section.goal.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
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
            const SizedBox(height: AppSpacing.sm),
            for (var index = 0; index < section.items.length; index++) ...[
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
                const Divider(height: AppSpacing.lg),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_actionIcon(action.kind), size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(action.body),
                  if (time != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      time,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
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
        ),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: busy ? null : onOpen,
          borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_resourceIcon(resource.kind), size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(resource.label),
                      if (due != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          due,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerRight,
          child: onComplete == null
              ? TextButton.icon(
                  key: ValueKey('goal-today-open-${resource.stableKey}'),
                  onPressed: busy ? null : onOpen,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open'),
                )
              : TextButton.icon(
                  key: ValueKey('goal-today-prayed-${resource.stableKey}'),
                  onPressed: busy ? null : onComplete,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: const Text('Prayed'),
                ),
        ),
      ],
    );
  }
}

bool _isCompletable(GoalTodayResourceHandle? handle) =>
    handle is GoalTodayReminderHandle || handle is GoalTodayLegacyPrayerHandle;

IconData _actionIcon(GoalActionKind kind) => switch (kind) {
  GoalActionKind.guard => Icons.shield_outlined,
  GoalActionKind.accountability => Icons.people_outline,
  GoalActionKind.nextStep => Icons.arrow_forward_outlined,
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
