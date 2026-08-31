import 'package:powersync/powersync.dart';
import 'package:powersync/sqlite_async.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;
import 'package:uuid/uuid.dart';

import '../../prayers/domain/prayer_reference.dart';
import '../domain/sacred_hour.dart';
import 'sacred_hour_repository.dart';

class PowerSyncSacredHourRepository implements SacredHourRepository {
  PowerSyncSacredHourRepository({
    required this.database,
    required String ownerId,
    required String deviceId,
    DateTime Function()? now,
    Uuid? uuid,
  }) : ownerId = _identifier(ownerId, 'ownerId'),
       deviceId = _identifier(deviceId, 'deviceId'),
       _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid() {
    timezone_data.initializeTimeZones();
  }

  final PowerSyncDatabase database;
  final String ownerId;
  final String deviceId;
  final DateTime Function() _now;
  final Uuid _uuid;

  @override
  Stream<List<SacredHour>> watchAll() => database
      .watch(
        '''
        SELECT * FROM sacred_hours
        WHERE owner_id = ? AND archived_at IS NULL
        ORDER BY local_time, id
        ''',
        parameters: [ownerId],
      )
      .map((rows) => rows.map(SacredHour.fromRow).toList(growable: false));

  @override
  Stream<List<SacredHour>> watchActive() => database
      .watch(
        '''
        SELECT * FROM sacred_hours
        WHERE owner_id = ? AND enabled = 1 AND archived_at IS NULL
        ORDER BY local_time, id
        ''',
        parameters: [ownerId],
      )
      .map((rows) => rows.map(SacredHour.fromRow).toList(growable: false));

  @override
  Stream<SacredHour?> watch(String id) => database
      .watch(
        '''
        SELECT * FROM sacred_hours
        WHERE id = ? AND owner_id = ? AND archived_at IS NULL
        LIMIT 1
        ''',
        parameters: [id, ownerId],
      )
      .map((rows) => rows.isEmpty ? null : SacredHour.fromRow(rows.single));

  @override
  Stream<SacredHour?> watchCurrentOrNext(DateTime nowUtc) =>
      watchActive().map((hours) => _currentOrNext(hours, nowUtc.toUtc()));

  @override
  Stream<List<SacredHourDelivery>> watchDeliveries() => database
      .watch(
        '''
        SELECT device.*, hour.enabled AS hour_enabled,
               hour.archived_at AS hour_archived_at
        FROM sacred_hour_devices AS device
        JOIN sacred_hours AS hour ON hour.id = device.sacred_hour_id
        WHERE hour.owner_id = ? AND device.device_id = ?
        ORDER BY hour.local_time, hour.id
        ''',
        parameters: [ownerId, deviceId],
      )
      .map(
        (rows) => rows
            .map((row) {
              final delivery = SacredHourDelivery.fromRow(row);
              return SacredHourDelivery(
                sacredHourId: delivery.sacredHourId,
                enabledOnDevice:
                    delivery.enabledOnDevice &&
                    row['hour_enabled'] == 1 &&
                    row['hour_archived_at'] == null,
                reminderMode: delivery.reminderMode,
                nextOccurrenceAt: delivery.nextOccurrenceAt,
                platformNotificationId: delivery.platformNotificationId,
                scheduledTimezone: delivery.scheduledTimezone,
                snoozedUntil: delivery.snoozedUntil,
                dismissedOccurrenceKey: delivery.dismissedOccurrenceKey,
                updatedAt: delivery.updatedAt,
              );
            })
            .toList(growable: false),
      );

  @override
  Future<List<SacredHour>> ensureDefaults({required String timezone}) {
    final morning = SacredHour.defaultMorning(
      ownerId: ownerId,
      timezone: timezone,
      now: _now(),
    );
    final evening = SacredHour.defaultEvening(
      ownerId: ownerId,
      timezone: timezone,
      now: _now(),
    );
    return database.writeTransaction((transaction) async {
      for (final hour in [morning, evening]) {
        await _insertDefault(transaction, hour);
        final stored = SacredHour.fromRow(
          await transaction.get(
            'SELECT * FROM sacred_hours WHERE id = ? AND owner_id = ?',
            [hour.id, ownerId],
          ),
        );
        await _ensureDefaultDelivery(transaction, stored);
      }
      final rows = await transaction.getAll(
        '''
        SELECT * FROM sacred_hours
        WHERE owner_id = ? AND purpose_key IN ('morning', 'evening')
          AND archived_at IS NULL
        ORDER BY local_time, id
        ''',
        [ownerId],
      );
      return rows.map(SacredHour.fromRow).toList(growable: false);
    });
  }

  @override
  Future<SacredHour> save(SacredHourDraft draft, {String? id}) {
    return database.writeTransaction((transaction) async {
      await _requireLinks(transaction, draft);
      final now = _now().toUtc();
      final nowWire = now.toIso8601String();
      final hourId = id == null ? _uuid.v7() : _identifier(id, 'sacredHourId');
      Map<String, dynamic>? existing;
      if (id != null) {
        existing = await _requireHour(transaction, hourId);
      }
      final prayerType = draft.prayer?.source.name;
      final values = <Object?>[
        draft.purpose.wireValue,
        draft.name,
        draft.localTime.wireValue,
        draft.timezone,
        draft.durationMinutes,
        draft.prayerMinutes,
        draft.enabled ? 1 : 0,
        draft.sound.wireValue,
        prayerType,
        draft.prayer?.id,
        draft.personId,
      ];
      if (existing == null) {
        await transaction.execute(
          '''
          INSERT INTO sacred_hours(
            id, owner_id, purpose_key, name, local_time, timezone,
            duration_minutes, prayer_minutes, enabled, sound_key,
            prayer_type, prayer_id, person_id, created_at, updated_at,
            archived_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
          ''',
          [hourId, ownerId, ...values, nowWire, nowWire],
        );
      } else {
        await transaction.execute(
          '''
          UPDATE sacred_hours
          SET purpose_key = ?, name = ?, local_time = ?, timezone = ?,
              duration_minutes = ?, prayer_minutes = ?, enabled = ?,
              sound_key = ?, prayer_type = ?, prayer_id = ?, person_id = ?,
              updated_at = ?
          WHERE id = ? AND owner_id = ? AND archived_at IS NULL
          ''',
          [...values, nowWire, hourId, ownerId],
        );
      }
      final row = await transaction.get(
        'SELECT * FROM sacred_hours WHERE id = ? AND owner_id = ?',
        [hourId, ownerId],
      );
      final hour = SacredHour.fromRow(row);
      await _refreshDelivery(transaction, hour);
      return hour;
    });
  }

  @override
  Future<void> setEnabled(String id, bool enabled) {
    return database.writeTransaction((transaction) async {
      final row = await _requireHour(transaction, id);
      final hour = SacredHour.fromRow(row);
      final nowWire = _now().toUtc().toIso8601String();
      await transaction.execute(
        '''
        UPDATE sacred_hours SET enabled = ?, updated_at = ?
        WHERE id = ? AND owner_id = ? AND archived_at IS NULL
        ''',
        [enabled ? 1 : 0, nowWire, id, ownerId],
      );
      final device = await transaction.getOptional(
        'SELECT id FROM sacred_hour_devices WHERE sacred_hour_id = ? AND device_id = ?',
        [id, deviceId],
      );
      if (device == null && enabled) {
        await _ensureDefaultDelivery(transaction, hour, enabledOverride: true);
      } else if (device != null) {
        await transaction.execute(
          '''
          UPDATE sacred_hour_devices
          SET enabled_on_device = ?, next_occurrence_at = ?, updated_at = ?
          WHERE sacred_hour_id = ? AND device_id = ?
          ''',
          [
            enabled ? 1 : 0,
            enabled
                ? _nextOccurrence(hour, _now().toUtc()).toIso8601String()
                : null,
            nowWire,
            id,
            deviceId,
          ],
        );
      }
    });
  }

  @override
  Future<void> archive(String id) {
    return database.writeTransaction((transaction) async {
      await _requireHour(transaction, id);
      final nowWire = _now().toUtc().toIso8601String();
      await transaction.execute(
        '''
        UPDATE sacred_hours
        SET enabled = 0, archived_at = ?, updated_at = ?
        WHERE id = ? AND owner_id = ?
        ''',
        [nowWire, nowWire, id, ownerId],
      );
      await transaction.execute(
        '''
        UPDATE sacred_hour_devices
        SET enabled_on_device = 0, next_occurrence_at = NULL,
            snoozed_until = NULL, updated_at = ?
        WHERE sacred_hour_id = ? AND device_id = ?
        ''',
        [nowWire, id, deviceId],
      );
    });
  }

  @override
  Future<void> updateDeviceDelivery(String id, SacredHourDeviceDraft draft) {
    return database.writeTransaction((transaction) async {
      await _requireHour(transaction, id);
      final deliveryId = _deliveryId(id);
      final nowWire = _now().toUtc().toIso8601String();
      final existing = await transaction.getOptional(
        'SELECT id FROM sacred_hour_devices WHERE id = ?',
        [deliveryId],
      );
      final values = <Object?>[
        draft.enabledOnDevice ? 1 : 0,
        draft.reminderMode.wireValue,
        draft.nextOccurrenceAt?.toUtc().toIso8601String(),
        draft.platformNotificationId,
        draft.scheduledTimezone,
        draft.snoozedUntil?.toUtc().toIso8601String(),
        draft.dismissedOccurrenceKey,
        nowWire,
      ];
      if (existing == null) {
        await transaction.execute(
          '''
          INSERT INTO sacred_hour_devices(
            id, sacred_hour_id, device_id, enabled_on_device, reminder_mode,
            next_occurrence_at, platform_notification_id, scheduled_timezone,
            snoozed_until, dismissed_occurrence_key, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [deliveryId, id, deviceId, ...values],
        );
      } else {
        await transaction.execute(
          '''
          UPDATE sacred_hour_devices
          SET enabled_on_device = ?, reminder_mode = ?,
              next_occurrence_at = ?, platform_notification_id = ?,
              scheduled_timezone = ?, snoozed_until = ?,
              dismissed_occurrence_key = ?, updated_at = ?
          WHERE id = ? AND device_id = ?
          ''',
          [...values, deliveryId, deviceId],
        );
      }
    });
  }

  @override
  Future<void> markOccurrence(
    String id,
    DateTime dueAt,
    SacredHourOccurrenceStatus status, {
    String? prayerSessionId,
  }) {
    return database.writeTransaction((transaction) async {
      final hour = SacredHour.fromRow(await _requireHour(transaction, id));
      final sessionId = prayerSessionId == null
          ? null
          : _identifier(prayerSessionId, 'prayerSessionId');
      final dueUtc = dueAt.toUtc();
      final dueWire = dueUtc.toIso8601String();
      final occurrenceId = _uuid.v5(
        Namespace.url.value,
        'soulbuddy:sacred-hour-occurrence:$id:$dueWire',
      );
      final nowWire = _now().toUtc().toIso8601String();
      final existing = await transaction.getOptional(
        'SELECT id FROM sacred_hour_occurrences WHERE id = ? AND owner_id = ?',
        [occurrenceId, ownerId],
      );
      if (existing == null) {
        await transaction.execute(
          '''
          INSERT INTO sacred_hour_occurrences(
            id, owner_id, sacred_hour_id, due_at, local_date, status,
            prayer_session_id, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            occurrenceId,
            ownerId,
            id,
            dueWire,
            _localDate(dueUtc, hour.timezone),
            status.wireValue,
            sessionId,
            nowWire,
            nowWire,
          ],
        );
      } else {
        await transaction.execute(
          '''
          UPDATE sacred_hour_occurrences
          SET status = ?, prayer_session_id = COALESCE(?, prayer_session_id),
              updated_at = ?
          WHERE id = ? AND owner_id = ? AND sacred_hour_id = ?
          ''',
          [status.wireValue, sessionId, nowWire, occurrenceId, ownerId, id],
        );
      }
    });
  }

  Future<void> _insertDefault(
    SqliteWriteContext transaction,
    SacredHour hour,
  ) async {
    final existing = await transaction.getOptional(
      'SELECT id FROM sacred_hours WHERE id = ? AND owner_id = ?',
      [hour.id, ownerId],
    );
    if (existing != null) return;
    await transaction.execute(
      '''
      INSERT INTO sacred_hours(
        id, owner_id, purpose_key, name, local_time, timezone,
        duration_minutes, prayer_minutes, enabled, sound_key, prayer_type,
        prayer_id, person_id, created_at, updated_at, archived_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, ?, ?, NULL)
      ''',
      [
        hour.id,
        ownerId,
        hour.purpose.wireValue,
        hour.name,
        hour.localTime.wireValue,
        hour.timezone,
        hour.durationMinutes,
        hour.prayerMinutes,
        hour.enabled ? 1 : 0,
        hour.sound.wireValue,
        hour.createdAt.toIso8601String(),
        hour.updatedAt.toIso8601String(),
      ],
    );
  }

  Future<void> _ensureDefaultDelivery(
    SqliteWriteContext transaction,
    SacredHour hour, {
    bool? enabledOverride,
  }) async {
    final id = _deliveryId(hour.id);
    final existing = await transaction.getOptional(
      'SELECT id FROM sacred_hour_devices WHERE id = ?',
      [id],
    );
    if (existing != null) return;
    final now = _now().toUtc();
    final enabled = enabledOverride ?? hour.enabled;
    await transaction.execute(
      '''
      INSERT INTO sacred_hour_devices(
        id, sacred_hour_id, device_id, enabled_on_device, reminder_mode,
        next_occurrence_at, platform_notification_id, scheduled_timezone,
        snoozed_until, dismissed_occurrence_key, updated_at
      ) VALUES (?, ?, ?, ?, 'ordinary', ?, ?, ?, NULL, NULL, ?)
      ''',
      [
        id,
        hour.id,
        deviceId,
        enabled ? 1 : 0,
        enabled ? _nextOccurrence(hour, now).toIso8601String() : null,
        _notificationId(id),
        hour.timezone,
        now.toIso8601String(),
      ],
    );
  }

  Future<void> _refreshDelivery(
    SqliteWriteContext transaction,
    SacredHour hour,
  ) async {
    final existing = await transaction.getOptional(
      '''
      SELECT enabled_on_device FROM sacred_hour_devices
      WHERE id = ? AND device_id = ?
      ''',
      [_deliveryId(hour.id), deviceId],
    );
    if (existing == null) {
      await _ensureDefaultDelivery(transaction, hour);
      return;
    }
    final enabled = hour.enabled && existing['enabled_on_device'] == 1;
    final now = _now().toUtc();
    await transaction.execute(
      '''
      UPDATE sacred_hour_devices
      SET next_occurrence_at = ?, scheduled_timezone = ?,
          snoozed_until = NULL, dismissed_occurrence_key = NULL,
          updated_at = ?
      WHERE id = ? AND device_id = ?
      ''',
      [
        enabled ? _nextOccurrence(hour, now).toIso8601String() : null,
        hour.timezone,
        now.toIso8601String(),
        _deliveryId(hour.id),
        deviceId,
      ],
    );
  }

  Future<void> _requireLinks(
    SqliteWriteContext transaction,
    SacredHourDraft draft,
  ) async {
    final prayer = draft.prayer;
    if (prayer != null) {
      final prayerRow = switch (prayer.source) {
        PrayerSource.personal => await transaction.getOptional(
          '''
          SELECT id FROM personal_prayers
          WHERE id = ? AND owner_id = ? AND archived_at IS NULL LIMIT 1
          ''',
          [prayer.id, ownerId],
        ),
        PrayerSource.library => await transaction.getOptional(
          '''
          SELECT id FROM library_prayers
          WHERE id = ? AND published_at IS NOT NULL AND archived_at IS NULL
          UNION ALL
          SELECT id FROM bundled_prayers
          WHERE id = ? AND archived_at IS NULL
          LIMIT 1
          ''',
          [prayer.id, prayer.id],
        ),
      };
      if (prayerRow == null) {
        throw StateError('The selected prayer is unavailable.');
      }
    }
    final personId = draft.personId;
    if (personId != null) {
      final person = await transaction.getOptional(
        '''
        SELECT id FROM prayer_people
        WHERE id = ? AND owner_id = ? AND archived_at IS NULL LIMIT 1
        ''',
        [personId, ownerId],
      );
      if (person == null) {
        throw StateError('The selected Person is unavailable.');
      }
    }
  }

  Future<Map<String, dynamic>> _requireHour(
    SqliteWriteContext transaction,
    String id,
  ) async {
    final row = await transaction.getOptional(
      '''
      SELECT * FROM sacred_hours
      WHERE id = ? AND owner_id = ? AND archived_at IS NULL LIMIT 1
      ''',
      [id, ownerId],
    );
    if (row == null) throw StateError('The Sacred Hour is unavailable.');
    return row;
  }

  SacredHour? _currentOrNext(List<SacredHour> hours, DateTime nowUtc) {
    if (hours.isEmpty) return null;
    final candidates = hours.map((hour) {
      final location = timezone.getLocation(hour.timezone);
      final localNow = timezone.TZDateTime.from(nowUtc, location);
      final todayStart = timezone.TZDateTime(
        location,
        localNow.year,
        localNow.month,
        localNow.day,
        hour.localTime.hour,
        hour.localTime.minute,
      );
      final todayEnd = todayStart.add(Duration(minutes: hour.durationMinutes));
      final previousStart = timezone.TZDateTime(
        location,
        localNow.year,
        localNow.month,
        localNow.day - 1,
        hour.localTime.hour,
        hour.localTime.minute,
      );
      final previousEnd = previousStart.add(
        Duration(minutes: hour.durationMinutes),
      );
      final currentToday =
          !nowUtc.isBefore(todayStart.toUtc()) &&
          nowUtc.isBefore(todayEnd.toUtc());
      final currentPrevious =
          !nowUtc.isBefore(previousStart.toUtc()) &&
          nowUtc.isBefore(previousEnd.toUtc());
      final current = currentToday || currentPrevious;
      final nextStart = current || todayStart.toUtc().isAfter(nowUtc)
          ? (currentPrevious ? previousStart.toUtc() : todayStart.toUtc())
          : timezone.TZDateTime(
              location,
              localNow.year,
              localNow.month,
              localNow.day + 1,
              hour.localTime.hour,
              hour.localTime.minute,
            ).toUtc();
      return (hour: hour, current: current, start: nextStart);
    }).toList();
    candidates.sort((left, right) {
      if (left.current != right.current) return left.current ? -1 : 1;
      final time = left.start.compareTo(right.start);
      return time != 0 ? time : left.hour.id.compareTo(right.hour.id);
    });
    return candidates.first.hour;
  }

  DateTime _nextOccurrence(SacredHour hour, DateTime afterUtc) {
    final location = timezone.getLocation(hour.timezone);
    final local = timezone.TZDateTime.from(afterUtc, location);
    var candidate = timezone.TZDateTime(
      location,
      local.year,
      local.month,
      local.day,
      hour.localTime.hour,
      hour.localTime.minute,
    );
    if (!candidate.toUtc().isAfter(afterUtc)) {
      candidate = timezone.TZDateTime(
        location,
        local.year,
        local.month,
        local.day + 1,
        hour.localTime.hour,
        hour.localTime.minute,
      );
    }
    return candidate.toUtc();
  }

  String _deliveryId(String hourId) => _uuid.v5(
    Namespace.url.value,
    'soulbuddy:sacred-hour-device:$hourId:$deviceId',
  );
}

int _notificationId(String id) =>
    int.parse(id.replaceAll('-', '').substring(0, 8), radix: 16) & 0x7fffffff;

String _localDate(DateTime instant, String timezoneName) {
  final local = timezone.TZDateTime.from(
    instant.toUtc(),
    timezone.getLocation(timezoneName),
  );
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String _identifier(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 120) {
    throw ArgumentError.value(value, name);
  }
  return normalized;
}
