import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/circles/data/powersync_legacy_circle_migration_repository.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-legacy-circles-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'reads legacy Circle messages locally and discards only on request',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/legacy.db',
      );
      addTearDown(database.close);
      await _seedLegacyCircle(database.powersync, ownerId: 'owner-1');
      final repository = PowerSyncLegacyCircleMigrationRepository(
        database: database.powersync,
        ownerId: 'owner-1',
      );

      final summaries = await repository.list();
      final archive = await repository.read('legacy-circle-1');

      expect(summaries, hasLength(1));
      expect(summaries.single.name, 'Old accountability');
      expect(summaries.single.messageCount, 2);
      expect(archive?.messages.map((item) => item.body), [
        'Please pray for wisdom.',
        'I will check in tomorrow.',
      ]);
      expect(await database.powersync.getNextCrudTransaction(), isNull);

      await repository.discard('legacy-circle-1');

      expect(await repository.list(), isEmpty);
      expect(
        await database.powersync.getAll(
          'SELECT id FROM circle_messages WHERE circle_id = ?',
          ['legacy-circle-1'],
        ),
        isEmpty,
      );
      expect(await database.powersync.getNextCrudTransaction(), isNull);
    },
  );

  test('legacy migration remains owner scoped', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/owner.db',
    );
    addTearDown(database.close);
    await _seedLegacyCircle(database.powersync, ownerId: 'owner-2');
    final repository = PowerSyncLegacyCircleMigrationRepository(
      database: database.powersync,
      ownerId: 'owner-1',
    );

    expect(await repository.list(), isEmpty);
    expect(await repository.read('legacy-circle-1'), isNull);
    await repository.discard('legacy-circle-1');

    expect(
      await database.powersync.getAll('SELECT id FROM circles WHERE id = ?', [
        'legacy-circle-1',
      ]),
      hasLength(1),
    );
  });
}

Future<void> _seedLegacyCircle(
  dynamic database, {
  required String ownerId,
}) async {
  const createdAt = '2026-08-12T08:00:00.000Z';
  await database.execute(
    '''
    INSERT INTO circles(id, owner_id, name, created_at, updated_at, archived_at)
    VALUES (?, ?, ?, ?, ?, NULL)
    ''',
    ['legacy-circle-1', ownerId, 'Old accountability', createdAt, createdAt],
  );
  await database.execute(
    '''
    INSERT INTO circle_members(
      id, circle_id, owner_id, display_name, role, joined_at
    ) VALUES (?, ?, ?, ?, ?, ?)
    ''',
    ['legacy-member-1', 'legacy-circle-1', ownerId, 'Me', 'owner', createdAt],
  );
  for (final message in const [
    ('legacy-message-1', 'Please pray for wisdom.', '2026-08-12T08:01:00.000Z'),
    (
      'legacy-message-2',
      'I will check in tomorrow.',
      '2026-08-12T08:02:00.000Z',
    ),
  ]) {
    await database.execute(
      '''
      INSERT INTO circle_messages(
        id, circle_id, owner_id, body, created_at, device_id, delivery
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        message.$1,
        'legacy-circle-1',
        ownerId,
        message.$2,
        message.$3,
        'device-1',
        'on_this_device',
      ],
    );
  }
}
