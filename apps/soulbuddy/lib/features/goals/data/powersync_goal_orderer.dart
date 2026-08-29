import 'package:powersync/powersync.dart';

import 'goal_orderer.dart';

class PowerSyncGoalOrderer implements GoalOrderer {
  PowerSyncGoalOrderer({
    required this.database,
    required this.ownerId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final PowerSyncDatabase database;
  final String ownerId;
  final DateTime Function() _now;

  @override
  Future<void> reorderActive(List<String> orderedGoalIds) async {
    final requestedIds = orderedGoalIds
        .map(_requiredGoalId)
        .toList(growable: false);
    if (requestedIds.toSet().length != requestedIds.length) {
      throw ArgumentError.value(
        orderedGoalIds,
        'orderedGoalIds',
        'must not contain duplicate Goal ids',
      );
    }

    final timestamp = _now().toUtc().toIso8601String();
    await database.writeTransaction((transaction) async {
      final rows = await transaction.getAll(
        '''
        SELECT id, status, position, updated_at
        FROM goals
        WHERE owner_id = ? AND archived_at IS NULL
        ORDER BY position ASC, updated_at DESC, id ASC
        ''',
        [ownerId],
      );
      final activeRows = rows
          .where((row) => row['status'] == 'active')
          .toList(growable: false);
      final currentIds = activeRows
          .map((row) => row['id'] as String)
          .toList(growable: false);
      final requestedSet = requestedIds.toSet();
      if (currentIds.length != requestedIds.length ||
          currentIds.any((id) => !requestedSet.contains(id))) {
        throw StateError('Active Goals changed while their order was updated.');
      }

      final reservedPositions = rows
          .where((row) => row['status'] != 'active')
          .map((row) => (row['position'] as num).toInt())
          .toSet();
      final targetSlots = <int>[];
      for (final row in activeRows) {
        final position = (row['position'] as num).toInt();
        if (!reservedPositions.contains(position) &&
            !targetSlots.contains(position)) {
          targetSlots.add(position);
        }
      }

      var nextPosition =
          rows.fold<int>(
            -1,
            (maximum, row) => ((row['position'] as num).toInt() > maximum)
                ? (row['position'] as num).toInt()
                : maximum,
          ) +
          1;
      while (targetSlots.length < activeRows.length) {
        while (reservedPositions.contains(nextPosition) ||
            targetSlots.contains(nextPosition)) {
          nextPosition++;
        }
        targetSlots.add(nextPosition++);
      }
      targetSlots.sort();

      final currentPositions = <String, int>{
        for (final row in activeRows)
          row['id'] as String: (row['position'] as num).toInt(),
      };
      for (var index = 0; index < requestedIds.length; index++) {
        final id = requestedIds[index];
        final targetPosition = targetSlots[index];
        if (currentPositions[id] == targetPosition) continue;
        await transaction.execute(
          '''
          UPDATE goals
          SET position = ?, updated_at = ?
          WHERE id = ?
            AND owner_id = ?
            AND status = 'active'
            AND archived_at IS NULL
          ''',
          [targetPosition, timestamp, id, ownerId],
        );
      }
    });
  }
}

String _requiredGoalId(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.runes.length > 120) {
    throw ArgumentError.value(value, 'goalId', 'must contain 1-120 characters');
  }
  return normalized;
}
