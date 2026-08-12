import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../../record/domain/encounter.dart';
import 'daily_memory_repository.dart';
import '../domain/daily_memory.dart';

class PowerSyncDailyMemoryRepository implements DailyMemoryRepository {
  PowerSyncDailyMemoryRepository({
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
  Stream<DailyMemory?> watchForDate(DateTime localDate) => database
      .watch(_occurrenceQuery, parameters: [ownerId, _dateKey(localDate)])
      .map((rows) => rows.isEmpty ? null : _fromRow(rows.single));

  @override
  Future<DailyMemory?> ensureForDate(DateTime localDate) async {
    final date = _dateKey(localDate);
    final existing = await _get(date);
    if (existing != null) return existing;

    final candidates = await _eligibleCandidates(date);
    if (candidates.isEmpty) return null;
    final chosen = _deterministicChoice(candidates, date);
    final timestamp = _now().toUtc().toIso8601String();
    final occurrenceId = _uuid.v5(Namespace.url.value, '$ownerId:$date');
    try {
      await database.execute(
        '''
        INSERT INTO daily_memory_occurrences(
          id, owner_id, local_date, encounter_id, status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          occurrenceId,
          ownerId,
          date,
          chosen['id'],
          DailyMemoryStatus.active.wireValue,
          timestamp,
          timestamp,
        ],
      );
      await _recordShown(chosen['id'] as String, date, timestamp);
    } catch (_) {
      final raced = await _get(date);
      if (raced == null) rethrow;
      return raced;
    }
    return _get(date);
  }

  @override
  Future<DailyMemory?> chooseAnother(
    DateTime localDate, {
    required String expectedEncounterId,
  }) async {
    final date = _dateKey(localDate);
    final current = await _get(date);
    if (current == null || current.memory.id != expectedEncounterId) {
      return current;
    }
    final candidates = await _eligibleCandidates(
      date,
      excludedEncounterId: expectedEncounterId,
    );
    if (candidates.isEmpty) return current;
    final chosen = _deterministicChoice(candidates, '$date:another');
    await database.execute(
      '''
      UPDATE daily_memory_occurrences
      SET encounter_id = ?, status = ?, updated_at = ?
      WHERE owner_id = ? AND local_date = ? AND encounter_id = ?
      ''',
      [
        chosen['id'],
        DailyMemoryStatus.active.wireValue,
        _now().toUtc().toIso8601String(),
        ownerId,
        date,
        expectedEncounterId,
      ],
    );
    await _recordShown(
      chosen['id'] as String,
      date,
      _now().toUtc().toIso8601String(),
    );
    return _get(date);
  }

  @override
  Future<void> setStatus(
    DateTime localDate, {
    required String expectedEncounterId,
    required DailyMemoryStatus status,
  }) => database.execute(
    '''
    UPDATE daily_memory_occurrences
    SET status = ?, updated_at = ?
    WHERE owner_id = ? AND local_date = ? AND encounter_id = ?
    ''',
    [
      status.wireValue,
      _now().toUtc().toIso8601String(),
      ownerId,
      _dateKey(localDate),
      expectedEncounterId,
    ],
  );

  Future<DailyMemory?> _get(String date) async {
    final row = await database.getOptional(_occurrenceQuery, [ownerId, date]);
    return row == null ? null : _fromRow(row);
  }

  Future<List<Map<String, dynamic>>> _eligibleCandidates(
    String date, {
    String? excludedEncounterId,
  }) async {
    final rows = await database.getAll(
      '''
      SELECT e.id, e.memory_type, e.recall_interval_days
      FROM encounters e
      WHERE e.owner_id = ? AND e.archived_at IS NULL
        AND COALESCE(e.recall_enabled, 1) = 1
        AND COALESCE(e.recall_paused, 0) = 0
        ${excludedEncounterId == null ? '' : 'AND e.id != ?'}
      ''',
      [ownerId, if (excludedEncounterId != null) excludedEncounterId],
    );
    final eligible = <Map<String, dynamic>>[];
    for (final row in rows) {
      final last = await database.getOptional(
        '''
        SELECT local_date FROM daily_memory_history
        WHERE owner_id = ? AND encounter_id = ? AND local_date < ?
        ORDER BY local_date DESC LIMIT 1
        ''',
        [ownerId, row['id'], date],
      );
      final interval = (row['recall_interval_days'] as int?) ?? 7;
      if (last == null ||
          DateTime.parse(date)
                  .difference(DateTime.parse(last['local_date'] as String))
                  .inDays >=
              interval) {
        eligible.add(row);
      }
    }
    return eligible;
  }

  Future<void> _recordShown(
    String encounterId,
    String date,
    String timestamp,
  ) async {
    final id = _uuid.v5(Namespace.url.value, '$ownerId:$date:$encounterId');
    final existing = await database.getOptional(
      'SELECT id FROM daily_memory_history WHERE id = ?',
      [id],
    );
    if (existing != null) return;
    await database.execute(
      '''
      INSERT INTO daily_memory_history(
        id, owner_id, encounter_id, local_date, shown_at
      ) VALUES (?, ?, ?, ?, ?)
      ''',
      [id, ownerId, encounterId, date, timestamp],
    );
  }

  Map<String, dynamic> _deterministicChoice(
    List<Map<String, dynamic>> candidates,
    String seed,
  ) {
    final bestPriority = candidates
        .map((row) => _priority(row['memory_type'] as String?))
        .reduce((a, b) => a < b ? a : b);
    final group =
        candidates
            .where(
              (row) => _priority(row['memory_type'] as String?) == bestPriority,
            )
            .toList()
          ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    final hash = seed.codeUnits.fold<int>(
      0,
      (value, unit) => value * 31 + unit,
    );
    return group[hash.abs() % group.length];
  }

  DailyMemory _fromRow(Map<String, dynamic> row) => DailyMemory(
    occurrenceId: row['occurrence_id'] as String,
    localDate: DateTime.parse(row['local_date'] as String),
    status: DailyMemoryStatus.fromWire(row['status'] as String),
    memory: Encounter(
      id: row['encounter_id'] as String,
      ownerId: row['owner_id'] as String,
      title: row['title'] as String,
      body: row['body'] as String,
      occurredOn: row['occurred_on'] as String,
      isAltar: row['is_altar'] == 1,
      createdAt: DateTime.parse(row['memory_created_at'] as String),
      updatedAt: DateTime.parse(row['memory_updated_at'] as String),
      currentRevisionId: row['current_revision_id'] as String,
      syncState: EncounterSyncState.pending,
      memoryType: MemoryType.fromWire(row['memory_type'] as String?),
      sensitive: (row['sensitive'] as int?) == 1,
      recallEnabled: (row['recall_enabled'] as int?) != 0,
      recallPaused: (row['recall_paused'] as int?) == 1,
      recallIntervalDays: (row['recall_interval_days'] as int?) ?? 7,
    ),
  );
}

int _priority(String? type) => switch (MemoryType.fromWire(type)) {
  MemoryType.promise => 0,
  MemoryType.leftBehind => 1,
  MemoryType.revelation || MemoryType.encounter => 2,
  _ => 3,
};

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

const _occurrenceQuery = '''
  SELECT o.id AS occurrence_id, o.local_date, o.status,
         e.id AS encounter_id, e.owner_id, e.title, e.body, e.occurred_on,
         e.is_altar, e.created_at AS memory_created_at,
         e.updated_at AS memory_updated_at, e.current_revision_id,
         e.memory_type, e.sensitive, e.recall_enabled, e.recall_paused,
         e.recall_interval_days
  FROM daily_memory_occurrences o
  JOIN encounters e ON e.id = o.encounter_id
  WHERE o.owner_id = ? AND o.local_date = ?
    AND e.owner_id = o.owner_id AND e.archived_at IS NULL
''';
