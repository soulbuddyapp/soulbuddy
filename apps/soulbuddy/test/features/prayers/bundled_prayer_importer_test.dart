import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/data/bundled_prayer_importer.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';

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
             content_version, archived_at
      FROM bundled_prayers
      ORDER BY purpose
      ''');
    final approvedGroundings = PrayerGrounding.values
        .map((value) => value.wireValue)
        .toSet();
    final approvedPurposes = PrayerPurpose.values
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
      expect(row['helpful_count'], 0);
      expect(row['content_version'], 1);
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

  test('rejects an unsupported content version before writing', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);
    final importer = BundledPrayerImporter(
      assetBundle: _StringAssetBundle(_payload(version: 2)),
    );

    await expectLater(
      importer.ensureLoaded(database.powersync),
      throwsA(isA<FormatException>()),
    );

    expect(
      await database.powersync.getAll('SELECT id FROM bundled_prayers'),
      isEmpty,
    );
  });

  test(
    'rejects invalid controlled values, empty fields, and long bodies',
    () async {
      final invalidPrayers = <Map<String, Object?>>[
        _prayer(grounding: 'other'),
        _prayer(purpose: 'success'),
        _prayer(title: '   '),
        _prayer(action: ''),
        _prayer(body: List.filled(111, 'word').join(' ')),
        _prayer(helpfulCount: 1),
        _prayer(helpfulCount: 0.0),
      ];

      for (var index = 0; index < invalidPrayers.length; index++) {
        final database = await openTestDatabase(
          '${temporaryDirectory.path}/invalid-$index.db',
        );
        addTearDown(database.close);
        final importer = BundledPrayerImporter(
          assetBundle: _StringAssetBundle(
            jsonEncode({
              'version': 1,
              'prayers': [invalidPrayers[index]],
            }),
          ),
        );

        await expectLater(
          importer.ensureLoaded(database.powersync),
          throwsA(isA<FormatException>()),
          reason: 'invalid case $index should be rejected',
        );
        expect(
          await database.powersync.getAll('SELECT id FROM bundled_prayers'),
          isEmpty,
        );
      }
    },
  );
}

int _wordCount(String value) {
  return value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .length;
}

String _payload({required int version}) {
  return jsonEncode({
    'version': version,
    'prayers': [_prayer()],
  });
}

Map<String, Object?> _prayer({
  String id = '0198a100-0000-7000-8000-000000000001',
  String title = 'For this day',
  String body = 'Father, help me love my neighbor today. Amen.',
  String grounding = 'general_christian',
  String purpose = 'daily',
  String action = 'Help one person with a practical need.',
  Object helpfulCount = 0,
}) {
  return {
    'id': id,
    'title': title,
    'body': body,
    'grounding': grounding,
    'purpose': purpose,
    'action': action,
    'helpful_count': helpfulCount,
  };
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
