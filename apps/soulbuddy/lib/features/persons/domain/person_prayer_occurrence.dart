import 'prayer_person.dart';

String personPrayerLocalDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class PersonPrayerOccurrence {
  const PersonPrayerOccurrence({
    required this.id,
    required this.personId,
    required this.ownerId,
    required this.localDate,
    required this.occurrenceKey,
    required this.prayedAt,
    required this.deviceId,
  });

  final String id;
  final String personId;
  final String ownerId;
  final String localDate;
  final String occurrenceKey;
  final DateTime prayedAt;
  final String deviceId;
}

class DuePersonPrayer {
  const DuePersonPrayer({required this.person, required this.occurrenceKey});

  final PrayerPerson person;
  final String occurrenceKey;
}
