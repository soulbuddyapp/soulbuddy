import '../domain/person_prayer_occurrence.dart';
import '../domain/prayer_person.dart';
import '../../record/domain/encounter.dart';

abstract interface class PersonRepository {
  Stream<List<PrayerPerson>> watchActive();
  Stream<List<PrayerPerson>> watchForReminders();
  Stream<PrayerPerson?> watch(String id);
  Stream<List<DuePersonPrayer>> watchDue(DateTime localDate);
  Stream<List<Encounter>> watchLinkedMemories(String personId);
  Future<PrayerPerson> create(PrayerPersonDraft draft);
  Future<PrayerPerson> update(String id, PrayerPersonDraft draft);
  Future<void> archive(String id);
  Future<PersonPrayerOccurrence?> recordPrayer(
    String personId, {
    required DateTime localDate,
  });
}
