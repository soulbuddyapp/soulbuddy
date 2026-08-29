import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../domain/guard_definition.dart';
import 'guard_selection_repository.dart';

class PowerSyncGuardSelectionRepository implements GuardSelectionRepository {
  PowerSyncGuardSelectionRepository({
    required this.database,
    required this.ownerId,
    DateTime Function()? now,
    Uuid? uuid,
  }) : _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final PowerSyncDatabase database;
  final String ownerId;
  final DateTime Function() _now;
  final Uuid _uuid;

  @override
  Stream<List<GoalGuardSelection>> watchForGoal(String goalId) {
    final normalizedGoalId = _requiredText(goalId, 'goalId', 120);
    return database
        .watch(
          '''
          SELECT *
          FROM goal_guard_selections
          WHERE goal_id = ?
            AND owner_id = ?
            AND archived_at IS NULL
          ORDER BY configured_at ASC, id ASC
          ''',
          parameters: [normalizedGoalId, ownerId],
        )
        .map((rows) => List.unmodifiable(rows.map(GoalGuardSelection.fromRow)));
  }

  @override
  Future<GoalGuardSelection> select({
    required String goalId,
    required GuardDefinition definition,
    String? privateNote,
  }) async {
    final normalizedGoalId = _requiredText(goalId, 'goalId', 120);
    final normalizedDefinitionId = _requiredText(
      definition.id,
      'guardDefinitionId',
      120,
    );
    if (definition.contentVersion <= 0 || definition.archived) {
      throw ArgumentError.value(
        definition,
        'definition',
        'must be an active versioned guard definition',
      );
    }
    final note = _optionalText(privateNote, 'privateNote', 1000);
    final selectionId = _uuid.v5(
      Namespace.url.value,
      'soulbuddy:$ownerId:$normalizedGoalId:$normalizedDefinitionId',
    );
    final configuredAt = _now().toUtc();

    await database.writeTransaction((transaction) async {
      final goal = await transaction.getOptional(
        '''
        SELECT id FROM goals
        WHERE id = ? AND owner_id = ? AND archived_at IS NULL
        LIMIT 1
        ''',
        [normalizedGoalId, ownerId],
      );
      if (goal == null) throw StateError('Goal is not available');

      final existing = await transaction.getOptional(
        '''
        SELECT id FROM goal_guard_selections
        WHERE id = ? AND owner_id = ?
        LIMIT 1
        ''',
        [selectionId, ownerId],
      );
      if (existing == null) {
        await transaction.execute(
          '''
          INSERT INTO goal_guard_selections(
            id, goal_id, owner_id, guard_definition_id,
            guard_content_version, private_note, configured_at, archived_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, NULL)
          ''',
          [
            selectionId,
            normalizedGoalId,
            ownerId,
            normalizedDefinitionId,
            definition.contentVersion,
            note,
            configuredAt.toIso8601String(),
          ],
        );
      } else {
        await transaction.execute(
          '''
          UPDATE goal_guard_selections
          SET guard_content_version = ?, private_note = ?,
              configured_at = ?, archived_at = NULL
          WHERE id = ? AND owner_id = ? AND goal_id = ?
          ''',
          [
            definition.contentVersion,
            note,
            configuredAt.toIso8601String(),
            selectionId,
            ownerId,
            normalizedGoalId,
          ],
        );
      }
    });

    return (await watchForGoal(
      normalizedGoalId,
    ).first).singleWhere((selection) => selection.id == selectionId);
  }

  @override
  Future<void> archive(String selectionId) async {
    final normalizedId = _requiredText(selectionId, 'selectionId', 120);
    final existing = await database.getOptional(
      '''
      SELECT id FROM goal_guard_selections
      WHERE id = ? AND owner_id = ? AND archived_at IS NULL
      LIMIT 1
      ''',
      [normalizedId, ownerId],
    );
    if (existing == null) throw StateError('Guard selection is not available');
    await database.execute(
      '''
      UPDATE goal_guard_selections
      SET archived_at = ?
      WHERE id = ? AND owner_id = ? AND archived_at IS NULL
      ''',
      [_now().toUtc().toIso8601String(), normalizedId, ownerId],
    );
  }
}

String _requiredText(String value, String name, int maximum) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.runes.length > maximum) {
    throw ArgumentError.value(
      value,
      name,
      'must contain 1-$maximum characters',
    );
  }
  return normalized;
}

String? _optionalText(String? value, String name, int maximum) {
  if (value == null) return null;
  final normalized = value.trim();
  if (normalized.isEmpty) return null;
  if (normalized.runes.length > maximum) {
    throw ArgumentError.value(
      value,
      name,
      'must not exceed $maximum characters',
    );
  }
  return normalized;
}
