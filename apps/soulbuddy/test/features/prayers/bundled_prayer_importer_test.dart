import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/data/bundled_prayer_importer.dart';
import 'package:soulbuddy/features/prayers/data/powersync_prayer_repository.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_language.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-bundled-prayers-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('imports exactly eight controlled starter prayers idempotently', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);
    final importer = BundledPrayerImporter();
    await database.powersync.execute(
      '''
      INSERT INTO bundled_prayers(
        id, title, body, grounding, purpose, action, helpful_count,
        content_version, archived_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        '0198a100-0000-7000-8000-000000000001',
        'Stale title',
        'Stale body',
        'general_christian',
        'daily',
        null,
        9,
        0,
        '2026-08-10T00:00:00.000Z',
      ],
    );

    await importer.ensureLoaded(database.powersync);
    await importer.ensureLoaded(database.powersync);

    final rows = await database.powersync.getAll('''
      SELECT id, title, body, grounding, purpose, action, helpful_count,
             language_style, content_version, archived_at
      FROM bundled_prayers
      ORDER BY purpose
      ''');
    final approvedGroundings = PrayerGrounding.values
        .map((value) => value.wireValue)
        .toSet();
    final approvedPurposes = PrayerPurpose.values
        .map((value) => value.wireValue)
        .toSet();
    final approvedLanguageStyles = PrayerLanguageStyle.values
        .map((value) => value.wireValue)
        .toSet();
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    expect(rows, hasLength(8));
    expect(rows.map((row) => row['id']).toSet(), hasLength(8));
    expect(rows.map((row) => row['purpose']).toSet(), approvedPurposes);
    expect(
      rows.singleWhere(
        (row) => row['id'] == '0198a100-0000-7000-8000-000000000001',
      )['title'],
      'For this day',
    );
    for (final row in rows) {
      expect(row['id'], matches(uuidPattern));
      expect((row['title'] as String).trim(), isNotEmpty);
      expect((row['body'] as String).trim(), isNotEmpty);
      expect((row['action'] as String).trim(), isNotEmpty);
      expect(approvedGroundings, contains(row['grounding']));
      expect(approvedPurposes, contains(row['purpose']));
      expect(approvedLanguageStyles, contains(row['language_style']));
      expect(row['helpful_count'], 0);
      expect(row['content_version'], 2);
      expect(row['archived_at'], isNull);
      expect(_wordCount(row['body'] as String), lessThanOrEqualTo(110));
    }
  });

  test(
    'import writes only local bundled prayers and creates no upload',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/soulbuddy.db',
      );
      addTearDown(database.close);

      await BundledPrayerImporter().ensureLoaded(database.powersync);

      expect(
        await database.powersync.getAll('SELECT id FROM library_prayers'),
        isEmpty,
      );
      expect(
        await database.powersync.getAll('SELECT id FROM prayer_votes'),
        isEmpty,
      );
      expect(
        await database.powersync.getAll('SELECT id FROM today_prayers'),
        isEmpty,
      );
      expect(await database.powersync.getNextCrudTransaction(), isNull);
    },
  );

  test(
    'archives prayers removed from the bundle and keeps the upgrade idempotent',
    () async {
      const staleId = '0198a100-0000-7000-8000-000000000099';
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/soulbuddy.db',
      );
      addTearDown(database.close);
      await database.powersync.execute(
        '''
        INSERT INTO bundled_prayers(
          id, title, body, grounding, purpose, action, helpful_count,
          content_version, archived_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)
        ''',
        [
          staleId,
          'Removed prayer',
          'Father, help me remain faithful. Amen.',
          'general_christian',
          'daily',
          null,
          0,
          0,
        ],
      );
      final importer = BundledPrayerImporter();
      final repository = PowerSyncPrayerRepository(
        database: database.powersync,
        ownerId: 'owner-1',
      );

      await importer.ensureLoaded(database.powersync);

      final staleAfterFirstImport = await database.powersync.get(
        'SELECT archived_at FROM bundled_prayers WHERE id = ?',
        [staleId],
      );
      final firstArchivedAt = staleAfterFirstImport['archived_at'];
      final activeRows = await database.powersync.getAll(
        'SELECT id FROM bundled_prayers WHERE archived_at IS NULL',
      );
      final surfacedIds = (await repository.watchLibrary().first)
          .map((prayer) => prayer.id)
          .toSet();

      expect(firstArchivedAt, isNotNull);
      expect(activeRows, hasLength(8));
      expect(surfacedIds, hasLength(8));
      expect(surfacedIds, isNot(contains(staleId)));

      await importer.ensureLoaded(database.powersync);

      final staleAfterSecondImport = await database.powersync.get(
        'SELECT archived_at FROM bundled_prayers WHERE id = ?',
        [staleId],
      );
      expect(staleAfterSecondImport['archived_at'], firstArchivedAt);
      expect(
        await database.powersync.getAll(
          'SELECT id FROM bundled_prayers WHERE archived_at IS NULL',
        ),
        hasLength(8),
      );
      expect(await database.powersync.getNextCrudTransaction(), isNull);
    },
  );

  final invalidPayloadCases = <_InvalidPayloadCase>[
    _InvalidPayloadCase(
      name: 'unknown root key',
      mutate: (payload) => payload['unexpected'] = true,
      diagnostic: 'Unexpected bundled prayer root key: unexpected',
    ),
    _InvalidPayloadCase(
      name: 'unknown prayer key',
      mutate: (payload) => _prayers(payload).first['author'] = 'Unknown',
      diagnostic: 'Unexpected bundled prayer field: author',
    ),
    _InvalidPayloadCase(
      name: 'unknown grounding',
      mutate: (payload) => _prayers(payload).first['grounding'] = 'other',
      diagnostic: 'Unknown prayer grounding: other',
    ),
    _InvalidPayloadCase(
      name: 'unknown purpose',
      mutate: (payload) => _prayers(payload).first['purpose'] = 'success',
      diagnostic: 'Unknown prayer purpose: success',
    ),
    _InvalidPayloadCase(
      name: 'empty required field',
      mutate: (payload) => _prayers(payload).first['title'] = '   ',
      diagnostic: 'field "title" must be a non-empty string',
    ),
    _InvalidPayloadCase(
      name: 'non-string required field',
      mutate: (payload) => _prayers(payload).first['title'] = 42,
      diagnostic: 'field "title" must be a non-empty string',
    ),
    _InvalidPayloadCase(
      name: 'empty optional action',
      mutate: (payload) => _prayers(payload).first['action'] = '',
      diagnostic: 'field "action" must be omitted or a non-empty string',
    ),
    _InvalidPayloadCase(
      name: 'body over the word limit',
      mutate: (payload) {
        _prayers(payload).first['body'] = List.filled(111, 'word').join(' ');
      },
      diagnostic: 'exceeds 110 words',
    ),
    _InvalidPayloadCase(
      name: 'non-integer helpful count',
      mutate: (payload) => _prayers(payload).first['helpful_count'] = 0.0,
      diagnostic: 'field "helpful_count" must be an integer',
    ),
    _InvalidPayloadCase(
      name: 'non-zero helpful count',
      mutate: (payload) => _prayers(payload).first['helpful_count'] = 1,
      diagnostic: 'field "helpful_count" must be 0',
    ),
    _InvalidPayloadCase(
      name: 'malformed UUID',
      mutate: (payload) => _prayers(payload).first['id'] = 'not-a-uuid',
      diagnostic: 'does not have a valid UUID',
    ),
    _InvalidPayloadCase(
      name: 'duplicate UUID',
      mutate: (payload) {
        final prayers = _prayers(payload);
        prayers[1]['id'] = prayers[0]['id'];
      },
      diagnostic: 'Bundled prayer IDs must be unique',
    ),
    _InvalidPayloadCase(
      name: 'incorrect prayer count',
      mutate: (payload) => _prayers(payload).removeLast(),
      diagnostic: 'must contain exactly 8 prayers',
    ),
    _InvalidPayloadCase(
      name: 'unsupported content version',
      mutate: (payload) => payload['version'] = 3,
      diagnostic: 'Unsupported bundled prayer content version: 3',
    ),
  ];

  for (final testCase in invalidPayloadCases) {
    test('rejects ${testCase.name} with a useful diagnostic', () async {
      final payload = _validPayload();
      testCase.mutate(payload);
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/invalid.db',
      );
      addTearDown(database.close);
      final importer = BundledPrayerImporter(
        assetBundle: _StringAssetBundle(jsonEncode(payload)),
      );

      await expectLater(
        importer.ensureLoaded(database.powersync),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message.toString(),
            'message',
            contains(testCase.diagnostic),
          ),
        ),
      );
      expect(
        await database.powersync.getAll('SELECT id FROM bundled_prayers'),
        isEmpty,
      );
    });
  }
}

int _wordCount(String value) {
  return value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .length;
}

Map<String, Object?> _validPayload() {
  const purposes = [
    'daily',
    'gratitude',
    'guidance',
    'family',
    'healing',
    'work',
    'forgiveness',
    'difficult_time',
  ];
  return {
    'version': 2,
    'prayers': List.generate(purposes.length, (index) {
      final suffix = (index + 1).toString().padLeft(12, '0');
      return <String, Object?>{
        'id': '0198a100-0000-7000-8000-$suffix',
        'title': 'Prayer ${index + 1}',
        'body': 'Father, help me love my neighbor today. Amen.',
        'grounding': index.isEven ? 'general_christian' : 'catholic',
        'language_style': index.isEven ? 'christian' : 'catholic',
        'purpose': purposes[index],
        'action': 'Help one person with a practical need.',
        'helpful_count': 0,
      };
    }),
  };
}

List<Map<String, Object?>> _prayers(Map<String, Object?> payload) {
  return (payload['prayers'] as List<Object?>).cast<Map<String, Object?>>();
}

class _InvalidPayloadCase {
  const _InvalidPayloadCase({
    required this.name,
    required this.mutate,
    required this.diagnostic,
  });

  final String name;
  final void Function(Map<String, Object?> payload) mutate;
  final String diagnostic;
}

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.contents);

  final String contents;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(contents));
    return ByteData.sublistView(bytes);
  }
}
