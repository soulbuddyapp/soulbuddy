import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/commitments/domain/commitment.dart';
import 'package:soulbuddy/features/commitments/data/commitment_reminder_device_repository.dart';
import 'package:soulbuddy/features/commitments/data/powersync_commitment_reminder_device_repository.dart';
import '../../helpers/powersync_test_database.dart';

void main() {
  test(
    'device reminders stay local and isolate accounts and devices',
    () async {
      final dir = await Directory.systemTemp.createTemp('commitment-device-');
      final db = await openTestDatabase('${dir.path}/test.db');
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      final alice = PowerSyncCommitmentReminderDeviceRepository(
        database: db.powersync,
        ownerId: 'alice',
      );
      await alice.save(
        CommitmentReminderDeviceState(
          commitmentId: 'c',
          deviceId: 'a',
          mode: CommitmentReminderMode.voice,
          nextOccurrence: DateTime.utc(2026, 9, 27),
          scheduledTimezone: 'Africa/Lagos',
          notificationIds: [7, 8],
        ),
      );
      expect((await alice.load('c', 'a'))!.notificationIds, [7, 8]);
      expect(await alice.load('c', 'b'), isNull);
      expect(
        await PowerSyncCommitmentReminderDeviceRepository(
          database: db.powersync,
          ownerId: 'bob',
        ).load('c', 'a'),
        isNull,
      );
      expect(await db.powersync.getNextCrudTransaction(), isNull);
      await alice.clear('c', 'a');
      expect(await alice.load('c', 'a'), isNull);
    },
  );
}
