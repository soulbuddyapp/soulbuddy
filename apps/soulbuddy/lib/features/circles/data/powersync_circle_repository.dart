import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../domain/circle.dart';
import '../domain/circle_message.dart';
import 'circle_repository.dart';

export '../domain/circle_message.dart' show CircleMessageDelivery;

class PowerSyncCircleRepository implements CircleRepository {
  PowerSyncCircleRepository({
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
  Stream<List<Circle>> watchCircles() => database
      .watch(
        '''
        SELECT c.id, c.name, c.created_at, c.updated_at,
               COUNT(m.id) AS member_count
        FROM circles c
        LEFT JOIN circle_members m ON m.circle_id = c.id
        WHERE c.owner_id = ? AND c.archived_at IS NULL
        GROUP BY c.id, c.name, c.created_at, c.updated_at
        ORDER BY c.updated_at DESC, c.name COLLATE NOCASE
        ''',
        parameters: [ownerId],
      )
      .map((rows) => rows.map(_circleFromRow).toList(growable: false));

  @override
  Stream<Circle?> watchCircle(String circleId) => database
      .watch(
        '''
        SELECT c.id, c.name, c.created_at, c.updated_at,
               COUNT(m.id) AS member_count
        FROM circles c
        LEFT JOIN circle_members m ON m.circle_id = c.id
        WHERE c.id = ? AND c.owner_id = ? AND c.archived_at IS NULL
        GROUP BY c.id, c.name, c.created_at, c.updated_at
        ''',
        parameters: [circleId, ownerId],
      )
      .map((rows) => rows.isEmpty ? null : _circleFromRow(rows.single));

  @override
  Stream<List<CircleMessage>> watchMessages(String circleId) => database
      .watch(
        '''
        SELECT msg.id, msg.circle_id, msg.owner_id, msg.body,
               msg.created_at, msg.delivery
        FROM circle_messages msg
        INNER JOIN circles c ON c.id = msg.circle_id
        WHERE msg.circle_id = ? AND c.owner_id = ? AND c.archived_at IS NULL
        ORDER BY msg.created_at ASC, msg.id ASC
        ''',
        parameters: [circleId, ownerId],
      )
      .map(
        (rows) => rows
            .map(
              (row) => CircleMessage(
                id: row['id'] as String,
                circleId: row['circle_id'] as String,
                body: row['body'] as String,
                createdAt: DateTime.parse(row['created_at'] as String),
                isMine: row['owner_id'] == ownerId,
                delivery: CircleMessageDelivery.onThisDevice,
              ),
            )
            .toList(growable: false),
      );

  @override
  Future<String> createCircle(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty || normalized.length > 80) {
      throw ArgumentError.value(name, 'name', 'Use 1 to 80 characters');
    }
    final id = _uuid.v7();
    final memberId = _uuid.v7();
    final timestamp = _now().toUtc().toIso8601String();
    await database.writeTransaction((transaction) async {
      await transaction.execute(
        '''
        INSERT INTO circles(
          id, owner_id, name, created_at, updated_at, archived_at
        ) VALUES (?, ?, ?, ?, ?, NULL)
        ''',
        [id, ownerId, normalized, timestamp, timestamp],
      );
      await transaction.execute(
        '''
        INSERT INTO circle_members(
          id, circle_id, owner_id, display_name, role, joined_at
        ) VALUES (?, ?, ?, ?, ?, ?)
        ''',
        [memberId, id, ownerId, 'You', 'owner', timestamp],
      );
    });
    return id;
  }

  @override
  Future<void> sendMessage(String circleId, String body) async {
    final normalized = body.trim();
    if (normalized.isEmpty || normalized.length > 2000) {
      throw ArgumentError.value(body, 'body', 'Use 1 to 2000 characters');
    }
    final owned = await database.getOptional(
      'SELECT id FROM circles WHERE id = ? AND owner_id = ? '
      'AND archived_at IS NULL',
      [circleId, ownerId],
    );
    if (owned == null) throw StateError('Circle is not available');
    final timestamp = _now().toUtc().toIso8601String();
    await database.writeTransaction((transaction) async {
      await transaction.execute(
        '''
        INSERT INTO circle_messages(
          id, circle_id, owner_id, body, created_at, device_id, delivery
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          _uuid.v7(),
          circleId,
          ownerId,
          normalized,
          timestamp,
          deviceId,
          'on_this_device',
        ],
      );
      await transaction.execute(
        'UPDATE circles SET updated_at = ? WHERE id = ? AND owner_id = ?',
        [timestamp, circleId, ownerId],
      );
    });
  }

  Circle _circleFromRow(Map<String, dynamic> row) => Circle(
    id: row['id'] as String,
    name: row['name'] as String,
    memberCount: (row['member_count'] as num).toInt(),
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
}
