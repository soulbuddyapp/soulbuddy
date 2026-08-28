import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../../prayers/domain/prayer_reference.dart';
import '../domain/goal.dart';
import '../domain/goal_link.dart';

abstract interface class GoalPrayerMigration {
  Stream<bool> watchLinked(PrayerReference prayer);

  Future<String> keepPrayerUnderGoal({
    required String title,
    required PrayerReference prayer,
  });
}

class PowerSyncGoalPrayerMigration implements GoalPrayerMigration {
  PowerSyncGoalPrayerMigration({
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
  Stream<bool> watchLinked(PrayerReference prayer) {
    final target = _targetFor(prayer);
    return database
        .watch(
          '''
          SELECT 1
          FROM goal_links AS link
          JOIN goals AS goal
            ON goal.id = link.goal_id
           AND goal.owner_id = link.owner_id
          WHERE link.owner_id = ?
            AND link.link_type = ?
            AND link.${target.column} = ?
            AND link.archived_at IS NULL
            AND goal.archived_at IS NULL
          LIMIT 1
          ''',
          parameters: [ownerId, target.linkType.wireValue, prayer.id],
        )
        .map((rows) => rows.isNotEmpty);
  }

  @override
  Future<String> keepPrayerUnderGoal({
    required String title,
    required PrayerReference prayer,
  }) async {
    final normalizedOwnerId = _requiredText(ownerId, 'ownerId', 120);
    final normalizedDeviceId = _requiredText(deviceId, 'deviceId', 120);
    final normalizedTitle = _requiredText(title, 'title', 120);
    final target = _targetFor(prayer);
    final timestamp = _now().toUtc().toIso8601String();
    final candidateGoalId = _uuid.v7();
    final revisionId = _uuid.v7();
    final linkId = _uuid.v7();
    String? existingGoalId;

    await database.writeTransaction((transaction) async {
      final existing = await transaction.getOptional(
        '''
        SELECT goal.id AS goal_id
        FROM goal_links AS link
        JOIN goals AS goal
          ON goal.id = link.goal_id
         AND goal.owner_id = link.owner_id
        WHERE link.owner_id = ?
          AND link.link_type = ?
          AND link.${target.column} = ?
          AND link.archived_at IS NULL
          AND goal.archived_at IS NULL
        LIMIT 1
        ''',
        [normalizedOwnerId, target.linkType.wireValue, prayer.id],
      );
      if (existing != null) {
        existingGoalId = existing['goal_id'] as String;
        return;
      }

      await _requirePrayerTarget(
        transaction,
        prayer,
        normalizedOwnerId,
      );

      final maximumRow = await transaction.getOptional(
        'SELECT MAX(position) AS maximum FROM goals '
        'WHERE owner_id = ? AND archived_at IS NULL',
        [normalizedOwnerId],
      );
      final position = ((maximumRow?['maximum'] as num?)?.toInt() ?? -1) + 1;

      await transaction.execute(
        '''
        INSERT INTO goals(
          id, owner_id, starter_key, mode, status, current_revision_id,
          position, created_at, updated_at, archived_at
        ) VALUES (?, ?, NULL, ?, ?, ?, ?, ?, ?, NULL)
        ''',
        [
          candidateGoalId,
          normalizedOwnerId,
          GoalMode.mixed.wireValue,
          GoalStatus.active.wireValue,
          revisionId,
          position,
          timestamp,
          timestamp,
        ],
      );
      await transaction.execute(
        '''
        INSERT INTO goal_revisions(
          id, goal_id, owner_id, title, current_situation, why_it_matters,
          created_at, device_id
        ) VALUES (?, ?, ?, ?, NULL, NULL, ?, ?)
        ''',
        [
          revisionId,
          candidateGoalId,
          normalizedOwnerId,
          normalizedTitle,
          timestamp,
          normalizedDeviceId,
        ],
      );
      await transaction.execute(
        '''
        INSERT INTO goal_links(
          id, goal_id, owner_id, link_type, personal_prayer_id,
          library_prayer_id, encounter_id, voice_tablet_id, circle_id,
          translation, book, chapter, first_verse, last_verse, role,
          created_at, archived_at
        ) VALUES (?, ?, ?, ?, ?, ?, NULL, NULL, NULL,
                  NULL, NULL, NULL, NULL, NULL, ?, ?, NULL)
        ''',
        [
          linkId,
          candidateGoalId,
          normalizedOwnerId,
          target.linkType.wireValue,
          prayer.source == PrayerSource.personal ? prayer.id : null,
          prayer.source == PrayerSource.library ? prayer.id : null,
          GoalLinkRole.primaryPrayer.wireValue,
          timestamp,
        ],
      );
    });

    return existingGoalId ?? candidateGoalId;
  }
}

Future<void> _requirePrayerTarget(
  SqliteWriteTransaction transaction,
  PrayerReference prayer,
  String ownerId,
) async {
  switch (prayer.source) {
    case PrayerSource.personal:
      final row = await transaction.getOptional(
        '''
        SELECT id FROM personal_prayers
        WHERE id = ? AND owner_id = ? AND archived_at IS NULL
        LIMIT 1
        ''',
        [prayer.id, ownerId],
      );
      if (row == null) throw StateError('Prayer is not available.');
    case PrayerSource.library:
      final remote = await transaction.getOptional(
        '''
        SELECT id FROM library_prayers
        WHERE id = ? AND archived_at IS NULL
        LIMIT 1
        ''',
        [prayer.id],
      );
      final bundled =
          remote ??
          await transaction.getOptional(
            '''
            SELECT id FROM bundled_prayers
            WHERE id = ? AND archived_at IS NULL
            LIMIT 1
            ''',
            [prayer.id],
          );
      if (bundled == null) throw StateError('Prayer is not available.');
  }
}

_PrayerGoalTarget _targetFor(PrayerReference prayer) => switch (prayer.source) {
  PrayerSource.personal => const _PrayerGoalTarget(
    linkType: GoalLinkType.personalPrayer,
    column: 'personal_prayer_id',
  ),
  PrayerSource.library => const _PrayerGoalTarget(
    linkType: GoalLinkType.libraryPrayer,
    column: 'library_prayer_id',
  ),
};

class _PrayerGoalTarget {
  const _PrayerGoalTarget({required this.linkType, required this.column});

  final GoalLinkType linkType;
  final String column;
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
