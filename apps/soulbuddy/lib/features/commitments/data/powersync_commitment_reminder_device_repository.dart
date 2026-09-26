import 'dart:convert';
import 'package:powersync/powersync.dart';
import '../domain/commitment.dart';
import 'commitment_reminder_device_repository.dart';

class PowerSyncCommitmentReminderDeviceRepository
    implements CommitmentReminderDeviceRepository {
  PowerSyncCommitmentReminderDeviceRepository({
    required this.database,
    required this.ownerId,
  });
  final PowerSyncDatabase database;
  final String ownerId;
  @override
  Future<CommitmentReminderDeviceState?> load(
    String commitmentId,
    String deviceId,
  ) async {
    final row = await database.getOptional(
      'SELECT * FROM commitment_reminder_devices WHERE owner_id=? AND commitment_id=? AND device_id=?',
      [ownerId, commitmentId, deviceId],
    );
    if (row == null) return null;
    return CommitmentReminderDeviceState(
      commitmentId: commitmentId,
      deviceId: deviceId,
      mode: CommitmentReminderMode.fromWire(row['mode'] as String),
      nextOccurrence: row['next_occurrence'] == null
          ? null
          : DateTime.parse(row['next_occurrence'] as String),
      scheduledTimezone: row['scheduled_timezone'] as String?,
      notificationIds: row['notification_ids'] == null
          ? const []
          : List<int>.from(
              jsonDecode(row['notification_ids'] as String) as List,
            ),
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
    );
  }

  @override
  Future<void> save(CommitmentReminderDeviceState state) async {
    if (state.scheduledTimezone != null) {
      commitmentTimezone(state.scheduledTimezone!);
    }
    if (state.notificationIds.any((id) => id < 0 || id > 2147483647)) {
      throw ArgumentError('Invalid notification identifier');
    }
    await database.execute(
      '''INSERT OR REPLACE INTO commitment_reminder_devices(id,owner_id,commitment_id,device_id,mode,next_occurrence,scheduled_timezone,notification_ids,updated_at) VALUES(?,?,?,?,?,?,?,?,?)''',
      [
        '$ownerId:${state.deviceId}:${state.commitmentId}',
        ownerId,
        state.commitmentId,
        state.deviceId,
        state.mode.wireValue,
        state.nextOccurrence?.toUtc().toIso8601String(),
        state.scheduledTimezone,
        jsonEncode(state.notificationIds),
        (state.updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
      ],
    );
  }

  @override
  Future<void> clear(String commitmentId, String deviceId) async {
    await database.execute(
      'DELETE FROM commitment_reminder_devices WHERE owner_id=? AND commitment_id=? AND device_id=?',
      [ownerId, commitmentId, deviceId],
    );
  }
}
