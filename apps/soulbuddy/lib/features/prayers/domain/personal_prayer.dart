import 'library_prayer.dart';
import 'prayer_reference.dart';

enum PersonalPrayerContentFormat {
  text,
  audio;

  static PersonalPrayerContentFormat fromWire(String? value) => switch (value) {
    null || 'text' => PersonalPrayerContentFormat.text,
    'audio' => PersonalPrayerContentFormat.audio,
    _ => throw FormatException('Unknown personal prayer content format: $value'),
  };
}

class PersonalPrayer implements PrayerDisplay {
  const PersonalPrayer({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.style,
    required this.reach,
    required this.grounding,
    required this.purpose,
    required this.currentRevisionId,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.contentFormat = PersonalPrayerContentFormat.text,
    this.action,
    this.archivedAt,
  });

  @override
  final String id;
  final String ownerId;
  @override
  final String title;
  final String style;
  final String reach;
  @override
  final PrayerGrounding grounding;
  @override
  final PrayerPurpose purpose;
  final String currentRevisionId;
  final PersonalPrayerContentFormat contentFormat;
  bool get isAudio => contentFormat == PersonalPrayerContentFormat.audio;
  @override
  final String body;
  @override
  final String? action;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  @override
  PrayerReference get reference => PrayerReference.personal(id);

  @override
  int get helpfulCount => 0;

  @override
  bool get viewerMarkedHelpful => false;

  factory PersonalPrayer.fromRow(Map<String, dynamic> row) {
    return PersonalPrayer(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      title: row['title'] as String,
      style: row['style'] as String,
      reach: row['reach'] as String,
      grounding: PrayerGrounding.fromWire(row['grounding'] as String),
      purpose: PrayerPurpose.fromWire(row['purpose'] as String),
      currentRevisionId: row['current_revision_id'] as String,
      contentFormat: PersonalPrayerContentFormat.fromWire(
        row['content_format'] as String?,
      ),
      body: row['body'] as String,
      action: row['action'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      archivedAt: row['archived_at'] == null
          ? null
          : DateTime.parse(row['archived_at'] as String),
    );
  }
}
