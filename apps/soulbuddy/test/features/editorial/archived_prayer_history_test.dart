import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/data/powersync_prayer_repository.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-archived-prayer-history-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'archived editorial prayer leaves selection but keeps detail and Today history',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/archive.db',
      );
      addTearDown(database.close);
      const prayerId = '0198a100-0000-7000-8000-000000000091';
      const reviewedTitle = 'Reviewed prayer';
      const reviewedBody = 'Father, keep me close to you today. Amen.';

      await database.powersync.execute(
        '''
        INSERT INTO bundled_prayers(
          id, title, body, grounding, language_style, purpose, action,
          helpful_count, content_version, archived_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 0, 3, NULL)
        ''',
        [
          prayerId,
          reviewedTitle,
          reviewedBody,
          'general_christian',
          'christian',
          'daily',
          'Take one faithful step.',
        ],
      );
      await database.powersync.execute(
        '''
        INSERT INTO editorial_items(
          id, content_kind, content_version, provenance, source_ref,
          review_state, reviewed_on, published_at, archived_at, tags_json
        ) VALUES (?, 'prepared_prayer', 1, 'soulbuddy_editorial', ?,
          'approved', '2026-08-29', '2026-08-29T00:00:00.000Z', NULL, ?)
        ''',
        [
          prayerId,
          'fixture:archive-v1',
          jsonEncode(['prayer', 'daily']),
        ],
      );
      await database.powersync.execute(
        '''
        INSERT INTO library_prayers(
          id, title, body, grounding, language_style, purpose, action,
          helpful_count, published_at, archived_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 100, ?, NULL)
        ''',
        [
          prayerId,
          'Unprovenanced server replacement',
          'This wording must never replace reviewed history.',
          'general_christian',
          'christian',
          'daily',
          'Different action.',
          '2026-08-29T00:00:00.000Z',
        ],
      );

      final repository = PowerSyncPrayerRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        now: () => DateTime(2026, 8, 29, 8),
      );

      expect(
        (await repository.watchLibrary().first).map((item) => item.title),
        contains(reviewedTitle),
      );
      await repository.selectForToday(
        const PrayerReference.library(prayerId),
        includeAction: true,
      );

      const archivedAt = '2026-08-30T00:00:00.000Z';
      await database.powersync.execute(
        'UPDATE bundled_prayers SET archived_at = ? WHERE id = ?',
        [archivedAt, prayerId],
      );
      await database.powersync.execute(
        'UPDATE editorial_items SET archived_at = ? WHERE id = ?',
        [archivedAt, prayerId],
      );

      final selectable = await repository.watchLibrary().first;
      expect(selectable.where((item) => item.id == prayerId), isEmpty);

      final historical = await repository.watchPrayer(prayerId).first;
      expect(historical?.title, reviewedTitle);
      expect(historical?.body, reviewedBody);

      final today = await repository.watchToday(DateTime(2026, 8, 29)).first;
      expect(today?.prayer.title, reviewedTitle);
      expect(today?.prayer.body, reviewedBody);
      expect(today?.prayer.id, prayerId);
    },
  );
}
