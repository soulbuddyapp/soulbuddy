import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:uuid/uuid.dart';

enum SacredHourPurpose {
  morning('morning'),
  evening('evening'),
  custom(null);

  const SacredHourPurpose(this.wireValue);

  final String? wireValue;

  factory SacredHourPurpose.fromWire(Object? value) => switch (value) {
    'morning' => SacredHourPurpose.morning,
    'evening' => SacredHourPurpose.evening,
    null => SacredHourPurpose.custom,
    _ => throw const FormatException('Unknown Sacred Hour purpose'),
  };
}

enum SacredHourSound {
  gentleChime('gentle_chime'),
  dawnChime('dawn_chime'),
  stillBell('still_bell'),
  eveningChime('evening_chime'),
  device('device'),
  silent('silent');

  const SacredHourSound(this.wireValue);

  final String wireValue;

  factory SacredHourSound.fromWire(String value) => values.firstWhere(
    (sound) => sound.wireValue == value,
    orElse: () => throw const FormatException('Unknown Sacred Hour sound'),
  );
}

enum SacredHourReminderMode {
  ordinary('ordinary'),
  precise('precise');

  const SacredHourReminderMode(this.wireValue);

  final String wireValue;

  factory SacredHourReminderMode.fromWire(String value) => values.firstWhere(
    (mode) => mode.wireValue == value,
    orElse: () => throw const FormatException('Unknown reminder mode'),
  );
}

enum SacredHourOccurrenceStatus {
  due('due'),
  begun('begun'),
  completed('completed'),
  dismissed('dismissed');

  const SacredHourOccurrenceStatus(this.wireValue);

  final String wireValue;
}

class SacredHourDraft {
  factory SacredHourDraft.fromHour(
    SacredHour hour, {
    PrayerReference? prayer,
  }) => SacredHourDraft(
    name: hour.name,
    localTime: hour.localTime,
    timezone: hour.timezone,
    durationMinutes: hour.durationMinutes,
    prayerMinutes: hour.prayerMinutes,
    enabled: hour.enabled,
    sound: hour.sound,
    purpose: hour.purpose,
    prayer: prayer ?? hour.prayer,
    personId: hour.personId,
  );

  factory SacredHourDraft({
    required String name,
    required PrayerLocalTime localTime,
    required String timezone,
    int durationMinutes = 60,
    int prayerMinutes = 15,
    bool enabled = true,
    SacredHourSound sound = SacredHourSound.gentleChime,
    SacredHourPurpose purpose = SacredHourPurpose.custom,
    PrayerReference? prayer,
    String? personId,
  }) {
    final cleanName = _validateName(name);
    final cleanTimezone = _validateTimezone(timezone);
    final cleanPersonId = _validateOptionalId(personId, 'personId');
    _validateDuration(durationMinutes, prayerMinutes);
    _validatePrayer(prayer);
    return SacredHourDraft._(
      name: cleanName,
      localTime: localTime,
      timezone: cleanTimezone,
      durationMinutes: durationMinutes,
      prayerMinutes: prayerMinutes,
      enabled: enabled,
      sound: sound,
      purpose: purpose,
      prayer: prayer,
      personId: cleanPersonId,
    );
  }

  const SacredHourDraft._({
    required this.name,
    required this.localTime,
    required this.timezone,
    required this.durationMinutes,
    required this.prayerMinutes,
    required this.enabled,
    required this.sound,
    required this.purpose,
    required this.prayer,
    required this.personId,
  });

  final String name;
  final PrayerLocalTime localTime;
  final String timezone;
  final int durationMinutes;
  final int prayerMinutes;
  final bool enabled;
  final SacredHourSound sound;
  final SacredHourPurpose purpose;
  final PrayerReference? prayer;
  final String? personId;
}

class SacredHour {
  factory SacredHour({
    required String id,
    required String ownerId,
    required SacredHourPurpose purpose,
    required String name,
    required PrayerLocalTime localTime,
    required String timezone,
    required int durationMinutes,
    required int prayerMinutes,
    required bool enabled,
    required SacredHourSound sound,
    required DateTime createdAt,
    required DateTime updatedAt,
    PrayerReference? prayer,
    String? personId,
    DateTime? archivedAt,
  }) {
    final cleanId = _validateRequiredId(id, 'id');
    final cleanOwnerId = _validateRequiredId(ownerId, 'ownerId');
    final cleanName = _validateName(name);
    final cleanTimezone = _validateTimezone(timezone);
    final cleanPersonId = _validateOptionalId(personId, 'personId');
    _validateDuration(durationMinutes, prayerMinutes);
    _validatePrayer(prayer);
    return SacredHour._(
      id: cleanId,
      ownerId: cleanOwnerId,
      purpose: purpose,
      name: cleanName,
      localTime: localTime,
      timezone: cleanTimezone,
      durationMinutes: durationMinutes,
      prayerMinutes: prayerMinutes,
      enabled: enabled,
      sound: sound,
      prayer: prayer,
      personId: cleanPersonId,
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
      archivedAt: archivedAt?.toUtc(),
    );
  }

  const SacredHour._({
    required this.id,
    required this.ownerId,
    required this.purpose,
    required this.name,
    required this.localTime,
    required this.timezone,
    required this.durationMinutes,
    required this.prayerMinutes,
    required this.enabled,
    required this.sound,
    required this.prayer,
    required this.personId,
    required this.createdAt,
    required this.updatedAt,
    required this.archivedAt,
  });

  factory SacredHour.defaultMorning({
    required String ownerId,
    required String timezone,
    DateTime? now,
  }) => _defaultHour(
    ownerId: ownerId,
    timezone: timezone,
    purpose: SacredHourPurpose.morning,
    name: 'Morning Sacred Hour',
    localTime: PrayerLocalTime(hour: 6, minute: 0),
    now: now,
  );

  factory SacredHour.defaultEvening({
    required String ownerId,
    required String timezone,
    DateTime? now,
  }) => _defaultHour(
    ownerId: ownerId,
    timezone: timezone,
    purpose: SacredHourPurpose.evening,
    name: 'Evening Sacred Hour',
    localTime: PrayerLocalTime(hour: 22, minute: 0),
    now: now,
  );

  factory SacredHour.fromRow(Map<String, dynamic> row) {
    final prayerType = row['prayer_type'] as String?;
    final prayerId = row['prayer_id'] as String?;
    if ((prayerType == null) != (prayerId == null)) {
      throw const FormatException(
        'A Sacred Hour prayer requires both type and id',
      );
    }
    final prayer = switch (prayerType) {
      'library' => PrayerReference.library(prayerId!),
      'personal' => PrayerReference.personal(prayerId!),
      null => null,
      _ => throw const FormatException('Unknown prayer reference type'),
    };
    return SacredHour(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      purpose: SacredHourPurpose.fromWire(row['purpose_key']),
      name: row['name'] as String,
      localTime: PrayerLocalTime.parse(row['local_time'] as String),
      timezone: row['timezone'] as String,
      durationMinutes: row['duration_minutes'] as int,
      prayerMinutes: row['prayer_minutes'] as int,
      enabled: row['enabled'] == 1,
      sound: SacredHourSound.fromWire(row['sound_key'] as String),
      prayer: prayer,
      personId: row['person_id'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      archivedAt: _optionalDate(row['archived_at']),
    );
  }

  final String id;
  final String ownerId;
  final SacredHourPurpose purpose;
  final String name;
  final PrayerLocalTime localTime;
  final String timezone;
  final int durationMinutes;
  final int prayerMinutes;
  final bool enabled;
  final SacredHourSound sound;
  final PrayerReference? prayer;
  final String? personId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  PrayerLocalTime get endLocalTime {
    final totalMinutes =
        (localTime.hour * 60 + localTime.minute + durationMinutes) % (24 * 60);
    return PrayerLocalTime(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
  }

  static SacredHour _defaultHour({
    required String ownerId,
    required String timezone,
    required SacredHourPurpose purpose,
    required String name,
    required PrayerLocalTime localTime,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final purposeKey = purpose.wireValue!;
    return SacredHour(
      id: const Uuid().v5(
        Namespace.url.value,
        'soulbuddy:sacred-hour:$ownerId:$purposeKey',
      ),
      ownerId: ownerId,
      purpose: purpose,
      name: name,
      localTime: localTime,
      timezone: timezone,
      durationMinutes: 60,
      prayerMinutes: 15,
      enabled: true,
      sound: SacredHourSound.gentleChime,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }
}

class SacredHourDeviceDraft {
  SacredHourDeviceDraft({
    required this.enabledOnDevice,
    required this.reminderMode,
    required this.platformNotificationId,
    required String scheduledTimezone,
    this.nextOccurrenceAt,
    this.snoozedUntil,
    this.dismissedOccurrenceKey,
  }) : scheduledTimezone = _validateTimezone(scheduledTimezone) {
    if (platformNotificationId < 1) {
      throw ArgumentError.value(
        platformNotificationId,
        'platformNotificationId',
      );
    }
  }

  final bool enabledOnDevice;
  final SacredHourReminderMode reminderMode;
  final DateTime? nextOccurrenceAt;
  final int platformNotificationId;
  final String scheduledTimezone;
  final DateTime? snoozedUntil;
  final String? dismissedOccurrenceKey;
}

class SacredHourDelivery {
  const SacredHourDelivery({
    required this.sacredHourId,
    required this.enabledOnDevice,
    required this.reminderMode,
    required this.platformNotificationId,
    required this.scheduledTimezone,
    required this.updatedAt,
    this.nextOccurrenceAt,
    this.snoozedUntil,
    this.dismissedOccurrenceKey,
  });

  final String sacredHourId;
  final bool enabledOnDevice;
  final SacredHourReminderMode reminderMode;
  final DateTime? nextOccurrenceAt;
  final int platformNotificationId;
  final String scheduledTimezone;
  final DateTime? snoozedUntil;
  final String? dismissedOccurrenceKey;
  final DateTime updatedAt;

  factory SacredHourDelivery.fromRow(Map<String, dynamic> row) =>
      SacredHourDelivery(
        sacredHourId: row['sacred_hour_id'] as String,
        enabledOnDevice: row['enabled_on_device'] == 1,
        reminderMode: SacredHourReminderMode.fromWire(
          row['reminder_mode'] as String,
        ),
        nextOccurrenceAt: _optionalDate(row['next_occurrence_at']),
        platformNotificationId: row['platform_notification_id'] as int,
        scheduledTimezone: row['scheduled_timezone'] as String,
        snoozedUntil: _optionalDate(row['snoozed_until']),
        dismissedOccurrenceKey: row['dismissed_occurrence_key'] as String?,
        updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
      );
}

void _validateDuration(int durationMinutes, int prayerMinutes) {
  if (durationMinutes != 60) {
    throw ArgumentError.value(
      durationMinutes,
      'durationMinutes',
      'a Sacred Hour lasts sixty minutes',
    );
  }
  if (!const {5, 15, 30}.contains(prayerMinutes)) {
    throw ArgumentError.value(
      prayerMinutes,
      'prayerMinutes',
      'must be 5, 15, or 30',
    );
  }
}

String _validateName(String value) {
  final clean = value.trim();
  if (clean.isEmpty || clean.length > 120) {
    throw ArgumentError.value(value, 'name');
  }
  return clean;
}

String _validateTimezone(String value) {
  final clean = value.trim();
  if (clean.isEmpty || clean.length > 64) {
    throw ArgumentError.value(value, 'timezone');
  }
  return clean;
}

String _validateRequiredId(String value, String field) {
  final clean = value.trim();
  if (clean.isEmpty || clean.length > 120) {
    throw ArgumentError.value(value, field);
  }
  return clean;
}

String? _validateOptionalId(String? value, String field) =>
    value == null ? null : _validateRequiredId(value, field);

void _validatePrayer(PrayerReference? prayer) {
  if (prayer != null) {
    _validateRequiredId(prayer.id, 'prayer.id');
  }
}

DateTime? _optionalDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String);
