import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/goals/data/powersync_goal_repository.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/guards/data/bundled_guard_catalogue.dart';
import 'package:soulbuddy/features/guards/data/powersync_guard_selection_repository.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-guard-selection-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'selected guard survives reopen and updates without duplicates',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/guards.db',
      );
      addTearDown(database.close);
      var now = DateTime.utc(2026, 8, 29, 8);
      final goals = PowerSyncGoalRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        deviceId: 'device-1',
        now: () => now,
        uuid: const Uuid(),
      );
      final repository = PowerSyncGuardSelectionRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        now: () => now,
        uuid: const Uuid(),
      );
      final goal = await goals.create(
        title: 'Stop watching pornography',
        mode: GoalMode.actionable,
        starterKey: GoalStarterKey.stopControl,
      );
      final definition = BundledGuardCatalogue.find('dns-adguard-family')!;

      final first = await repository.select(
        goalId: goal.id,
        definition: definition,
        privateNote: 'Router DNS changed; spouse keeps the admin password.',
      );
      now = now.add(const Duration(minutes: 5));
      final updated = await repository.select(
        goalId: goal.id,
        definition: definition,
        privateNote: 'Router and phone now use the family resolver.',
      );

      expect(updated.id, first.id);
      expect(
        updated.privateNote,
        'Router and phone now use the family resolver.',
      );
      expect(updated.guardContentVersion, definition.contentVersion);
      expect(await repository.watchForGoal(goal.id).first, hasLength(1));
    },
  );

  test('owner isolation and archive keep the selection private', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/owner.db',
    );
    addTearDown(database.close);
    final goals = PowerSyncGoalRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      uuid: const Uuid(),
    );
    final owner = PowerSyncGuardSelectionRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      uuid: const Uuid(),
    );
    final other = PowerSyncGuardSelectionRepository(
      database: database.powersync,
      ownerId: 'owner-2',
      uuid: const Uuid(),
    );
    final goal = await goals.create(
      title: 'Close the door',
      mode: GoalMode.mixed,
    );
    final selection = await owner.select(
      goalId: goal.id,
      definition: BundledGuardCatalogue.find('physical-boundary')!,
    );

    expect(await other.watchForGoal(goal.id).first, isEmpty);
    await expectLater(other.archive(selection.id), throwsStateError);
    await owner.archive(selection.id);
    expect(await owner.watchForGoal(goal.id).first, isEmpty);
  });
}
