import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';
import 'package:soulbuddy/features/prayers/data/powersync_prayer_repository.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-reviewed-prayer-projection-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'reviewed bundled wording survives detail and Today projections',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/projection.db',
      );
      addTearDown(database.close);
      const prayerId = '0198a100-0000-7000-8000-000000000001';
      await _seedReviewedBundle(database.powersync, prayerId);
      await _seedServerReplacement(database.powersync, prayerId);
      final repository = PowerSyncPrayerRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        now: () => DateTime(2026, 8, 29, 12),
      );

      final detail = await repository.watchPrayer(prayerId).first;

      expect(detail?.title, 'Reviewed wording');
      expect(detail?.body, 'Father, keep me near you today. Amen.');
      expect(detail?.action, 'Pause and pray slowly.');

      await repository.selectForToday(
        const PrayerReference.library(prayerId),
        includeAction: true,
      );
      final today = await repository.watchToday(DateTime(2026, 8, 29)).first;

      expect(today?.prayer.title, 'Reviewed wording');
      expect(today?.prayer.body, 'Father, keep me near you today. Amen.');
      expect(today?.prayer.action, 'Pause and pray slowly.');
    },
  );
}

Future<void> _seedReviewedBundle(
  PowerSyncDatabase database,
  String prayerId,
) async {
  await database.execute(
    '''
    INSERT INTO bundled_prayers(
      id, title, body, grounding, language_style, purpose, action,
      helpful_count, content_version, archived_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, 0, 2, NULL)
    ''',
    [
      prayerId,
      'Reviewed wording',
      'Father, keep me near you today. Amen.',
      'general_christian',
      'christian',
      'daily',
      'Pause and pray slowly.',
    ],
  );
  await database.execute(
    '''
    INSERT INTO editorial_items(
      id, content_kind, content_version, provenance, source_ref,
      review_state, reviewed_on, published_at, archived_at, tags_json
    ) VALUES (?, 'prepared_prayer', 1, 'soulbuddy_editorial',
              'prayer_library:v2', 'approved', '2026-08-29',
              '2026-08-29T00:00:00.000Z', NULL, '["prayer"]')
    ''',
    [prayerId],
  );
}

Future<void> _seedServerReplacement(
  PowerSyncDatabase database,
  String prayerId,
) async {
  await database.execute(
    '''
    INSERT INTO library_prayers(
      id, title, body, grounding, language_style, purpose, action,
      helpful_count, published_at, archived_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, 99, ?, NULL)
    ''',
    [
      prayerId,
      'Unreviewed server replacement',
      'This wording must not replace reviewed content.',
      'general_christian',
      'christian',
      'daily',
      'Different action.',
      '2026-08-29T01:00:00.000Z',
    ],
  );
}
