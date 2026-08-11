enum PrayerScheduleType {
  once('once'),
  daily('daily'),
  weekdays('weekdays');

  const PrayerScheduleType(this.wireValue);

  final String wireValue;

  factory PrayerScheduleType.fromWire(String value) {
    return values.firstWhere(
      (item) => item.wireValue == value,
      orElse: () => throw FormatException('Unknown prayer schedule type'),
    );
  }
}

class PrayerLocalTime {
  const PrayerLocalTime._({required this.hour, required this.minute});

  factory PrayerLocalTime({required int hour, required int minute}) {
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(hour, 'hour', 'must be from 0 to 23');
    }
    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute', 'must be from 0 to 59');
    }
    return PrayerLocalTime._(hour: hour, minute: minute);
  }

  final int hour;
  final int minute;

  String get wireValue =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  factory PrayerLocalTime.parse(String value) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
    if (match == null) {
      throw const FormatException('Invalid prayer local time');
    }
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) {
      throw const FormatException('Invalid prayer local time');
    }
    return PrayerLocalTime(hour: hour, minute: minute);
  }

  @override
  bool operator ==(Object other) =>
      other is PrayerLocalTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

class PrayerReminderSchedule {
  PrayerReminderSchedule._({
    required this.type,
    required this.localTime,
    required this.timezone,
    this.onceAt,
    this.weekdaysMask,
  }) {
    if (timezone.trim().isEmpty || timezone.length > 64) {
      throw ArgumentError.value(timezone, 'timezone');
    }
    switch (type) {
      case PrayerScheduleType.once:
        if (onceAt == null || weekdaysMask != null) {
          throw ArgumentError('Once reminders require only onceAt');
        }
      case PrayerScheduleType.daily:
        if (onceAt != null || weekdaysMask != null) {
          throw ArgumentError('Daily reminders cannot have date or weekdays');
        }
      case PrayerScheduleType.weekdays:
        if (onceAt != null ||
            weekdaysMask == null ||
            weekdaysMask! < 1 ||
            weekdaysMask! > 127) {
          throw ArgumentError('Weekday reminders require a mask from 1 to 127');
        }
    }
  }

  factory PrayerReminderSchedule.once({
    required PrayerLocalTime localTime,
    required String timezone,
    required DateTime onceAt,
  }) => PrayerReminderSchedule._(
    type: PrayerScheduleType.once,
    localTime: localTime,
    timezone: timezone.trim(),
    onceAt: onceAt.toUtc(),
  );

  factory PrayerReminderSchedule.daily({
    required PrayerLocalTime localTime,
    required String timezone,
  }) => PrayerReminderSchedule._(
    type: PrayerScheduleType.daily,
    localTime: localTime,
    timezone: timezone.trim(),
  );

  factory PrayerReminderSchedule.weekdays({
    required PrayerLocalTime localTime,
    required String timezone,
    required int weekdaysMask,
  }) => PrayerReminderSchedule._(
    type: PrayerScheduleType.weekdays,
    localTime: localTime,
    timezone: timezone.trim(),
    weekdaysMask: weekdaysMask,
  );

  final PrayerScheduleType type;
  final PrayerLocalTime localTime;
  final String timezone;
  final DateTime? onceAt;
  final int? weekdaysMask;

  factory PrayerReminderSchedule.fromRow(Map<String, dynamic> row) {
    final type = PrayerScheduleType.fromWire(row['schedule_type'] as String);
    final localTime = PrayerLocalTime.parse(row['local_time'] as String);
    final timezone = row['timezone'] as String;
    return switch (type) {
      PrayerScheduleType.once => PrayerReminderSchedule.once(
        localTime: localTime,
        timezone: timezone,
        onceAt: DateTime.parse(row['once_at'] as String),
      ),
      PrayerScheduleType.daily => PrayerReminderSchedule.daily(
        localTime: localTime,
        timezone: timezone,
      ),
      PrayerScheduleType.weekdays => PrayerReminderSchedule.weekdays(
        localTime: localTime,
        timezone: timezone,
        weekdaysMask: row['weekdays_mask'] as int,
      ),
    };
  }
}

class PrayerReminder {
  const PrayerReminder({
    required this.id,
    required this.ownerId,
    required this.personalPrayerId,
    required this.schedule,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  final String id;
  final String ownerId;
  final String personalPrayerId;
  final PrayerReminderSchedule schedule;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  factory PrayerReminder.fromRow(Map<String, dynamic> row) => PrayerReminder(
    id: row['id'] as String,
    ownerId: row['owner_id'] as String,
    personalPrayerId: row['personal_prayer_id'] as String,
    schedule: PrayerReminderSchedule.fromRow(row),
    enabled: row['enabled'] == 1,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    archivedAt: row['archived_at'] == null
        ? null
        : DateTime.parse(row['archived_at'] as String),
  );
}

class PrayerReminderDevice {
  const PrayerReminderDevice({
    required this.id,
    required this.reminderId,
    required this.deviceId,
    required this.enabledOnDevice,
    required this.platformNotificationId,
    required this.updatedAt,
    this.nextOccurrenceAt,
    this.scheduledTimezone,
    this.snoozedUntil,
    this.dismissedOccurrenceKey,
  });

  final String id;
  final String reminderId;
  final String deviceId;
  final bool enabledOnDevice;
  final DateTime? nextOccurrenceAt;
  final int platformNotificationId;
  final String? scheduledTimezone;
  final DateTime? snoozedUntil;
  final String? dismissedOccurrenceKey;
  final DateTime updatedAt;

  factory PrayerReminderDevice.fromRow(Map<String, dynamic> row) =>
      PrayerReminderDevice(
        id: row['id'] as String,
        reminderId: row['reminder_id'] as String,
        deviceId: row['device_id'] as String,
        enabledOnDevice: row['enabled_on_device'] == 1,
        nextOccurrenceAt: _optionalDate(row['next_occurrence_at']),
        platformNotificationId: row['platform_notification_id'] as int,
        scheduledTimezone: row['scheduled_timezone'] as String?,
        snoozedUntil: _optionalDate(row['snoozed_until']),
        dismissedOccurrenceKey: row['dismissed_occurrence_key'] as String?,
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );
}

class DuePrayerOccurrence {
  const DuePrayerOccurrence({
    required this.reminder,
    required this.device,
    required this.prayerTitle,
    required this.prayerBody,
    required this.prayerRevisionId,
    this.occurrenceAt,
  });

  final PrayerReminder reminder;
  final PrayerReminderDevice device;
  final String prayerTitle;
  final String prayerBody;
  final String prayerRevisionId;
  final DateTime? occurrenceAt;

  String get occurrenceKey {
    final value = occurrenceAt;
    if (value == null) {
      throw StateError('Prayer occurrence has not been scheduled');
    }
    return '${reminder.id}@${value.toUtc().toIso8601String()}';
  }
}

DateTime? _optionalDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String);
