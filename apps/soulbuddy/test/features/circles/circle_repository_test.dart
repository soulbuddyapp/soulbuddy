import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/circles/data/powersync_circle_repository.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-circles-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('creates a private Circle with its owner membership', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncCircleRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      now: () => DateTime.utc(2026, 8, 12, 10),
    );

    final circleId = await repository.createCircle('  Family prayer  ');
    final circles = await repository.watchCircles().first;
    final members = await database.powersync.getAll(
      'SELECT circle_id, owner_id, role FROM circle_members',
    );

    expect(circles.single.id, circleId);
    expect(circles.single.name, 'Family prayer');
    expect(circles.single.memberCount, 1);
    expect(members.single['circle_id'], circleId);
    expect(members.single['owner_id'], 'owner-1');
    expect(members.single['role'], 'owner');
    expect(await database.powersync.getNextCrudTransaction(), isNull);
  });

  test('sends ordered messages and keeps them after reopen', () async {
    final path = '${temporaryDirectory.path}/soulbuddy.db';
    final firstDatabase = await openTestDatabase(path);
    final firstRepository = PowerSyncCircleRepository(
      database: firstDatabase.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      now: () => DateTime.utc(2026, 8, 12, 10),
    );
    final circleId = await firstRepository.createCircle('Friends');
    await firstRepository.sendMessage(circleId, 'Please pray for wisdom.');
    await firstDatabase.close();

    final reopenedDatabase = await openTestDatabase(path);
    addTearDown(reopenedDatabase.close);
    final reopenedRepository = PowerSyncCircleRepository(
      database: reopenedDatabase.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
    );

    final circle = await reopenedRepository.watchCircle(circleId).first;
    final messages = await reopenedRepository.watchMessages(circleId).first;

    expect(circle?.name, 'Friends');
    expect(messages.single.body, 'Please pray for wisdom.');
    expect(messages.single.isMine, isTrue);
    expect(messages.single.delivery, CircleMessageDelivery.onThisDevice);
  });

  test('keeps Circles and messages owner-scoped', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);
    final ownerOne = PowerSyncCircleRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
    );
    final ownerTwo = PowerSyncCircleRepository(
      database: database.powersync,
      ownerId: 'owner-2',
      deviceId: 'device-2',
    );
    final circleId = await ownerOne.createCircle('Private');
    await ownerOne.sendMessage(circleId, 'Only mine.');

    expect(await ownerTwo.watchCircles().first, isEmpty);
    expect(await ownerTwo.watchCircle(circleId).first, isNull);
    expect(await ownerTwo.watchMessages(circleId).first, isEmpty);
    await expectLater(
      ownerTwo.sendMessage(circleId, 'Not allowed'),
      throwsA(isA<StateError>()),
    );
  });

  test('validates names and messages before writing', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncCircleRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
    );

    await expectLater(repository.createCircle('   '), throwsArgumentError);
    final circleId = await repository.createCircle('Church family');
    await expectLater(
      repository.sendMessage(circleId, '   '),
      throwsArgumentError,
    );
    await expectLater(
      repository.sendMessage(circleId, 'x' * 2001),
      throwsArgumentError,
    );

    expect(
      await database.powersync.getAll('SELECT id FROM circle_messages'),
      isEmpty,
    );
  });
}
