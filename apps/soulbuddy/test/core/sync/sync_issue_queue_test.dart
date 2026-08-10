import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  test('a local sync issue never enters the PowerSync upload queue', () async {
    final directory = await Directory.systemTemp.createTemp(
      'soulbuddy-sync-issues-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final database = await openTestDatabase('${directory.path}/soulbuddy.db');
    addTearDown(database.close);

    await database.powersync.execute(
      '''
      INSERT INTO sync_issues(
        id, record_type, record_id, code, message, created_at, resolved_at
      ) VALUES (?, ?, ?, ?, ?, ?, NULL)
      ''',
      [
        '0198a000-0000-7000-8000-000000000009',
        'encounters',
        '0198a000-0000-7000-8000-000000000002',
        'forbidden',
        'A saved item needs attention before it can sync.',
        '2026-08-10T12:00:00.000Z',
      ],
    );

    expect(await database.powersync.getNextCrudTransaction(), isNull);
  });
}
