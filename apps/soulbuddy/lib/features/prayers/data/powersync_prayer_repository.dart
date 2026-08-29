import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../domain/library_prayer.dart';
import '../domain/prayer_reference.dart';
import '../domain/prayer_language.dart';
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
    SELECT canonical.id, canonical.title, canonical.body, canonical.grounding,
           canonical.language_style, canonical.purpose, canonical.action,
           canonical.helpful_count
    FROM library_prayers AS canonical
    WHERE canonical.published_at IS NOT NULL
      AND canonical.archived_at IS NULL
      AND NOT EXISTS (
        SELECT 1
        FROM bundled_prayers AS bundled
        JOIN editorial_items AS editorial ON editorial.id = bundled.id
        WHERE bundled.id = canonical.id
          AND bundled.archived_at IS NULL
          AND editorial.content_kind = 'prepared_prayer'
          AND editorial.review_state = 'approved'
          AND editorial.published_at IS NOT NULL
          AND editorial.archived_at IS NULL
      )
    UNION ALL
    SELECT bundled.id, bundled.title, bundled.body, bundled.grounding,
           bundled.language_style,
           bundled.purpose, bundled.action, bundled.helpful_count
    FROM bundled_prayers AS bundled
    WHERE bundled.archived_at IS NULL
      AND (
        EXISTS (
          SELECT 1
          FROM editorial_items AS editorial
          WHERE editorial.id = bundled.id
            AND editorial.content_kind = 'prepared_prayer'
            AND editorial.review_state = 'approved'
            AND editorial.published_at IS NOT NULL
            AND editorial.archived_at IS NULL
        )
        OR NOT EXISTS (
          SELECT 1 FROM library_prayers AS canonical
          WHERE canonical.id = bundled.id
            AND canonical.published_at IS NOT NULL
            AND canonical.archived_at IS NULL
        )
      )
  ''';

  @override
  Stream<List<LibraryPrayer>> watchLibrary({
    PrayerGrounding? grounding,
    PrayerPurpose? purpose,
    PrayerLanguagePreference? languagePreference,
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
        .map((rows) {
          final prayers = rows
              .map<Map<String, dynamic>>((row) => row)
              .map(_prayerFromRow)
              .toList();
          if (languagePreference != null) {
            prayers.sort((left, right) {
              final rank = languagePreference
                  .rankOf(left.languageStyle)
                  .compareTo(languagePreference.rankOf(right.languageStyle));
              if (rank != 0) return rank;
              final helpful = right.helpfulCount.compareTo(left.helpfulCount);
              if (helpful != 0) return helpful;
              final title = left.title.toLowerCase().compareTo(
                right.title.toLowerCase(),
              );
              return title != 0 ? title : left.id.compareTo(right.id);
            });
          }
          return List.unmodifiable(prayers);
        });
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
    PrayerReference prayer, {
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
            id, owner_id, local_date, prayer_id, personal_prayer_id,
            include_action,
            action_completed, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, 0, ?)
          ''',
          [
            id,
            ownerId,
            localDate,
            prayer.source == PrayerSource.library ? prayer.id : null,
            prayer.source == PrayerSource.personal ? prayer.id : null,
            includeAction ? 1 : 0,
            _now().toUtc().toIso8601String(),
          ],
        );
        return;
      }
      await transaction.execute(
        '''
        UPDATE today_prayers
        SET prayer_id = ?, personal_prayer_id = ?, include_action = ?,
            action_completed = 0
        WHERE id = ? AND owner_id = ?
        ''',
        [
          prayer.source == PrayerSource.library ? prayer.id : null,
          prayer.source == PrayerSource.personal ? prayer.id : null,
          includeAction ? 1 : 0,
          id,
          ownerId,
        ],
      );
    });
  }

  @override
  Stream<TodayPrayer?> watchToday(DateTime localDate) {
    final dateKey = _dateKey(localDate);
    return database
        .watch(
          '''
          WITH merged AS ($_mergedPrayers), selected AS (
          SELECT 'library' AS source, merged.id, merged.title, merged.body,
                 merged.grounding, merged.purpose, merged.action,
                 merged.helpful_count,
                 EXISTS(
                   SELECT 1 FROM prayer_votes AS vote
                   WHERE vote.owner_id = ? AND vote.prayer_id = merged.id
                 ) AS viewer_marked_helpful,
                 today.include_action,
                 today.action_completed,
                 today.local_date,
                 NULL AS prayer_revision_id
          FROM today_prayers AS today
          JOIN merged ON merged.id = today.prayer_id
          WHERE today.owner_id = ? AND today.local_date = ?
          UNION ALL
          SELECT 'personal' AS source, personal.id, personal.title,
                 revision.body, personal.grounding, personal.purpose,
                 revision.action, 0 AS helpful_count,
                 0 AS viewer_marked_helpful, today.include_action,
                 today.action_completed, today.local_date,
                 revision.id AS prayer_revision_id
          FROM today_prayers AS today
          JOIN personal_prayers AS personal
            ON personal.id = today.personal_prayer_id
           AND personal.owner_id = today.owner_id
           AND personal.archived_at IS NULL
          JOIN personal_prayer_revisions AS revision
            ON revision.id = personal.current_revision_id
           AND revision.prayer_id = personal.id
           AND revision.owner_id = personal.owner_id
          WHERE today.owner_id = ? AND today.local_date = ?
          )
          SELECT * FROM selected
          LIMIT 1
          ''',
          parameters: [ownerId, ownerId, dateKey, ownerId, dateKey],
        )
        .map((rows) {
          if (rows.isEmpty) {
            return null;
          }
          final row = rows.single;
          return TodayPrayer(
            prayer: PrayerDisplayValue(
              reference: row['source'] == 'library'
                  ? PrayerReference.library(row['id'] as String)
                  : PrayerReference.personal(row['id'] as String),
              title: row['title'] as String,
              body: row['body'] as String,
              grounding: PrayerGrounding.fromWire(row['grounding'] as String),
              purpose: PrayerPurpose.fromWire(row['purpose'] as String),
              action: row['action'] as String?,
              helpfulCount: row['helpful_count'] as int? ?? 0,
              viewerMarkedHelpful: row['viewer_marked_helpful'] == 1,
            ),
            localDate: _dateFromKey(row['local_date'] as String),
            includeAction: row['include_action'] == 1,
            actionCompleted: row['action_completed'] == 1,
            prayerRevisionId: row['prayer_revision_id'] as String?,
          );
        });
  }

  @override
  Future<void> completeTodayAction(
    DateTime localDate, {
    required PrayerReference expectedPrayer,
    required bool value,
  }) async {
    final dateKey = _dateKey(localDate);
    final id = _uuid.v5(Namespace.url.value, '$ownerId:$dateKey');
    await database.execute(
      '''
      UPDATE today_prayers
      SET action_completed = ?
      WHERE id = ? AND owner_id = ? AND local_date = ?
        AND ((? = 'library' AND prayer_id = ? AND personal_prayer_id IS NULL)
          OR (? = 'personal' AND personal_prayer_id = ? AND prayer_id IS NULL))
      ''',
      [
        value ? 1 : 0,
        id,
        ownerId,
        dateKey,
        expectedPrayer.source.name,
        expectedPrayer.id,
        expectedPrayer.source.name,
        expectedPrayer.id,
      ],
    );
  }

  LibraryPrayer _prayerFromRow(Map<String, dynamic> row) {
    return LibraryPrayer(
      id: row['id'] as String,
      title: row['title'] as String,
      body: row['body'] as String,
      grounding: PrayerGrounding.fromWire(row['grounding'] as String),
      purpose: PrayerPurpose.fromWire(row['purpose'] as String),
      languageStyle: PrayerLanguageStyle.fromWire(
        row['language_style'] as String?,
      ),
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
