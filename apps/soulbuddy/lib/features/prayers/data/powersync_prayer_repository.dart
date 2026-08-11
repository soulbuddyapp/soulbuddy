import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../domain/library_prayer.dart';
import '../domain/today_prayer.dart';
import 'prayer_repository.dart';

class PowerSyncPrayerRepository implements PrayerRepository {
  PowerSyncPrayerRepository({
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

  static const _mergedPrayers = '''
    SELECT id, title, body, grounding, purpose, action, helpful_count
    FROM library_prayers
    WHERE published_at IS NOT NULL AND archived_at IS NULL
    UNION ALL
    SELECT bundled.id, bundled.title, bundled.body, bundled.grounding,
           bundled.purpose, bundled.action, bundled.helpful_count
    FROM bundled_prayers AS bundled
    WHERE bundled.archived_at IS NULL
      AND NOT EXISTS (
        SELECT 1 FROM library_prayers AS canonical
        WHERE canonical.id = bundled.id
      )
  ''';

  @override
  Stream<List<LibraryPrayer>> watchLibrary({
    PrayerGrounding? grounding,
    PrayerPurpose? purpose,
  }) {
    return database
        .watch(
          '''
          WITH merged AS ($_mergedPrayers)
          SELECT merged.*,
                 EXISTS(
                   SELECT 1 FROM prayer_votes AS vote
                   WHERE vote.owner_id = ? AND vote.prayer_id = merged.id
                 ) AS viewer_marked_helpful
          FROM merged
          WHERE (? IS NULL OR merged.grounding = ?)
            AND (? IS NULL OR merged.purpose = ?)
          ORDER BY merged.helpful_count DESC,
                   merged.title COLLATE NOCASE ASC,
                   merged.id ASC
          ''',
          parameters: [
            ownerId,
            grounding?.wireValue,
            grounding?.wireValue,
            purpose?.wireValue,
            purpose?.wireValue,
          ],
        )
        .map(
          (rows) => rows
              .map<Map<String, dynamic>>((row) => row)
              .map(_prayerFromRow)
              .toList(growable: false),
        );
  }

  @override
  Stream<LibraryPrayer?> watchPrayer(String id) {
    return database
        .watch(
          '''
          WITH merged AS ($_mergedPrayers)
          SELECT merged.*,
                 EXISTS(
                   SELECT 1 FROM prayer_votes AS vote
                   WHERE vote.owner_id = ? AND vote.prayer_id = merged.id
                 ) AS viewer_marked_helpful
          FROM merged
          WHERE merged.id = ?
          LIMIT 1
          ''',
          parameters: [ownerId, id],
        )
        .map((rows) => rows.isEmpty ? null : _prayerFromRow(rows.single));
  }

  @override
  Future<void> setHelpful(String prayerId, {required bool value}) async {
    final id = _uuid.v5(Namespace.url.value, '$ownerId:$prayerId');
    if (!value) {
      await database.execute(
        'DELETE FROM prayer_votes WHERE id = ? AND owner_id = ?',
        [id, ownerId],
      );
      return;
    }

    await database.writeTransaction((transaction) async {
      final existing = await transaction.getOptional(
        'SELECT id FROM prayer_votes WHERE id = ? AND owner_id = ?',
        [id, ownerId],
      );
      if (existing != null) {
        return;
      }
      await transaction.execute(
        '''
        INSERT INTO prayer_votes(id, owner_id, prayer_id, created_at)
        VALUES (?, ?, ?, ?)
        ''',
        [id, ownerId, prayerId, _now().toUtc().toIso8601String()],
      );
    });
  }

  @override
  Future<void> selectForToday(
    String prayerId, {
    required bool includeAction,
  }) async {
    final localDate = _dateKey(_now());
    final id = _uuid.v5(Namespace.url.value, '$ownerId:$localDate');

    await database.writeTransaction((transaction) async {
      final existing = await transaction.getOptional(
        'SELECT id FROM today_prayers WHERE id = ? AND owner_id = ?',
        [id, ownerId],
      );
      if (existing == null) {
        await transaction.execute(
          '''
          INSERT INTO today_prayers(
            id, owner_id, local_date, prayer_id, include_action,
            action_completed, created_at
          ) VALUES (?, ?, ?, ?, ?, 0, ?)
          ''',
          [
            id,
            ownerId,
            localDate,
            prayerId,
            includeAction ? 1 : 0,
            _now().toUtc().toIso8601String(),
          ],
        );
        return;
      }
      await transaction.execute(
        '''
        UPDATE today_prayers
        SET prayer_id = ?, include_action = ?, action_completed = 0
        WHERE id = ? AND owner_id = ?
        ''',
        [prayerId, includeAction ? 1 : 0, id, ownerId],
      );
    });
  }

  @override
  Stream<TodayPrayer?> watchToday(DateTime localDate) {
    final dateKey = _dateKey(localDate);
    return database
        .watch(
          '''
          WITH merged AS ($_mergedPrayers)
          SELECT merged.*,
                 EXISTS(
                   SELECT 1 FROM prayer_votes AS vote
                   WHERE vote.owner_id = ? AND vote.prayer_id = merged.id
                 ) AS viewer_marked_helpful,
                 today.include_action,
                 today.action_completed,
                 today.local_date
          FROM today_prayers AS today
          JOIN merged ON merged.id = today.prayer_id
          WHERE today.owner_id = ? AND today.local_date = ?
          LIMIT 1
          ''',
          parameters: [ownerId, ownerId, dateKey],
        )
        .map((rows) {
          if (rows.isEmpty) {
            return null;
          }
          final row = rows.single;
          return TodayPrayer(
            prayer: _prayerFromRow(row),
            localDate: _dateFromKey(row['local_date'] as String),
            includeAction: row['include_action'] == 1,
            actionCompleted: row['action_completed'] == 1,
          );
        });
  }

  @override
  Future<void> completeTodayAction(
    DateTime localDate, {
    required String expectedPrayerId,
    required bool value,
  }) async {
    final dateKey = _dateKey(localDate);
    final id = _uuid.v5(Namespace.url.value, '$ownerId:$dateKey');
    await database.execute(
      '''
      UPDATE today_prayers
      SET action_completed = ?
      WHERE id = ? AND owner_id = ? AND local_date = ? AND prayer_id = ?
      ''',
      [value ? 1 : 0, id, ownerId, dateKey, expectedPrayerId],
    );
  }

  LibraryPrayer _prayerFromRow(Map<String, dynamic> row) {
    return LibraryPrayer(
      id: row['id'] as String,
      title: row['title'] as String,
      body: row['body'] as String,
      grounding: PrayerGrounding.fromWire(row['grounding'] as String),
      purpose: PrayerPurpose.fromWire(row['purpose'] as String),
      helpfulCount: row['helpful_count'] as int? ?? 0,
      viewerMarkedHelpful: row['viewer_marked_helpful'] == 1,
      action: row['action'] as String?,
    );
  }
}

String _dateKey(DateTime localDate) {
  final month = localDate.month.toString().padLeft(2, '0');
  final day = localDate.day.toString().padLeft(2, '0');
  return '${localDate.year}-$month-$day';
}

DateTime _dateFromKey(String value) {
  final parts = value.split('-').map(int.parse).toList(growable: false);
  return DateTime(parts[0], parts[1], parts[2]);
}
