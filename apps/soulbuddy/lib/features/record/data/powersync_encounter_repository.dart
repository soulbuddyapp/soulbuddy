import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../domain/encounter.dart';
import '../domain/encounter_draft.dart';
import 'encounter_repository.dart';

class PowerSyncEncounterRepository implements EncounterRepository {
  PowerSyncEncounterRepository({
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

  @override
  Stream<List<Encounter>> watchAll() {
    return database
        .watch(
          '''
          SELECT id, owner_id, title, body, occurred_on, is_altar,
                 created_at, updated_at, current_revision_id,
                 memory_type, sensitive, recall_enabled, recall_paused,
                 recall_interval_days
          FROM encounters
          WHERE owner_id = ? AND archived_at IS NULL
          ORDER BY occurred_on DESC, created_at DESC
          ''',
          parameters: [ownerId],
        )
        .map(
          (rows) => rows
              .map<Map<String, dynamic>>((row) => row)
              .map(_encounterFromRow)
              .toList(growable: false),
        );
  }

  @override
  Future<Encounter> create(EncounterDraft draft) async {
    final encounterId = _uuid.v7();
    final revisionId = _uuid.v7();
    final timestamp = _now().toUtc().toIso8601String();

    await database.writeTransaction((transaction) async {
      await transaction.execute(
        '''
        INSERT INTO encounters(
          id, owner_id, title, body, occurred_on, is_altar,
          created_at, updated_at, archived_at, current_revision_id,
          memory_type, sensitive, recall_enabled, recall_paused,
          recall_interval_days
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, ?)
        ''',
        [
          encounterId,
          ownerId,
          draft.title.trim(),
          draft.body.trim(),
          draft.occurredOn,
          draft.isAltar ? 1 : 0,
          timestamp,
          timestamp,
          revisionId,
          draft.memoryType.wireValue,
          draft.sensitive ? 1 : 0,
          draft.recallEnabled ? 1 : 0,
          draft.recallPaused ? 1 : 0,
          draft.recallIntervalDays,
        ],
      );
      await transaction.execute(
        '''
        INSERT INTO encounter_revisions(
          id, encounter_id, owner_id, title, body, created_at, device_id
          , memory_type, sensitive, recall_enabled, recall_paused,
          recall_interval_days
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          revisionId,
          encounterId,
          ownerId,
          draft.title.trim(),
          draft.body.trim(),
          timestamp,
          deviceId,
          draft.memoryType.wireValue,
          draft.sensitive ? 1 : 0,
          draft.recallEnabled ? 1 : 0,
          draft.recallPaused ? 1 : 0,
          draft.recallIntervalDays,
        ],
      );
    });

    return Encounter(
      id: encounterId,
      ownerId: ownerId,
      title: draft.title.trim(),
      body: draft.body.trim(),
      occurredOn: draft.occurredOn,
      isAltar: draft.isAltar,
      createdAt: DateTime.parse(timestamp),
      updatedAt: DateTime.parse(timestamp),
      currentRevisionId: revisionId,
      syncState: EncounterSyncState.pending,
      memoryType: draft.memoryType,
      sensitive: draft.sensitive,
      recallEnabled: draft.recallEnabled,
      recallPaused: draft.recallPaused,
      recallIntervalDays: draft.recallIntervalDays,
    );
  }

  @override
  Future<void> markAsAltar(String encounterId, {required bool value}) async {
    await database.execute(
      '''
      UPDATE encounters
      SET is_altar = ?, updated_at = ?
      WHERE id = ? AND owner_id = ? AND archived_at IS NULL
      ''',
      [value ? 1 : 0, _now().toUtc().toIso8601String(), encounterId, ownerId],
    );
  }

  @override
  Future<void> archive(String encounterId) async {
    final timestamp = _now().toUtc().toIso8601String();
    await database.execute(
      '''
      UPDATE encounters
      SET archived_at = ?, updated_at = ?
      WHERE id = ? AND owner_id = ? AND archived_at IS NULL
      ''',
      [timestamp, timestamp, encounterId, ownerId],
    );
  }

  @override
  Stream<List<MemoryReflection>> watchReflections(String encounterId) {
    return database
        .watch(
          '''
          SELECT id, encounter_id, owner_id, body, local_date, created_at,
                 device_id
          FROM memory_reflections
          WHERE encounter_id = ? AND owner_id = ?
          ORDER BY local_date DESC, created_at DESC
          ''',
          parameters: [encounterId, ownerId],
        )
        .map(
          (rows) => rows
              .map(
                (row) => MemoryReflection(
                  id: row['id'] as String,
                  encounterId: row['encounter_id'] as String,
                  ownerId: row['owner_id'] as String,
                  body: row['body'] as String,
                  localDate: row['local_date'] as String,
                  createdAt: DateTime.parse(row['created_at'] as String),
                  deviceId: row['device_id'] as String,
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<MemoryReflection> addReflection(
    String encounterId, {
    required String body,
    required String localDate,
  }) async {
    final value = body.trim();
    if (value.isEmpty) throw ArgumentError.value(body, 'body');
    final owned = await database.getOptional(
      'SELECT id FROM encounters WHERE id = ? AND owner_id = ? '
      'AND archived_at IS NULL',
      [encounterId, ownerId],
    );
    if (owned == null) throw StateError('Memory is not available');
    final reflection = MemoryReflection(
      id: _uuid.v7(),
      encounterId: encounterId,
      ownerId: ownerId,
      body: value,
      localDate: localDate,
      createdAt: _now().toUtc(),
      deviceId: deviceId,
    );
    await database.execute(
      '''
      INSERT INTO memory_reflections(
        id, encounter_id, owner_id, body, local_date, created_at, device_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        reflection.id,
        reflection.encounterId,
        reflection.ownerId,
        reflection.body,
        reflection.localDate,
        reflection.createdAt.toIso8601String(),
        reflection.deviceId,
      ],
    );
    return reflection;
  }

  Encounter _encounterFromRow(Map<String, dynamic> row) {
    return Encounter(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      title: row['title'] as String,
      body: row['body'] as String,
      occurredOn: row['occurred_on'] as String,
      isAltar: row['is_altar'] == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      currentRevisionId: row['current_revision_id'] as String,
      syncState: EncounterSyncState.pending,
      memoryType: MemoryType.fromWire(row['memory_type'] as String?),
      sensitive: (row['sensitive'] as int?) == 1,
      recallEnabled: (row['recall_enabled'] as int?) != 0,
      recallPaused: (row['recall_paused'] as int?) == 1,
      recallIntervalDays: (row['recall_interval_days'] as int?) ?? 7,
    );
  }
}
