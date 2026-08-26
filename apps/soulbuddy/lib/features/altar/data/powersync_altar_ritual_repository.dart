import 'package:powersync/powersync.dart';
import 'package:powersync/sqlite_async.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;
import 'package:uuid/uuid.dart';

import '../../prayers/application/prayer_occurrence_calculator.dart';
import '../../prayers/domain/prayer_reminder.dart';
import '../domain/altar_ritual.dart';
import 'altar_ritual_repository.dart';

class PowerSyncAltarRitualRepository implements AltarRitualRepository {
  PowerSyncAltarRitualRepository({
    required this.database,
    required String ownerId,
    required String deviceId,
    DateTime Function()? now,
    Uuid? uuid,
    PrayerOccurrenceCalculator? occurrenceCalculator,
  }) : ownerId = _identifier(ownerId, 'ownerId'),
       deviceId = _identifier(deviceId, 'deviceId'),
       _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid(),
       _occurrenceCalculator =
           occurrenceCalculator ??
           TimezonePrayerOccurrenceCalculator.initialize() {
    timezone_data.initializeTimeZones();
  }

  final PowerSyncDatabase database;
  final String ownerId;
  final String deviceId;
  final DateTime Function() _now;
  final Uuid _uuid;
  final PrayerOccurrenceCalculator _occurrenceCalculator;

  @override
  Stream<AltarRitual?> watchForTarget(AltarTarget target) {
    final column = _targetColumn(target.type);
    return database
        .watch(
          '''
          SELECT ritual.*
          FROM altar_rituals AS ritual
          JOIN altar_items AS item
            ON item.id = ritual.altar_item_id
           AND item.owner_id = ritual.owner_id
          WHERE ritual.owner_id = ? AND item.target_type = ?
            AND item.$column = ? AND item.archived_at IS NULL
            AND ritual.archived_at IS NULL
          LIMIT 1
          ''',
          parameters: [ownerId, target.type.wireValue, target.targetId],
        )
        .map((rows) => rows.isEmpty ? null : _ritualFromRow(rows.single));
  }

  @override
  Stream<DueAltarRitual?> watchNextForDate(
    DateTime localDate, {
    DateTime? now,
  }) {
    return database
        .watch(
          '''
          SELECT
            item.id AS item_id_value,
            item.owner_id AS item_owner_id,
            item.target_type,
            item.encounter_id,
            item.personal_prayer_id,
            item.library_prayer_id,
            item.voice_tablet_id,
            item.created_at AS item_created_at,
            item.updated_at AS item_updated_at,
            item.archived_at AS item_archived_at,
            ritual.id AS ritual_id_value,
            ritual.owner_id AS ritual_owner_id,
            ritual.altar_item_id,
            ritual.schedule_type,
            ritual.local_time,
            ritual.timezone,
            ritual.weekdays_mask,
            ritual.playback_mode,
            ritual.enabled,
            ritual.created_at AS ritual_created_at,
            ritual.updated_at AS ritual_updated_at,
            ritual.archived_at AS ritual_archived_at,
            device.next_occurrence_at,
            device.snoozed_until,
            device.autoplay_when_opened,
            occurrence.status AS occurrence_status,
            occurrence.prayer_session_id AS occurrence_session_id,
            full.storage_key AS full_storage_key,
            refrain.storage_key AS refrain_storage_key
          FROM altar_rituals AS ritual
          JOIN altar_items AS item
            ON item.id = ritual.altar_item_id
           AND item.owner_id = ritual.owner_id
          JOIN altar_ritual_devices AS device
            ON device.ritual_id = ritual.id
           AND device.device_id = ?
          LEFT JOIN altar_ritual_occurrences AS occurrence
            ON occurrence.ritual_id = ritual.id
           AND occurrence.owner_id = ritual.owner_id
           AND occurrence.local_date = ?
          LEFT JOIN voice_tablets AS tablet
            ON tablet.id = item.voice_tablet_id
           AND tablet.owner_id = item.owner_id
           AND tablet.archived_at IS NULL
          LEFT JOIN voice_tablet_audio_assets AS full
            ON full.id = tablet.full_audio_id
           AND full.owner_id = tablet.owner_id
          LEFT JOIN voice_tablet_audio_assets AS refrain
            ON refrain.id = tablet.refrain_audio_id
           AND refrain.owner_id = tablet.owner_id
          WHERE ritual.owner_id = ? AND ritual.enabled = 1
            AND ritual.archived_at IS NULL AND item.archived_at IS NULL
            AND device.enabled_on_device = 1
          ORDER BY ritual.local_time, ritual.id
          ''',
          parameters: [deviceId, _dateWire(localDate), ownerId],
        )
        .map((rows) => _nextDue(rows, localDate, (now ?? _now()).toUtc()));
  }

  @override
  Stream<List<AltarReminderDelivery>> watchReminderDeliveries() {
    return database
        .watch(
          '''
          SELECT device.ritual_id, device.platform_notification_id,
                 device.next_occurrence_at, device.enabled_on_device,
                 ritual.schedule_type, ritual.local_time, ritual.timezone,
                 ritual.weekdays_mask, ritual.enabled AS ritual_enabled,
                 ritual.archived_at AS ritual_archived_at,
                 item.archived_at AS item_archived_at
          FROM altar_ritual_devices AS device
          JOIN altar_rituals AS ritual ON ritual.id = device.ritual_id
          JOIN altar_items AS item ON item.id = ritual.altar_item_id
          WHERE ritual.owner_id = ? AND device.device_id = ?
          ORDER BY device.next_occurrence_at, device.ritual_id
          ''',
          parameters: [ownerId, deviceId],
        )
        .map(
          (rows) => rows
              .map(
                (row) => AltarReminderDelivery(
                  ritualId: row['ritual_id'] as String,
                  platformNotificationId:
                      row['platform_notification_id'] as int,
                  nextOccurrenceAt: _optionalDate(row['next_occurrence_at']),
                  enabledOnDevice:
                      row['enabled_on_device'] == 1 &&
                      row['ritual_enabled'] == 1 &&
                      row['ritual_archived_at'] == null &&
                      row['item_archived_at'] == null,
                  schedule: AltarRitualSchedule.fromRow(row),
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<AltarRitual> save(AltarRitualDraft draft) {
    if (draft.target.type != AltarTargetType.voiceTablet &&
        draft.playbackMode != AltarPlaybackMode.openQuietly) {
      throw ArgumentError(
        'Only a Voice Tablet can play a recorded prayer or refrain.',
      );
    }
    return database.writeTransaction((transaction) async {
      await _requireTarget(transaction, draft.target);
      final now = _now().toUtc();
      final nowWire = now.toIso8601String();
      final column = _targetColumn(draft.target.type);
      var item = await transaction.getOptional(
        '''
        SELECT * FROM altar_items
        WHERE owner_id = ? AND target_type = ? AND $column = ?
        LIMIT 1
        ''',
        [ownerId, draft.target.type.wireValue, draft.target.targetId],
      );
      if (item == null) {
        final itemId = _uuid.v7();
        await transaction.execute(
          '''
          INSERT INTO altar_items(
            id, owner_id, target_type, encounter_id, personal_prayer_id,
            library_prayer_id, voice_tablet_id, created_at, updated_at,
            archived_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
          ''',
          [
            itemId,
            ownerId,
            draft.target.type.wireValue,
            draft.target.type == AltarTargetType.encounter
                ? draft.target.targetId
                : null,
            draft.target.type == AltarTargetType.personalPrayer
                ? draft.target.targetId
                : null,
            draft.target.type == AltarTargetType.libraryPrayer
                ? draft.target.targetId
                : null,
            draft.target.type == AltarTargetType.voiceTablet
                ? draft.target.targetId
                : null,
            nowWire,
            nowWire,
          ],
        );
        item = await transaction.get('SELECT * FROM altar_items WHERE id = ?', [
          itemId,
        ]);
      } else if (item['archived_at'] != null) {
        await transaction.execute(
          'UPDATE altar_items SET archived_at = NULL, updated_at = ? WHERE id = ? AND owner_id = ?',
          [nowWire, item['id'], ownerId],
        );
      }

      var ritual = await transaction.getOptional(
        'SELECT * FROM altar_rituals WHERE owner_id = ? AND altar_item_id = ? LIMIT 1',
        [ownerId, item['id']],
      );
      final ritualId = ritual?['id'] as String? ?? _uuid.v7();
      if (ritual == null) {
        await transaction.execute(
          '''
          INSERT INTO altar_rituals(
            id, owner_id, altar_item_id, schedule_type, local_time, timezone,
            weekdays_mask, playback_mode, enabled, created_at, updated_at,
            archived_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, NULL)
          ''',
          [
            ritualId,
            ownerId,
            item['id'],
            draft.schedule.type.wireValue,
            draft.schedule.localTime.wireValue,
            draft.schedule.timezone,
            draft.schedule.weekdaysMask,
            draft.playbackMode.wireValue,
            nowWire,
            nowWire,
          ],
        );
      } else {
        await transaction.execute(
          '''
          UPDATE altar_rituals
          SET schedule_type = ?, local_time = ?, timezone = ?,
              weekdays_mask = ?, playback_mode = ?, enabled = 1,
              updated_at = ?, archived_at = NULL
          WHERE id = ? AND owner_id = ?
          ''',
          [
            draft.schedule.type.wireValue,
            draft.schedule.localTime.wireValue,
            draft.schedule.timezone,
            draft.schedule.weekdaysMask,
            draft.playbackMode.wireValue,
            nowWire,
            ritualId,
            ownerId,
          ],
        );
      }
      await _upsertDevice(
        transaction,
        ritualId: ritualId,
        enabled: draft.enableOnThisDevice,
        autoplayWhenOpened: draft.autoplayWhenOpened,
        nextOccurrenceAt: _nextOccurrence(draft.schedule, now),
        scheduledTimezone: draft.schedule.timezone,
        now: nowWire,
      );
      ritual = await transaction.get(
        'SELECT * FROM altar_rituals WHERE id = ? AND owner_id = ?',
        [ritualId, ownerId],
      );
      return _ritualFromRow(ritual);
    });
  }

  @override
  Future<void> setPaused(String ritualId, bool paused) {
    return database.writeTransaction((transaction) async {
      await _requireRitual(transaction, ritualId);
      final now = _now().toUtc().toIso8601String();
      await transaction.execute(
        'UPDATE altar_rituals SET enabled = ?, updated_at = ? WHERE id = ? AND owner_id = ?',
        [paused ? 0 : 1, now, ritualId, ownerId],
      );
    });
  }

  @override
  Future<void> snooze(String ritualId, DateTime until) {
    return database.writeTransaction((transaction) async {
      await _requireRitual(transaction, ritualId);
      final device = await transaction.getOptional(
        '''
        SELECT id FROM altar_ritual_devices
        WHERE ritual_id = ? AND device_id = ? AND enabled_on_device = 1
        LIMIT 1
        ''',
        [ritualId, deviceId],
      );
      if (device == null) {
        throw StateError('The Altar ritual is not enabled on this device.');
      }
      await transaction.execute(
        '''
        UPDATE altar_ritual_devices
        SET snoozed_until = ?, dismissed_occurrence_key = NULL, updated_at = ?
        WHERE ritual_id = ? AND device_id = ? AND enabled_on_device = 1
        ''',
        [
          until.toUtc().toIso8601String(),
          _now().toUtc().toIso8601String(),
          ritualId,
          deviceId,
        ],
      );
    });
  }

  @override
  Future<DateTime?> advance(String ritualId, {required DateTime afterUtc}) {
    return database.writeTransaction((transaction) async {
      final row = await _requireRitual(transaction, ritualId);
      final ritual = _ritualFromRow(row);
      final next = _nextOccurrence(ritual.schedule, afterUtc.toUtc());
      await transaction.execute(
        '''
        UPDATE altar_ritual_devices
        SET next_occurrence_at = ?, snoozed_until = NULL,
            dismissed_occurrence_key = NULL, updated_at = ?
        WHERE ritual_id = ? AND device_id = ? AND enabled_on_device = 1
        ''',
        [
          next?.toUtc().toIso8601String(),
          _now().toUtc().toIso8601String(),
          ritualId,
          deviceId,
        ],
      );
      return next;
    });
  }

  @override
  Future<void> markPrayed({
    required String ritualId,
    required DateTime occurrenceAt,
    required DateTime localDate,
    required String prayerSessionId,
  }) {
    return database.writeTransaction((transaction) async {
      await _requireRitual(transaction, ritualId);
      final occurrenceWire = occurrenceAt.toUtc().toIso8601String();
      final id = _uuid.v5(
        Namespace.url.value,
        'soulbuddy:altar-occurrence:$ritualId:$occurrenceWire',
      );
      final now = _now().toUtc().toIso8601String();
      final existing = await transaction.getOptional(
        'SELECT id FROM altar_ritual_occurrences WHERE id = ? AND owner_id = ?',
        [id, ownerId],
      );
      if (existing == null) {
        await transaction.execute(
          '''
          INSERT INTO altar_ritual_occurrences(
            id, owner_id, ritual_id, local_date, occurrence_at, status,
            prayer_session_id, updated_at
          ) VALUES (?, ?, ?, ?, ?, 'prayed', ?, ?)
          ''',
          [
            id,
            ownerId,
            ritualId,
            _dateWire(localDate),
            occurrenceWire,
            prayerSessionId,
            now,
          ],
        );
      } else {
        await transaction.execute(
          '''
          UPDATE altar_ritual_occurrences
          SET status = 'prayed', prayer_session_id = ?, updated_at = ?
          WHERE id = ? AND owner_id = ?
          ''',
          [prayerSessionId, now, id, ownerId],
        );
      }
    });
  }

  @override
  Future<void> retractPrayer({
    required String ritualId,
    required DateTime occurrenceAt,
  }) {
    return database.writeTransaction((transaction) async {
      await _requireRitual(transaction, ritualId);
      final id = _uuid.v5(
        Namespace.url.value,
        'soulbuddy:altar-occurrence:$ritualId:${occurrenceAt.toUtc().toIso8601String()}',
      );
      await transaction.execute(
        '''
        UPDATE altar_ritual_occurrences
        SET status = 'retracted', updated_at = ?
        WHERE id = ? AND owner_id = ? AND ritual_id = ?
        ''',
        [_now().toUtc().toIso8601String(), id, ownerId, ritualId],
      );
    });
  }

  @override
  Future<void> archive(String ritualId) {
    return database.writeTransaction((transaction) async {
      final ritual = await _requireRitual(transaction, ritualId);
      final now = _now().toUtc().toIso8601String();
      await transaction.execute(
        'UPDATE altar_rituals SET enabled = 0, archived_at = ?, updated_at = ? WHERE id = ? AND owner_id = ?',
        [now, now, ritualId, ownerId],
      );
      await transaction.execute(
        'UPDATE altar_items SET archived_at = ?, updated_at = ? WHERE id = ? AND owner_id = ?',
        [now, now, ritual['altar_item_id'], ownerId],
      );
      await transaction.execute(
        '''
        UPDATE altar_ritual_devices
        SET enabled_on_device = 0, next_occurrence_at = NULL,
            snoozed_until = NULL, updated_at = ?
        WHERE ritual_id = ? AND device_id = ?
        ''',
        [now, ritualId, deviceId],
      );
    });
  }

  DueAltarRitual? _nextDue(
    List<Map<String, dynamic>> rows,
    DateTime localDate,
    DateTime now,
  ) {
    final candidates = <DueAltarRitual>[];
    for (final row in rows) {
      if (row['occurrence_status'] == 'prayed') continue;
      final ritual = _ritualFromAliasedRow(row);
      final scheduled = _occurrenceForDate(ritual.schedule, localDate);
      if (scheduled == null) continue;
      final snoozedUntil = _optionalDate(row['snoozed_until']);
      final occurrence = snoozedUntil != null && snoozedUntil.isAfter(scheduled)
          ? snoozedUntil
          : scheduled;
      if (!_sameLocalDate(occurrence, localDate, ritual.schedule.timezone)) {
        continue;
      }
      final item = _itemFromRow(row);
      final storageKey = switch (ritual.playbackMode) {
        AltarPlaybackMode.refrain => row['refrain_storage_key'] as String?,
        AltarPlaybackMode.fullPrayer => row['full_storage_key'] as String?,
        AltarPlaybackMode.openQuietly => null,
      };
      final hasAudio =
          ritual.playbackMode == AltarPlaybackMode.openQuietly ||
          storageKey != null;
      final status = !hasAudio
          ? AltarRitualLocalStatus.missingAudio
          : snoozedUntil != null && snoozedUntil.isAfter(now)
          ? AltarRitualLocalStatus.snoozed
          : !occurrence.isAfter(now)
          ? AltarRitualLocalStatus.due
          : AltarRitualLocalStatus.upcoming;
      candidates.add(
        DueAltarRitual(
          item: item,
          ritual: ritual,
          occurrenceAt: occurrence,
          localStatus: status,
          hasLocalAudio: hasAudio,
          autoplayWhenOpened: row['autoplay_when_opened'] == 1,
          audioStorageKey: storageKey,
        ),
      );
    }
    candidates.sort((left, right) {
      final leftDue = !left.occurrenceAt.isAfter(now);
      final rightDue = !right.occurrenceAt.isAfter(now);
      if (leftDue != rightDue) return leftDue ? -1 : 1;
      return left.occurrenceAt.compareTo(right.occurrenceAt);
    });
    return candidates.firstOrNull;
  }

  DateTime? _occurrenceForDate(
    AltarRitualSchedule schedule,
    DateTime localDate,
  ) {
    if (schedule.type == AltarScheduleType.weekdays) {
      final weekdayBit = 1 << (localDate.weekday - 1);
      if ((schedule.weekdaysMask! & weekdayBit) == 0) return null;
    }
    final location = timezone.getLocation(schedule.timezone);
    final localStart = timezone.TZDateTime(
      location,
      localDate.year,
      localDate.month,
      localDate.day,
    );
    final prayerSchedule = schedule.type == AltarScheduleType.daily
        ? PrayerReminderSchedule.daily(
            localTime: schedule.localTime,
            timezone: schedule.timezone,
          )
        : PrayerReminderSchedule.weekdays(
            localTime: schedule.localTime,
            timezone: schedule.timezone,
            weekdaysMask: schedule.weekdaysMask!,
          );
    final occurrence = _occurrenceCalculator.next(
      prayerSchedule,
      afterUtc: localStart.toUtc().subtract(const Duration(milliseconds: 1)),
    );
    return occurrence != null &&
            _sameLocalDate(occurrence, localDate, schedule.timezone)
        ? occurrence
        : null;
  }

  DateTime? _nextOccurrence(AltarRitualSchedule schedule, DateTime afterUtc) {
    final prayerSchedule = schedule.type == AltarScheduleType.daily
        ? PrayerReminderSchedule.daily(
            localTime: schedule.localTime,
            timezone: schedule.timezone,
          )
        : PrayerReminderSchedule.weekdays(
            localTime: schedule.localTime,
            timezone: schedule.timezone,
            weekdaysMask: schedule.weekdaysMask!,
          );
    return _occurrenceCalculator.next(prayerSchedule, afterUtc: afterUtc);
  }

  bool _sameLocalDate(DateTime instant, DateTime date, String timezoneName) {
    final local = timezone.TZDateTime.from(
      instant.toUtc(),
      timezone.getLocation(timezoneName),
    );
    return local.year == date.year &&
        local.month == date.month &&
        local.day == date.day;
  }

  Future<void> _requireTarget(
    SqliteWriteContext transaction,
    AltarTarget target,
  ) async {
    final (table, ownerClause, archiveClause) = switch (target.type) {
      AltarTargetType.encounter => (
        'encounters',
        'AND owner_id = ?',
        'AND archived_at IS NULL',
      ),
      AltarTargetType.personalPrayer => (
        'personal_prayers',
        'AND owner_id = ?',
        'AND archived_at IS NULL',
      ),
      AltarTargetType.libraryPrayer => (
        'library_prayers',
        '',
        'AND published_at IS NOT NULL AND archived_at IS NULL',
      ),
      AltarTargetType.voiceTablet => (
        'voice_tablets',
        'AND owner_id = ?',
        'AND archived_at IS NULL',
      ),
    };
    final row = await transaction.getOptional(
      'SELECT id FROM $table WHERE id = ? $ownerClause $archiveClause LIMIT 1',
      [target.targetId, if (ownerClause.isNotEmpty) ownerId],
    );
    if (row == null) throw StateError('The Altar item is unavailable.');
  }

  Future<Map<String, dynamic>> _requireRitual(
    SqliteWriteContext transaction,
    String ritualId,
  ) async {
    final row = await transaction.getOptional(
      '''
      SELECT * FROM altar_rituals
      WHERE id = ? AND owner_id = ? AND archived_at IS NULL
      LIMIT 1
      ''',
      [ritualId, ownerId],
    );
    if (row == null) throw StateError('The Altar ritual is unavailable.');
    return row;
  }

  Future<void> _upsertDevice(
    SqliteWriteContext transaction, {
    required String ritualId,
    required bool enabled,
    required bool autoplayWhenOpened,
    required DateTime? nextOccurrenceAt,
    required String scheduledTimezone,
    required String now,
  }) async {
    final id = _uuid.v5(
      Namespace.url.value,
      'soulbuddy:altar-ritual-device:$ritualId:$deviceId',
    );
    final notificationId =
        int.parse(id.replaceAll('-', '').substring(0, 8), radix: 16) &
        0x7fffffff;
    final existing = await transaction.getOptional(
      'SELECT id FROM altar_ritual_devices WHERE id = ? LIMIT 1',
      [id],
    );
    final values = [
      enabled ? 1 : 0,
      nextOccurrenceAt?.toUtc().toIso8601String(),
      notificationId,
      scheduledTimezone,
      autoplayWhenOpened ? 1 : 0,
      now,
    ];
    if (existing == null) {
      await transaction.execute(
        '''
        INSERT INTO altar_ritual_devices(
          id, ritual_id, device_id, enabled_on_device, next_occurrence_at,
          platform_notification_id, scheduled_timezone, snoozed_until,
          dismissed_occurrence_key, autoplay_when_opened, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, NULL, NULL, ?, ?)
        ''',
        [id, ritualId, deviceId, ...values],
      );
      return;
    }
    await transaction.execute(
      '''
      UPDATE altar_ritual_devices
      SET enabled_on_device = ?, next_occurrence_at = ?,
          platform_notification_id = ?, scheduled_timezone = ?,
          snoozed_until = NULL, dismissed_occurrence_key = NULL,
          autoplay_when_opened = ?, updated_at = ?
      WHERE id = ? AND device_id = ?
      ''',
      [...values, id, deviceId],
    );
  }

  AltarItem _itemFromRow(Map<String, dynamic> row) {
    final type = AltarTargetType.fromWire(row['target_type'] as String);
    final targetId = row[_targetColumn(type)] as String;
    final target = switch (type) {
      AltarTargetType.encounter => AltarTarget.encounter(targetId),
      AltarTargetType.personalPrayer => AltarTarget.personalPrayer(targetId),
      AltarTargetType.libraryPrayer => AltarTarget.libraryPrayer(targetId),
      AltarTargetType.voiceTablet => AltarTarget.voiceTablet(targetId),
    };
    return AltarItem(
      id: row['item_id_value'] as String,
      ownerId: row['item_owner_id'] as String,
      target: target,
      createdAt: DateTime.parse(row['item_created_at'] as String),
      updatedAt: DateTime.parse(row['item_updated_at'] as String),
      archivedAt: _optionalDate(row['item_archived_at']),
    );
  }

  AltarRitual _ritualFromAliasedRow(Map<String, dynamic> row) => AltarRitual(
    id: row['ritual_id_value'] as String,
    ownerId: row['ritual_owner_id'] as String,
    itemId: row['altar_item_id'] as String,
    schedule: AltarRitualSchedule.fromRow(row),
    playbackMode: AltarPlaybackMode.fromWire(row['playback_mode'] as String),
    enabled: row['enabled'] == 1,
    createdAt: DateTime.parse(row['ritual_created_at'] as String),
    updatedAt: DateTime.parse(row['ritual_updated_at'] as String),
    archivedAt: _optionalDate(row['ritual_archived_at']),
  );

  AltarRitual _ritualFromRow(Map<String, dynamic> row) => AltarRitual(
    id: row['id'] as String,
    ownerId: row['owner_id'] as String,
    itemId: row['altar_item_id'] as String,
    schedule: AltarRitualSchedule.fromRow(row),
    playbackMode: AltarPlaybackMode.fromWire(row['playback_mode'] as String),
    enabled: row['enabled'] == 1,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    archivedAt: _optionalDate(row['archived_at']),
  );
}

String _targetColumn(AltarTargetType type) => switch (type) {
  AltarTargetType.encounter => 'encounter_id',
  AltarTargetType.personalPrayer => 'personal_prayer_id',
  AltarTargetType.libraryPrayer => 'library_prayer_id',
  AltarTargetType.voiceTablet => 'voice_tablet_id',
};

DateTime? _optionalDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

String _dateWire(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _identifier(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 128) {
    throw ArgumentError.value(value, name);
  }
  return normalized;
}
