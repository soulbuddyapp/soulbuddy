import '../domain/library_prayer.dart';
import '../domain/personal_prayer.dart';

abstract interface class PersonalPrayerRepository {
  Stream<List<PersonalPrayer>> watchAll();
  Stream<PersonalPrayer?> watch(String id);

  Future<PersonalPrayer> createOwnWords({
    required String title,
    required String body,
    String? action,
    PrayerGrounding grounding = PrayerGrounding.generalChristian,
    PrayerPurpose purpose = PrayerPurpose.daily,
  });

  Future<PersonalPrayer> accept({
    required String requestId,
    required String title,
    required String body,
    String? action,
  });
}
