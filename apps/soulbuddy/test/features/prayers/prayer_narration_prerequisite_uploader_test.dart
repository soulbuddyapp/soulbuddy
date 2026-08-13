import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:powersync/powersync.dart';
import 'package:soulbuddy/features/prayers/data/prayer_narration_prerequisite_uploader.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  test(
    'uploads only the selected prayer and exact immutable revision',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'soulbuddy-narration-prerequisite-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final database = await openTestDatabase('${directory.path}/soulbuddy.db');
      addTearDown(database.close);
      await _seedPrayer(database.powersync);
      await database.powersync.execute(
        '''
      INSERT INTO encounters(
        id, owner_id, title, body, occurred_on, is_altar,
        current_revision_id, created_at, updated_at, archived_at,
        memory_type, sensitive, recall_enabled, recall_paused,
        recall_interval_days
      ) VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?, NULL, 'deed', 0, 1, 0, 7)
      ''',
        [
          '0198a000-0000-7000-8000-000000000010',
          '0198a000-0000-7000-8000-000000000001',
          'Unrelated private encounter',
          'Do not upload this.',
          '2026-08-13',
          '0198a000-0000-7000-8000-000000000011',
          '2026-08-13T10:00:00Z',
          '2026-08-13T10:00:00Z',
        ],
      );
      Map<String, dynamic>? payload;
      final uploader = PrayerNarrationPrerequisiteUploader(
        database: database.powersync,
        apiBaseUri: Uri.parse('https://sbuddy.elbiblio.com'),
        installationId: 'device-1',
        accessToken: () async => 'token',
        client: MockClient((request) async {
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'accepted': 2, 'rejected': 0}), 200);
        }),
      );

      await uploader.upload(
        personalPrayerId: _prayerId,
        revisionId: _revisionId,
      );

      final operations = payload?['operations'] as List<dynamic>;
      expect(operations.map((item) => (item as Map)['table']), [
        'personal_prayers',
        'personal_prayer_revisions',
      ]);
      expect(
        jsonEncode(payload),
        isNot(contains('Unrelated private encounter')),
      );
      expect(jsonEncode(payload), isNot(contains('Do not upload this.')));
      expect(
        await database.powersync.getNextCrudTransaction(),
        isNotNull,
        reason: 'Scoped upload must not consume the normal PowerSync queue.',
      );
    },
  );

  test(
    'rejects any prerequisite batch the server does not fully accept',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'soulbuddy-narration-rejected-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final database = await openTestDatabase('${directory.path}/soulbuddy.db');
      addTearDown(database.close);
      await _seedPrayer(database.powersync);
      final uploader = PrayerNarrationPrerequisiteUploader(
        database: database.powersync,
        apiBaseUri: Uri.parse('https://sbuddy.elbiblio.com'),
        installationId: 'device-1',
        accessToken: () async => 'token',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({'accepted': 0, 'rejected': 2, 'code': 'invalid_data'}),
            200,
          ),
        ),
      );

      await expectLater(
        uploader.upload(personalPrayerId: _prayerId, revisionId: _revisionId),
        throwsA(isA<Exception>()),
      );
    },
  );
}

const _prayerId = '0198a000-0000-7000-8000-000000000002';
const _revisionId = '0198a000-0000-7000-8000-000000000003';

Future<void> _seedPrayer(PowerSyncDatabase database) async {
  await database.execute(
    '''
    INSERT INTO personal_prayers(
      id, owner_id, title, style, reach, grounding, purpose,
      current_revision_id, created_at, updated_at, archived_at
    ) VALUES (?, ?, ?, 'daily', 'personal', 'general_christian', 'daily',
      ?, ?, ?, NULL)
    ''',
    [
      _prayerId,
      '0198a000-0000-7000-8000-000000000001',
      'Morning prayer',
      _revisionId,
      '2026-08-13T10:00:00Z',
      '2026-08-13T10:00:00Z',
    ],
  );
  await database.execute(
    '''
    INSERT INTO personal_prayer_revisions(
      id, prayer_id, owner_id, body, action, created_at, device_id
    ) VALUES (?, ?, ?, ?, NULL, ?, ?)
    ''',
    [
      _revisionId,
      _prayerId,
      '0198a000-0000-7000-8000-000000000001',
      'Father, guide me today. Amen.',
      '2026-08-13T10:00:00Z',
      'device-1',
    ],
  );
}
