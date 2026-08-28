import '../domain/goal.dart';
import '../domain/goal_action.dart';

enum GoalTodayResourceKind { prayer, scripture, reminder, accountability }

class GoalTodayResourceCandidate {
  const GoalTodayResourceCandidate({
    required this.goalId,
    required this.stableKey,
    required this.dedupeKey,
    required this.kind,
    required this.label,
    this.dueAt,
  });

  final String goalId;
  final String stableKey;
  final String dedupeKey;
  final GoalTodayResourceKind kind;
  final String label;
  final DateTime? dueAt;
}

sealed class GoalTodayItem {
  const GoalTodayItem();

  String get goalId;
  String get stableKey;
  String get dedupeKey;
}

final class GoalTodayActionItem extends GoalTodayItem {
  const GoalTodayActionItem(this.occurrence);

  final GoalActionOccurrence occurrence;

  @override
  String get goalId => occurrence.action.goalId;

  @override
  String get stableKey => 'action:${occurrence.occurrenceKey}';

  @override
  String get dedupeKey => stableKey;
}

final class GoalTodayResourceItem extends GoalTodayItem {
  const GoalTodayResourceItem(this.resource);

  final GoalTodayResourceCandidate resource;

  @override
  String get goalId => resource.goalId;

  @override
  String get stableKey => 'resource:${resource.stableKey}';

  @override
  String get dedupeKey => resource.dedupeKey;
}

class GoalTodaySection {
  const GoalTodaySection({required this.goal, required this.items});

  final Goal goal;
  final List<GoalTodayItem> items;
}

class GoalTodayComposer {
  const GoalTodayComposer({this.maximumItemsPerGoal = 3})
    : assert(maximumItemsPerGoal > 0);

  final int maximumItemsPerGoal;

  List<GoalTodaySection> compose({
    required List<Goal> goals,
    required List<GoalActionOccurrence> dueActions,
    List<GoalTodayResourceCandidate> resources = const [],
  }) {
    final orderedGoals = goals
        .where(
          (goal) =>
              goal.status == GoalStatus.active && goal.archivedAt == null,
        )
        .toList()
      ..sort((left, right) {
        final byPosition = left.position.compareTo(right.position);
        if (byPosition != 0) return byPosition;
        return left.id.compareTo(right.id);
      });
    final activeGoalIds = orderedGoals.map((goal) => goal.id).toSet();
    final candidatesByGoal = <String, List<_RankedGoalTodayItem>>{};
    var sequence = 0;

    for (final occurrence in dueActions) {
      if (!activeGoalIds.contains(occurrence.action.goalId)) continue;
      if (occurrence.latestEventType == GoalActionEventType.completed ||
          occurrence.latestEventType == GoalActionEventType.skipped) {
        continue;
      }
      final item = GoalTodayActionItem(occurrence);
      (candidatesByGoal[item.goalId] ??= []).add(
        _RankedGoalTodayItem(
          item: item,
          rank: _actionRank(occurrence.action),
          sequence: sequence++,
        ),
      );
    }

    for (final resource in resources) {
      if (!activeGoalIds.contains(resource.goalId)) continue;
      if (resource.stableKey.trim().isEmpty ||
          resource.dedupeKey.trim().isEmpty ||
          resource.label.trim().isEmpty) {
        continue;
      }
      final item = GoalTodayResourceItem(resource);
      (candidatesByGoal[item.goalId] ??= []).add(
        _RankedGoalTodayItem(
          item: item,
          rank: _resourceRank(resource),
          sequence: sequence++,
        ),
      );
    }

    final sections = <GoalTodaySection>[];
    for (final goal in orderedGoals) {
      final candidates = candidatesByGoal[goal.id];
      if (candidates == null || candidates.isEmpty) continue;
      candidates.sort((left, right) {
        final byRank = left.rank.compareTo(right.rank);
        if (byRank != 0) return byRank;
        final bySequence = left.sequence.compareTo(right.sequence);
        if (bySequence != 0) return bySequence;
        return left.item.stableKey.compareTo(right.item.stableKey);
      });

      final seen = <String>{};
      final items = <GoalTodayItem>[];
      for (final candidate in candidates) {
        if (!seen.add(candidate.item.dedupeKey)) continue;
        items.add(candidate.item);
        if (items.length == maximumItemsPerGoal) break;
      }
      if (items.isEmpty) continue;
      sections.add(
        GoalTodaySection(goal: goal, items: List.unmodifiable(items)),
      );
    }
    return List.unmodifiable(sections);
  }
}

int _actionRank(GoalAction action) {
  final timeSensitive = _hasExplicitTime(action);
  if (timeSensitive &&
      (action.kind == GoalActionKind.guard ||
          action.kind == GoalActionKind.accountability)) {
    return 0;
  }
  return switch (action.kind) {
    GoalActionKind.guard => 3,
    GoalActionKind.accountability => 3,
    GoalActionKind.nextStep => 4,
    GoalActionKind.care => 5,
    GoalActionKind.other => 6,
  };
}

int _resourceRank(GoalTodayResourceCandidate resource) => switch (resource.kind) {
  GoalTodayResourceKind.accountability when resource.dueAt != null => 0,
  GoalTodayResourceKind.reminder => 1,
  GoalTodayResourceKind.prayer || GoalTodayResourceKind.scripture => 2,
  GoalTodayResourceKind.accountability => 3,
};

bool _hasExplicitTime(GoalAction action) =>
    action.localTime != null ||
    (action.scheduleType == GoalScheduleType.once && action.onceAt != null);

class _RankedGoalTodayItem {
  const _RankedGoalTodayItem({
    required this.item,
    required this.rank,
    required this.sequence,
  });

  final GoalTodayItem item;
  final int rank;
  final int sequence;
}
