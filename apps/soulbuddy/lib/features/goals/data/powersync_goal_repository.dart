import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../domain/goal.dart';
import '../domain/goal_action.dart';
import '../domain/goal_link.dart';
import 'goal_repository.dart';

class PowerSyncGoalRepository implements GoalRepository {
  PowerSyncGoalRepository({
    required this.database,
    required this.ownerId,
    required this.deviceId,
    DateTime Function()? now,
    Uuid? uuid,
  }) : _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final PowerSyncDatabase database;
  final String ownerId;
  final String deviceId;
  final DateTime Function() _now;
  final Uuid _uuid;

  static const _goalProjection = '''
    SELECT goal.*, revision.title, revision.current_situation,
           revision.why_it_matters
    FROM goals AS goal
    JOIN goal_revisions AS revision
      ON revision.id = goal.current_revision_id
     AND revision.goal_id = goal.id
     AND revision.owner_id = goal.owner_id
  ''';

  @override
  Stream<List<Goal>> watchActive() => database
      .watch(
        '''
        $_goalProjection
        WHERE goal.owner_id = ?
          AND goal.status = 'active'
          AND goal.archived_at IS NULL
        ORDER BY goal.position ASC, goal.updated_at DESC, goal.id ASC
        ''',
        parameters: [ownerId],
      )
      .map((rows) => List.unmodifiable(rows.map(Goal.fromRow)));

  @override
  Stream<Goal?> watch(String id) => database
      .watch(
        '''
        $_goalProjection
        WHERE goal.id = ? AND goal.owner_id = ?
        LIMIT 1
        ''',
        parameters: [id, ownerId],
      )
      .map((rows) => rows.isEmpty ? null : Goal.fromRow(rows.single));

  @override
  Stream<List<GoalRevision>> watchRevisions(String goalId) => database
      .watch(
        '''
        SELECT * FROM goal_revisions
        WHERE goal_id = ? AND owner_id = ?
        ORDER BY created_at DESC, id DESC
        ''',
        parameters: [goalId, ownerId],
      )
      .map((rows) => List.unmodifiable(rows.map(GoalRevision.fromRow)));

  @override
  Stream<List<GoalActionOccurrence>> watchDueActions(DateTime localDate) {
    final localDateKey = goalLocalDateKey(localDate);
    return database
        .watch(
          '''
          SELECT action.*,
            (
              SELECT event.event_type
              FROM goal_action_events AS event
              WHERE event.goal_action_id = action.id
                AND event.owner_id = action.owner_id
                AND event.occurrence_key = action.id || ':' || ?
              ORDER BY event.occurred_at DESC, event.id DESC
              LIMIT 1
            ) AS latest_event_type
          FROM goal_actions AS action
          JOIN goals AS goal
            ON goal.id = action.goal_id
           AND goal.owner_id = action.owner_id
          WHERE action.owner_id = ?
            AND action.enabled = 1
            AND action.archived_at IS NULL
            AND goal.status = 'active'
            AND goal.archived_at IS NULL
          ORDER BY goal.position ASC, action.created_at ASC, action.id ASC
          ''',
          parameters: [localDateKey, ownerId],
        )
        .map((rows) {
          final result = <GoalActionOccurrence>[];
          for (final row in rows) {
            final action = GoalAction.fromRow(row);
            if (!action.isScheduledOn(localDate)) continue;
            final latest = switch (row['latest_event_type']) {
              final String value => GoalActionEventType.fromWire(value),
              _ => null,
            };
            if (latest == GoalActionEventType.completed ||
                latest == GoalActionEventType.skipped) {
              continue;
            }
            result.add(
              GoalActionOccurrence(
                action: action,
                occurrenceKey: action.occurrenceKeyFor(localDate),
                latestEventType: latest,
              ),
            );
          }
          return List.unmodifiable(result);
        });
  }

  @override
  Future<Goal> create({
    required String title,
    required GoalMode mode,
    GoalStarterKey? starterKey,
    String? currentSituation,
    String? whyItMatters,
    int? position,
  }) async {
    final normalizedTitle = _requiredText(title, 'title', 120);
    final situation = _optionalText(currentSituation, 'currentSituation', 4000);
    final why = _optionalText(whyItMatters, 'whyItMatters', 4000);
    final timestamp = _now().toUtc().toIso8601String();
    final goalId = _uuid.v7();
    final revisionId = _uuid.v7();

    await database.writeTransaction((transaction) async {
      final maximumRow = await transaction.getOptional(
        'SELECT MAX(position) AS maximum FROM goals '
        'WHERE owner_id = ? AND archived_at IS NULL',
        [ownerId],
      );
      final resolvedPosition =
          position ?? ((maximumRow?['maximum'] as num?)?.toInt() ?? -1) + 1;
      if (resolvedPosition < 0) {
        throw ArgumentError.value(position, 'position', 'must be non-negative');
      }
      await transaction.execute(
        '''
        INSERT INTO goals(
          id, owner_id, starter_key, mode, status, current_revision_id,
          position, created_at, updated_at, archived_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
        ''',
        [
          goalId,
          ownerId,
          starterKey?.wireValue,
          mode.wireValue,
          GoalStatus.active.wireValue,
          revisionId,
          resolvedPosition,
          timestamp,
          timestamp,
        ],
      );
      await transaction.execute(
        '''
        INSERT INTO goal_revisions(
          id, goal_id, owner_id, title, current_situation, why_it_matters,
          created_at, device_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          revisionId,
          goalId,
          ownerId,
          normalizedTitle,
          situation,
          why,
          timestamp,
          _requiredText(deviceId, 'deviceId', 120),
        ],
      );
    });

    return (await watch(goalId).first)!;
  }

  @override
  Future<Goal> edit(
    String goalId, {
    required String title,
    String? currentSituation,
    String? whyItMatters,
  }) async {
    final normalizedTitle = _requiredText(title, 'title', 120);
    final situation = _optionalText(currentSituation, 'currentSituation', 4000);
    final why = _optionalText(whyItMatters, 'whyItMatters', 4000);
    final revisionId = _uuid.v7();
    final timestamp = _now().toUtc().toIso8601String();

    await database.writeTransaction((transaction) async {
      final existing = await transaction.getOptional(
        'SELECT id FROM goals WHERE id = ? AND owner_id = ?',
        [goalId, ownerId],
      );
      if (existing == null) throw StateError('Goal is not available');
      await transaction.execute(
        '''
        INSERT INTO goal_revisions(
          id, goal_id, owner_id, title, current_situation, why_it_matters,
          created_at, device_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          revisionId,
          goalId,
          ownerId,
          normalizedTitle,
          situation,
          why,
          timestamp,
          _requiredText(deviceId, 'deviceId', 120),
        ],
      );
      await transaction.execute(
        '''
        UPDATE goals
        SET current_revision_id = ?, updated_at = ?
        WHERE id = ? AND owner_id = ?
        ''',
        [revisionId, timestamp, goalId, ownerId],
      );
    });

    return (await watch(goalId).first)!;
  }

  @override
  Future<void> setStatus(String goalId, GoalStatus status) async {
    await _requireOwnedGoal(goalId);
    final timestamp = _now().toUtc().toIso8601String();
    final archivedAt = status == GoalStatus.archived ? timestamp : null;
    await database.execute(
      '''
      UPDATE goals
      SET status = ?, archived_at = ?, updated_at = ?
      WHERE id = ? AND owner_id = ?
      ''',
      [status.wireValue, archivedAt, timestamp, goalId, ownerId],
    );
  }

  @override
  Future<GoalLink> addLink(String goalId, GoalLinkDraft link) async {
    if (!link.hasValidShape) {
      throw ArgumentError.value(link, 'link', 'invalid target shape');
    }
    if (link.type == GoalLinkType.circle) {
      throw UnsupportedError(
        'Circle links become available with the external Circle foundation.',
      );
    }
    await _requireOwnedGoal(goalId);
    await _requireLinkTarget(link);
    final id = _uuid.v7();
    final timestamp = _now().toUtc().toIso8601String();
    await database.execute(
      '''
      INSERT INTO goal_links(
        id, goal_id, owner_id, link_type, personal_prayer_id,
        library_prayer_id, encounter_id, voice_tablet_id, circle_id,
        translation, book, chapter, first_verse, last_verse, role,
        created_at, archived_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
      ''',
      [
        id,
        goalId,
        ownerId,
        link.type.wireValue,
        link.personalPrayerId,
        link.libraryPrayerId,
        link.encounterId,
        link.voiceTabletId,
        link.circleId,
        link.translation,
        link.book,
        link.chapter,
        link.firstVerse,
        link.lastVerse,
        link.role.wireValue,
        timestamp,
      ],
    );
    return GoalLink(
      id: id,
      goalId: goalId,
      ownerId: ownerId,
      type: link.type,
      role: link.role,
      personalPrayerId: link.personalPrayerId,
      libraryPrayerId: link.libraryPrayerId,
      encounterId: link.encounterId,
      voiceTabletId: link.voiceTabletId,
      circleId: link.circleId,
      translation: link.translation,
      book: link.book,
      chapter: link.chapter,
      firstVerse: link.firstVerse,
      lastVerse: link.lastVerse,
      createdAt: DateTime.parse(timestamp),
    );
  }

  @override
  Future<void> archiveLink(String linkId) async {
    final link = await database.getOptional(
      'SELECT id FROM goal_links '
      'WHERE id = ? AND owner_id = ? AND archived_at IS NULL',
      [linkId, ownerId],
    );
    if (link == null) throw StateError('Goal link is not available');
    await database.execute(
      '''
      UPDATE goal_links
      SET archived_at = ?
      WHERE id = ? AND owner_id = ? AND archived_at IS NULL
      ''',
      [_now().toUtc().toIso8601String(), linkId, ownerId],
    );
  }

  @override
  Future<GoalAction> addAction(String goalId, GoalActionDraft action) async {
    await _requireOwnedGoal(goalId);
    final body = _requiredText(action.body, 'body', 1000);
    final localTime = _validatedLocalTime(action.localTime);
    final timezone = _optionalText(action.timezone, 'timezone', 100);
    final now = _now();
    final onceAt = switch (action.scheduleType) {
      GoalScheduleType.today => action.onceAt ?? now,
      GoalScheduleType.once =>
        action.onceAt ??
            (throw ArgumentError.value(
              action.onceAt,
              'onceAt',
              'is required for a once action',
            )),
      _ => action.onceAt,
    };
    if (action.scheduleType != GoalScheduleType.today &&
        action.scheduleType != GoalScheduleType.once &&
        onceAt != null) {
      throw ArgumentError.value(
        action.onceAt,
        'onceAt',
        'is only valid for today or once actions',
      );
    }
    if (action.scheduleType == GoalScheduleType.selectedDays &&
        (action.weekdaysMask == null ||
            action.weekdaysMask! <= 0 ||
            action.weekdaysMask! > 127)) {
      throw ArgumentError.value(
        action.weekdaysMask,
        'weekdaysMask',
        'must select at least one weekday',
      );
    }
    if (action.scheduleType != GoalScheduleType.selectedDays &&
        action.weekdaysMask != null) {
      throw ArgumentError.value(
        action.weekdaysMask,
        'weekdaysMask',
        'is only valid for selected-days actions',
      );
    }

    final id = _uuid.v7();
    final timestamp = now.toUtc().toIso8601String();
    await database.execute(
      '''
      INSERT INTO goal_actions(
        id, goal_id, owner_id, body, action_kind, schedule_type,
        local_time, timezone, once_at, weekdays_mask, enabled,
        created_at, updated_at, archived_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
      ''',
      [
        id,
        goalId,
        ownerId,
        body,
        action.kind.wireValue,
        action.scheduleType.wireValue,
        localTime,
        timezone,
        onceAt?.toUtc().toIso8601String(),
        action.weekdaysMask,
        action.enabled ? 1 : 0,
        timestamp,
        timestamp,
      ],
    );
    return GoalAction(
      id: id,
      goalId: goalId,
      ownerId: ownerId,
      body: body,
      kind: action.kind,
      scheduleType: action.scheduleType,
      localTime: localTime,
      timezone: timezone,
      onceAt: onceAt?.toUtc(),
      weekdaysMask: action.weekdaysMask,
      enabled: action.enabled,
      createdAt: DateTime.parse(timestamp),
      updatedAt: DateTime.parse(timestamp),
    );
  }

  @override
  Future<void> archiveAction(String actionId) async {
    final action = await database.getOptional(
      'SELECT id FROM goal_actions '
      'WHERE id = ? AND owner_id = ? AND archived_at IS NULL',
      [actionId, ownerId],
    );
    if (action == null) throw StateError('Goal action is not available');
    final timestamp = _now().toUtc().toIso8601String();
    await database.execute(
      '''
      UPDATE goal_actions
      SET archived_at = ?, enabled = 0, updated_at = ?
      WHERE id = ? AND owner_id = ? AND archived_at IS NULL
      ''',
      [timestamp, timestamp, actionId, ownerId],
    );
  }

  @override
  Future<GoalActionEvent?> completeAction(
    String actionId, {
    required DateTime localDate,
    DateTime? occurredAt,
  }) => _recordActionEvent(
    actionId,
    GoalActionEventType.completed,
    localDate: localDate,
    occurredAt: occurredAt,
  );

  @override
  Future<GoalActionEvent?> skipAction(
    String actionId, {
    required DateTime localDate,
    DateTime? occurredAt,
  }) => _recordActionEvent(
    actionId,
    GoalActionEventType.skipped,
    localDate: localDate,
    occurredAt: occurredAt,
  );

  @override
  Future<GoalActionEvent?> retractAction(
    String actionId, {
    required DateTime localDate,
    DateTime? occurredAt,
  }) => _recordActionEvent(
    actionId,
    GoalActionEventType.retracted,
    localDate: localDate,
    occurredAt: occurredAt,
  );

  Future<GoalActionEvent?> _recordActionEvent(
    String actionId,
    GoalActionEventType type, {
    required DateTime localDate,
    DateTime? occurredAt,
  }) async {
    final actionRow = await database.getOptional(
      '''
      SELECT action.*
      FROM goal_actions AS action
      JOIN goals AS goal
        ON goal.id = action.goal_id AND goal.owner_id = action.owner_id
      WHERE action.id = ? AND action.owner_id = ?
        AND action.archived_at IS NULL
      LIMIT 1
      ''',
      [actionId, ownerId],
    );
    if (actionRow == null) throw StateError('Goal action is not available');
    final action = GoalAction.fromRow(actionRow);
    final key = action.occurrenceKeyFor(localDate);
    final latest = await database.getOptional(
      '''
      SELECT * FROM goal_action_events
      WHERE goal_action_id = ? AND owner_id = ? AND occurrence_key = ?
      ORDER BY occurred_at DESC, id DESC
      LIMIT 1
      ''',
      [actionId, ownerId, key],
    );
    final latestType = latest == null
        ? null
        : GoalActionEventType.fromWire(latest['event_type'] as String);
    if (type == GoalActionEventType.retracted) {
      if (latestType == null || latestType == GoalActionEventType.retracted) {
        return null;
      }
    } else if (latestType == type) {
      return null;
    }

    final id = _uuid.v7();
    final at = (occurredAt ?? _now()).toUtc();
    final localDateKey = goalLocalDateKey(localDate);
    await database.execute(
      '''
      INSERT INTO goal_action_events(
        id, goal_action_id, goal_id, owner_id, event_type,
        occurrence_key, occurred_at, local_date, device_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        id,
        actionId,
        action.goalId,
        ownerId,
        type.wireValue,
        key,
        at.toIso8601String(),
        localDateKey,
        _requiredText(deviceId, 'deviceId', 120),
      ],
    );
    return GoalActionEvent(
      id: id,
      goalActionId: actionId,
      goalId: action.goalId,
      ownerId: ownerId,
      type: type,
      occurrenceKey: key,
      occurredAt: at,
      localDate: localDateKey,
      deviceId: deviceId,
    );
  }

  Future<void> _requireOwnedGoal(String goalId) async {
    final owned = await database.getOptional(
      'SELECT id FROM goals WHERE id = ? AND owner_id = ?',
      [goalId, ownerId],
    );
    if (owned == null) throw StateError('Goal is not available');
  }

  Future<void> _requireLinkTarget(GoalLinkDraft link) async {
    switch (link.type) {
      case GoalLinkType.personalPrayer:
        await _requireOwnedTarget('personal_prayers', link.personalPrayerId!);
        return;
      case GoalLinkType.libraryPrayer:
        final remote = await database.getOptional(
          'SELECT id FROM library_prayers WHERE id = ? LIMIT 1',
          [link.libraryPrayerId],
        );
        final bundled =
            remote ??
            await database.getOptional(
              'SELECT id FROM bundled_prayers WHERE id = ? LIMIT 1',
              [link.libraryPrayerId],
            );
        if (bundled == null) throw StateError('Prayer is not available');
        return;
      case GoalLinkType.encounter:
        await _requireOwnedTarget('encounters', link.encounterId!);
        return;
      case GoalLinkType.voiceTablet:
        await _requireOwnedTarget('voice_tablets', link.voiceTabletId!);
        return;
      case GoalLinkType.scripture:
        return;
      case GoalLinkType.circle:
        throw UnsupportedError('Circle links are not available yet.');
    }
  }

  Future<void> _requireOwnedTarget(String table, String id) async {
    final target = await database.getOptional(
      'SELECT id FROM $table WHERE id = ? AND owner_id = ? LIMIT 1',
      [id, ownerId],
    );
    if (target == null) throw StateError('Linked resource is not available');
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

String? _validatedLocalTime(String? value) {
  final normalized = _optionalText(value, 'localTime', 5);
  if (normalized == null) return null;
  if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(normalized)) {
    throw ArgumentError.value(value, 'localTime', 'must be HH:mm');
  }
  return normalized;
}
