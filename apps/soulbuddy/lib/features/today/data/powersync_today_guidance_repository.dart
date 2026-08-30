import 'package:powersync/powersync.dart';

import '../domain/today_guidance.dart';
import 'today_guidance_repository.dart';

class PowerSyncTodayGuidanceRepository implements TodayGuidanceRepository {
  PowerSyncTodayGuidanceRepository({
    required this.database,
    required this.ownerId,
  });

  final PowerSyncDatabase database;
  final String ownerId;

  @override
  Stream<TodayGuidanceSnapshot> watch(DateTime displayedLocalDate) => database
      .watch('''
        SELECT
          EXISTS(SELECT 1 FROM goals WHERE owner_id = ?) AS used_goals,
          (EXISTS(SELECT 1 FROM personal_prayers WHERE owner_id = ?)
            OR EXISTS(SELECT 1 FROM today_prayers WHERE owner_id = ?)
            OR EXISTS(SELECT 1 FROM prayer_sessions WHERE owner_id = ?)) AS used_prayer,
          EXISTS(SELECT 1 FROM encounters WHERE owner_id = ?) AS used_memory,
          EXISTS(SELECT 1 FROM prayer_people WHERE owner_id = ?) AS used_persons,
          EXISTS(SELECT 1 FROM altar_items WHERE owner_id = ?) AS used_altar,
          EXISTS(SELECT 1 FROM circle_members WHERE owner_id = ?) AS joined_circle,
          EXISTS(SELECT 1 FROM goal_actions WHERE owner_id = ?) AS observed_goal_actions,
          EXISTS(SELECT 1 FROM goal_action_events WHERE owner_id = ?) AS observed_goal_action_events
        ''', parameters: List.filled(10, ownerId))
      .asyncMap((rows) async {
        final row = rows.single;
        int? missed;
        try {
          missed = await _missedGoalActions(displayedLocalDate);
        } catch (_) {
          missed = null;
        }
        return TodayGuidanceSnapshot(
          missedScheduledRoutineCount: missed,
          joinedCircle: row['joined_circle'] == 1 ? true : null,
          usedGoals: row['used_goals'] == 1,
          usedPrayer: row['used_prayer'] == 1,
          usedMemory: row['used_memory'] == 1,
          usedPersons: row['used_persons'] == 1,
          usedAltar: row['used_altar'] == 1,
        );
      });

  Future<int> _missedGoalActions(DateTime displayedLocalDate) async {
    final today = DateTime(
      displayedLocalDate.year,
      displayedLocalDate.month,
      displayedLocalDate.day,
    );
    final firstDate = today.subtract(const Duration(days: 7));
    final lastDate = today.subtract(const Duration(days: 1));
    final actions = await database.getAll(
      '''
      SELECT action.id, action.schedule_type, action.weekdays_mask,
             action.created_at, action.archived_at
      FROM goal_actions AS action
      JOIN goals AS goal
        ON goal.id = action.goal_id AND goal.owner_id = action.owner_id
      WHERE action.owner_id = ? AND action.enabled = 1
        AND goal.status = 'active' AND goal.archived_at IS NULL
        AND action.schedule_type IN ('daily', 'selected_days')
        AND date(action.created_at) <= ?
        AND (action.archived_at IS NULL OR date(action.archived_at) >= ?)
      ''',
      [ownerId, _dateKey(lastDate), _dateKey(firstDate)],
    );
    if (actions.isEmpty) return 0;
    final events = await database.getAll(
      '''
      SELECT goal_action_id, occurrence_key, event_type, occurred_at, id
      FROM goal_action_events
      WHERE owner_id = ? AND local_date BETWEEN ? AND ?
      ORDER BY occurred_at ASC, id ASC
      ''',
      [ownerId, _dateKey(firstDate), _dateKey(lastDate)],
    );
    final latest = <String, String>{};
    for (final event in events) {
      latest[event['occurrence_key'] as String] = event['event_type'] as String;
    }

    var missed = 0;
    for (var offset = 7; offset >= 1; offset--) {
      final date = today.subtract(Duration(days: offset));
      final dateKey = _dateKey(date);
      for (final action in actions) {
        final created = DateTime.parse(
          action['created_at'] as String,
        ).toLocal();
        final archived = switch (action['archived_at']) {
          final String value => DateTime.parse(value).toLocal(),
          _ => null,
        };
        if (_day(created).isAfter(date) ||
            (archived != null && !_day(archived).isAfter(date))) {
          continue;
        }
        final mask = (action['weekdays_mask'] as num?)?.toInt() ?? 0;
        final scheduled =
            action['schedule_type'] == 'daily' ||
            (mask & (1 << (date.weekday - 1))) != 0;
        if (!scheduled) continue;
        final key = '${action['id']}:$dateKey';
        if (latest[key] != 'completed') missed++;
      }
    }
    return missed;
  }
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
