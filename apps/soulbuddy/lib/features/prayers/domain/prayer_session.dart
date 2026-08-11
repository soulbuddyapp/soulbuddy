enum PrayerSessionSource {
  reminder('reminder'),
  manual('manual');

  const PrayerSessionSource(this.wireValue);

  final String wireValue;

  factory PrayerSessionSource.fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw const FormatException('Unknown prayer session source'),
  );
}

class PrayerSession {
  const PrayerSession({
    required this.id,
    required this.ownerId,
    required this.personalPrayerId,
    required this.prayerRevisionId,
    required this.source,
    required this.occurredAt,
    required this.localDate,
    required this.timezone,
    required this.deviceId,
    this.reminderId,
    this.reminderOccurrenceKey,
    this.retractedAt,
  });

  final String id;
  final String ownerId;
  final String personalPrayerId;
  final String prayerRevisionId;
  final String? reminderId;
  final String? reminderOccurrenceKey;
  final PrayerSessionSource source;
  final DateTime occurredAt;
  final DateTime localDate;
  final String timezone;
  final String deviceId;
  final DateTime? retractedAt;

  bool canRetract(DateTime at) =>
      retractedAt == null &&
      !at.toUtc().isAfter(occurredAt.toUtc().add(const Duration(minutes: 5)));

  factory PrayerSession.fromRow(Map<String, dynamic> row) => PrayerSession(
    id: row['id'] as String,
    ownerId: row['owner_id'] as String,
    personalPrayerId: row['personal_prayer_id'] as String,
    prayerRevisionId: row['prayer_revision_id'] as String,
    reminderId: row['reminder_id'] as String?,
    reminderOccurrenceKey: row['reminder_occurrence_key'] as String?,
    source: PrayerSessionSource.fromWire(row['source'] as String),
    occurredAt: DateTime.parse(row['occurred_at'] as String),
    localDate: DateTime.parse(row['local_date'] as String),
    timezone: row['timezone'] as String,
    deviceId: row['device_id'] as String,
    retractedAt: row['retracted_at'] == null
        ? null
        : DateTime.parse(row['retracted_at'] as String),
  );
}
