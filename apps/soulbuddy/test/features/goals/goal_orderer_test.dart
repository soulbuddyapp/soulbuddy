import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';
import 'package:soulbuddy/features/goals/data/powersync_goal_orderer.dart';
import 'package:soulbuddy/features/goals/data/powersync_goal_repository.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-goal-ordering-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'reorders active Goals atomically without moving paused position slots',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/ordering.db',
      );
      addTearDown(database.close);
      final repository = PowerSyncGoalRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        deviceId: 'device-1',
        now: () => DateTime.utc(2026, 8, 29, 6),
        uuid: const Uuid(),
      );
      final orderer = PowerSyncGoalOrderer(
        database: database.powersync,
        ownerId: 'owner-1',
        now: () => DateTime.utc(2026, 8, 29, 7),
      );

      final first = await repository.create(
        title: 'Grow closer to God',
        mode: GoalMode.mixed,
      );
      final paused = await repository.create(
        title: 'Discern the move',
        mode: GoalMode.mixed,
      );
      final last = await repository.create(
        title: 'Take the next faithful step',
        mode: GoalMode.actionable,
      );
      await repository.setStatus(paused.id, GoalStatus.paused);
      await _completePendingCrud(database.powersync);

      await orderer.reorderActive([last.id, first.id]);

      expect(
        (await repository.watchActive().first).map((goal) => goal.id),
        [last.id, first.id],
      );
      final rows = await database.powersync.getAll(
        'SELECT id, position FROM goals WHERE owner_id = ? ORDER BY position',
        ['owner-1'],
      );
      expect(
        rows.singleWhere((row) => row['id'] == paused.id)['position'],
        1,
      );
      expect(
        rows.singleWhere((row) => row['id'] == last.id)['position'],
        0,
      );
      expect(
        rows.singleWhere((row) => row['id'] == first.id)['position'],
        2,
      );

      final transaction = await database.powersync.getNextCrudTransaction();
      expect(transaction, isNotNull);
      expect(transaction!.crud, hasLength(2));
      expect(transaction.crud.map((entry) => entry.table).toSet(), {'goals'});
      expect(transaction.crud.map((entry) => entry.id).toSet(), {
        first.id,
        last.id,
      });
      await transaction.complete();
    },
  );

  test('stale or duplicate active sets never partially rewrite positions', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/stale.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncGoalRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      uuid: const Uuid(),
    );
    final orderer = PowerSyncGoalOrderer(
      database: database.powersync,
      ownerId: 'owner-1',
    );
    final first = await repository.create(
      title: 'First Goal',
      mode: GoalMode.mixed,
    );
    final second = await repository.create(
      title: 'Second Goal',
      mode: GoalMode.mixed,
    );

    final before = await _positions(database.powersync);
    await expectLater(
      orderer.reorderActive([first.id]),
      throwsA(isA<StateError>()),
    );
    expect(await _positions(database.powersync), before);

    await expectLater(
      orderer.reorderActive([first.id, first.id]),
      throwsA(isA<ArgumentError>()),
    );
    expect(await _positions(database.powersync), before);
    expect(second.id, isNot(first.id));
  });
}

Future<Map<String, int>> _positions(PowerSyncDatabase database) async {
  final rows = await database.getAll(
    'SELECT id, position FROM goals WHERE owner_id = ?',
    ['owner-1'],
  );
  return {
    for (final row in rows)
      row['id'] as String: (row['position'] as num).toInt(),
  };
}

Future<void> _completePendingCrud(PowerSyncDatabase database) async {
  while (true) {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;
    await transaction.complete();
  }
}
