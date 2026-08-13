import 'prayer_reference.dart';

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
    required this.prayer,
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
  final PrayerReference prayer;
  final String? prayerRevisionId;
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

  String? get personalPrayerId =>
      prayer.source == PrayerSource.personal ? prayer.id : null;

  factory PrayerSession.fromRow(Map<String, dynamic> row) {
    final libraryPrayerId = row['library_prayer_id'] as String?;
    final personalPrayerId = row['personal_prayer_id'] as String?;
    final revisionId = row['prayer_revision_id'] as String?;
    final hasLibrarySource =
        libraryPrayerId != null &&
        personalPrayerId == null &&
        revisionId == null;
    final hasPersonalSource =
        libraryPrayerId == null &&
        personalPrayerId != null &&
        revisionId != null;
    if (!hasLibrarySource && !hasPersonalSource) {
      throw const FormatException('Prayer session must have one source');
    }

    return PrayerSession(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      prayer: hasLibrarySource
          ? PrayerReference.library(libraryPrayerId)
          : PrayerReference.personal(personalPrayerId!),
      prayerRevisionId: revisionId,
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
}
