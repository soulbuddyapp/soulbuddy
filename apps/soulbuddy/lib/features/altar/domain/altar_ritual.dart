import '../../prayers/domain/prayer_reminder.dart';

enum AltarTargetType {
  encounter('encounter'),
  personalPrayer('personal_prayer'),
  libraryPrayer('library_prayer'),
  voiceTablet('voice_tablet');

  const AltarTargetType(this.wireValue);
  final String wireValue;

  factory AltarTargetType.fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw const FormatException('Unknown Altar target'),
  );
}

class AltarTarget {
  const AltarTarget.encounter(this.targetId) : type = AltarTargetType.encounter;
  const AltarTarget.personalPrayer(this.targetId)
    : type = AltarTargetType.personalPrayer;
  const AltarTarget.libraryPrayer(this.targetId)
    : type = AltarTargetType.libraryPrayer;
  const AltarTarget.voiceTablet(this.targetId)
    : type = AltarTargetType.voiceTablet;

  final AltarTargetType type;
  final String targetId;

  @override
  bool operator ==(Object other) =>
      other is AltarTarget && other.type == type && other.targetId == targetId;

  @override
  int get hashCode => Object.hash(type, targetId);
}

enum AltarScheduleType {
  daily('daily'),
  weekdays('weekdays');

  const AltarScheduleType(this.wireValue);
  final String wireValue;

  factory AltarScheduleType.fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw const FormatException('Unknown Altar schedule'),
  );
}

enum AltarPlaybackMode {
  refrain('refrain'),
  fullPrayer('full_prayer'),
  openQuietly('open_quietly');

  const AltarPlaybackMode(this.wireValue);
  final String wireValue;

  factory AltarPlaybackMode.fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw const FormatException('Unknown Altar playback mode'),
  );
}

class AltarRitualSchedule {
  AltarRitualSchedule._({
    required this.type,
    required this.localTime,
    required String timezone,
    this.weekdaysMask,
  }) : timezone = _requiredText(timezone, 'timezone', 64) {
    if (type == AltarScheduleType.daily && weekdaysMask != null) {
      throw ArgumentError('A daily ritual cannot select weekdays.');
    }
    if (type == AltarScheduleType.weekdays &&
        (weekdaysMask == null || weekdaysMask! < 1 || weekdaysMask! > 127)) {
      throw ArgumentError.value(weekdaysMask, 'weekdaysMask');
    }
  }

  factory AltarRitualSchedule.daily({
    required PrayerLocalTime localTime,
    required String timezone,
  }) => AltarRitualSchedule._(
    type: AltarScheduleType.daily,
    localTime: localTime,
    timezone: timezone,
  );

  factory AltarRitualSchedule.weekdays({
    required PrayerLocalTime localTime,
    required String timezone,
    required int weekdaysMask,
  }) => AltarRitualSchedule._(
    type: AltarScheduleType.weekdays,
    localTime: localTime,
    timezone: timezone,
    weekdaysMask: weekdaysMask,
  );

  final AltarScheduleType type;
  final PrayerLocalTime localTime;
  final String timezone;
  final int? weekdaysMask;

  factory AltarRitualSchedule.fromRow(Map<String, dynamic> row) {
    final type = AltarScheduleType.fromWire(row['schedule_type'] as String);
    final localTime = PrayerLocalTime.parse(row['local_time'] as String);
    final timezone = row['timezone'] as String;
    return type == AltarScheduleType.daily
        ? AltarRitualSchedule.daily(localTime: localTime, timezone: timezone)
        : AltarRitualSchedule.weekdays(
            localTime: localTime,
            timezone: timezone,
            weekdaysMask: row['weekdays_mask'] as int,
          );
  }
}

class AltarItem {
  const AltarItem({
    required this.id,
    required this.ownerId,
    required this.target,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  final String id;
  final String ownerId;
  final AltarTarget target;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
}

class AltarRitual {
  const AltarRitual({
    required this.id,
    required this.ownerId,
    required this.itemId,
    required this.schedule,
    required this.playbackMode,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  final String id;
  final String ownerId;
  final String itemId;
  final AltarRitualSchedule schedule;
  final AltarPlaybackMode playbackMode;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
}

class AltarRitualDraft {
  AltarRitualDraft({
    required this.target,
    required this.schedule,
    required this.playbackMode,
    required this.enableOnThisDevice,
  }) {
    _requiredText(target.targetId, 'targetId', 128);
  }

  final AltarTarget target;
  final AltarRitualSchedule schedule;
  final AltarPlaybackMode playbackMode;
  final bool enableOnThisDevice;
}

class AltarReminderDelivery {
  const AltarReminderDelivery({
    required this.ritualId,
    required this.platformNotificationId,
    required this.nextOccurrenceAt,
    required this.enabledOnDevice,
    required this.schedule,
  });

  final String ritualId;
  final int platformNotificationId;
  final DateTime? nextOccurrenceAt;
  final bool enabledOnDevice;
  final AltarRitualSchedule schedule;
}

enum AltarRitualLocalStatus { upcoming, due, snoozed, missingAudio }

class DueAltarRitual {
  const DueAltarRitual({
    required this.item,
    required this.ritual,
    required this.occurrenceAt,
    required this.localStatus,
    required this.hasLocalAudio,
    this.audioStorageKey,
  });

  final AltarItem item;
  final AltarRitual ritual;
  final DateTime occurrenceAt;
  final AltarRitualLocalStatus localStatus;
  final bool hasLocalAudio;
  final String? audioStorageKey;
}

String _requiredText(String value, String name, int maximumLength) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > maximumLength) {
    throw ArgumentError.value(value, name);
  }
  return normalized;
}
