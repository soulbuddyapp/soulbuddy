import 'package:powersync/powersync.dart';

import '../domain/legacy_circle.dart';
import 'legacy_circle_migration_repository.dart';

class PowerSyncLegacyCircleMigrationRepository
    implements LegacyCircleMigrationRepository {
  const PowerSyncLegacyCircleMigrationRepository({
    required this.database,
    required this.ownerId,
  });

  final PowerSyncDatabase database;
  final String ownerId;

  @override
  Future<List<LegacyCircleSummary>> list() async {
    final rows = await database.getAll(
      '''
      SELECT circle.id, circle.name, circle.updated_at,
             COUNT(message.id) AS message_count
      FROM circles AS circle
      LEFT JOIN circle_messages AS message
        ON message.circle_id = circle.id
       AND message.owner_id = circle.owner_id
      WHERE circle.owner_id = ? AND circle.archived_at IS NULL
      GROUP BY circle.id, circle.name, circle.updated_at
      ORDER BY circle.updated_at DESC, circle.id DESC
      ''',
      [ownerId],
    );
    return List.unmodifiable(
      rows.map(
        (row) => LegacyCircleSummary(
          id: row['id'] as String,
          name: row['name'] as String,
          messageCount: row['message_count'] as int? ?? 0,
          updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
        ),
      ),
    );
  }

  @override
  Future<LegacyCircleArchive?> read(String circleId) async {
    final circle = await database.getOptional(
      '''
      SELECT id, name, updated_at
      FROM circles
      WHERE id = ? AND owner_id = ? AND archived_at IS NULL
      ''',
      [circleId, ownerId],
    );
    if (circle == null) return null;
    final rows = await database.getAll(
      '''
      SELECT id, body, created_at
      FROM circle_messages
      WHERE circle_id = ? AND owner_id = ?
      ORDER BY created_at ASC, id ASC
      ''',
      [circleId, ownerId],
    );
    final messages = rows
        .map(
          (row) => LegacyCircleMessage(
            id: row['id'] as String,
            body: row['body'] as String,
            createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
          ),
        )
        .toList(growable: false);
    return LegacyCircleArchive(
      summary: LegacyCircleSummary(
        id: circle['id'] as String,
        name: circle['name'] as String,
        messageCount: messages.length,
        updatedAt: DateTime.parse(circle['updated_at'] as String).toUtc(),
      ),
      messages: List.unmodifiable(messages),
    );
  }

  @override
  Future<void> discard(String circleId) async {
    await database.writeTransaction((transaction) async {
      final owned = await transaction.getOptional(
        'SELECT id FROM circles WHERE id = ? AND owner_id = ?',
        [circleId, ownerId],
      );
      if (owned == null) return;
      await transaction.execute(
        'DELETE FROM circle_messages WHERE circle_id = ? AND owner_id = ?',
        [circleId, ownerId],
      );
      await transaction.execute(
        'DELETE FROM circle_members WHERE circle_id = ? AND owner_id = ?',
        [circleId, ownerId],
      );
      await transaction.execute(
        'DELETE FROM circles WHERE id = ? AND owner_id = ?',
        [circleId, ownerId],
      );
    });
  }
}
