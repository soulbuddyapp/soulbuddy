import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';
import 'package:soulbuddy/features/editorial/data/powersync_editorial_prayer_repository.dart';
import 'package:soulbuddy/features/editorial/domain/editorial_item.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_language.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-editorial-prayers-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('same-ID server prayer cannot override reviewed bundled wording', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/precedence.db',
    );
    addTearDown(database.close);
    const id = '0198a100-0000-7000-8000-000000000001';
    await _seedBundledPrayer(
      database.powersync,
      id: id,
      title: 'Reviewed wording',
      body: 'Father, keep me near you today. Amen.',
    );
    await _seedEditorial(database.powersync, id: id);
    await database.powersync.execute(
      '''
      INSERT INTO library_prayers(
        id, title, body, grounding, language_style, purpose, action,
        helpful_count, published_at, archived_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
      ''',
      [
        id,
        'Unprovenanced server replacement',
        'Runtime wording that has no editorial record.',
        'general_christian',
        'christian',
        'daily',
        'Do something different.',
        999,
        '2026-08-29T00:00:00.000Z',
      ],
    );
    final repository = PowerSyncEditorialPrayerRepository(
      database: database.powersync,
    );

    final result = await repository.watchApprovedPrayer(id).first;

    expect(result, isNotNull);
    expect(result!.prayer.title, 'Reviewed wording');
    expect(result.prayer.body, 'Father, keep me near you today. Amen.');
    expect(result.editorial.provenance, 'soulbuddy_editorial');
    expect(result.editorial.reviewState, EditorialReviewState.approved);
    expect(result.editorial.isSelectable, isTrue);
  });

  test('only approved published non-archived editorial prayers are selectable', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/selection.db',
    );
    addTearDown(database.close);
    final cases = [
      (
        '0198a100-0000-7000-8000-000000000011',
        'Approved',
        'approved',
        '2026-08-29T00:00:00.000Z',
        null,
      ),
      (
        '0198a100-0000-7000-8000-000000000012',
        'Draft',
        'draft',
        null,
        null,
      ),
      (
        '0198a100-0000-7000-8000-000000000013',
        'Unpublished',
        'approved',
        null,
        null,
      ),
      (
        '0198a100-0000-7000-8000-000000000014',
        'Archived',
        'approved',
        '2026-08-29T00:00:00.000Z',
        '2026-08-30T00:00:00.000Z',
      ),
    ];
    for (final item in cases) {
      await _seedBundledPrayer(
        database.powersync,
        id: item.$1,
        title: item.$2,
      );
      await _seedEditorial(
        database.powersync,
        id: item.$1,
        reviewState: item.$3,
        publishedAt: item.$4,
        archivedAt: item.$5,
      );
    }
    final repository = PowerSyncEditorialPrayerRepository(
      database: database.powersync,
    );

    final prayers = await repository.watchApproved().first;

    expect(prayers.map((item) => item.prayer.title), ['Approved']);
  });

  test('approved selection is deterministic for language preference', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/ranking.db',
    );
    addTearDown(database.close);
    final items = [
      (
        '0198a100-0000-7000-8000-000000000021',
        'Catholic',
        PrayerLanguageStyle.catholic,
      ),
      (
        '0198a100-0000-7000-8000-000000000022',
        'Jesus',
        PrayerLanguageStyle.jesus,
      ),
      (
        '0198a100-0000-7000-8000-000000000023',
        'Christian',
        PrayerLanguageStyle.christian,
      ),
    ];
    for (final item in items) {
      await _seedBundledPrayer(
        database.powersync,
        id: item.$1,
        title: item.$2,
        languageStyle: item.$3,
        purpose: PrayerPurpose.guidance,
      );
      await _seedEditorial(database.powersync, id: item.$1);
    }
    final repository = PowerSyncEditorialPrayerRepository(
      database: database.powersync,
    );

    final first = await repository
        .watchApproved(
          purpose: PrayerPurpose.guidance,
          languagePreference: PrayerLanguagePreference.jesus,
        )
        .first;
    final second = await repository
        .watchApproved(
          purpose: PrayerPurpose.guidance,
          languagePreference: PrayerLanguagePreference.jesus,
        )
        .first;

    expect(first.map((item) => item.prayer.languageStyle), [
      PrayerLanguageStyle.jesus,
      PrayerLanguageStyle.christian,
      PrayerLanguageStyle.catholic,
    ]);
    expect(
      second.map((item) => item.prayer.id),
      first.map((item) => item.prayer.id),
    );
  });
}

Future<void> _seedBundledPrayer(
  PowerSyncDatabase database, {
  required String id,
  required String title,
  String body = 'Father, help me take the next faithful step. Amen.',
  PrayerGrounding grounding = PrayerGrounding.generalChristian,
  PrayerLanguageStyle languageStyle = PrayerLanguageStyle.christian,
  PrayerPurpose purpose = PrayerPurpose.daily,
}) {
  return database.execute(
    '''
    INSERT INTO bundled_prayers(
      id, title, body, grounding, language_style, purpose, action,
      helpful_count, content_version, archived_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, 0, 2, NULL)
    ''',
    [
      id,
      title,
      body,
      grounding.wireValue,
      languageStyle.wireValue,
      purpose.wireValue,
      'Take one faithful step.',
    ],
  );
}

Future<void> _seedEditorial(
  PowerSyncDatabase database, {
  required String id,
  String reviewState = 'approved',
  String? publishedAt = '2026-08-29T00:00:00.000Z',
  String? archivedAt,
}) {
  return database.execute(
    '''
    INSERT INTO editorial_items(
      id, content_kind, content_version, provenance, source_ref,
      review_state, reviewed_on, published_at, archived_at, tags_json
    ) VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      id,
      'prepared_prayer',
      'soulbuddy_editorial',
      'fixture:v1',
      reviewState,
      '2026-08-29',
      publishedAt,
      archivedAt,
      jsonEncode(['prayer']),
    ],
  );
}
