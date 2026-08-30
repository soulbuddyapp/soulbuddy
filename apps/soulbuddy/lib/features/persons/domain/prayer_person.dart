enum PersonPrayerCadence {
  daily('daily'),
  weekly('weekly'),
  selectedDays('selected_days');

  const PersonPrayerCadence(this.wireValue);
  final String wireValue;

  factory PersonPrayerCadence.fromWire(String? value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => PersonPrayerCadence.daily,
  );
}

class PrayerPersonDraft {
  const PrayerPersonDraft({
    required this.name,
    this.relationship,
    this.cadence = PersonPrayerCadence.daily,
    this.localTime,
    this.timezone,
    this.weekdaysMask = 0,
  });

  final String name;
  final String? relationship;
  final PersonPrayerCadence cadence;
  final String? localTime;
  final String? timezone;
  final int weekdaysMask;
}

class PrayerPerson {
  const PrayerPerson({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.cadence,
    required this.weekdaysMask,
    required this.createdAt,
    required this.updatedAt,
    this.relationship,
    this.localTime,
    this.timezone,
    this.archivedAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String? relationship;
  final PersonPrayerCadence cadence;
  final String? localTime;
  final String? timezone;
  final int weekdaysMask;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  bool isScheduledOn(DateTime localDate) {
    if (cadence == PersonPrayerCadence.daily) return true;
    final dayBit = 1 << (localDate.weekday - 1);
    return weekdaysMask & dayBit != 0;
  }

  factory PrayerPerson.fromRow(Map<String, dynamic> row) => PrayerPerson(
    id: row['id'] as String,
    ownerId: row['owner_id'] as String,
    name: row['name'] as String,
    relationship: row['relationship'] as String?,
    cadence: PersonPrayerCadence.fromWire(row['cadence'] as String?),
    localTime: row['local_time'] as String?,
    timezone: row['timezone'] as String?,
    weekdaysMask: (row['weekdays_mask'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    archivedAt: switch (row['archived_at']) {
      final String value => DateTime.parse(value),
      _ => null,
    },
  );
}
