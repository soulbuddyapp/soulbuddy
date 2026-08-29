import 'package:powersync/powersync.dart';

import '../../prayers/domain/library_prayer.dart';
import '../../prayers/domain/prayer_language.dart';
import '../domain/editorial_item.dart';
import 'editorial_prayer_repository.dart';

class PowerSyncEditorialPrayerRepository implements EditorialPrayerRepository {
  const PowerSyncEditorialPrayerRepository({required this.database});

  final PowerSyncDatabase database;

  static const _approvedPrayerSelect = '''
    SELECT bundled.id,
           bundled.title,
           bundled.body,
           bundled.grounding,
           bundled.language_style,
           bundled.purpose,
           bundled.action,
           bundled.helpful_count,
           editorial.content_kind,
           editorial.content_version,
           editorial.provenance,
           editorial.source_ref,
           editorial.review_state,
           editorial.reviewed_on,
           editorial.published_at,
           editorial.archived_at,
           editorial.tags_json
    FROM bundled_prayers AS bundled
    JOIN editorial_items AS editorial ON editorial.id = bundled.id
    WHERE bundled.archived_at IS NULL
      AND editorial.content_kind = 'prepared_prayer'
      AND editorial.review_state = 'approved'
      AND editorial.published_at IS NOT NULL
      AND datetime(editorial.published_at) <= datetime('now')
      AND editorial.archived_at IS NULL
  ''';

  @override
  Stream<List<EditorialPrayer>> watchApproved({
    PrayerGrounding? grounding,
    PrayerPurpose? purpose,
    PrayerLanguagePreference? languagePreference,
  }) {
    return database
        .watch(
          '''
          $_approvedPrayerSelect
            AND (? IS NULL OR bundled.grounding = ?)
            AND (? IS NULL OR bundled.purpose = ?)
          ORDER BY bundled.title COLLATE NOCASE ASC, bundled.id ASC
          ''',
          parameters: [
            grounding?.wireValue,
            grounding?.wireValue,
            purpose?.wireValue,
            purpose?.wireValue,
          ],
        )
        .map((rows) {
          final items = rows.map(_fromRow).toList();
          if (languagePreference != null) {
            items.sort((left, right) {
              final languageRank = languagePreference
                  .rankOf(left.prayer.languageStyle)
                  .compareTo(
                    languagePreference.rankOf(right.prayer.languageStyle),
                  );
              if (languageRank != 0) return languageRank;
              final title = left.prayer.title.toLowerCase().compareTo(
                right.prayer.title.toLowerCase(),
              );
              return title != 0
                  ? title
                  : left.prayer.id.compareTo(right.prayer.id);
            });
          }
          return List.unmodifiable(items);
        });
  }

  @override
  Stream<EditorialPrayer?> watchApprovedPrayer(String id) {
    return database
        .watch(
          '''
          $_approvedPrayerSelect
            AND bundled.id = ?
          LIMIT 1
          ''',
          parameters: [id],
        )
        .map((rows) => rows.isEmpty ? null : _fromRow(rows.single));
  }

  EditorialPrayer _fromRow(Map<String, dynamic> row) {
    return EditorialPrayer(
      prayer: LibraryPrayer(
        id: row['id'] as String,
        title: row['title'] as String,
        body: row['body'] as String,
        grounding: PrayerGrounding.fromWire(row['grounding'] as String),
        purpose: PrayerPurpose.fromWire(row['purpose'] as String),
        languageStyle: PrayerLanguageStyle.fromWire(
          row['language_style'] as String?,
        ),
        helpfulCount: row['helpful_count'] as int? ?? 0,
        viewerMarkedHelpful: false,
        action: row['action'] as String?,
      ),
      editorial: EditorialItem.fromRow(row),
    );
  }
}
