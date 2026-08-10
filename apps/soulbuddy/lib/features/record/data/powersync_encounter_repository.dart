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
                 created_at, updated_at, current_revision_id
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
          created_at, updated_at, archived_at, current_revision_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, ?)
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
        ],
      );
      await transaction.execute(
        '''
        INSERT INTO encounter_revisions(
          id, encounter_id, owner_id, title, body, created_at, device_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          revisionId,
          encounterId,
          ownerId,
          draft.title.trim(),
          draft.body.trim(),
          timestamp,
          deviceId,
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
    );
  }
}
