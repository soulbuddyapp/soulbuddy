import 'package:powersync/powersync.dart';
import 'package:powersync/sqlite_async.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;
import 'package:uuid/uuid.dart';

import '../domain/prayer_reminder.dart';
import '../domain/prayer_session.dart';
import 'prayer_practice_repository.dart';

class PowerSyncPrayerPracticeRepository implements PrayerPracticeRepository {
  PowerSyncPrayerPracticeRepository({
    required this.database,
    required this.ownerId,
    required this.deviceId,
    DateTime Function()? now,
    Uuid? uuid,
  }) : _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid() {
    if (ownerId.trim().isEmpty || deviceId.trim().isEmpty) {
      throw ArgumentError('Owner and device identifiers are required');
    }
  }

  final PowerSyncDatabase database;
  final String ownerId;
  final String deviceId;
  final DateTime Function() _now;
  final Uuid _uuid;

  @override
  Stream<PrayerReminder?> watchReminder(String personalPrayerId) {
    return database
        .watch(
          '''
          SELECT * FROM prayer_reminders
          WHERE owner_id = ? AND personal_prayer_id = ?
            AND enabled = 1 AND archived_at IS NULL
          LIMIT 1
          ''',
          parameters: [ownerId, personalPrayerId],
        )
        .map(
          (rows) => rows.isEmpty ? null : PrayerReminder.fromRow(rows.single),
        );
  }

  @override
  Stream<PrayerReminderDevice?> watchDevice(String reminderId) {
    return database
        .watch(
          '''
          SELECT device.*
          FROM prayer_reminder_devices AS device
          JOIN prayer_reminders AS reminder ON reminder.id = device.reminder_id
          WHERE device.reminder_id = ? AND device.device_id = ?
            AND reminder.owner_id = ?
          LIMIT 1
          ''',
          parameters: [reminderId, deviceId, ownerId],
        )
        .map(
          (rows) =>
              rows.isEmpty ? null : PrayerReminderDevice.fromRow(rows.single),
        );
  }

  @override
  Stream<List<DuePrayerOccurrence>> watchDue(DateTime atUtc) {
    return database
        .watch(
          '''
          SELECT
            reminder.id AS reminder_id_value,
            reminder.owner_id AS reminder_owner_id,
            reminder.personal_prayer_id AS reminder_prayer_id,
            reminder.schedule_type,
            reminder.local_time,
            reminder.timezone,
            reminder.once_at,
            reminder.weekdays_mask,
            reminder.enabled,
            reminder.created_at AS reminder_created_at,
            reminder.updated_at AS reminder_updated_at,
            reminder.archived_at AS reminder_archived_at,
            device.id AS device_row_id,
            device.device_id,
            device.enabled_on_device,
            device.next_occurrence_at,
            device.platform_notification_id,
            device.scheduled_timezone,
            device.snoozed_until,
            device.dismissed_occurrence_key,
            device.updated_at AS device_updated_at,
            prayer.title AS prayer_title,
            revision.body AS prayer_body,
            prayer.current_revision_id
          FROM prayer_reminder_devices AS device
          JOIN prayer_reminders AS reminder ON reminder.id = device.reminder_id
          JOIN personal_prayers AS prayer
            ON prayer.id = reminder.personal_prayer_id
           AND prayer.owner_id = reminder.owner_id
          JOIN personal_prayer_revisions AS revision
            ON revision.id = prayer.current_revision_id
           AND revision.prayer_id = prayer.id
           AND revision.owner_id = prayer.owner_id
          WHERE reminder.owner_id = ? AND device.device_id = ?
            AND reminder.enabled = 1 AND reminder.archived_at IS NULL
            AND prayer.archived_at IS NULL AND device.enabled_on_device = 1
            AND COALESCE(device.snoozed_until, device.next_occurrence_at) <= ?
          ORDER BY COALESCE(device.snoozed_until, device.next_occurrence_at), reminder.id
          ''',
          parameters: [ownerId, deviceId, atUtc.toUtc().toIso8601String()],
        )
        .map((rows) => List.unmodifiable(rows.map(_dueOccurrenceFromRow)));
  }

  @override
  Stream<int> watchSessionCount(String revisionId) {
    return database
        .watch(
          '''
          SELECT COUNT(*) AS session_count
          FROM prayer_sessions
          WHERE owner_id = ? AND prayer_revision_id = ? AND retracted_at IS NULL
          ''',
          parameters: [ownerId, revisionId],
        )
        .map((rows) => rows.single['session_count'] as int);
  }

  @override
  Future<PrayerReminder> saveReminder({
    required String personalPrayerId,
    required PrayerReminderSchedule schedule,
    required bool enableOnThisDevice,
  }) {
    return database.writeTransaction((transaction) async {
      final prayer = await transaction.getOptional(
        '''
        SELECT id FROM personal_prayers
        WHERE id = ? AND owner_id = ? AND archived_at IS NULL
          AND current_revision_id IS NOT NULL
        LIMIT 1
        ''',
        [personalPrayerId, ownerId],
      );
      if (prayer == null) {
        throw StateError('Saved prayer is unavailable');
      }

      final existing = await transaction.getOptional(
        '''
        SELECT * FROM prayer_reminders
        WHERE owner_id = ? AND personal_prayer_id = ?
        LIMIT 1
        ''',
        [ownerId, personalPrayerId],
      );
      final now = _now().toUtc().toIso8601String();
      final id = existing?['id'] as String? ?? _uuid.v7();
      if (existing == null) {
        await transaction.execute(
          '''
          INSERT INTO prayer_reminders(
            id, owner_id, personal_prayer_id, schedule_type, local_time,
            timezone, once_at, weekdays_mask, enabled, created_at, updated_at,
            archived_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, NULL)
          ''',
          [
            id,
            ownerId,
            personalPrayerId,
            schedule.type.wireValue,
            schedule.localTime.wireValue,
            schedule.timezone,
            schedule.onceAt?.toUtc().toIso8601String(),
            schedule.weekdaysMask,
            now,
            now,
          ],
        );
      } else {
        await transaction.execute(
          '''
          UPDATE prayer_reminders
          SET schedule_type = ?, local_time = ?, timezone = ?, once_at = ?,
              weekdays_mask = ?, enabled = 1, updated_at = ?, archived_at = NULL
          WHERE id = ? AND owner_id = ?
          ''',
          [
            schedule.type.wireValue,
            schedule.localTime.wireValue,
            schedule.timezone,
            schedule.onceAt?.toUtc().toIso8601String(),
            schedule.weekdaysMask,
            now,
            id,
            ownerId,
          ],
        );
      }
      await _upsertDevice(
        transaction,
        reminderId: id,
        enabled: enableOnThisDevice,
        now: now,
      );
      final saved = await transaction.get(
        'SELECT * FROM prayer_reminders WHERE id = ? AND owner_id = ?',
        [id, ownerId],
      );
      return PrayerReminder.fromRow(saved);
    });
  }

  @override
  Future<void> archiveReminder(String reminderId) {
    return database.writeTransaction((transaction) async {
      await _requireReminder(transaction, reminderId);
      final now = _now().toUtc().toIso8601String();
      await transaction.execute(
        '''
        UPDATE prayer_reminders
        SET enabled = 0, archived_at = ?, updated_at = ?
        WHERE id = ? AND owner_id = ? AND archived_at IS NULL
        ''',
        [now, now, reminderId, ownerId],
      );
      await transaction.execute(
        '''
        UPDATE prayer_reminder_devices
        SET enabled_on_device = 0, next_occurrence_at = NULL,
            snoozed_until = NULL, updated_at = ?
        WHERE reminder_id = ? AND device_id = ?
        ''',
        [now, reminderId, deviceId],
      );
    });
  }

  @override
  Future<void> setDeviceEnabled(String reminderId, {required bool enabled}) {
    return database.writeTransaction((transaction) async {
      await _requireReminder(transaction, reminderId);
      await _upsertDevice(
        transaction,
        reminderId: reminderId,
        enabled: enabled,
        now: _now().toUtc().toIso8601String(),
      );
    });
  }

  @override
  Future<void> updateDeviceSchedule({
    required String reminderId,
    required DateTime? nextOccurrenceAt,
    required int platformNotificationId,
    required String scheduledTimezone,
  }) {
    return database.writeTransaction((transaction) async {
      await _requireReminder(transaction, reminderId);
      final now = _now().toUtc().toIso8601String();
      await _upsertDevice(
        transaction,
        reminderId: reminderId,
        enabled: true,
        now: now,
      );
      await transaction.execute(
        '''
        UPDATE prayer_reminder_devices
        SET next_occurrence_at = ?, platform_notification_id = ?,
            scheduled_timezone = ?, snoozed_until = NULL,
            dismissed_occurrence_key = NULL, updated_at = ?
        WHERE reminder_id = ? AND device_id = ?
        ''',
        [
          nextOccurrenceAt?.toUtc().toIso8601String(),
          platformNotificationId,
          scheduledTimezone,
          now,
          reminderId,
          deviceId,
        ],
      );
    });
  }

  @override
  Future<void> snooze(String reminderId, DateTime untilUtc) {
    return _updateOwnedDevice(
      reminderId,
      'snoozed_until = ?, dismissed_occurrence_key = NULL',
      [untilUtc.toUtc().toIso8601String()],
    );
  }

  @override
  Future<void> dismiss(String reminderId, String occurrenceKey) {
    if (occurrenceKey.trim().isEmpty || occurrenceKey.length > 160) {
      throw ArgumentError.value(occurrenceKey, 'occurrenceKey');
    }
    return _updateOwnedDevice(
      reminderId,
      'dismissed_occurrence_key = ?, snoozed_until = NULL',
      [occurrenceKey],
    );
  }

  @override
  Future<PrayerSession> recordSession({
    required String personalPrayerId,
    required String revisionId,
    required String timezone,
    String? reminderId,
    String? occurrenceKey,
  }) {
    final isReminder = reminderId != null || occurrenceKey != null;
    if (isReminder &&
        (reminderId == null ||
            occurrenceKey == null ||
            occurrenceKey.trim().isEmpty ||
            occurrenceKey.length > 160)) {
      throw ArgumentError('Reminder sessions require reminder and occurrence');
    }
    if (timezone.trim().isEmpty || timezone.length > 64) {
      throw ArgumentError.value(timezone, 'timezone');
    }

    return database.writeTransaction((transaction) async {
      final prayer = await transaction.getOptional(
        '''
        SELECT id, current_revision_id FROM personal_prayers
        WHERE id = ? AND owner_id = ? AND archived_at IS NULL
        LIMIT 1
        ''',
        [personalPrayerId, ownerId],
      );
      if (prayer == null || prayer['current_revision_id'] != revisionId) {
        throw StateError('Displayed prayer revision is no longer current');
      }
      if (isReminder) {
        final reminder = await transaction.getOptional(
          '''
          SELECT id FROM prayer_reminders
          WHERE id = ? AND owner_id = ? AND personal_prayer_id = ?
            AND enabled = 1 AND archived_at IS NULL
          LIMIT 1
          ''',
          [reminderId, ownerId, personalPrayerId],
        );
        if (reminder == null) {
          throw StateError('Prayer reminder is unavailable');
        }
      }

      final id = isReminder
          ? _uuid.v5(
              Namespace.url.value,
              'soulbuddy:prayer-session:$reminderId:$occurrenceKey',
            )
          : _uuid.v7();
      final existing = await transaction.getOptional(
        'SELECT * FROM prayer_sessions WHERE id = ? AND owner_id = ?',
        [id, ownerId],
      );
      if (existing != null) {
        final session = PrayerSession.fromRow(existing);
        if (session.personalPrayerId != personalPrayerId ||
            session.prayerRevisionId != revisionId ||
            session.reminderId != reminderId ||
            session.reminderOccurrenceKey != occurrenceKey) {
          throw StateError('Prayer session identity conflict');
        }
        return session;
      }

      final occurredAt = _now().toUtc();
      final localDate = _localDateInZone(occurredAt, timezone.trim());
      await transaction.execute(
        '''
        INSERT INTO prayer_sessions(
          id, owner_id, personal_prayer_id, prayer_revision_id, reminder_id,
          reminder_occurrence_key, source, occurred_at, local_date, timezone,
          device_id, retracted_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
        ''',
        [
          id,
          ownerId,
          personalPrayerId,
          revisionId,
          reminderId,
          occurrenceKey,
          isReminder
              ? PrayerSessionSource.reminder.wireValue
              : PrayerSessionSource.manual.wireValue,
          occurredAt.toIso8601String(),
          localDate,
          timezone.trim(),
          deviceId,
        ],
      );
      return PrayerSession.fromRow(
        await transaction.get('SELECT * FROM prayer_sessions WHERE id = ?', [
          id,
        ]),
      );
    });
  }

  @override
  Future<void> retractSession(String sessionId) {
    return database.writeTransaction((transaction) async {
      final row = await transaction.getOptional(
        'SELECT * FROM prayer_sessions WHERE id = ? AND owner_id = ? LIMIT 1',
        [sessionId, ownerId],
      );
      if (row == null) {
        throw StateError('Prayer session is unavailable');
      }
      final session = PrayerSession.fromRow(row);
      if (session.retractedAt != null) {
        return;
      }
      final now = _now();
      if (!session.canRetract(now)) {
        throw StateError('Prayer session can no longer be undone');
      }
      await transaction.execute(
        '''
        UPDATE prayer_sessions SET retracted_at = ?
        WHERE id = ? AND owner_id = ? AND retracted_at IS NULL
        ''',
        [now.toUtc().toIso8601String(), sessionId, ownerId],
      );
    });
  }

  Future<void> _requireReminder(
    SqliteWriteContext transaction,
    String reminderId,
  ) async {
    final reminder = await transaction.getOptional(
      '''
      SELECT id FROM prayer_reminders
      WHERE id = ? AND owner_id = ? AND enabled = 1 AND archived_at IS NULL
      LIMIT 1
      ''',
      [reminderId, ownerId],
    );
    if (reminder == null) {
      throw StateError('Prayer reminder is unavailable');
    }
  }

  Future<void> _upsertDevice(
    SqliteWriteContext transaction, {
    required String reminderId,
    required bool enabled,
    required String now,
  }) async {
    final id = _deviceRowId(reminderId);
    final existing = await transaction.getOptional(
      'SELECT id FROM prayer_reminder_devices WHERE id = ?',
      [id],
    );
    if (existing == null) {
      await transaction.execute(
        '''
        INSERT INTO prayer_reminder_devices(
          id, reminder_id, device_id, enabled_on_device, next_occurrence_at,
          platform_notification_id, scheduled_timezone, snoozed_until,
          dismissed_occurrence_key, updated_at
        ) VALUES (?, ?, ?, ?, NULL, ?, NULL, NULL, NULL, ?)
        ''',
        [id, reminderId, deviceId, enabled ? 1 : 0, _notificationId(id), now],
      );
      return;
    }
    await transaction.execute(
      '''
      UPDATE prayer_reminder_devices
      SET enabled_on_device = ?, updated_at = ?
      WHERE id = ? AND device_id = ?
      ''',
      [enabled ? 1 : 0, now, id, deviceId],
    );
  }

  Future<void> _updateOwnedDevice(
    String reminderId,
    String assignment,
    List<Object?> values,
  ) {
    return database.writeTransaction((transaction) async {
      await _requireReminder(transaction, reminderId);
      final device = await transaction.getOptional(
        '''
        SELECT id FROM prayer_reminder_devices
        WHERE reminder_id = ? AND device_id = ? AND enabled_on_device = 1
        LIMIT 1
        ''',
        [reminderId, deviceId],
      );
      if (device == null) {
        throw StateError('Prayer reminder is not enabled on this device');
      }
      await transaction.execute(
        '''
        UPDATE prayer_reminder_devices
        SET $assignment, updated_at = ?
        WHERE reminder_id = ? AND device_id = ? AND enabled_on_device = 1
        ''',
        [...values, _now().toUtc().toIso8601String(), reminderId, deviceId],
      );
    });
  }

  String _deviceRowId(String reminderId) => _uuid.v5(
    Namespace.url.value,
    'soulbuddy:reminder-device:$reminderId:$deviceId',
  );

  int _notificationId(String deviceRowId) =>
      int.parse(deviceRowId.replaceAll('-', '').substring(0, 8), radix: 16) &
      0x7fffffff;

  DuePrayerOccurrence _dueOccurrenceFromRow(Map<String, dynamic> row) {
    final reminder = PrayerReminder.fromRow({
      'id': row['reminder_id_value'],
      'owner_id': row['reminder_owner_id'],
      'personal_prayer_id': row['reminder_prayer_id'],
      'schedule_type': row['schedule_type'],
      'local_time': row['local_time'],
      'timezone': row['timezone'],
      'once_at': row['once_at'],
      'weekdays_mask': row['weekdays_mask'],
      'enabled': row['enabled'],
      'created_at': row['reminder_created_at'],
      'updated_at': row['reminder_updated_at'],
      'archived_at': row['reminder_archived_at'],
    });
    final device = PrayerReminderDevice.fromRow({
      'id': row['device_row_id'],
      'reminder_id': row['reminder_id_value'],
      'device_id': row['device_id'],
      'enabled_on_device': row['enabled_on_device'],
      'next_occurrence_at': row['next_occurrence_at'],
      'platform_notification_id': row['platform_notification_id'],
      'scheduled_timezone': row['scheduled_timezone'],
      'snoozed_until': row['snoozed_until'],
      'dismissed_occurrence_key': row['dismissed_occurrence_key'],
      'updated_at': row['device_updated_at'],
    });
    final occurrenceAt = device.snoozedUntil ?? device.nextOccurrenceAt;
    if (occurrenceAt == null) {
      throw StateError('Due prayer occurrence has no time');
    }
    return DuePrayerOccurrence(
      reminder: reminder,
      device: device,
      prayerTitle: row['prayer_title'] as String,
      prayerBody: row['prayer_body'] as String,
      prayerRevisionId: row['current_revision_id'] as String,
      occurrenceAt: occurrenceAt,
    );
  }
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

bool _timezonesInitialized = false;

String _localDateInZone(DateTime occurredAt, String timezoneName) {
  if (!_timezonesInitialized) {
    timezone_data.initializeTimeZones();
    _timezonesInitialized = true;
  }
  final location = timezone.getLocation(timezoneName);
  return _dateOnly(timezone.TZDateTime.from(occurredAt, location));
}
