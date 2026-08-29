import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/editorial/data/bundled_editorial_importer.dart';
import 'package:soulbuddy/features/editorial/domain/editorial_item.dart';
import 'package:soulbuddy/features/prayers/data/bundled_prayer_importer.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-editorial-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'imports reviewed prayer metadata without changing stable prayer IDs',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/editorial.db',
      );
      addTearDown(database.close);

      await BundledPrayerImporter().ensureLoaded(database.powersync);
      await BundledEditorialImporter().ensureLoaded(database.powersync);

      final prayerIds = (await database.powersync.getAll(
        'SELECT id FROM bundled_prayers WHERE archived_at IS NULL ORDER BY id',
      )).map((row) => row['id']).toList(growable: false);
      final editorialRows = await database.powersync.getAll('''
      SELECT *
      FROM editorial_items
      WHERE archived_at IS NULL
      ORDER BY id
      ''');
      final editorialIds = editorialRows
          .map((row) => row['id'])
          .toList(growable: false);

      expect(editorialRows, hasLength(8));
      expect(editorialIds, prayerIds);
      for (final row in editorialRows) {
        final item = EditorialItem.fromRow(row);
        expect(item.kind, EditorialContentKind.preparedPrayer);
        expect(item.contentVersion, 1);
        expect(item.provenance, 'soulbuddy_editorial');
        expect(item.sourceRef, 'prayer_library:v2');
        expect(item.reviewState, EditorialReviewState.approved);
        expect(item.reviewedOn, DateTime.utc(2026, 8, 29));
        expect(item.publishedAt, DateTime.utc(2026, 8, 29));
        expect(item.tags, contains('prayer'));
        expect(item.isSelectable, isTrue);
      }
      expect(await database.powersync.getNextCrudTransaction(), isNull);
    },
  );

  test(
    'archives removed manifest entries once and keeps reimport idempotent',
    () async {
      const staleId = '0198a100-0000-7000-8000-000000000099';
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/archive.db',
      );
      addTearDown(database.close);
      await database.powersync.execute(
        '''
      INSERT INTO editorial_items(
        id, content_kind, content_version, provenance, source_ref,
        review_state, reviewed_on, published_at, archived_at, tags_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, ?)
      ''',
        [
          staleId,
          'prepared_prayer',
          1,
          'soulbuddy_editorial',
          'old-manifest',
          'approved',
          '2026-08-01',
          '2026-08-01T00:00:00.000Z',
          jsonEncode(['prayer']),
        ],
      );
      final importer = BundledEditorialImporter();

      await importer.ensureLoaded(database.powersync);
      final first = await database.powersync.get(
        'SELECT archived_at FROM editorial_items WHERE id = ?',
        [staleId],
      );
      expect(first['archived_at'], isNotNull);

      await importer.ensureLoaded(database.powersync);
      final second = await database.powersync.get(
        'SELECT archived_at FROM editorial_items WHERE id = ?',
        [staleId],
      );
      expect(second['archived_at'], first['archived_at']);
      expect(
        await database.powersync.getAll(
          'SELECT id FROM editorial_items WHERE archived_at IS NULL',
        ),
        hasLength(8),
      );
    },
  );

  test(
    'rejects unreviewable manifest state instead of importing partial rows',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/invalid.db',
      );
      addTearDown(database.close);
      final payload = _validPayload();
      final items = (payload['items'] as List<Object?>)
          .cast<Map<String, Object?>>();
      items.first['review_state'] = 'approved';
      items.first.remove('published_at');
      final importer = BundledEditorialImporter(
        assetBundle: _StringAssetBundle(jsonEncode(payload)),
      );

      await expectLater(
        importer.ensureLoaded(database.powersync),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message.toString(),
            'message',
            contains('requires published_at'),
          ),
        ),
      );
      expect(
        await database.powersync.getAll('SELECT id FROM editorial_items'),
        isEmpty,
      );
    },
  );

  test('content kind and review state wire values are stable', () {
    expect(EditorialContentKind.values.map((value) => value.wireValue), [
      'prepared_prayer',
      'prayer_frame',
      'goal_starter_copy',
      'return_copy',
      'guard_instruction',
      'safety_notice',
      'exhortation',
      'bible_study_question',
      'bible_study_plan',
    ]);
    expect(EditorialReviewState.values.map((value) => value.wireValue), [
      'draft',
      'approved',
    ]);
  });
}

Map<String, Object?> _validPayload() => {
  'version': 1,
  'items': [
    <String, Object?>{
      'id': '0198a100-0000-7000-8000-000000000001',
      'kind': 'prepared_prayer',
      'content_version': 1,
      'provenance': 'soulbuddy_editorial',
      'source_ref': 'fixture:v1',
      'review_state': 'approved',
      'reviewed_on': '2026-08-29',
      'published_at': '2026-08-29T00:00:00.000Z',
      'tags': ['prayer', 'daily'],
    },
  ],
};

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.contents);

  final String contents;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(contents));
    return ByteData.sublistView(bytes);
  }
}
